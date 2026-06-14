"""núcleo da curadoria semanal: lê os lotes ao vivo (do sqlite grande ou, como
fallback, do parquet exportado), pontua cada lote e devolve candidatos prontos
para o supabase.

a fila prioriza a vibe murano / cristal / vidro soprado / luminária / objeto
decorativo / prata / porcelana / escultura, sem ignorar boas oportunidades
econômicas de mobiliário e arte. o score blenda quatro coisas:

  - vibe        peça é do tipo estético que a curadora quer ver
  - acesso      preço de entrada num ponto trabalhável (nem lixo, nem caro)
  - upside      margem/folga econômica vinda do pipeline leiloes-intel
  - liveness    encerra em breve e tem algum interesse (lances)

tudo em caixa baixa nos rótulos. nenhuma decisão é tomada aqui: o sistema só
ordena e sinaliza risco; o fica/talvez/passa é da curadora.
"""
from __future__ import annotations

import json
import math
import re
import sqlite3
import unicodedata
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# vocabulário de vibe e de risco (forma normalizada: sem acento, minúsculas)
# ---------------------------------------------------------------------------
VIBE_TYPES = {
    "cristal_vidro", "luminaria_lustre", "objeto_decorativo",
    "prata_metal", "porcelana_ceramica", "escultura",
}
# tipos que ainda interessam quando a economia é boa (mobiliário/arte forte)
SECONDARY_TYPES = {
    "espelho", "quadro_pintura", "gravura", "aparador", "mesa_de_centro",
    "poltrona", "par_de_poltronas", "comoda", "cristaleira",
}

PREMIUM_GLASS_KW = [
    "murano", "baccarat", "lalique", "daum", "saint louis", "saint-louis",
    "vidro soprado", "cristal soprado", "soprado", "opalina", "demi cristal",
    "cristal lapidado", "art glass", "boemia", "bohemia",
]
PREMIUM_SILVER_KW = [
    "prata de lei", "prata 800", "prata 900", "prata 925", "christofle",
    "wmf", "contraste", "teor de prata",
]
PREMIUM_PORCELAIN_KW = [
    "limoges", "sevres", "meissen", "vista alegre", "rosenthal",
    "capodimonte", "bavaria", "porcelana alema", "porcelana francesa",
]
SCULPTURE_KW = ["bronze patinado", "art deco", "art nouveau", "marfim vegetal", "petit bronze"]

DAMAGE_KW = [
    "restauro", "restaur", "quebrad", "trincad", "lascad", "danificad",
    "faltando", "incompleto", "bicado", "colad", "solta", "solto",
    "acao de insetos", "cupim", "rachad", "avariad", "sem tampo",
    "no estado", "desgaste acentuado", "necessita",
]
ELECTRIC_KW = ["parte eletrica", "revisao eletrica", "fiacao", "luminaria"]


def _norm(text: str | None) -> str:
    if not text:
        return ""
    t = unicodedata.normalize("NFKD", text)
    t = "".join(c for c in t if not unicodedata.combining(c))
    return t.lower()


def _has(haystack: str, needles: list[str]) -> bool:
    return any(n in haystack for n in needles)


