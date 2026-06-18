from __future__ import annotations

from typing import Any
from urllib.parse import urlencode

import pandas as pd
import requests

# ─── CONFIGURAÇÃO DA CAMADA HTTP ─────────────────────────────────────
# Altere aqui se precisar customizar sem tocar no resto do código

BASE_URL = "https://www.latamairlines.com/bff/web-products-searchbox/v1/calendar"

DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json",
    "Accept-Language": "pt-BR,pt;q=0.9",
    "Referer": "https://www.latamairlines.com/",
}

# Para passar cookies de sessão quando necessário:
# DEFAULT_COOKIES = {"session_id": "...", "token": "..."}
DEFAULT_COOKIES: dict = {}
# ─────────────────────────────────────────────────────────────────────


def build_url(origin: str, destination: str, month: int, year: int) -> str:
    """Monta a URL completa com parâmetros."""
    params = {
        "origin": origin.upper(),
        "destination": destination.upper(),
        "month": int(month),
        "year": int(year),
        "isRoundTrip": "true",
        "extended": "true",
    }
    return f"{BASE_URL}?{urlencode(params)}"


def fetch_calendar(
    origin: str,
    destination: str,
    month: int,
    year: int,
    headers: dict | None = None,
    cookies: dict | None = None,
    timeout: int = 15,
) -> dict:
    """Faz o GET e retorna o JSON bruto. Lança exceção em caso de erro."""
    request_headers = {**DEFAULT_HEADERS, **(headers or {})}
    request_cookies = {**DEFAULT_COOKIES, **(cookies or {})}

    try:
        response = requests.get(
            BASE_URL,
            params={
                "origin": origin.upper(),
                "destination": destination.upper(),
                "month": int(month),
                "year": int(year),
                "isRoundTrip": True,
                "extended": True,
            },
            headers=request_headers,
            cookies=request_cookies,
            timeout=timeout,
        )
    except requests.Timeout as exc:
        raise TimeoutError(
            f"Timeout ao consultar LATAM ({origin}->{destination}, {month}/{year})."
        ) from exc

    response.raise_for_status()

    try:
        data = response.json()
    except ValueError as exc:
        raise ValueError("Resposta não é JSON válido") from exc

    if not isinstance(data, (dict, list)):
        raise ValueError("Resposta JSON em formato inesperado")

    return data


def _extract_direction_payload(raw: dict | list, direction: str) -> dict:
    normalized_direction = direction.upper()

    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, dict) and item.get("direction", "").upper() == normalized_direction:
                return item
        raise KeyError(f"Direção '{normalized_direction}' não encontrada no payload de lista")

    if not isinstance(raw, dict):
        raise ValueError("Payload bruto deve ser dict ou list")

    raw_direction = str(raw.get("direction", "")).upper()
    if raw_direction == normalized_direction:
        return raw

    for key in ("calendars", "data", "items", "results"):
        maybe = raw.get(key)
        if isinstance(maybe, list):
            for item in maybe:
                if isinstance(item, dict) and item.get("direction", "").upper() == normalized_direction:
                    return item

    if normalized_direction == "OUTBOUND":
        return raw

    raise KeyError(f"Direção '{normalized_direction}' não encontrada no payload")


def parse_calendar(raw: dict, direction: str) -> pd.DataFrame:
    """
    Extrai detailsCalendar para um DataFrame normalizado.
    direction: "OUTBOUND" ou "INBOUND"
    Colunas resultantes: date, price, currency, formatted_amount,
                         percentile, enabled, low_price, origin, destination
    """
    payload = _extract_direction_payload(raw, direction)

    if "detailsCalendar" not in payload:
        raise KeyError(f"Campo 'detailsCalendar' ausente. Payload recebido: {payload}")

    details = payload["detailsCalendar"]
    if not isinstance(details, list):
        raise KeyError(f"Campo 'detailsCalendar' não é lista. Payload recebido: {payload}")

    if not details:
        return pd.DataFrame(
            columns=[
                "date",
                "price",
                "currency",
                "formatted_amount",
                "percentile",
                "enabled",
                "low_price",
                "origin",
                "destination",
            ]
        )

    rows: list[dict[str, Any]] = []
    for item in details:
        fare = item.get("fare", {}) if isinstance(item, dict) else {}
        rows.append(
            {
                "date": pd.to_datetime(item.get("date")).date() if item.get("date") else None,
                "price": fare.get("amount"),
                "currency": fare.get("currency"),
                "formatted_amount": item.get("formattedAmount"),
                "percentile": item.get("percentile"),
                "enabled": bool(item.get("enabled", False)),
                "low_price": bool(item.get("lowPrice", False)),
                "origin": payload.get("origin"),
                "destination": payload.get("destination"),
            }
        )

    return pd.DataFrame(rows)


def fetch_month_prices(
    origin: str,
    destination: str,
    month: int,
    year: int,
    direction: str,
    headers: dict | None = None,
    cookies: dict | None = None,
) -> pd.DataFrame:
    """Orquestra fetch + parse para um mês e direção. Retorna apenas enabled=True."""
    raw = fetch_calendar(
        origin=origin,
        destination=destination,
        month=month,
        year=year,
        headers=headers,
        cookies=cookies,
    )
    df = parse_calendar(raw=raw, direction=direction)
    if df.empty:
        return df
    return df[df["enabled"] == True].copy()
