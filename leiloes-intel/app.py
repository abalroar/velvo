"""Dashboard de deep dive nos dados da LeilõesBR.

Lê os CSVs versionados em data/exports/ (não precisa do SQLite nem de re-scrape).
Rodar:  streamlit run app.py
"""
from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st

EXPORTS = Path(__file__).resolve().parent / "data" / "exports"

st.set_page_config(page_title="LeilõesBR Intel", page_icon="🔨", layout="wide")


# ----------------------------------------------------------------------------
# Dados
# ----------------------------------------------------------------------------
@st.cache_data(show_spinner="Carregando base de lotes…")
def load_lots() -> pd.DataFrame:
    df = pd.read_csv(EXPORTS / "lots.csv", low_memory=False)
    df = df[df["excluded_sensitive"] != 1].copy()
    df["designer"] = df["designer"].fillna("—")
    df["item_type_normalized"] = df["item_type_normalized"].fillna("outro")
    df["uf"] = df["uf"].fillna("?")
    df["signal"] = df["signal"].fillna("—")
    # data do pregão: finalizados vêm como D/M/AAAA, ao vivo como ISO
    dt = pd.to_datetime(df["auction_datetime"], format="%d/%m/%Y", errors="coerce")
    dt_iso = pd.to_datetime(df["auction_datetime"], errors="coerce", format="ISO8601")
    df["auction_date"] = dt.fillna(dt_iso).dt.date
    return df


@st.cache_data
def load_csv(name: str) -> pd.DataFrame:
    return pd.read_csv(EXPORTS / name)


def brl(v) -> str:
    if v is None or pd.isna(v):
        return "—"
    return "R$ " + f"{float(v):,.0f}".replace(",", ".")


lots = load_lots()

# ----------------------------------------------------------------------------
# Filtros globais (sidebar)
# ----------------------------------------------------------------------------
st.sidebar.title("🔨 LeilõesBR Intel")
st.sidebar.caption("Filtros aplicam a todas as abas")

status_sel = st.sidebar.multiselect(
    "Status", sorted(lots["status"].dropna().unique()),
    default=sorted(lots["status"].dropna().unique()))

tipos = sorted(lots["item_type_normalized"].unique())
tipo_sel = st.sidebar.multiselect("Tipo de peça", tipos, default=[])

designers = sorted(d for d in lots["designer"].unique() if d != "—")
designer_sel = st.sidebar.multiselect("Designer/autor detectado", designers, default=[])

ufs = sorted(u for u in lots["uf"].unique() if u != "?")
uf_sel = st.sidebar.multiselect("UF", ufs, default=[])

casas = sorted(lots["house_domain"].dropna().unique())
casa_sel = st.sidebar.multiselect("Casa (domínio)", casas, default=[])

preco_max = st.sidebar.number_input(
    "Preço máx. (lance atual ou martelo, R$)", min_value=0, value=0,
    help="0 = sem limite")
busca = st.sidebar.text_input("Busca no título", "",
                              placeholder="ex.: jacarandá, Tenreiro, palhinha")

f = lots[lots["status"].isin(status_sel)].copy()
if tipo_sel:
    f = f[f["item_type_normalized"].isin(tipo_sel)]
if designer_sel:
    f = f[f["designer"].isin(designer_sel)]
if uf_sel:
    f = f[f["uf"].isin(uf_sel)]
if casa_sel:
    f = f[f["house_domain"].isin(casa_sel)]
f["preco_ref"] = f["hammer_price_brl"].fillna(f["current_bid_brl"])
if preco_max > 0:
    f = f[f["preco_ref"].fillna(0) <= preco_max]
if busca.strip():
    f = f[f["title"].str.contains(busca.strip(), case=False, na=False)]

st.sidebar.markdown(f"**{len(f):,}".replace(",", ".") + " lotes no recorte**")

# ----------------------------------------------------------------------------
# KPIs do recorte
# ----------------------------------------------------------------------------
fin = f[f["status"] == "finalizado"]
sold = fin[fin["sold"] == 1]
live = f[f["status"] == "andamento"]