# ---------------------------------------------------------------------------
# leitura da fonte de dados
# ---------------------------------------------------------------------------
LIVE_SQL = """
SELECT
  l.house_domain               AS house_domain,
  l.lot_id                     AS lot_id,
  l.title                      AS title,
  l.uf                         AS uf,
  l.auction_datetime           AS auction_datetime,
  l.lot_url                    AS lot_url,
  l.thumbnail_url              AS thumbnail_url,
  s.current_bid_brl            AS current_bid_brl,
  s.bid_count                  AS bid_count,
  e.item_type_normalized       AS item_type,
  e.macro_category             AS macro_category,
  e.designer                   AS designer,
  e.attribution_strength       AS attribution_strength,
  e.condition_tier             AS condition_tier,
  e.size_class                 AS size_class,
  e.est_resale_base            AS est_resale_base,
  e.est_total_cost             AS est_total_cost,
  e.est_gross_profit           AS est_gross_profit,
  e.est_gross_margin_pct       AS est_gross_margin_pct,
  e.max_bid_40pct              AS max_bid_40pct,
  e.confidence                 AS confidence,
  e.signal                     AS signal,
  e.signal_reasons             AS signal_reasons,
  h.name                       AS house_name
FROM lots l
JOIN lot_snapshots s
  ON s.house_domain = l.house_domain AND s.lot_id = l.lot_id
 AND s.status = 'andamento'
 AND s.scraped_at = (
       SELECT MAX(s2.scraped_at) FROM lot_snapshots s2
       WHERE s2.house_domain = s.house_domain AND s2.lot_id = s.lot_id
         AND s2.status = 'andamento')
LEFT JOIN lot_enrichment e
  ON e.house_domain = l.house_domain AND e.lot_id = l.lot_id
LEFT JOIN auction_houses h
  ON h.house_domain = l.house_domain
WHERE l.excluded_sensitive = 0
"""


def read_live_rows_from_sqlite(db_path: str) -> list[dict]:
    """lê os lotes em andamento do sqlite grande do leiloes-intel."""
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        rows = [dict(r) for r in conn.execute(LIVE_SQL)]
    finally:
        conn.close()
    return rows


def read_live_rows_from_parquet(parquet_path: str, thumb_map: dict | None = None) -> list[dict]:
    """fallback portátil: lê do export slim (lots.parquet). não traz
    condition_tier / size_class / confidence / signal_reasons (só existem no
    sqlite cheio); o scoring lida com a ausência."""
    import pyarrow.parquet as pq

    thumb_map = thumb_map or {}
    cols = [
        "house_domain", "lot_id", "title", "uf", "auction_datetime",
        "item_type_normalized", "macro_category", "designer",
        "attribution_strength", "status", "current_bid_brl", "bid_count",
        "excluded_sensitive", "est_resale_base", "est_gross_margin_pct",
        "max_bid_40pct", "signal",
    ]
    tbl = pq.read_table(parquet_path, columns=cols)
    out = []
    for r in tbl.to_pylist():
        if r["status"] != "andamento" or r["excluded_sensitive"]:
            continue
        house = r["house_domain"]
        lot_id = int(r["lot_id"])
        out.append({
            "house_domain": house,
            "lot_id": lot_id,
            "title": r["title"],
            "uf": r["uf"],
            "auction_datetime": r["auction_datetime"],
            "lot_url": f"https://{house}/peca.asp?Id={lot_id}",
            "thumbnail_url": thumb_map.get(f"{house}|{lot_id}"),
            "current_bid_brl": r["current_bid_brl"],
            "bid_count": r["bid_count"],
            "item_type": r["item_type_normalized"],
            "macro_category": r["macro_category"],
            "designer": r["designer"],
            "attribution_strength": r["attribution_strength"],
            "condition_tier": None,
            "size_class": None,
            "est_resale_base": r["est_resale_base"],
            "est_total_cost": None,
            "est_gross_profit": None,
            "est_gross_margin_pct": r["est_gross_margin_pct"],
            "max_bid_40pct": r["max_bid_40pct"],
            "confidence": None,
            "signal": r["signal"],
            "signal_reasons": None,
            "house_name": None,
        })
    return out


# ---------------------------------------------------------------------------
# identidade e rótulos
# ---------------------------------------------------------------------------
def slugify(text: str, maxlen: int = 60) -> str:
    t = _norm(text)
    t = re.sub(r"[^a-z0-9]+", "-", t).strip("-")
    return t[:maxlen].strip("-")


def candidate_id(house_domain: str, lot_id) -> str:
    """chave estável por lote (sobrevive entre rodadas semanais)."""
    house = re.sub(r"[^a-z0-9]+", "-", _norm(house_domain)).strip("-")
    return f"{house}-{lot_id}"


def price_label(current_bid: float | None, bid_count: int | None) -> str:
    if not current_bid or current_bid <= 0:
        return "sem lance"
    val = f"r$ {current_bid:,.0f}".replace(",", ".")
    if bid_count and bid_count > 0:
        return f"lance atual {val}"
    return f"lance inicial {val}"


