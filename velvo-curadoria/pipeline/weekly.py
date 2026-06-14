"""orquestração da rodada semanal, compartilhada por run_weekly.py (gera
seed.sql) e push_weekly.py (envia direto ao supabase)."""
from __future__ import annotations

import glob
import json
import os
import sys
from datetime import datetime

import candidates as C


def _ensure_cache_extracted(intel_dir: str) -> str:
    """num clone limpo o cache http vem compactado em data/checkpoint/.
    extrai sob demanda para que o fallback parquet recupere as imagens."""
    cache_dir = os.path.join(intel_dir, "cache")
    has_meta = os.path.isdir(cache_dir) and any(
        f.endswith(".meta.json") for f in os.listdir(cache_dir))
    if has_meta:
        return cache_dir
    parts = sorted(glob.glob(os.path.join(intel_dir, "data/checkpoint/cache.tar.gz.part*")))
    if not parts:
        return cache_dir
    import tarfile
    tmp = os.path.join(intel_dir, "data/checkpoint/_cache.tar.gz")
    with open(tmp, "wb") as out:
        for p in parts:
            with open(p, "rb") as f:
                out.write(f.read())
    os.makedirs(cache_dir, exist_ok=True)
    with tarfile.open(tmp, "r:gz") as tar:
        tar.extractall(cache_dir)
    os.remove(tmp)
    return cache_dir


def _thumb_map_from_cache(intel_dir: str) -> dict:
    """recupera thumbnails das páginas busca_andamento cacheadas (fallback
    parquet). só usado quando o sqlite cheio não está disponível."""
    cache_dir = _ensure_cache_extracted(intel_dir)
    if not os.path.isdir(cache_dir):
        return {}
    sys.path.insert(0, intel_dir)
    try:
        from bs4 import BeautifulSoup
        sys.argv = ["x"]
        import scrape_listings as sl
    except Exception:
        return {}
    thumb: dict[str, str] = {}
    for meta in glob.glob(os.path.join(cache_dir, "*.meta.json")):
        try:
            url = json.load(open(meta))["url"]
        except Exception:
            continue
        if "busca_andamento" not in url:
            continue
        html = open(meta[:-10] + ".html", encoding="utf-8").read()
        for card in BeautifulSoup(html, "lxml").select("div.mostbidded"):
            row = sl.parse_card(card, "weekly")
            if row and row.get("thumbnail_url"):
                thumb[f"{row['house_domain']}|{int(row['lot_id'])}"] = row["thumbnail_url"]
    return thumb


def resolve_rows(db: str | None, parquet: str | None, intel: str) -> tuple[list[dict], str]:
    """devolve (linhas, fonte). prioriza o sqlite cheio; cai no parquet."""
    if db and os.path.exists(db):
        return C.read_live_rows_from_sqlite(db), f"sqlite:{db}"
    if not parquet:
        parquet = os.path.join(intel, "data/exports/lots.parquet")
    if not os.path.exists(parquet):
        raise SystemExit(
            f"nenhuma fonte de dados encontrada.\n  sqlite: {db}\n  parquet: {parquet}")
    thumb = _thumb_map_from_cache(intel)
    return C.read_live_rows_from_parquet(parquet, thumb), f"parquet:{parquet}"


def generate_batch(db, parquet, intel, limit, batch_id=None):
    rows, source = resolve_rows(db, parquet, intel)
    now = datetime.now()
    batch_id = batch_id or C.iso_week(now)
    refreshed_at = C.now_utc_iso()
    cands = C.build_candidates(rows, batch_id, refreshed_at, limit=limit)
    return cands, batch_id, refreshed_at, source, len(rows)


def summarize(cands: list[dict]) -> str:
    from collections import Counter
    pr = Counter(c["priority"] for c in cands)
    rk = Counter(c["risk"] for c in cands)
    vibe = sum(1 for c in cands if c["payload"].get("item_type") in C.VIBE_TYPES)
    buy = sum(1 for c in cands if (c["payload"].get("signal") or "") == "BUY_NOW")
    img = sum(1 for c in cands if c["image_url"])
    return (
        f"candidatos: {len(cands)}\n"
        f"  com imagem:   {img}\n"
        f"  vibe decorativa: {vibe}\n"
        f"  buy_now:      {buy}\n"
        f"  prioridade:   alta={pr['alta']} media={pr['media']} baixa={pr['baixa']}\n"
        f"  risco:        baixo={rk['baixo']} medio={rk['medio']} alto={rk['alto']}"
    )