c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("Lotes no recorte", f"{len(f):,}".replace(",", "."))
c2.metric("Sell-through", f"{len(sold)/len(fin):.1%}".replace(".", ",") if len(fin) else "—")
c3.metric("Martelo mediano", brl(sold["hammer_price_brl"].median()) if len(sold) else "—")
c4.metric("Zero-bid (finalizados)",
          f"{(fin['bid_count'] == 0).mean():.1%}".replace(".", ",") if len(fin) else "—")
c5.metric("Ao vivo agora", f"{len(live):,}".replace(",", "."))

tabs = st.tabs(["📈 Tendências", "🪑 Categorias", "🏛️ Casas", "✍️ Designers",
                "💰 Preços & competição", "🎯 Oportunidades", "🔍 Explorador"])

# ----------------------------------------------------------------------------
# 1. Tendências (série temporal da janela de finalizados)
# ----------------------------------------------------------------------------
with tabs[0]:
    st.subheader("Tendência diária — leilões finalizados no recorte")
    t = fin.dropna(subset=["auction_date"]).copy()
    if t.empty:
        st.info("Sem finalizados no recorte atual (ajuste os filtros).")
    else:
        daily = t.groupby("auction_date").agg(
            ofertados=("lot_id", "count"),
            vendidos=("sold", "sum"),
            gmv=("hammer_price_brl", "sum"),
            martelo_mediano=("hammer_price_brl", "median"),
        ).reset_index()
        daily["sell_through"] = daily["vendidos"] / daily["ofertados"]
        col1, col2 = st.columns(2)
        col1.plotly_chart(px.bar(daily, x="auction_date", y="gmv",
                                 title="GMV diário (martelo somado, R$)"), width="stretch")
        col2.plotly_chart(px.line(daily, x="auction_date", y="sell_through",
                                  title="Sell-through diário", markers=True), width="stretch")
        col3, col4 = st.columns(2)
        col3.plotly_chart(px.bar(daily, x="auction_date", y="ofertados",
                                 title="Lotes ofertados por dia"), width="stretch")
        col4.plotly_chart(px.line(daily, x="auction_date", y="martelo_mediano",
                                  title="Martelo mediano diário (R$)", markers=True), width="stretch")
        st.caption("Janela ≈ últimos 15 dias de finalizados (rotativa do site). "
                   "Use os filtros para ver a tendência de um tipo/designer/casa específico.")

# ----------------------------------------------------------------------------
# 2. Categorias
# ----------------------------------------------------------------------------
with tabs[1]:
    st.subheader("Liquidez × ticket por tipo de peça (finalizados do recorte)")
    g = fin.groupby("item_type_normalized").agg(
        ofertados=("lot_id", "count"), vendidos=("sold", "sum"),
        martelo_mediano=("hammer_price_brl", "median"),
        lances_medio=("bid_count", "mean")).reset_index()
    g = g[g["ofertados"] >= 10]
    g["sell_through"] = g["vendidos"] / g["ofertados"]
    g["zero_ref"] = g["item_type_normalized"]
    if g.empty:
        st.info("Sem volume suficiente no recorte.")
    else:
        fig = px.scatter(
            g, x="sell_through", y="martelo_mediano", size="ofertados", text="item_type_normalized",
            log_y=True, labels={"sell_through": "sell-through", "martelo_mediano": "martelo mediano (R$, log)"},
            title="Quadrante mágico: canto superior direito = alta liquidez e alto ticket")
        fig.update_traces(textposition="top center")
        st.plotly_chart(fig, width="stretch")
        st.dataframe(
            g.sort_values("sell_through", ascending=False)
             .assign(sell_through=lambda d: (d["sell_through"] * 100).round(1),
                     martelo_mediano=lambda d: d["martelo_mediano"].round(0),
                     lances_medio=lambda d: d["lances_medio"].round(1))
             .drop(columns="zero_ref"),
            width="stretch", hide_index=True)

