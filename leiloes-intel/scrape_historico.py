"""Varredura do histórico de leilões finalizados, casa a casa.

Fonte: <casa>/templates/listacatalogo/asp/catalogo-list.asp?final=1 lista os
leilões finalizados da casa com data (DT) e total (TOTALFINAL); paginamos até
o fim. Para cada leilão ainda ausente do banco, catalogocontentload.asp
devolve todos os lotes com martelo/lances/status. Idempotente: re-rodar pula
o que já existe (banco) e o que já foi baixado (cache HTTP).

Casas que respondem 403 são puladas e respeitadas. Casas sem histórico (404 /
fora da plataforma) são memorizadas em recon_findings para re-runs rápidos.

Uso:
  python scrape_historico.py                # varredura completa (até o talo)
  python scrape_historico.py --days 30      # só a janela recente
  python scrape_historico.py --max-houses 50
"""
import argparse
import json
import time
from datetime import datetime, timedelta

import config
import db
import http_client
from scrape_finalizados import fetch_lots, store_auction_lots

# varredura cobre centenas de domínios de terceiros, alguns mortos/lentos:
# timeout e retries mais curtos evitam horas presas em hosts que não respondem
config.REQUEST_TIMEOUT = 15
config.MAX_RETRIES = 2

PAGE_LIMIT = 100


def list_url(domain: str, page: int, host_prefix: str) -> str:
    return (f"https://{host_prefix}{domain}/templates/listacatalogo/asp/catalogo-list.asp"
            f"?final=1&pag={page}&limit={PAGE_LIMIT}&leilao=")


def fetch_history_page(domain: str, page: int) -> list[dict]:
    last = None
    for prefix in ("www.", ""):
        try:
            raw = http_client.get(list_url(domain, page, prefix))
            data = json.loads(raw)
            block = data.get("Finalizado") or []
            return block[0].get("Leiloes", []) if block else []
        except http_client.BlockedError:
            raise
        except Exception as exc:
            last = exc
    raise last


def fetch_full_history(domain: str, cutoff) -> list[dict]:
    """Pagina o histórico da casa; para cedo se passar do cutoff (lista é
    ordenada do mais recente para o mais antigo)."""
    out, page = [], 1
    while True:
        entries = fetch_history_page(domain, page)
        if not entries:
            break
        out.extend(entries)
        total = int(entries[0].get("TOTALFINAL") or 0)
        oldest = parse_dt(entries[-1].get("DT", ""))
        if cutoff and oldest and oldest < cutoff:
            break
        if len(out) >= total or len(entries) < PAGE_LIMIT:
            break
        page += 1
    return out


def parse_dt(s: str):
    try:
        return datetime.strptime((s or "").strip(), "%d/%m/%Y").date()
    except ValueError:
        return None


def already_scraped(conn) -> set[tuple[str, str]]:
    rows = conn.execute(
        """SELECT DISTINCT l.house_domain, l.auction_id
           FROM lots l JOIN lot_snapshots s
             ON s.house_domain=l.house_domain AND s.lot_id=l.lot_id
           WHERE s.status='finalizado' AND l.auction_id IS NOT NULL""").fetchall()
    return {(r["house_domain"], str(r["auction_id"])) for r in rows}


def dead_houses(conn) -> set[str]:
    rows = conn.execute(
        "SELECT DISTINCT url FROM recon_findings WHERE kind='dead_house'").fetchall()
    return {r["url"] for r in rows}


def mark_dead(conn, domain: str, note: str):
    conn.execute("INSERT INTO recon_findings (url, kind, note, scraped_at) VALUES (?,?,?,?)",
                 (domain, "dead_house", note[:200],
                  datetime.now().strftime("%Y-%m-%dT%H:%M:%S")))
    conn.commit()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=0,
                    help="janela em dias (0 = histórico completo)")
    ap.add_argument("--max-houses", type=int, default=0)
    args = ap.parse_args()
    cutoff = (datetime.now().date() - timedelta(days=args.days)) if args.days else None

    conn = db.connect()
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    done = already_scraped(conn)
    skip = dead_houses(conn)
    # casas com dados conhecidos primeiro (plataforma confirmada), depois o resto
    houses = [r["house_domain"] for r in conn.execute(
        """SELECT h.house_domain,
                  EXISTS(SELECT 1 FROM lot_snapshots s WHERE s.house_domain=h.house_domain) known
           FROM auction_houses h ORDER BY known DESC, h.house_domain""")]
    houses = [h for h in houses if h not in skip]
    if args.max_houses:
        houses = houses[:args.max_houses]
    print(f"{len(houses)} casas a varrer | cutoff: {cutoff or 'NENHUM (completo)'} | "
          f"leilões já no banco: {len(done)} | casas mortas memorizadas: {len(skip)}",
          flush=True)

    total_lots = total_auctions = failures = 0
    blocked: set[str] = set()
    t0 = time.time()
    for i, domain in enumerate(houses, 1):
        try:
            hist = fetch_full_history(domain, cutoff)
        except http_client.BlockedError:
            blocked.add(domain)
            print(f"  [BLOQUEADO->skip] {domain}", flush=True)
            continue
        except Exception as exc:
            mark_dead(conn, domain, str(exc))
            continue
        targets = []
        for e in hist:
            d = parse_dt(e.get("DT", ""))
            aid = str(e.get("IDLEILAO"))
            if (cutoff and (not d or d < cutoff)) or (domain, aid) in done:
                continue
            targets.append((aid, e))
        consec_fail = 0
        for aid, e in targets:
            if domain in blocked or consec_fail >= 3:
                # endpoint da casa indisponível: não insistir leilão a leilão
                if consec_fail >= 3:
                    print(f"  [DISJUNTOR] {domain}: 3 falhas seguidas, pulando o resto", flush=True)
                break
            leilao = {"NOME": None, "URL_SITE": e.get("URL_SITE") or f"https://www.{domain}/",
                      "ID": aid, "TITULO": e.get("TITULO"), "DATA_FIM": e.get("DT"),
                      "UF1": None, "UF2": None}
            try:
                pecas = fetch_lots(domain, aid)
                n = store_auction_lots(conn, leilao, pecas, now)
                total_lots += n
                total_auctions += 1
                done.add((domain, aid))
                conn.commit()
                consec_fail = 0
            except http_client.BlockedError:
                blocked.add(domain)
                print(f"  [BLOQUEADO->skip] {domain}", flush=True)
            except Exception as exc:
                failures += 1
                consec_fail += 1
                if failures <= 30:
                    print(f"  [ERRO] {domain} #{aid}: {exc}", flush=True)
        elapsed = time.time() - t0
        print(f"  [{i}/{len(houses)}] {domain}: {len(hist)} no histórico, "
              f"{len(targets)} novos | acum {total_auctions} leilões / {total_lots} lotes "
              f"| {elapsed/60:.0f}min", flush=True)
    print(f"\nVarredura: {total_auctions} leilões novos, {total_lots} lotes, "
          f"{failures} falhas, {len(blocked)} casas bloqueadas, "
          f"em {(time.time()-t0)/60:.0f}min", flush=True)


if __name__ == "__main__":
    main()
