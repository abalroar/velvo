"""Varredura do histórico de leilões finalizados, casa a casa, em paralelo.

Fonte: <casa>/templates/listacatalogo/asp/catalogo-list.asp?final=1 lista os
leilões finalizados da casa com data (DT) e total (TOTALFINAL); paginamos até
o fim. Para cada leilão ainda ausente do banco, catalogocontentload.asp
devolve todos os lotes com martelo/lances/status.

Velocidade: rate limit é POR DOMÍNIO (http_client) e as casas são processadas
em paralelo (--workers). Cada servidor individual vê um ritmo educado; o ganho
de tempo vem de tocar muitas casas (servidores distintos) ao mesmo tempo.
Idempotente: re-rodar pula o que já existe (banco) e o que já foi baixado
(cache). Casas que respondem 403 são respeitadas e puladas. Casas sem
histórico (404/fora da plataforma) vão para recon_findings (dead_house).

Uso:
  python scrape_historico.py                  # tudo, até o talo
  python scrape_historico.py --days 30        # só a janela recente
  python scrape_historico.py --workers 12
"""
import argparse
import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta

import config
import db
import http_client
from scrape_finalizados import fetch_lots, store_auction_lots

# domínios de terceiros, alguns mortos/lentos: timeout/retries curtos
config.REQUEST_TIMEOUT = 15
config.MAX_RETRIES = 2

PAGE_LIMIT = 100

_print_lock = threading.Lock()
_agg_lock = threading.Lock()
_agg = {"auctions": 0, "lots": 0, "failures": 0, "blocked": 0, "houses": 0}


def log(msg: str):
    with _print_lock:
        print(msg, flush=True)


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
    return {r["url"] for r in conn.execute(
        "SELECT DISTINCT url FROM recon_findings WHERE kind='dead_house'")}


def process_house(domain: str, cutoff, done: set, n_total: int) -> None:
    """Processa uma casa inteira em sua própria conexão SQLite."""
    conn = db.connect()
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    try:
        hist = fetch_full_history(domain, cutoff)
    except http_client.BlockedError:
        with _agg_lock:
            _agg["blocked"] += 1
        _bump_house(n_total, domain, "bloqueada")
        return
    except Exception as exc:
        conn.execute("INSERT INTO recon_findings (url, kind, note, scraped_at) VALUES (?,?,?,?)",
                     (domain, "dead_house", str(exc)[:200], now))
        conn.commit()
        _bump_house(n_total, domain, "sem histórico")
        return

    targets = []
    for e in hist:
        d = parse_dt(e.get("DT", ""))
        aid = str(e.get("IDLEILAO"))
        if (cutoff and (not d or d < cutoff)) or (domain, aid) in done:
            continue
        targets.append((aid, e))

    a = lots = fails = 0
    consec_fail = 0
    blocked = False
    for aid, e in targets:
        if blocked or consec_fail >= 3:
            break
        leilao = {"NOME": None, "URL_SITE": e.get("URL_SITE") or f"https://www.{domain}/",
                  "ID": aid, "TITULO": e.get("TITULO"), "DATA_FIM": e.get("DT"),
                  "UF1": None, "UF2": None}
        try:
            pecas = fetch_lots(domain, aid)
            n = store_auction_lots(conn, leilao, pecas, now)
            conn.commit()
            a += 1
            lots += n
            consec_fail = 0
        except http_client.BlockedError:
            blocked = True
        except Exception:
            fails += 1
            consec_fail += 1
    with _agg_lock:
        _agg["auctions"] += a
        _agg["lots"] += lots
        _agg["failures"] += fails
        if blocked:
            _agg["blocked"] += 1
    note = f"{len(hist)} hist, {len(targets)} alvos -> {a} leilões / {lots} lotes"
    if blocked:
        note += " [BLOQUEADA->skip]"
    elif consec_fail >= 3:
        note += " [DISJUNTOR]"
    _bump_house(n_total, domain, note)


def _bump_house(n_total: int, domain: str, note: str):
    with _agg_lock:
        _agg["houses"] += 1
        i = _agg["houses"]
        tot = _agg
    log(f"  [{i}/{n_total}] {domain}: {note} "
        f"| acum {tot['auctions']} leilões / {tot['lots']} lotes")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=0, help="janela em dias (0 = completo)")
    ap.add_argument("--max-houses", type=int, default=0)
    ap.add_argument("--workers", type=int, default=config.MAX_WORKERS)
    args = ap.parse_args()
    cutoff = (datetime.now().date() - timedelta(days=args.days)) if args.days else None

    conn = db.connect()
    done = already_scraped(conn)
    skip = dead_houses(conn)
    houses = [r["house_domain"] for r in conn.execute(
        """SELECT h.house_domain,
                  EXISTS(SELECT 1 FROM lot_snapshots s WHERE s.house_domain=h.house_domain) known
           FROM auction_houses h ORDER BY known DESC, h.house_domain""")]
    houses = [h for h in houses if h not in skip]
    if args.max_houses:
        houses = houses[:args.max_houses]
    n_total = len(houses)
    log(f"{n_total} casas | cutoff: {cutoff or 'NENHUM (completo)'} | workers: {args.workers} "
        f"| leilões já no banco: {len(done)} | casas mortas memorizadas: {len(skip)}")

    t0 = time.time()
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futures = [ex.submit(process_house, d, cutoff, done, n_total) for d in houses]
        for fut in as_completed(futures):
            fut.result()
    log(f"\nVarredura: {_agg['auctions']} leilões novos, {_agg['lots']} lotes, "
        f"{_agg['failures']} falhas, {_agg['blocked']} casas bloqueadas, "
        f"em {(time.time()-t0)/60:.0f}min")


if __name__ == "__main__":
    main()
