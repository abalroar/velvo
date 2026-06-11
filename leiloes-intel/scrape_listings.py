"""Fases 1-2: valida categorias-alvo e coleta as listagens paginadas de
busca_andamento.asp (fonte de verdade para lance atual / nº de lances).

Uso:
  python scrape_listings.py                 # todas as categorias-alvo
  python scrape_listings.py --category Mesa # uma categoria
  python scrape_listings.py --no-cache      # força re-snapshot (fase 5)
"""
import argparse
import math
import re
import sys
import time
from datetime import datetime
from urllib.parse import urlparse

from bs4 import BeautifulSoup

import config
import db
import http_client

COUNT_RE = re.compile(r"<b>([\d.]+)</b></span>\s*Itens encontrados", re.I)
DATE_RE = re.compile(r"(\d{1,2})/(\d{1,2})/(\d{4})\s*-\s*(\d{1,2})h")
LOT_LINK_RE = re.compile(r"abre_catalogo\.asp\?t=1\|([^|]+)\|(\d+)\|(\d+)")


def parse_brl(text: str) -> float | None:
    m = re.search(r"R\$\s*([\d.]+,\d{2})", text)
    if not m:
        return None
    return float(m.group(1).replace(".", "").replace(",", "."))


def parse_card(card, now: str) -> dict | None:
    link = card.find("a", href=LOT_LINK_RE)
    if not link:
        return None
    house_url, auction_id, lot_id = LOT_LINK_RE.search(link["href"]).groups()
    house_domain = urlparse(house_url).netloc.replace("www.", "").lower()

    title = None
    title_a = card.select_one("div.product-title a[title]")
    if title_a:
        title = title_a["title"].strip()
    if not title:
        img = card.find("img", alt=True)
        title = (img["alt"].strip() if img else None)

    price_el = card.select_one("div.venda-price")
    current_bid = parse_brl(price_el.get_text()) if price_el else None

    bid_el = card.select_one("p.bid-text")
    bid_count = 0
    if bid_el:
        m = re.search(r"(\d+)\s+Lance", bid_el.get_text())
        bid_count = int(m.group(1)) if m else 0

    dt_iso, uf = None, None
    for info in card.select("div.mostbidded__info"):
        txt = info.get_text(" ", strip=True)
        m = DATE_RE.search(txt)
        if m:
            d, mo, y, h = (int(g) for g in m.groups())
            dt_iso = f"{y:04d}-{mo:02d}-{d:02d}T{h:02d}:00"
            uf_el = info.select_one("span.pesq-uf")
            if uf_el:
                uf = uf_el.get_text(strip=True)

    house_name = None
    house_a = card.select_one(f'div.mostbidded__info a[href*="{house_domain}"]')
    if house_a:
        house_name = house_a.get_text(strip=True)

    img = card.find("img", src=True)
    return {
        "house_domain": house_domain,
        "house_url": house_url,
        "house_name": house_name,
        "auction_id": auction_id,
        "lot_id": lot_id,
        "title": title,
        "current_bid": current_bid,
        "bid_count": bid_count,
        "auction_datetime": dt_iso,
        "uf": uf,
        "thumbnail_url": img["src"] if img else None,
        "lot_url": f"https://{house_domain}/peca.asp?Id={lot_id}",
        "scraped_at": now,
    }