# ----------------------------------------------------------------------------
# 3. Casas
# ----------------------------------------------------------------------------
with tabs[2]:
    st.subheader("Casas: onde comprar barato × quem vende bem")
    h = fin.groupby("house_domain").agg(
        finalizados=("lot_id", "count"), vendidos=("sold", "sum"),
        zero_bid=("bid_count", lambda s: (s == 0).mean()),
        martelo_medio=("hammer_price_brl", "mean")).reset_index()
    h = h[h["finalizados"] >= 30]
    h["sell_through"] = h["vendidos"] / h["finalizados"]
    if h.empty:
        st.info("Sem casas com ≥30 lotes finalizados no recorte.")
    else:
        fig = px.scatter(
            h, x="zero_bid", y="sell_through", size="finalizados",
            hover_name="house_domain", color="martelo_medio",
            color_continuous_scale="Viridis",
            labels={"zero_bid": "taxa de lotes sem lance", "sell_through": "sell-through",
                    "martelo_medio": "martelo médio (R$)"},
            title="Esquerda-alto = benchmark (vende tudo). Direita-baixo = sourcing (ninguém dá lance).")
        st.plotly_chart(fig, width="stretch")
        cA, cB = st.columns(2)
        cA.markdown("**🛒 Sourcing (maior zero-bid)**")
        cA.dataframe(h.sort_values("zero_bid", ascending=False).head(15)
                      .assign(zero_bid=lambda d: (d["zero_bid"] * 100).round(1),
                              sell_through=lambda d: (d["sell_through"] * 100).round(1)),
                     width="stretch", hide_index=True)
        cB.markdown("**🏆 Benchmark (maior sell-through)**")
        cB.dataframe(h.sort_values("sell_through", ascending=False).head(15)
                      .assign(zero_bid=lambda d: (d["zero_bid"] * 100).round(1),
                              sell_through=lambda d: (d["sell_through"] * 100).round(1)),
                     width="stretch", hide_index=True)

# ----------------------------------------------------------------------------
# 4. Designers
# ----------------------------------------------------------------------------
with tabs[3]:
    st.subheader("Martelo real por designer (lotes vendidos)")
    d = sold[sold["designer"] != "—"]
    if d.empty:
        st.info("Nenhuma venda com designer detectado no recorte.")
    else:
        order = d.groupby("designer")["hammer_price_brl"].median().sort_values(ascending=False).index
        fig = px.strip(d, x="designer", y="hammer_price_brl", color="attribution_strength",
                       category_orders={"designer": list(order)}, log_y=True,
                       hover_data=["title", "house_domain"],
                       labels={"hammer_price_brl": "martelo (R$, log)"},
                       title="Cada ponto = uma venda real. Cor = força da atribuição no texto.")
        st.plotly_chart(fig, width="stretch")
        resumo = d.groupby("designer").agg(
            vendas=("lot_id", "count"),
            mediana=("hammer_price_brl", "median"),
            minimo=("hammer_price_brl", "min"),
            maximo=("hammer_price_brl", "max")).sort_values("mediana", ascending=False)
        st.dataframe(resumo.round(0), width="stretch")
        st.caption("Atenção: o match é por keyword no título/descrição — 'STYLE_OF' e 'ATTRIBUTED' "
                   "não são autenticação. Min/máx mostram a variância entre linhas/modelos.")

