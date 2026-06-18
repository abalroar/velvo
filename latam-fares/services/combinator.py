from __future__ import annotations

import pandas as pd


def combine_trips(
    outbound_df: pd.DataFrame,
    inbound_df: pd.DataFrame,
    min_days: int,
    max_days: int,
    outbound_weekdays: list[int] | None = None,
    inbound_weekdays: list[int] | None = None,
    top_n: int = 50,
) -> pd.DataFrame:
    """
    Combina datas de ida e volta seguindo as regras:
    - data_volta > data_ida
    - (data_volta - data_ida).days entre min_days e max_days
    - filtros de dia da semana quando fornecidos
    Retorna as top_n combinações ordenadas por total_price.
    """
    if outbound_df.empty or inbound_df.empty:
        return pd.DataFrame(
            columns=[
                "departure_date",
                "return_date",
                "departure_price",
                "return_price",
                "trip_length_days",
                "total_price",
                "departure_low_price",
                "return_low_price",
                "departure_percentile",
                "return_percentile",
                "score",
            ]
        )

    out = outbound_df.copy()
    inn = inbound_df.copy()

    out["date"] = pd.to_datetime(out["date"])
    inn["date"] = pd.to_datetime(inn["date"])

    if outbound_weekdays is not None and len(outbound_weekdays) > 0:
        out = out[out["date"].dt.weekday.isin(outbound_weekdays)]

    if inbound_weekdays is not None and len(inbound_weekdays) > 0:
        inn = inn[inn["date"].dt.weekday.isin(inbound_weekdays)]

    if out.empty or inn.empty:
        return pd.DataFrame()

    out = out.rename(
        columns={
            "date": "departure_date",
            "price": "departure_price",
            "low_price": "departure_low_price",
            "percentile": "departure_percentile",
        }
    )
    inn = inn.rename(
        columns={
            "date": "return_date",
            "price": "return_price",
            "low_price": "return_low_price",
            "percentile": "return_percentile",
        }
    )

    out["_k"] = 1
    inn["_k"] = 1
    combos = out.merge(inn, on="_k", how="inner").drop(columns=["_k"])

    combos["trip_length_days"] = (combos["return_date"] - combos["departure_date"]).dt.days
    combos = combos[
        (combos["trip_length_days"] >= int(min_days))
        & (combos["trip_length_days"] <= int(max_days))
        & (combos["trip_length_days"] > 0)
    ]

    if combos.empty:
        return pd.DataFrame()

    combos["total_price"] = combos["departure_price"] + combos["return_price"]
    combos["avg_percentile"] = (
        combos["departure_percentile"].fillna(0) + combos["return_percentile"].fillna(0)
    ) / 2
    combos["both_low_price"] = combos["departure_low_price"] & combos["return_low_price"]

    # Score: menor é melhor
    # Combina preço total com percentis médios
    # low_price em ambas as pernas dá desconto de 5%
    combos["score"] = combos["total_price"] * (1 + combos["avg_percentile"]) * (
        0.95 * combos["both_low_price"] + 1.0 * (~combos["both_low_price"])
    )

    cols = [
        "departure_date",
        "return_date",
        "departure_price",
        "return_price",
        "trip_length_days",
        "total_price",
        "departure_low_price",
        "return_low_price",
        "departure_percentile",
        "return_percentile",
        "score",
    ]

    combos = combos.sort_values("total_price", ascending=True)[cols].head(int(top_n)).reset_index(drop=True)
    return combos
