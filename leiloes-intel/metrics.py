"""Motor de métricas: comparáveis de martelo reais (de leilões finalizados),
custo all-in, margem e sinais BUY_NOW/WATCH/AVOID por lote ao vivo.

Comps = preço de martelo de lotes VENDIDOS em finalizados, agrupados por
(item_type, designer) e por item_type. A "estimativa de revenda" usa a mediana
desses comps como valor de mercado líquido — conservador e defensável: se itens
equivalentes batem o martelo na mediana M e você adquire por bem menos, o gap
(menos custos) é a margem. Sem comps suficientes, usa markup sobre o lance.
"""
import re
import statistics
from datetime import datetime

import yaml

import config
import db

ATTR_ORDER = {"NONE": 0, "MATERIAL_HINT": 1, "STYLE_OF": 1, "ATTRIBUTED": 2,
              "STATED": 3, "DOCUMENTED": 4}

# Acessórios/peças avulsas que casam com o tipo mas não valem o móvel inteiro.
ACCESSORY_RE = re.compile(
    r"\balmofada|\bcapa\b|\bcapas\b|revestimento|estofamento|forracao|forração|"
    r"peca de reposicao|peça de reposição|par de bracos|par de braços|"
    r"\bso o\b|apenas o|somente o|fragmento|\bpe\b de |conjunto de pes|reposicao")


def load_assumptions() -> dict:
    with open(config.BASE_DIR / "assumptions.yaml", encoding="utf-8") as f:
        return yaml.safe_load(f)


def pct(values, q):
    if not values:
        return None
    s = sorted(values)
    if len(s) == 1:
        return s[0]
    pos = q * (len(s) - 1)
    lo = int(pos)
    frac = pos - lo
    if lo + 1 < len(s):
        return s[lo] * (1 - frac) + s[lo + 1] * frac
    return s[lo]


def build_comps(conn):
    """Retorna (comps_designer, comps_type) com listas de martelo de vendidos."""
    rows = conn.execute(
        """SELECT e.item_type_normalized AS it, e.designer AS d, s.hammer_price_brl AS h
           FROM lot_snapshots s
           JOIN lot_enrichment e ON e.house_domain=s.house_domain AND e.lot_id=s.lot_id
           JOIN lots l ON l.house_domain=s.house_domain AND l.lot_id=s.lot_id
           WHERE s.status='finalizado' AND s.sold=1 AND s.hammer_price_brl > 0
             AND l.excluded_sensitive=0""").fetchall()
    comps_designer, comps_type = {}, {}
    for r in rows:
        comps_type.setdefault(r["it"], []).append(r["h"])
        if r["d"]:
            comps_designer.setdefault((r["it"], r["d"]), []).append(r["h"])
    return comps_designer, comps_type


def latest_live_lots(conn):
    """Lotes em andamento com o snapshot mais recente (lance atual / nº lances)."""
    return conn.execute(
        """SELECT s.house_domain, s.lot_id, s.current_bid_brl AS bid, s.bid_count AS bids,
                  e.item_type_normalized AS it, e.size_class AS size, e.designer AS d,
                  e.attribution_strength AS attr, e.condition_tier AS cond,
                  l.title, l.description, l.uf
           FROM lot_snapshots s
           JOIN lot_enrichment e ON e.house_domain=s.house_domain AND e.lot_id=s.lot_id
           JOIN lots l ON l.house_domain=s.house_domain AND l.lot_id=s.lot_id
           WHERE s.status='andamento' AND l.excluded_sensitive=0
             AND s.scraped_at=(SELECT MAX(s2.scraped_at) FROM lot_snapshots s2
                               WHERE s2.house_domain=s.house_domain AND s2.lot_id=s.lot_id
                                 AND s2.status='andamento')""").fetchall()


def estimate_resale(lot, comps_designer, comps_type, A):
    """(base, low, high, n_comps, basis). Comps são martelo (atacado); o varejo
    aplica retail_markup_over_hammer sobre eles."""
    rm = A["resale"]["retail_markup_over_hammer"]
    key = (lot["it"], lot["d"])
    if lot["d"] and len(comps_designer.get(key, [])) >= 3:
        c = comps_designer[key]
        return (statistics.median(c) * rm, pct(c, .25) * rm, pct(c, .75) * rm, len(c), "designer_comps")
    c = comps_type.get(lot["it"], [])
    if len(c) >= A["resale"]["min_comps"]:
        return (statistics.median(c) * rm, pct(c, .25) * rm, pct(c, .75) * rm, len(c), "type_comps")
    if c:
        return (statistics.median(c) * rm, pct(c, .25) * rm, pct(c, .75) * rm, len(c), "type_comps_thin")
    bid = lot["bid"] or 0
    base = bid * A["resale"]["fallback_markup_over_hammer"]
    return (base, base * 0.8, base * 1.25, 0, "fallback_markup")


def fixed_costs(size, cond, A):
    return (A["shipping_brl"].get(size, 180) + A["packaging_brl"].get(size, 90)
            + A["restoration_brl"].get(cond, 300))