def iso_week(dt: datetime) -> str:
    y, w, _ = dt.isocalendar()
    return f"{y}-w{w:02d}"


# ---------------------------------------------------------------------------
# scoring
# ---------------------------------------------------------------------------
def _clamp(x, lo, hi):
    return max(lo, min(hi, x))


def score_candidate(row: dict) -> dict:
    """devolve score 0..100, prioridade, risco e razões, em caixa baixa."""
    title_n = _norm(row.get("title"))
    item = row.get("item_type") or ""
    bid = row.get("current_bid_brl") or 0.0
    bids = row.get("bid_count") or 0
    margin = row.get("est_gross_margin_pct")
    max_bid = row.get("max_bid_40pct") or 0.0
    signal = (row.get("signal") or "").upper()
    attr = (row.get("attribution_strength") or "NONE").upper()
    cond = (row.get("condition_tier") or "").lower()
    designer = row.get("designer")

    entry, risks = [], []

    # --- vibe (0..35) ---------------------------------------------------
    vibe = 0.0
    if item in VIBE_TYPES:
        vibe += 20
        entry.append("vibe decorativa")
    elif item in SECONDARY_TYPES:
        vibe += 8
    if _has(title_n, PREMIUM_GLASS_KW):
        vibe += 12; entry.append("cristal/vidro de marca")
    if _has(title_n, PREMIUM_SILVER_KW):
        vibe += 9; entry.append("prata com teor")
    if _has(title_n, PREMIUM_PORCELAIN_KW):
        vibe += 9; entry.append("porcelana de manufatura")
    if item == "escultura" and _has(title_n, SCULPTURE_KW):
        vibe += 6; entry.append("escultura de época")
    vibe = _clamp(vibe, 0, 35)

    # --- acesso: preço de entrada num ponto trabalhável (0..20) ---------
    # curva: sobe até ~r$600, platô até ~r$3000, cai depois.
    access = 0.0
    if bid > 0:
        if bid <= 600:
            access = 12 + (bid / 600) * 6
        elif bid <= 3000:
            access = 18
        elif bid <= 8000:
            access = 18 - (bid - 3000) / 5000 * 10
        else:
            access = 4
    else:
        access = 14  # sem lance ainda: entrada potencialmente baixa
    access = _clamp(access, 0, 20)

    # --- upside econômico (0..30) ---------------------------------------
    upside = 0.0
    if margin is not None:
        upside += _clamp(margin, 0, 1) * 18
    if max_bid and bid:
        headroom_ratio = (max_bid - bid) / max(max_bid, 1.0)
        upside += _clamp(headroom_ratio, 0, 1) * 7
    upside += {"BUY_NOW": 5, "WATCH": 2}.get(signal, 0)
    upside = _clamp(upside, 0, 30)
    if signal == "BUY_NOW":
        entry.append("oportunidade buy_now")
    elif signal == "WATCH":
        entry.append("watch econômico")

    # --- liveness: encerra em breve + algum interesse (0..15) -----------
    live = 0.0
    ends = _parse_dt(row.get("auction_datetime"))
    if ends is not None:
        days = (ends - datetime.now()).total_seconds() / 86400
        if 0 <= days <= 2:
            live += 9
        elif 2 < days <= 7:
            live += 6
        elif days > 7:
            live += 3
    if 1 <= bids <= 6:
        live += 4
    elif bids == 0:
        live += 2
    live = _clamp(live, 0, 15)

    score = vibe + access + upside + live

    # --- risco ----------------------------------------------------------
    if cond == "heavy" or _has(title_n, DAMAGE_KW):
        risks.append("estado/restauro")
        score -= 6
    if designer and attr in {"NONE", "STYLE_OF", "MATERIAL_HINT"}:
        risks.append("atribuição fraca")
        score -= 4
    if margin is not None and margin < 0.2:
        risks.append("margem apertada")
    if item == "luminaria_lustre" and _has(title_n, ELECTRIC_KW):
        risks.append("parte elétrica")
    if bids and bids > 10:
        risks.append("competição alta")
        score -= 2
    if row.get("est_resale_base") in (None, 0):
        risks.append("sem comparáveis")

    if not entry:
        entry.append("peça de catálogo")

    score = round(_clamp(score, 0, 100), 1)

    # prioridade por faixa (calibrada à distribuição real da fila), com piso
    # para sinal econômico forte
    if score >= 56:
        priority = "alta"
    elif score >= 45:
        priority = "media"
    else:
        priority = "baixa"
    if signal == "BUY_NOW" and priority != "alta":
        priority = "alta" if score >= 50 else "media"

    # nível de risco textual
    if "estado/restauro" in risks or "atribuição fraca" in risks:
        risk_level = "alto"
    elif risks:
        risk_level = "medio"
    else:
        risk_level = "baixo"

    headroom = None
    if max_bid:
        headroom = round(max_bid - (bid or 0), 2)

    return {
        "score": score,
        "priority": priority,
        "risk": risk_level,
        "risk_reasons": risks,
        "entry_reasons": entry,
        "headroom": headroom,
    }


