"""Orquestrador do funil de curadoria — roda sozinho (cron) e renova a fila.

Estágio 0 (SQL) -> economia -> Estágio 1 (similaridade visual, opcional) ->
score -> grava no Supabase (upsert idempotente) e num JSON local de inspeção.

A curadora nunca vê este passo: ela só consome a fila pronta no site.

Uso:
  python run_pipeline.py --db ../../leiloes-intel/data/leiloes.sqlite
  python run_pipeline.py --db <...> --no-visual      # pula CLIP (rápido)
  python run_pipeline.py --db <...> --seed-only       # só JSON local, sem Supabase

Variáveis de ambiente p/ Supabase: SUPABASE_URL, SUPABASE_SERVICE_KEY.
"""
import argparse
import json
import math
import os
from datetime import datetime, timezone
from pathlib import Path

import config
import economics
import stage0_filter

OUT = Path(__file__).parent / "out"
ANTONIO_IMAGES = Path(__file__).parent / "antonio_images.txt"


def _deadline_score(auction_dt: str | None) -> float:
    """1.0 = fecha em <=1 dia; decai até 0 em ~14 dias; 0.3 se sem data."""
    if not auction_dt:
        return 0.3
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(auction_dt[:19], fmt)
            break
        except ValueError:
            dt = None
    if dt is None:
        return 0.3
    days = (dt - datetime.now()).total_seconds() / 86400
    if days <= 1:
        return 1.0
    if days >= 14:
        return 0.1
    return max(0.1, 1.0 - (days - 1) / 13)


def score(cand: dict) -> float:
    margin = min(1.0, max(0.0, cand["est_margin_pct"]))
    visual = cand.get("antonio_fit_visual")
    deadline = _deadline_score(cand.get("auction_datetime"))
    if visual is None:
        # sem visão: redistribui o peso visual para a margem
        return round((config.W_MARGIN + config.W_VISUAL) * margin
                     + config.W_DEADLINE * deadline, 4)
    return round(config.W_MARGIN * margin
                 + config.W_VISUAL * visual
                 + config.W_DEADLINE * deadline, 4)


def candidate_id(cand: dict) -> str:
    return f"{cand['house_domain']}|{cand['lot_id']}"


def build_queue(db_path: str, use_visual: bool) -> list[dict]:
    print(f"[stage0] lendo lotes ao vivo de {db_path} ...", flush=True)
    raw = stage0_filter.fetch_live_candidates(db_path)
    print(f"[stage0] candidatos pós-filtro categoria/porte: {len(raw)}", flush=True)

    comp_file = Path(__file__).parent / "comp_medians.json"
    if comp_file.exists():
        comps = json.loads(comp_file.read_text())
        print(f"[economics] comps de {comp_file.name}: {len(comps)} categorias", flush=True)
    else:
        comps = stage0_filter.category_comp_medians(db_path)
        print(f"[economics] comps do banco: {len(comps)} categorias", flush=True)
    evaluated = [c for c in (economics.evaluate(r, comps) for r in raw) if c]
    print(f"[economics] sobrevivem aos cortes de margem/lance: {len(evaluated)}", flush=True)

    if use_visual and ANTONIO_IMAGES.exists():
        import stage1_embed
        ant = [u.strip() for u in ANTONIO_IMAGES.read_text().splitlines() if u.strip()]
        print(f"[stage1] similaridade visual c/ {len(ant)} fotos do Antônio ...", flush=True)
        fits = stage1_embed.antonio_fit([c["thumbnail_url"] for c in evaluated], ant)
        for c, f in zip(evaluated, fits):
            c["antonio_fit_visual"] = f
        n = sum(1 for c in evaluated if c.get("antonio_fit_visual") is not None)
        print(f"[stage1] {n}/{len(evaluated)} com score visual", flush=True)
    else:
        for c in evaluated:
            c["antonio_fit_visual"] = None
        print("[stage1] pulado (--no-visual ou deps ausentes)", flush=True)

    for c in evaluated:
        c["candidate_id"] = candidate_id(c)
        c["score"] = score(c)
        c["suggested_name"] = None  # estágio 2 (Claude) — futuro
        c["refreshed_at"] = datetime.now(timezone.utc).isoformat()

    evaluated.sort(key=lambda c: c["score"], reverse=True)
    return evaluated[: config.QUEUE_LIMIT]


COLUMNS = [
    "candidate_id", "house_domain", "lot_id", "title", "thumbnail_url", "lot_url",
    "uf", "item_type", "size_class", "material", "period_hint", "condition_tier",
    "is_pair_or_set", "designer", "attribution_strength", "auction_datetime",
    "current_bid_brl", "bid_count", "comp_median", "retail_anchor",
    "est_allin_cost", "est_margin_pct", "max_bid_brl", "antonio_fit_visual",
    "suggested_name", "score", "refreshed_at",
]


def to_rows(queue: list[dict]) -> list[dict]:
    return [{k: c.get(k) for k in COLUMNS} for c in queue]


def write_seed(rows: list[dict]):
    OUT.mkdir(parents=True, exist_ok=True)
    p = OUT / "queue_seed.json"
    p.write_text(json.dumps(rows, ensure_ascii=False, indent=2))
    print(f"[out] {len(rows)} candidatos -> {p}", flush=True)


def push_supabase(rows: list[dict]):
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not (url and key):
        print("[supabase] SUPABASE_URL/SUPABASE_SERVICE_KEY ausentes — pulando upsert.", flush=True)
        return
    import urllib.request

    endpoint = f"{url.rstrip('/')}/rest/v1/candidates?on_conflict=candidate_id"
    # sanitiza NaN/inf p/ JSON válido
    clean = [{k: (None if isinstance(v, float) and not math.isfinite(v) else v)
              for k, v in r.items()} for r in rows]
    body = json.dumps(clean, ensure_ascii=False).encode()
    req = urllib.request.Request(endpoint, data=body, method="POST", headers={
        "apikey": key, "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    })
    with urllib.request.urlopen(req, timeout=60) as resp:
        print(f"[supabase] upsert {len(clean)} candidatos -> HTTP {resp.status}", flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True, help="caminho do leiloes.sqlite")
    ap.add_argument("--no-visual", action="store_true", help="pula estágio 1 (CLIP)")
    ap.add_argument("--seed-only", action="store_true", help="só JSON local, sem Supabase")
    args = ap.parse_args()

    queue = build_queue(args.db, use_visual=not args.no_visual)
    rows = to_rows(queue)
    write_seed(rows)
    if not args.seed_only:
        push_supabase(rows)
    print("[done]", flush=True)


if __name__ == "__main__":
    main()