def max_bid_for_margin(resale, fixed, premium, target):
    num = resale * (1 - target) - fixed
    return max(0.0, num / (1 + premium))


def confidence(n_comps, attr, desc):
    score = 0.3
    if n_comps >= 8:
        score += 0.35
    elif n_comps >= 3:
        score += 0.2
    if ATTR_ORDER.get(attr, 0) >= 3:
        score += 0.2
    elif ATTR_ORDER.get(attr, 0) >= 2:
        score += 0.1
    if desc and len(desc) > 120:
        score += 0.15
    return round(min(1.0, score), 2)


def decide_signal(margin, conf, lot, n_comps, size_rank, A):
    reasons = []
    bn = A["signals"]["buy_now"]
    wt = A["signals"]["watch"]
    title = (lot["title"] or "").lower()
    if ACCESSORY_RE.search(title):
        return "AVOID", "acessório/peça avulsa (não é o móvel inteiro); comp não aplicável"
    size_order = {"small": 0, "medium": 1, "large": 2, "xl": 3}
    max_size = size_order[bn["max_logistics_size"]]
    attr_ok = (lot["d"] is None) or (ATTR_ORDER.get(lot["attr"], 0)
                                     >= ATTR_ORDER[bn["min_attribution_for_designer_claim"]])
    # AVOID primeiro
    if margin is None or margin < wt["min_margin_pct"]:
        return "AVOID", "margem abaixo de WATCH"
    if lot["d"] and ATTR_ORDER.get(lot["attr"], 0) <= 1 and (lot["bid"] or 0) > 3000:
        return "AVOID", "atribuição fraca (style_of/none) com lance alto"
    if lot["cond"] == "heavy" and not lot["d"]:
        return "AVOID", "restauro pesado sem designer"
    # BUY_NOW
    if (margin >= bn["min_margin_pct"] and conf >= bn["min_confidence"]
            and size_order[lot["size"]] <= max_size
            and (lot["bids"] or 0) <= bn["max_bid_count"] and attr_ok):
        reasons.append(f"margem {margin:.0%}")
        reasons.append(f"comps={n_comps}")
        if lot["d"]:
            reasons.append(f"designer={lot['d']}({lot['attr']})")
        return "BUY_NOW", "; ".join(reasons)
    # WATCH
    if margin >= wt["min_margin_pct"] or conf >= wt["min_confidence"]:
        why = []
        if size_order[lot["size"]] > max_size:
            why.append("porte grande (frete)")
        if (lot["bids"] or 0) > bn["max_bid_count"]:
            why.append("competição alta")
        if conf < bn["min_confidence"]:
            why.append("confiança média")
        return "WATCH", "; ".join(why) or f"margem {margin:.0%} intermediária"
    return "AVOID", "não atende critérios"


def compute():
    conn = db.connect()
    A = load_assumptions()
    premium = A["buyer_premium_pct"]
    comps_designer, comps_type = build_comps(conn)
    lots = latest_live_lots(conn)
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    counts = {"BUY_NOW": 0, "WATCH": 0, "AVOID": 0}
    for lot in lots:
        bid = lot["bid"] or 0
        base, low, high, n_comps, basis = estimate_resale(lot, comps_designer, comps_type, A)
        fixed = fixed_costs(lot["size"], lot["cond"], A)
        total_cost = bid * (1 + premium) + fixed
        # Decisão usa o cenário CONSERVADOR (p25 dos comps): exige que o lote
        # seja lucrativo mesmo no quartil inferior dos comparáveis, robustez
        # contra a variância dentro do grupo (designer não captura o modelo).
        profit = low - total_cost
        margin = (profit / low) if low > 0 else None
        mb35 = max_bid_for_margin(low, fixed, premium, 0.35)
        mb40 = max_bid_for_margin(low, fixed, premium, 0.40)
        conf = confidence(n_comps, lot["attr"], lot["description"])
        signal, reason = decide_signal(margin, conf, lot, n_comps, lot["size"], A)
        reason = f"{reason} | base={basis} (conservador p25)"
        counts[signal] += 1
        conn.execute(
            """UPDATE lot_enrichment SET
                 est_resale_low=?, est_resale_base=?, est_resale_high=?,
                 est_total_cost=?, est_gross_profit=?, est_gross_margin_pct=?,
                 max_bid_35pct=?, max_bid_40pct=?, confidence=?, signal=?, signal_reasons=?
               WHERE house_domain=? AND lot_id=?""",
            (low, base, high, total_cost, profit,
             round(margin, 4) if margin is not None else None,
             round(mb35, 2), round(mb40, 2), conf, signal, reason,
             lot["house_domain"], lot["lot_id"]))
    conn.commit()
    print(f"Economia calculada p/ {len(lots)} lotes ao vivo. Sinais: {counts}")
    print(f"Comps: {len(comps_type)} tipos, "
          f"{sum(len(v) for v in comps_type.values())} martelos vendidos como base.")


if __name__ == "__main__":
    compute()
