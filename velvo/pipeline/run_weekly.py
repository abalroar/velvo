"""gera a rodada semanal de candidatos e grava um seed.sql idempotente.

uso típico (na máquina onde está o sqlite cheio):
  python pipeline/run_weekly.py \
      --db /home/user/baratex/leiloes-intel/data/leiloes.sqlite \
      --out supabase/seed_weekly.sql

sem o sqlite, cai automaticamente no export slim (lots.parquet) + thumbnails do
cache http, então roda igual em qualquer container limpo.
"""
from __future__ import annotations

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import candidates as C  # noqa: E402
import weekly  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", help="caminho do leiloes.sqlite (fonte preferida)")
    ap.add_argument("--parquet", help="fallback: lots.parquet")
    ap.add_argument("--intel", default="/home/user/baratex/leiloes-intel",
                    help="raiz do projeto leiloes-intel (cache + exports)")
    ap.add_argument("--out", default=os.path.join(HERE, "..", "supabase", "seed_weekly.sql"))
    ap.add_argument("--limit", type=int, default=600)
    ap.add_argument("--batch", help="batch_id manual (default: semana iso, ex 2026-w24)")
    args = ap.parse_args()

    cands, batch_id, refreshed_at, source, n_rows = weekly.generate_batch(
        args.db, args.parquet, args.intel, args.limit, args.batch)

    sql = C.to_seed_sql(cands, batch_id, refreshed_at)
    out = os.path.abspath(args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        f.write(sql)

    print(f"fonte:        {source}  ({n_rows} lotes ao vivo lidos)")
    print(f"batch_id:     {batch_id}")
    print(f"refreshed_at: {refreshed_at}")
    print(weekly.summarize(cands))
    print(f"seed escrito: {out}")


if __name__ == "__main__":
    main()
