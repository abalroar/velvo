"""Fase 0b: coleta leilões finalizados com PREÇO DE MARTELO REAL.

Descoberta do recon: a plataforma white-label expõe, no domínio de cada casa,
  templates/catalogo/asp/catalogocontentload.asp?leilao=<ID>&status=9&limit=N&remote=1
que devolve JSON com todos os lotes do leilão, incluindo VALOR_VENDA (martelo),
VALOR_CONTRATADO (lance inicial), QTDLANCE (nº de lances) e MOSTRABTN_STATUS
("Lote vendido" / "Não vendido"). A lista de finalizados (últimos ~15 dias) vem de
  https://d2khfqh5bqnqgx.cloudfront.net/12hor/leiloes_passados.asp?i=0

Isso dá sell-through e comparáveis de mercado REAIS — não apenas proxies.

Uso:
  python scrape_finalizados.py                # todos os finalizados disponíveis
  python scrape_finalizados.py --max 100      # amostra
"""
import argparse
import json
import re
import time
from datetime import datetime

import config
import db
import http_client

PASSADOS_URL = "https://d2khfqh5bqnqgx.cloudfront.net/12hor/leiloes_passados.asp?i=0"


def parse_int(v) -> int:
    try:
        return int(float(str(v).replace(".", "").replace(",", ".")))
    except (TypeError, ValueError):
        return 0


def parse_real(v) -> float:
    """Valores do JSON vêm como inteiros em reais (ex.: '11501' = R$ 11.501,00)."""
    try:
        return float(str(v).replace(".", "").replace(",", "."))
    except (TypeError, ValueError):
        return 0.0


def fetch_finalized_list() -> list[dict]:
    raw = http_client.get(PASSADOS_URL)
    data = json.loads(raw)
    if isinstance(data, str):
        data = json.loads(data)
    return data.get("LEILOES", [])


def domain_of(url_site: str) -> str:
    return re.sub(r"^https?://", "", (url_site or "")).strip("/").replace("www.", "").lower()


def content_url(domain: str, auction_id: str, limit: int = 600, host_prefix: str = "www.") -> str:
    return (
        f"https://{host_prefix}{domain}/templates/catalogo/asp/catalogocontentload.asp"
        f"?leilao={auction_id}&pesquisa=&irpara=&Dia=&Tipo=&artista="
        f"&Srt=0&Temtotal=&pag=1&limit={limit}&status=9&remote=1"
    )


def fetch_lots(domain: str, auction_id: str) -> list[dict]:
    """Tenta com e sem prefixo www (casas variam na config de host)."""
    last = None
    for prefix in ("www.", ""):
        try:
            raw = http_client.get(content_url(domain, auction_id, host_prefix=prefix))
            data = json.loads(raw)
            block = data.get("Catalogo") if isinstance(data, dict) else None
            return block[0].get("PECAS", []) if block else []
        except Exception as exc:
            last = exc
    raise last


def store_auction_lots(conn, leilao: dict, pecas: list[dict], now: str) -> int:
    domain = domain_of(leilao.get("URL_SITE"))
    auction_id = str(leilao.get("ID"))
    uf = leilao.get("UF1") or leilao.get("UF2")
    title = leilao.get("TITULO")
    name = leilao.get("NOME")
    dt_fim = leilao.get("DATA_FIM")

    conn.execute(
        """INSERT INTO auction_houses (house_domain, name, uf, first_seen, last_seen)
           VALUES (?,?,?,?,?)
           ON CONFLICT(house_domain) DO UPDATE SET
             name=COALESCE(excluded.name, name), uf=COALESCE(excluded.uf, uf),
             last_seen=excluded.last_seen""",
        (domain, name, uf, now, now))
    conn.execute(
        """INSERT INTO auctions (house_domain, auction_id, auction_datetime, uf, source_url, scraped_at)
           VALUES (?,?,?,?,?,?)
           ON CONFLICT(house_domain, auction_id) DO UPDATE SET
             uf=COALESCE(excluded.uf, uf)""",
        (domain, auction_id, dt_fim, uf, f"https://www.{domain}/", now))

    stored = 0
    for p in pecas:
        lot_id = str(p.get("ID"))
        if not lot_id or lot_id == "None":
            continue
        desc = p.get("DESCRICAO") or p.get("PECA") or p.get("MINI_DESCRICAO")
        sold = 1 if (p.get("MOSTRABTN_STATUS") == "Lote vendido") else 0
        hammer = parse_real(p.get("VALOR_VENDA")) if sold else None
        opening = parse_real(p.get("VALOR_CONTRATADO"))
        bids = parse_int(p.get("QTDLANCE"))
        conn.execute(
            """INSERT INTO lots (house_domain, lot_id, auction_id, title, uf,
                                 auction_datetime, lot_url, description, detail_scraped_at, first_seen)
               VALUES (?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(house_domain, lot_id) DO UPDATE SET
                 description=COALESCE(excluded.description, description),
                 title=COALESCE(lots.title, excluded.title),
                 detail_scraped_at=excluded.detail_scraped_at""",
            (domain, lot_id, auction_id, p.get("PECA") or desc, uf, dt_fim,
             f"https://www.{domain}/peca.asp?Id={lot_id}", desc, now, now))
        conn.execute(
            """INSERT OR REPLACE INTO lot_snapshots
               (house_domain, lot_id, scraped_at, lot_number, opening_bid_brl,
                current_bid_brl, hammer_price_brl, bid_count, sold, status, source)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (domain, lot_id, now, str(p.get("LOTE")), opening,
             hammer, hammer, bids, sold, "finalizado", "catalogo_finalizado"))
        stored += 1
    return stored


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--max", type=int, default=0, help="limite de leilões (0 = todos)")
    args = ap.parse_args()
    conn = db.connect()
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")

    leiloes = fetch_finalized_list()
    print(f"Leilões finalizados disponíveis: {len(leiloes)}")
    if args.max:
        leiloes = leiloes[:args.max]

    total_lots = 0
    failures = 0
    blocked_domains: set[str] = set()
    t0 = time.time()
    for i, leilao in enumerate(leiloes, 1):
        domain = domain_of(leilao.get("URL_SITE"))
        auction_id = str(leilao.get("ID"))
        if not domain or not auction_id:
            continue
        if domain in blocked_domains:
            continue  # casa pediu para não ser acessada (403): respeitar e pular
        try:
            pecas = fetch_lots(domain, auction_id)
            n = store_auction_lots(conn, leilao, pecas, now)
            total_lots += n
            conn.commit()
            if i % 20 == 0 or n == 0:
                print(f"  [{i}/{len(leiloes)}] {domain} #{auction_id}: {n} lotes "
                      f"(acum {total_lots})", flush=True)
        except http_client.BlockedError:
            # 403 é por-casa (domínios independentes): respeitar este host e seguir.
            blocked_domains.add(domain)
            print(f"  [BLOQUEADO->skip] {domain} bloqueia bots; pulando esta casa.", flush=True)
        except Exception as exc:
            failures += 1
            print(f"  [ERRO] {domain} #{auction_id}: {exc}", flush=True)
    print(f"\nFinalizados: {total_lots} lotes de {len(leiloes)} leilões "
          f"({failures} falhas, {len(blocked_domains)} casas bloqueadas) em {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
