"""Expansão histórica: coleta leilões finalizados além da janela de ~15 dias
do agregador, varrendo o histórico público de cada casa.

Fonte: <casa>/templates/listacatalogo/asp/catalogo-list.asp?final=1 lista TODOS
os leilões finalizados da casa com data (DT). Filtramos pela janela (--days) e
buscamos os lotes só dos leilões que ainda não estão no banco (idempotente:
re-rodar não duplica snapshots).

Uso:
  python scrape_historico.py --days 30
"""
import argparse
import json
import time
from datetime import datetime, timedelta

import db
import http_client
from scrape_finalizados import domain_of, fetch_lots, store_auction_lots


def list_url(domain: str, page: int = 1, limit: int = 100, host_prefix: str = "www.") -> str:
    return (f"https://{host_prefix}{domain}/templates/listacatalogo/asp/catalogo-list.asp"
            f"?final=1&pag={page}&limit={limit}&leilao=")


def fetch_house_history(domain: str) -> list[dict]:
    last = None
    for prefix in ("www.", ""):
        try:
            raw = http_client.get(list_url(domain, host_prefix=prefix))
            data = json.loads(raw)
            block = data.get("Finalizado") or []
            return block[0].get("Leiloes", []) if block else []
        except Exception as exc:
            last = exc
    raise last


def parse_dt(s: str):
    try:
        return datetime.strptime(s.strip(), "%d/%m/%Y").date()
    except (ValueError, AttributeError):
        return None


def already_scraped(conn) -> set[tuple[str, str]]:
    rows = conn.execute(
        """SELECT DISTINCT l.house_domain, l.auction_id
           FROM lots l JOIN lot_snapshots s
             ON s.house_domain=l.house_domain AND s.lot_id=l.lot_id
           WHERE s.status='finalizado' AND l.auction_id IS NOT NULL""").fetchall()
    return {(r["house_domain"], str(r["auction_id"])) for r in rows}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=30)
    args = ap.parse_args()
    cutoff = datetime.now().date() - timedelta(days=args.days)

    conn = db.connect()
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    houses = [r["house_domain"] for r in
              conn.execute("SELECT house_domain FROM auction_houses ORDER BY house_domain")]
    done = already_scraped(conn)
    print(f"{len(houses)} casas | janela: desde {cutoff} | leilões já no banco: {len(done)}")

    targets = []
    blocked, no_history = set(), 0
    for i, domain in enumerate(houses, 1):
        try:
            hist = fetch_house_history(domain)
        except http_client.BlockedError:
            blocked.add(domain)
            print(f"  [BLOQUEADO->skip] {domain}")
            continue
        except Exception:
            no_history += 1
            continue
        for e in hist:
            d = parse_dt(e.get("DT", ""))
            aid = str(e.get("IDLEILAO"))
            if d and d >= cutoff and (domain, aid) not in done:
                targets.append({"domain": domain, "id": aid, "dt": e.get("DT"),
                                "titulo": e.get("TITULO"), "url_site": e.get("URL_SITE")})
        if i % 40 == 0:
            print(f"  [{i}/{len(houses)}] casas varridas; {len(targets)} leilões novos na janela",
                  flush=True)

    print(f"\nHistórico: {len(targets)} leilões novos para coletar "
          f"({no_history} casas sem histórico/fora da plataforma, {len(blocked)} bloqueadas)")

    total, failures = 0, 0
    t0 = time.time()
    for i, t in enumerate(targets, 1):
        if t["domain"] in blocked:
            continue
        leilao = {"NOME": None, "URL_SITE": t["url_site"] or f"https://www.{t['domain']}/",
                  "ID": t["id"], "TITULO": t["titulo"], "DATA_FIM": t["dt"],
                  "UF1": None, "UF2": None}
        try:
            pecas = fetch_lots(t["domain"], t["id"])
            n = store_auction_lots(conn, leilao, pecas, now)
            total += n
            conn.commit()
            if i % 25 == 0:
                print(f"  [{i}/{len(targets)}] acum {total} lotes", flush=True)
        except http_client.BlockedError:
            blocked.add(t["domain"])
            print(f"  [BLOQUEADO->skip] {t['domain']}", flush=True)
        except Exception as exc:
            failures += 1
            print(f"  [ERRO] {t['domain']} #{t['id']}: {exc}", flush=True)
    print(f"\nHistórico coletado: {total} lotes novos de {len(targets)} leilões "
          f"({failures} falhas) em {time.time()-t0:.0f}s")


if __name__ == "__main__":
    main()
