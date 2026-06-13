"""Camada econômica — transforma um lote em sinal de revenda objetivo.

Para cada candidato calcula: revenda estimada (conservadora), custo all-in,
margem, lance máximo recomendado. Aplica os cortes de margem/lance. Só sobrevive
quem tem potencial real de revenda — exatamente o que a curadora deve ver.
"""
import config


def _retail_anchor(item_type: str, size_class: str, comp_median: float) -> float:
    base = comp_median * config.RETAIL_MARKUP_OVER_COMP
    floor = config.RETAIL_FLOOR_BRL.get(size_class, config.RETAIL_FLOOR_BRL[None])
    return max(base, floor)


def evaluate(cand: dict, comp_medians: dict[str, float]) -> dict | None:
    """Anota economia no candidato; devolve None se reprovar nos cortes."""
    it = cand["item_type"]
    comp = comp_medians.get(it)
    if not comp:
        return None  # categoria sem comp confiável

    bid = cand.get("current_bid_brl") or 0.0
    size = cand.get("size_class")
    retail = _retail_anchor(it, size, comp)
    frete = config.FRETE_BRL.get(size, config.FRETE_BRL[None])
    allin = bid * (1 + config.BUYER_PREMIUM_PCT) + frete
    margin = (retail - allin) / retail if retail > 0 else -1.0
    max_bid = (retail * (1 - config.MIN_MARGIN_PCT) - frete) / (1 + config.BUYER_PREMIUM_PCT)

    if margin < config.MIN_MARGIN_PCT:
        return None
    if bid > retail * config.MAX_BID_VS_RETAIL:
        return None

    cand = dict(cand)
    cand["comp_median"] = round(comp, 2)
    cand["retail_anchor"] = round(retail, 2)
    cand["est_allin_cost"] = round(allin, 2)
    cand["est_margin_pct"] = round(margin, 4)
    cand["max_bid_brl"] = round(max(max_bid, 0), 2)
    return cand
