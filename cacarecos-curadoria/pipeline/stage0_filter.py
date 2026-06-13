"""Estágio 0 — pré-filtro determinístico (SQL), sem IA.

Lê os lotes AO VIVO ('andamento') do banco do leiloes-intel, junta a
classificação semântica (lot_enrichment) e o lance atual (último snapshot), e
devolve só o que tem cara de revenda: categoria-alvo, porte aceito, com foto,
não-sensível. É a etapa que torna tudo barato — derruba ~8,5 mil para algumas
centenas antes de qualquer embedding.
"""
import sqlite3

import config


def fetch_live_candidates(db_path: str) -> list[dict]:
    c = sqlite3.connect(db_path)
    c.row_factory = sqlite3.Row
    placeholders = ",".join("?" for _ in config.FIT_ITEM_TYPES)
    sizes = ",".join("?" for _ in config.FIT_SIZE_CLASSES)
    rows = c.execute(
        f"""
        WITH live AS (
            SELECT l.house_domain, l.lot_id, l.title, l.thumbnail_url, l.lot_url,
                   l.uf, l.auction_datetime,
                   (SELECT s.current_bid_brl FROM lot_snapshots s
                     WHERE s.house_domain=l.house_domain AND s.lot_id=l.lot_id
                       AND s.status='andamento'
                     ORDER BY s.scraped_at DESC LIMIT 1)        AS current_bid_brl,
                   (SELECT s.bid_count FROM lot_snapshots s
                     WHERE s.house_domain=l.house_domain AND s.lot_id=l.lot_id
                       AND s.status='andamento'
                     ORDER BY s.scraped_at DESC LIMIT 1)        AS bid_count
            FROM lots l
            WHERE l.thumbnail_url IS NOT NULL
              AND l.excluded_sensitive = 0
              AND EXISTS (SELECT 1 FROM lot_snapshots s
                          WHERE s.house_domain=l.house_domain AND s.lot_id=l.lot_id
                            AND s.status='andamento')
        )
        SELECT live.*, e.item_type_normalized AS item_type, e.size_class,
               e.material, e.period_hint, e.condition_tier, e.is_pair_or_set,
               e.designer, e.attribution_strength
        FROM live
        JOIN lot_enrichment e
          ON e.house_domain=live.house_domain AND e.lot_id=live.lot_id
        WHERE e.item_type_normalized IN ({placeholders})
          AND (e.size_class IN ({sizes}) OR e.size_class IS NULL)
        """,
        (*config.FIT_ITEM_TYPES, *config.FIT_SIZE_CLASSES),
    ).fetchall()
    c.close()
    # dedupe por (casa, lote) — um lote pode ter vários snapshots
    seen, out = set(), []
    for r in rows:
        key = (r["house_domain"], r["lot_id"])
        if key in seen:
            continue
        seen.add(key)
        out.append(dict(r))
    return out


def category_comp_medians(db_path: str) -> dict[str, float]:
    """Mediana de martelo por categoria, dos lotes FINALIZADOS vendidos."""
    import statistics

    c = sqlite3.connect(db_path)
    c.row_factory = sqlite3.Row
    buckets: dict[str, list[float]] = {}
    for r in c.execute(
        """SELECT e.item_type_normalized t, s.hammer_price_brl h
           FROM lot_snapshots s
           JOIN lot_enrichment e
             ON e.house_domain=s.house_domain AND e.lot_id=s.lot_id
           WHERE s.status='finalizado' AND s.sold=1 AND s.hammer_price_brl>0"""
    ):
        buckets.setdefault(r["t"], []).append(r["h"])
    c.close()
    return {
        t: statistics.median(v)
        for t, v in buckets.items()
        if len(v) >= config.MIN_COMPS
    }
