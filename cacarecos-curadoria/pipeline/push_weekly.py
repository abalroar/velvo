"""envia a rodada semanal direto ao supabase via api rest, com a service role
key (server-side; nunca vai pro browser).

uso:
  SUPABASE_URL=https://xxxx.supabase.co \
  SUPABASE_SERVICE_ROLE_KEY=eyJ... \
  python pipeline/push_weekly.py \
      --db /home/user/baratex/leiloes-intel/data/leiloes.sqlite

faz upsert em curation_candidates (on conflict candidate_id), arquiva os
candidatos queued de rodadas anteriores e nunca toca em curator_decisions.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import weekly  # noqa: E402


def _req(method: str, url: str, key: str, body=None, prefer=None) -> bytes:
    headers = {
        "apikey": key,
        "authorization": f"Bearer {key}",
        "content-type": "application/json",
    }
    if prefer:
        headers["prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", help="caminho do leiloes.sqlite (fonte preferida)")
    ap.add_argument("--parquet")
    ap.add_argument("--intel", default="/home/user/baratex/leiloes-intel")
    ap.add_argument("--limit", type=int, default=600)
    ap.add_argument("--batch")
    ap.add_argument("--chunk", type=int, default=200)
    args = ap.parse_args()

    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise SystemExit("defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no ambiente.")

    cands, batch_id, refreshed_at, source, n_rows = weekly.generate_batch(
        args.db, args.parquet, args.intel, args.limit, args.batch)
    print(f"fonte: {source}  ({n_rows} lotes) | batch_id: {batch_id}")
    print(weekly.summarize(cands))

    endpoint = f"{url}/rest/v1/curation_candidates"
    rows = [{
        "candidate_id": c["candidate_id"],
        "product_slug": c["product_slug"],
        "batch_id": c["batch_id"],
        "title": c["title"],
        "price_brl": c["price_brl"],
        "price_label": c["price_label"],
        "source_house": c["source_house"],
        "source_url": c["source_url"],
        "image_url": c["image_url"],
        "auction_ends": c["auction_ends"],
        "score": c["score"],
        "priority": c["priority"],
        "risk": c["risk"],
        "headroom": c["headroom"],
        "bid_count": c["bid_count"],
        "status": "queued",
        "payload": c["payload"],
        "refreshed_at": c["refreshed_at"],
    } for c in cands]

    sent = 0
    for i in range(0, len(rows), args.chunk):
        chunk = rows[i:i + args.chunk]
        _req("POST", f"{endpoint}?on_conflict=candidate_id", key, chunk,
             prefer="resolution=merge-duplicates,return=minimal")
        sent += len(chunk)
        print(f"  upsert {sent}/{len(rows)}")

    # arquiva candidatos queued de rodadas anteriores (saem da feed; viram histórico)
    patch = f"{endpoint}?batch_id=neq.{batch_id}&status=eq.queued"
    _req("PATCH", patch, key, {"status": "archived"}, prefer="return=minimal")
    print("rodadas anteriores arquivadas; curator_decisions intacto.")
    print(f"ok: {sent} candidatos no supabase para o batch {batch_id}.")


if __name__ == "__main__":
    main()
