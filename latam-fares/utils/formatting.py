from __future__ import annotations

from datetime import date


def _ptbr_number(value: float, decimals: int = 2) -> str:
    formatted = f"{value:,.{decimals}f}"
    return formatted.replace(",", "X").replace(".", ",").replace("X", ".")


def fmt_brl(value: float) -> str:
    """R$ 1.670,34 — padrão brasileiro obrigatório em todos os displays."""
    return f"R$ {_ptbr_number(float(value), 2)}"


def fmt_date_br(d: date) -> str:
    """03/05/2026 (dom)"""
    weekdays = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    return f"{d.strftime('%d/%m/%Y')} ({weekdays[d.weekday()]})"


def fmt_percentile(p: float) -> str:
    """0.03 → 'top 3%'"""
    pct = round(float(p) * 100)
    return f"top {pct}%"