def _parse_dt(s: str | None):
    if not s:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M", "%Y-%m-%d"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    return None


# ---------------------------------------------------------------------------
# montagem do candidato (linha pronta p/ curation_candidates)
# ---------------------------------------------------------------------------
def build_candidates(rows: list[dict], batch_id: str, refreshed_at: str,
                     limit: int = 600, min_price: float = 20.0,
                     drop_ended: bool = True) -> list[dict]:
    now = datetime.now()
    scored = []
    for r in rows:
        bid = r.get("current_bid_brl") or 0
        if bid and bid < min_price:
            continue
        if not r.get("thumbnail_url"):
            # sem imagem a mesa de curadoria perde o sentido
            continue
        ends = _parse_dt(r.get("auction_datetime"))
        if drop_ended and ends is not None and ends < now:
            continue
        item = r.get("item_type") or ""
        sig = (r.get("signal") or "").upper()
        # pool: vibe, secundários fortes, ou oportunidade econômica clara
        keep = (item in VIBE_TYPES or item in SECONDARY_TYPES
                or sig in {"BUY_NOW", "WATCH"})
        if not keep:
            continue
        s = score_candidate(r)
        cid = candidate_id(r["house_domain"], r["lot_id"])
        payload = {
            "item_type": item,
            "macro_category": r.get("macro_category"),
            "designer": r.get("designer"),
            "attribution_strength": r.get("attribution_strength"),
            "condition_tier": r.get("condition_tier"),
            "size_class": r.get("size_class"),
            "uf": r.get("uf"),
            "house_name": r.get("house_name"),
            "est_resale_base": r.get("est_resale_base"),
            "est_total_cost": r.get("est_total_cost"),
            "est_gross_profit": r.get("est_gross_profit"),
            "est_gross_margin_pct": r.get("est_gross_margin_pct"),
            "max_bid_40pct": r.get("max_bid_40pct"),
            "confidence": r.get("confidence"),
            "signal": r.get("signal"),
            "signal_reasons": r.get("signal_reasons"),
            "entry_reasons": s["entry_reasons"],
            "risk_reasons": s["risk_reasons"],
        }
        scored.append({
            "candidate_id": cid,
            "product_slug": cid,
            "batch_id": batch_id,
            "title": (r.get("title") or "sem título").strip(),
            "price_brl": round(bid, 2) if bid else 0,
            "price_label": price_label(bid, r.get("bid_count")),
            "source_house": r.get("house_name") or r["house_domain"],
            "source_url": r.get("lot_url"),
            "image_url": r.get("thumbnail_url"),
            "auction_ends": r.get("auction_datetime"),
            "score": s["score"],
            "priority": s["priority"],
            "risk": s["risk"],
            "headroom": s["headroom"],
            "bid_count": r.get("bid_count") or 0,
            "status": "queued",
            "payload": payload,
            "refreshed_at": refreshed_at,
        })

    # dedup por candidate_id (mesmo lote em mais de uma categoria), maior score
    best: dict[str, dict] = {}
    for c in scored:
        cur = best.get(c["candidate_id"])
        if cur is None or c["score"] > cur["score"]:
            best[c["candidate_id"]] = c
    ordered = sorted(
        best.values(),
        key=lambda c: (c["score"], c["headroom"] or -1e9),
        reverse=True,
    )
    return ordered[:limit]