# ----------------------------------------------------------------------------
# 5. Preços & competição
# ----------------------------------------------------------------------------
with tabs[4]:
    st.subheader("Dinâmica de lances (finalizados do recorte)")
    if fin.empty:
        st.info("Sem finalizados no recorte.")
    else:
        col1, col2 = st.columns(2)
        bc = fin["bid_count"].clip(upper=30)
        col1.plotly_chart(px.histogram(bc, nbins=31, title="Distribuição do nº de lances (cap 30)",
                                       labels={"value": "lances"}),
                          width="stretch")
        s2 = sold[(sold["opening_bid_brl"] > 0)].copy()
        s2["martelo_sobre_inicial"] = (s2["hammer_price_brl"] / s2["opening_bid_brl"]).clip(upper=20)
        col2.plotly_chart(px.histogram(s2, x="martelo_sobre_inicial", nbins=40,
                                       title="Martelo ÷ lance inicial (vendidos, cap 20×)"),
                          width="stretch")
        um_lance = (sold["bid_count"] == 1).mean() if len(sold) else 0
        st.markdown(
            f"- **{um_lance:.1%}** dos vendidos saíram com **1 lance** (compra sem disputa).\n"
            f"- Martelo mediano do recorte: **{brl(sold['hammer_price_brl'].median())}** | "
            f"p25 **{brl(sold['hammer_price_brl'].quantile(.25))}** | "
            f"p75 **{brl(sold['hammer_price_brl'].quantile(.75))}**".replace(".", ",", 1))
        st.plotly_chart(px.histogram(sold, x="hammer_price_brl", nbins=60, log_y=True,
                                     title="Distribuição de martelo (R$) — eixo Y log"),
                        width="stretch")

# ----------------------------------------------------------------------------
# 6. Oportunidades
# ----------------------------------------------------------------------------
with tabs[5]:
    st.subheader("Lotes ao vivo com sinal de compra")
    sig = st.radio("Sinal", ["BUY_NOW", "WATCH", "AVOID"], horizontal=True)
    o = f[(f["status"] == "andamento") & (f["signal"] == sig)].copy()
    o = o.sort_values("est_gross_margin_pct", ascending=False)
    st.markdown(f"**{len(o)} lotes** no recorte com sinal `{sig}`.")
    if not o.empty:
        show = o[["title", "item_type_normalized", "designer", "attribution_strength",
                  "current_bid_brl", "bid_count", "est_resale_base", "est_gross_margin_pct",
                  "max_bid_40pct", "uf", "house_domain", "signal_reasons", "lot_url"]].copy()
        show["est_gross_margin_pct"] = (show["est_gross_margin_pct"] * 100).round(1)
        st.dataframe(
            show, width="stretch", hide_index=True,
            column_config={
                "lot_url": st.column_config.LinkColumn("lote", display_text="abrir ↗"),
                "title": st.column_config.TextColumn("título", width="large"),
                "current_bid_brl": st.column_config.NumberColumn("lance atual", format="R$ %.0f"),
                "est_resale_base": st.column_config.NumberColumn("revenda est.", format="R$ %.0f"),
                "max_bid_40pct": st.column_config.NumberColumn("lance máx (40%)", format="R$ %.0f"),
                "est_gross_margin_pct": st.column_config.NumberColumn("margem %", format="%.1f%%"),
            })
        st.caption("Sinais são triagem conservadora (p25 dos comps × markup de varejo), não garantia. "
                   "O comp não distingue modelo/linha do designer — verifique cada lote no link antes do lance.")

# ----------------------------------------------------------------------------
# 7. Explorador
# ----------------------------------------------------------------------------
with tabs[6]:
    st.subheader("Explorador de lotes (recorte atual)")
    n = st.slider("Linhas", 50, 2000, 300, step=50)
    cols = ["status", "title", "item_type_normalized", "designer", "preco_ref",
            "bid_count", "sold", "uf", "house_domain", "auction_date", "lot_url"]
    st.dataframe(
        f[cols].head(n), width="stretch", hide_index=True,
        column_config={
            "lot_url": st.column_config.LinkColumn("lote", display_text="abrir ↗"),
            "title": st.column_config.TextColumn("título", width="large"),
            "preco_ref": st.column_config.NumberColumn("preço (martelo/lance)", format="R$ %.0f"),
        })
    st.download_button("⬇️ Baixar recorte filtrado (CSV)",
                       f.to_csv(index=False).encode("utf-8"),
                       file_name="recorte_leiloes.csv", mime="text/csv")
