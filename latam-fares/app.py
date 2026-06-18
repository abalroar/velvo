from __future__ import annotations

from datetime import date

import pandas as pd
import requests
import streamlit as st

from services.combinator import combine_trips
from services.latam_api import fetch_month_prices
from utils.dates import WEEKDAY_NAMES_PT, month_range, weekday_name_to_int
from utils.formatting import fmt_brl, fmt_date_br, fmt_percentile

st.set_page_config(page_title="LATAM Fare Discovery", layout="wide")

st.title("LATAM Fare Discovery")
st.caption("Descubra combinações de ida e volta com melhor custo-benefício no calendário da LATAM.")


@st.cache_data(ttl=3600)
def cached_fetch_month_prices(origin, destination, month, year, direction):
    return fetch_month_prices(origin, destination, month, year, direction)


with st.sidebar:
    st.header("Configuração da busca")
    dep_origin = st.text_input("Origem da ida", value="GRU").strip().upper()
    dep_destination = st.text_input("Destino da ida", value="JFK").strip().upper()
    ret_origin = st.text_input("Origem da volta", value="JFK").strip().upper()
    ret_destination = st.text_input("Destino da volta", value="GRU").strip().upper()

    today = date.today()
    start_month = st.selectbox("Mês inicial", options=list(range(1, 13)), index=today.month - 1)
    start_year = st.number_input("Ano inicial", min_value=2024, value=today.year, step=1)
    n_months = st.slider("Quantidade de meses", min_value=1, max_value=6, value=2)

    st.header("Regras de combinação")
    min_days = st.number_input("Dias mínimos de viagem", min_value=1, value=3, step=1)
    max_days = st.number_input("Dias máximos de viagem", min_value=1, value=14, step=1)

    default_weekdays = WEEKDAY_NAMES_PT.copy()
    out_weekday_names = st.multiselect("Dias da semana — ida", options=WEEKDAY_NAMES_PT, default=default_weekdays)
    in_weekday_names = st.multiselect("Dias da semana — volta", options=WEEKDAY_NAMES_PT, default=default_weekdays)

    top_n = st.slider("Top N combinações", min_value=5, max_value=100, value=20)

search = st.button("Buscar combinações", type="primary")

if search:
    out_weekdays = [weekday_name_to_int(name) for name in out_weekday_names]
    in_weekdays = [weekday_name_to_int(name) for name in in_weekday_names]

    months = month_range(start_month=start_month, start_year=int(start_year), n_months=n_months)

    outbound_frames: list[pd.DataFrame] = []
    inbound_frames: list[pd.DataFrame] = []

    try:
        with st.spinner("Buscando preços da LATAM..."):
            for month, year in months:
                out_df = cached_fetch_month_prices(
                    origin=dep_origin,
                    destination=dep_destination,
                    month=month,
                    year=year,
                    direction="OUTBOUND",
                )
                in_df = cached_fetch_month_prices(
                    origin=ret_origin,
                    destination=ret_destination,
                    month=month,
                    year=year,
                    direction="INBOUND",
                )
                outbound_frames.append(out_df)
                inbound_frames.append(in_df)
    except requests.HTTPError as e:
        st.error(f"Erro ao consultar LATAM: {e}")
        st.stop()
    except Exception as e:
        st.error("Resposta inesperada da API. Veja dados brutos para debug.")
        st.exception(e)
        st.stop()

    outbound_all = pd.concat(outbound_frames, ignore_index=True) if outbound_frames else pd.DataFrame()
    inbound_all = pd.concat(inbound_frames, ignore_index=True) if inbound_frames else pd.DataFrame()

    combos = combine_trips(
        outbound_df=outbound_all,
        inbound_df=inbound_all,
        min_days=int(min_days),
        max_days=int(max_days),
        outbound_weekdays=out_weekdays,
        inbound_weekdays=in_weekdays,
        top_n=int(top_n),
    )

    if combos.empty:
        st.warning("Nenhuma combinação válida encontrada com os filtros aplicados.")
    else:
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Menor preço total", fmt_brl(float(combos["total_price"].min())))
        c2.metric("Melhor ida isolada", fmt_brl(float(outbound_all["price"].min())))
        c3.metric("Melhor volta isolada", fmt_brl(float(inbound_all["price"].min())))
        c4.metric("N combinações", f"{len(combos)}")

        sort_map = {
            "Menor preço total": "total_price",
            "Melhor score": "score",
            "Menor preço de ida": "departure_price",
            "Menor preço de volta": "return_price",
        }
        selected_sort = st.selectbox("Ordenar por", list(sort_map.keys()), index=0)
        combos_sorted = combos.sort_values(sort_map[selected_sort], ascending=True).copy()

        display_df = combos_sorted.copy()
        display_df["departure_date"] = pd.to_datetime(display_df["departure_date"]).dt.date.apply(fmt_date_br)
        display_df["return_date"] = pd.to_datetime(display_df["return_date"]).dt.date.apply(fmt_date_br)
        for col in ["departure_price", "return_price", "total_price", "score"]:
            display_df[col] = display_df[col].apply(fmt_brl)
        display_df["departure_percentile"] = display_df["departure_percentile"].apply(fmt_percentile)
        display_df["return_percentile"] = display_df["return_percentile"].apply(fmt_percentile)
        display_df["departure_low_price"] = display_df["departure_low_price"].apply(lambda x: "✅" if x else "—")
        display_df["return_low_price"] = display_df["return_low_price"].apply(lambda x: "✅" if x else "—")

        st.dataframe(display_df, use_container_width=True, hide_index=True)

    with st.expander("Dados brutos de ida"):
        st.dataframe(outbound_all, use_container_width=True)

    with st.expander("Dados brutos de volta"):
        st.dataframe(inbound_all, use_container_width=True)
