"""helper de verificação/dev: reconstrói data/leiloes.sqlite a partir dos
exports versionados (lots.parquet) + thumbnails recuperadas do cache http.

por que existe: o sqlite cheio (~920mb) é regenerável e não vai pro git
("sqlite gigante fora"). num container limpo ele não está presente, mas o
parquet slim + o cache http versionado contêm os lotes ao vivo com toda a
economia e as imagens cloudfront. este script remonta o suficiente para que
`run_weekly.py --db .../leiloes.sqlite` rode idêntico ao ambiente real.

na sua máquina, onde o leiloes.sqlite real existe, NÃO precisa rodar isto.

uso:
  python pipeline/build_sqlite_from_exports.py \
      --intel /home/user/baratex/leiloes-intel \
      --out  /home/user/baratex/leiloes-intel/data/leiloes.sqlite
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sqlite3
import sys
from datetime import datetime


def build_thumb_map(intel_dir: str) -> dict:
    """re-parseia as páginas busca_andamento já cacheadas para recuperar
    (house_domain|lot_id) -> thumbnail_url (cloudfront)."""
    sys.path.insert(0, intel_dir)
    from bs4 import BeautifulSoup  # noqa: E402
    sys.argv = ["x"]
    import scrape_listings as sl  # noqa: E402

    cache_dir = os.path.join(intel_dir, "cache")
    thumb: dict[str, str] = {}
    for meta in glob.glob(os.path.join(cache_dir, "*.meta.json")):
        try:
            url = json.load(open(meta))["url"]
        except Exception:
            continue
        if "busca_andamento" not in url:
            continue
        html = open(meta[:-10] + ".html", encoding="utf-8").read()
        soup = BeautifulSoup(html, "lxml")
        for card in soup.select("div.mostbidded"):
            row = sl.parse_card(card, "rebuild")
            if row and row.get("thumbnail_url"):
                thumb[f"{row['house_domain']}|{int(row['lot_id'])}"] = row["thumbnail_url"]
    return thumb


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--intel", default="/home/user/baratex/leiloes-intel")
    ap.add_argument("--out", default="/home/user/baratex/leiloes-intel/data/leiloes.sqlite")
    args = ap.parse_args()

    import pyarrow.parquet as pq

    sys.path.insert(0, args.intel)
    import db as intel_db  # reaproveita o SCHEMA real  # noqa: E402

    parquet = os.path.join(args.intel, "data/exports/lots.parquet")
    print(f"lendo {parquet} ...")
    cols = [
        "house_domain", "lot_id", "title", "uf", "auction_datetime",
        "item_type_normalized", "macro_category", "designer",
        "attribution_strength", "status", "current_bid_brl", "bid_count",
        "excluded_sensitive", "est_resale_base", "est_gross_margin_pct",
        "max_bid_40pct", "signal",
    ]
    rows = pq.read_table(parquet, columns=cols).to_pylist()
    live = [r for r in rows if r["status"] == "andamento" and not r["excluded_sensitive"]]
    print(f"lotes ao vivo (andamento, não-sensíveis): {len(live)}")

    print("recuperando thumbnails do cache http ...")
    thumb = build_thumb_map(args.intel)
    print(f"thumbnails recuperadas: {len(thumb)}")

    if os.path.exists(args.out):
        os.remove(args.out)
    conn = sqlite3.connect(args.out)
    conn.executescript(intel_db.SCHEMA)
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

    houses, auctions = set(), set()
    for r in live:
        house = r["house_domain"]
        lot_id = int(r["lot_id"])
        key = f"{house}|{lot_id}"
        if house not in houses:
            conn.execute(
                "INSERT OR IGNORE INTO auction_houses (house_domain, name, first_seen, last_seen)"
                " VALUES (?,?,?,?)", (house, None, now, now))
            houses.add(house)
        conn.execute(
            "INSERT OR IGNORE INTO lots (house_domain, lot_id, title, uf, auction_datetime,"
            " lot_url, thumbnail_url, excluded_sensitive, first_seen) VALUES (?,?,?,?,?,?,?,0,?)",
            (house, lot_id, r["title"], r["uf"], r["auction_datetime"],
             f"https://{house}/peca.asp?Id={lot_id}", thumb.get(key), now))
        conn.execute(
            "INSERT OR REPLACE INTO lot_snapshots (house_domain, lot_id, scraped_at,"
            " current_bid_brl, bid_count, status, source) VALUES (?,?,?,?,?, 'andamento','rebuild')",
            (house, lot_id, now, r["current_bid_brl"], r["bid_count"]))
        conn.execute(
            "INSERT OR REPLACE INTO lot_enrichment (house_domain, lot_id, item_type_normalized,"
            " macro_category, designer, attribution_strength, est_resale_base,"
            " est_gross_margin_pct, max_bid_40pct, signal) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (house, lot_id, r["item_type_normalized"], r["macro_category"], r["designer"],
             r["attribution_strength"], r["est_resale_base"], r["est_gross_margin_pct"],
             r["max_bid_40pct"], r["signal"]))
    conn.commit()
    n = conn.execute("SELECT COUNT(*) FROM lots").fetchone()[0]
    with_img = conn.execute("SELECT COUNT(*) FROM lots WHERE thumbnail_url IS NOT NULL").fetchone()[0]
    conn.close()
    print(f"ok: {args.out}  ({n} lotes, {with_img} com imagem)")


if __name__ == "__main__":
    main()