def upsert_lot(conn, row: dict, category: str):
    conn.execute(
        """INSERT INTO auction_houses (house_domain, name, first_seen, last_seen)
           VALUES (?,?,?,?)
           ON CONFLICT(house_domain) DO UPDATE SET
             name=COALESCE(excluded.name, name), last_seen=excluded.last_seen""",
        (row["house_domain"], row["house_name"], row["scraped_at"], row["scraped_at"]))
    conn.execute(
        """INSERT INTO auctions (house_domain, auction_id, auction_datetime, uf, source_url, scraped_at)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(house_domain, auction_id) DO UPDATE SET
             auction_datetime=COALESCE(excluded.auction_datetime, auction_datetime),
             uf=COALESCE(excluded.uf, uf)""",
        (row["house_domain"], row["auction_id"], row["auction_datetime"],
         row["uf"], row["house_url"], row["scraped_at"]))
    conn.execute(
        """INSERT INTO lots (house_domain, lot_id, auction_id, title, uf,
                             auction_datetime, lot_url, thumbnail_url, first_seen)
           VALUES (?,?,?,?,?,?,?,?,?)
           ON CONFLICT(house_domain, lot_id) DO UPDATE SET
             title=COALESCE(excluded.title, title),
             auction_datetime=COALESCE(excluded.auction_datetime, auction_datetime),
             uf=COALESCE(excluded.uf, uf)""",
        (row["house_domain"], row["lot_id"], row["auction_id"], row["title"],
         row["uf"], row["auction_datetime"], row["lot_url"],
         row["thumbnail_url"], row["scraped_at"]))
    conn.execute(
        "INSERT OR IGNORE INTO lot_categories (house_domain, lot_id, category) VALUES (?,?,?)",
        (row["house_domain"], row["lot_id"], category))
    conn.execute(
        """INSERT OR REPLACE INTO lot_snapshots
           (house_domain, lot_id, scraped_at, current_bid_brl, bid_count, status, source)
           VALUES (?,?,?,?,?,?,?)""",
        (row["house_domain"], row["lot_id"], row["scraped_at"],
         row["current_bid"], row["bid_count"], "andamento", "busca_andamento"))


def scrape_category(conn, category: str, use_cache: bool, per_page: int = 126) -> tuple[int, int]:
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    html = http_client.get(config.search_url(category, 1, per_page), use_cache=use_cache)
    m = COUNT_RE.search(html)
    total = int(m.group(1).replace(".", "")) if m else 0
    pages = max(1, math.ceil(total / per_page)) if total else 1
    parsed = 0
    for page in range(1, pages + 1):
        if page > 1:
            html = http_client.get(config.search_url(category, page, per_page), use_cache=use_cache)
        soup = BeautifulSoup(html, "lxml")
        cards = soup.select("div.mostbidded")
        for card in cards:
            row = parse_card(card, now)
            if row:
                upsert_lot(conn, row, category)
                parsed += 1
        conn.commit()
        print(f"  {category}: pág {page}/{pages} — {len(cards)} cards", flush=True)
    conn.execute(
        """INSERT OR REPLACE INTO categories_map (category, hex_code, item_count, pages_fetched, scraped_at)
           VALUES (?,?,?,?,?)""",
        (category, config.category_hex(category), total, pages, now))
    conn.commit()
    return total, parsed


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--category", action="append")
    ap.add_argument("--no-cache", action="store_true")
    args = ap.parse_args()
    cats = args.category or config.TARGET_CATEGORIES
    conn = db.connect()
    failures = []
    t0 = time.time()
    for cat in cats:
        try:
            total, parsed = scrape_category(conn, cat, use_cache=not args.no_cache)
            print(f"[OK] {cat}: {total} itens declarados, {parsed} cards parseados", flush=True)
            if total and parsed < total * 0.9:
                print(f"  [WARN] {cat}: parse abaixo de 90% ({parsed}/{total})", flush=True)
        except http_client.BlockedError as exc:
            print(f"[BLOQUEADO] {exc} — abortando coleta.", flush=True)
            sys.exit(2)
        except Exception as exc:
            failures.append((cat, str(exc)))
            print(f"[ERRO] {cat}: {exc}", flush=True)
    n = conn.execute("SELECT COUNT(*) c FROM lots").fetchone()["c"]
    print(f"\nTotal de lotes únicos no banco: {n} | tempo {time.time()-t0:.0f}s")
    if failures:
        print("Categorias com erro:", failures)


if __name__ == "__main__":
    main()