# ---------------------------------------------------------------------------
# geração de seed.sql idempotente
# ---------------------------------------------------------------------------
def _sql_str(v) -> str:
    if v is None:
        return "null"
    return "'" + str(v).replace("'", "''") + "'"


def _sql_num(v) -> str:
    if v is None:
        return "null"
    if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
        return "null"
    return repr(v)


def _sql_json(v) -> str:
    return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb"


def to_seed_sql(candidates: list[dict], batch_id: str, refreshed_at: str) -> str:
    """upsert idempotente: re-rodar não duplica e não toca em curator_decisions.
    candidatos de rodadas antigas que não voltaram são arquivados (saem da feed,
    permanecem no histórico)."""
    lines = [
        "-- seed semanal da curadoria velvo — gerado por pipeline/run_weekly.py",
        "-- idempotente: pode rodar de novo sem duplicar nem apagar decisões.",
        f"-- batch_id: {batch_id}  |  refreshed_at: {refreshed_at}",
        f"-- candidatos nesta rodada: {len(candidates)}",
        "",
        "begin;",
        "",
    ]
    cols = ("candidate_id, product_slug, batch_id, title, price_brl, price_label, "
            "source_house, source_url, image_url, auction_ends, score, priority, "
            "risk, headroom, bid_count, status, payload, refreshed_at")
    for c in candidates:
        vals = ", ".join([
            _sql_str(c["candidate_id"]),
            _sql_str(c["product_slug"]),
            _sql_str(c["batch_id"]),
            _sql_str(c["title"]),
            _sql_num(c["price_brl"]),
            _sql_str(c["price_label"]),
            _sql_str(c["source_house"]),
            _sql_str(c["source_url"]),
            _sql_str(c["image_url"]),
            _sql_str(c["auction_ends"]),
            _sql_num(c["score"]),
            _sql_str(c["priority"]),
            _sql_str(c["risk"]),
            _sql_num(c["headroom"]),
            _sql_num(c["bid_count"]),
            _sql_str(c["status"]),
            _sql_json(c["payload"]),
            _sql_str(c["refreshed_at"]),
        ])
        lines.append(
            f"insert into curation_candidates ({cols})\nvalues ({vals})\n"
            "on conflict (candidate_id) do update set\n"
            "  product_slug = excluded.product_slug,\n"
            "  batch_id = excluded.batch_id,\n"
            "  title = excluded.title,\n"
            "  price_brl = excluded.price_brl,\n"
            "  price_label = excluded.price_label,\n"
            "  source_house = excluded.source_house,\n"
            "  source_url = excluded.source_url,\n"
            "  image_url = excluded.image_url,\n"
            "  auction_ends = excluded.auction_ends,\n"
            "  score = excluded.score,\n"
            "  priority = excluded.priority,\n"
            "  risk = excluded.risk,\n"
            "  headroom = excluded.headroom,\n"
            "  bid_count = excluded.bid_count,\n"
            "  status = case when curation_candidates.status in ('hidden','archived')\n"
            "                then curation_candidates.status else 'queued' end,\n"
            "  payload = excluded.payload,\n"
            "  refreshed_at = excluded.refreshed_at,\n"
            "  updated_at = now();"
        )
        lines.append("")

    # arquiva candidatos queued de rodadas anteriores que não voltaram nesta.
    lines.append(
        "-- candidatos de rodadas anteriores que não voltaram nesta saem da feed\n"
        "-- (viram histórico); decisões nunca são apagadas.\n"
        "update curation_candidates set status = 'archived', updated_at = now()\n"
        f"where batch_id <> {_sql_str(batch_id)} and status = 'queued';"
    )
    lines.append("")
    lines.append("commit;")
    lines.append("")
    return "\n".join(lines)


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
