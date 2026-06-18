from __future__ import annotations

WEEKDAY_NAMES_PT = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]

_WEEKDAY_TO_INT = {
    "segunda": 0,
    "segunda-feira": 0,
    "terca": 1,
    "terça": 1,
    "terca-feira": 1,
    "terça-feira": 1,
    "quarta": 2,
    "quarta-feira": 2,
    "quinta": 3,
    "quinta-feira": 3,
    "sexta": 4,
    "sexta-feira": 4,
    "sabado": 5,
    "sábado": 5,
    "domingo": 6,
}


def month_range(start_month: int, start_year: int, n_months: int) -> list[tuple[int, int]]:
    """Retorna lista de (month, year) para n_months meses a partir de start."""
    if n_months < 1:
        return []

    month = int(start_month)
    year = int(start_year)
    out: list[tuple[int, int]] = []
    for _ in range(n_months):
        out.append((month, year))
        month += 1
        if month > 12:
            month = 1
            year += 1
    return out


def weekday_name_to_int(name: str) -> int:
    """'segunda' → 0, 'terça' → 1, ..., 'domingo' → 6"""
    key = name.strip().lower()
    if key not in _WEEKDAY_TO_INT:
        raise ValueError(f"Dia da semana inválido: {name}")
    return _WEEKDAY_TO_INT[key]
