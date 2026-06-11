"""Dashboard de inteligência de mercado da LeilõesBR.

Visualização didática e interativa dos dados coletados (preço de martelo real,
liquidez, designers, oportunidades). Lê os arquivos versionados em
data/exports/ — não exige SQLite nem re-scrape.

Rodar:  streamlit run app.py
"""
from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st

EXPORTS = Path(__file__).resolve().parent / "data" / "exports"

st.set_page_config(page_title="LeilõesBR — Inteligência de Mercado",
                   page_icon="🔨", layout="wide",
                   initial_sidebar_state="expanded")

# paleta consistente
PALETTE = px.colors.qualitative.Bold
px.defaults.color_discrete_sequence = PALETTE
px.defaults.template = "plotly_white"

st.markdown("""
<style>
  .block-container {padding-top: 2rem;}
  [data-testid="stMetricValue"] {font-size: 1.7rem;}
  h1, h2, h3 {letter-spacing: -0.01em;}
  .stTabs [data-baseweb="tab"] {font-size: 1rem; padding: 0.4rem 0.9rem;}
</style>
""", unsafe_allow_html=True)


# ----------------------------------------------------------------------------
# Dados
# ----------------------------------------------------------------------------
@st.cache_data(show_spinner="Carregando base de lotes…")
def load_lots() -> pd.DataFrame:
    pq = EXPORTS / "lots.parquet"
    df = pd.read_parquet(pq) if pq.exists() else pd.read_csv(EXPORTS / "lots.csv", low_memory=False)
    df = df[df["excluded_sensitive"] != 1].copy()
    df["designer"] = df["designer"].fillna("—")
    df["item_type_normalized"] = df["item_type_normalized"].fillna("outro")
    if "macro_category" not in df.columns:
        df["macro_category"] = "Outro"
    df["macro_category"] = df["macro_category"].fillna("Outro")
    df["uf"] = df["uf"].fillna("?")
    df["signal"] = df["signal"].fillna("—")
    dt = pd.to_datetime(df["auction_datetime"], format="%d/%m/%Y", errors="coerce")
    dt_iso = pd.to_datetime(df["auction_datetime"], errors="coerce", format="ISO8601")
    df["auction_date"] = dt.fillna(dt_iso)
    df["preco_ref"] = df["hammer_price_brl"].fillna(df["current_bid_brl"])
    # memória: categoriza colunas repetitivas e reduz numéricos (cabe no tier grátis)
    for c in ["house_domain", "item_type_normalized", "macro_category", "size_class",
              "designer", "attribution_strength", "material", "condition_tier",
              "status", "uf", "signal"]:
        if c in df.columns:
            df[c] = df[c].astype("category")
    for c in ["current_bid_brl", "opening_bid_brl", "hammer_price_brl", "preco_ref",
              "est_resale_base", "est_gross_margin_pct", "max_bid_40pct", "confidence"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], downcast="float")
    for c in ["bid_count", "sold"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], downcast="integer")
    return df


def brl(v) -> str:
    if v is None or pd.isna(v):
        return "—"
    return "R$ " + f"{float(v):,.0f}".replace(",", ".")


def intbr(v) -> str:
    return f"{int(v):,}".replace(",", ".")


lots = load_lots()
ITEM_LABELS = {
    "cadeira": "Cadeira", "par_de_cadeiras": "Par de cadeiras",
    "conjunto_de_cadeiras": "Conjunto de cadeiras", "poltrona": "Poltrona",
    "par_de_poltronas": "Par de poltronas", "sofa": "Sofá", "banco": "Banco",
    "mesa_de_centro": "Mesa de centro", "mesa_lateral": "Mesa lateral/apoio",
    "mesa_de_jantar": "Mesa de jantar", "mesa": "Mesa", "aparador": "Aparador",
    "comoda": "Cômoda", "estante": "Estante", "armario": "Armário", "cama": "Cama",
    "escrivaninha": "Escrivaninha", "cristaleira": "Cristaleira",
    "escultura": "Escultura", "luminaria_lustre": "Luminária/Lustre",
    "espelho": "Espelho", "tapete": "Tapete", "quadro_pintura": "Quadro/Pintura",
    "gravura": "Gravura", "porcelana_ceramica": "Porcelana/Cerâmica",
    "cristal_vidro": "Cristal/Vidro", "prata_metal": "Prata/Metal",
    "objeto_decorativo": "Objeto decorativo", "outro": "Outro",
}


def nice(it):
    return ITEM_LABELS.get(it, it.replace("_", " ").capitalize())


# ----------------------------------------------------------------------------
# Cabeçalho
# ----------------------------------------------------------------------------
st.title("🔨 LeilõesBR — Inteligência de Mercado")
st.caption("Preço de martelo **real**, liquidez e oportunidades de arte, antiguidades e "
           "mobiliário modernista. Dados de páginas públicas, coletados com rate limit.")

# ----------------------------------------------------------------------------
# Filtros globais
# ----------------------------------------------------------------------------
sb = st.sidebar
sb.header("Filtros")
sb.caption("Valem para todas as abas.")

status_opts = sorted(lots["status"].dropna().unique())
status_sel = sb.multiselect("Situação", status_opts, default=status_opts,
                            help="finalizado = já vendido/encerrado (tem martelo). "
                                 "andamento = aberto para lance agora.")

# --- recorte temporal (baseado na data do pregão dos finalizados) ---
_dates = lots["auction_date"].dropna()
DATA_MAX = _dates.max() if len(_dates) else pd.Timestamp.today()
DATA_MIN = _dates.min() if len(_dates) else DATA_MAX
anos = sorted({int(a) for a in _dates.dt.year.unique()}, reverse=True) if len(_dates) else []
periodo_opts = (["Tudo", "YTD (ano corrente)", "Últimos 2 meses",
                 "Últimos 6 meses", "Últimos 12 meses", "Últimos 24 meses"]
                + [f"Ano {a}" for a in anos])
periodo = sb.selectbox("Período (data do pregão)", periodo_opts, index=0,
                       help="Filtra pela data de encerramento. Lotes 'em andamento' "
                            "(sem data passada) só aparecem quando 'Tudo' está selecionado.")

# Família (macro): permite excluir grupos inteiros, ex.: Numismática/Filatelia
fam_opts = sorted(lots["macro_category"].unique())
TESE = ["Mobiliário", "Arte", "Decoração"]
fam_default = [m for m in TESE if m in fam_opts]
fam_modo = sb.radio("Família", ["Foco na tese (móveis/arte/decoração)",
                                "Tudo", "Escolher manualmente"], index=0,
                    help="A tese exclui numismática, filatelia, joias, livros etc. "
                         "Escolha 'Tudo' ou 'Manualmente' para incluir esses grupos.")
if fam_modo == "Foco na tese (móveis/arte/decoração)":
    fam_sel = fam_default
elif fam_modo == "Tudo":
    fam_sel = fam_opts
else:
    fam_sel = sb.multiselect("Famílias incluídas", fam_opts, default=fam_default)

tipos = sorted(lots[lots["macro_category"].isin(fam_sel)]["item_type_normalized"].unique())
tipo_sel = sb.multiselect("Tipo de peça", tipos, default=[], format_func=nice)
designers = sorted(d for d in lots["designer"].unique() if d != "—")
designer_sel = sb.multiselect("Designer/autor", designers, default=[])
ufs = sorted(u for u in lots["uf"].unique() if u != "?")
uf_sel = sb.multiselect("UF", ufs, default=[])
casas = sorted(lots["house_domain"].dropna().unique())
casa_sel = sb.multiselect("Casa de leilão", casas, default=[])
preco_max = sb.number_input("Preço máx. (R$, 0 = sem limite)", min_value=0, value=0, step=100)
busca = sb.text_input("Busca no título", "", placeholder="jacarandá, Tenreiro, palhinha…")

f = lots[lots["status"].isin(status_sel) & lots["macro_category"].isin(fam_sel)].copy()

# aplica o recorte temporal (âncora = hoje)
hoje = pd.Timestamp.today().normalize()
if periodo != "Tudo":
    d = f["auction_date"]
    if periodo == "YTD (ano corrente)":
        f = f[d >= pd.Timestamp(hoje.year, 1, 1)]
    elif periodo.startswith("Últimos"):
        meses = int(periodo.split()[1])
        f = f[d >= hoje - pd.DateOffset(months=meses)]
    elif periodo.startswith("Ano "):
        ano = int(periodo.split()[1])
        f = f[d.dt.year == ano]

if tipo_sel:
    f = f[f["item_type_normalized"].isin(tipo_sel)]
if designer_sel:
    f = f[f["designer"].isin(designer_sel)]
if uf_sel:
    f = f[f["uf"].isin(uf_sel)]
if casa_sel:
    f = f[f["house_domain"].isin(casa_sel)]
if preco_max > 0:
    f = f[f["preco_ref"].fillna(0) <= preco_max]
if busca.strip():
    f = f[f["title"].str.contains(busca.strip(), case=False, na=False)]

sb.markdown("---")
sb.metric("Lotes no recorte", intbr(len(f)))
_fd = f["auction_date"].dropna()
if len(_fd):
    sb.caption(f"📅 Período no recorte: {_fd.min():%d/%m/%Y} – {_fd.max():%d/%m/%Y}")
sb.caption("Dica: combine filtros (ex.: tipo = Poltrona + período = Últimos 6 meses).")

fin = f[f["status"] == "finalizado"]
soldf = fin[fin["sold"] == 1]
live = f[f["status"] == "andamento"]

# ----------------------------------------------------------------------------
# KPIs
# ----------------------------------------------------------------------------
k = st.columns(5)
k[0].metric("Lotes", intbr(len(f)))
k[1].metric("Vendas com martelo", intbr(len(soldf)),
            help="Lotes finalizados que foram vendidos — base de preço real.")
k[2].metric("Sell-through", f"{len(soldf)/len(fin):.0%}".replace("%", "") + "%"
            if len(fin) else "—", help="% dos lotes ofertados que venderam.")
k[3].metric("Martelo mediano", brl(soldf["hammer_price_brl"].median()) if len(soldf) else "—")
k[4].metric("Abertos agora", intbr(len(live)), help="Lotes em andamento, aceitando lance.")

tabs = st.tabs([
    "📖 Comece aqui", "📊 Visão geral", "🪑 Categorias", "✍️ Designers",
    "🏛️ Casas", "💰 Preços & competição", "🗺️ Geografia",
    "🎯 Oportunidades", "🔍 Explorar dados"])

# ============================================================================
# 0. Comece aqui
# ============================================================================
with tabs[0]:
    st.subheader("O que é isto?")
    st.markdown(f"""
Uma base de **{intbr(len(lots))} lotes** de leilões de arte, antiguidades e mobiliário
no Brasil, coletada das páginas públicas da plataforma LeilõesBR. O diferencial:
não são estimativas — temos o **preço de martelo real** de
**{intbr((lots['sold'] == 1).sum())} vendas** efetivamente fechadas.

Use os **filtros à esquerda** para recortar por tipo de peça, designer, casa, estado ou
preço — todas as abas reagem ao recorte.
""")
    c1, c2 = st.columns(2)
    with c1:
        st.markdown("""
##### 📌 As abas
- **Visão geral** — o retrato do recorte em gráficos.
- **Categorias** — quais tipos de peça dão giro e quais dão margem.
- **Designers** — quanto realmente vale cada nome (Sergio Rodrigues, Tenreiro…).
- **Casas** — onde comprar barato × quem vende bem.
- **Preços & competição** — como os lances se comportam.
- **Geografia** — onde estão os lotes (roteiro de garimpo).
- **Oportunidades** — lotes abertos com sinal de compra.
- **Explorar dados** — tabela livre + download.
""")
    with c2:
        st.markdown("""
##### 📖 Glossário rápido
- **Sell-through**: % dos lotes ofertados que venderam. Alto = líquido.
- **Martelo**: preço final de arremate (o que o item valeu de verdade).
- **Zero-bid**: lotes que terminaram sem nenhum lance.
- **BUY_NOW / WATCH / AVOID**: sinais de triagem para compra (aba Oportunidades).
- **Observed × Inferred**: martelo, lances e status são *observados* no site;
  tipo de peça, designer e margem são *inferidos* por regras automáticas.
""")
    st.info("⚠️ **Como interpretar os sinais de compra:** são triagem conservadora, "
            "não garantia de lucro. A atribuição de designer é por palavra-chave e não "
            "distingue o modelo exato — sempre confirme a peça no link antes de dar lance.")

# ============================================================================
# 1. Visão geral
# ============================================================================
with tabs[1]:
    st.subheader("Retrato do recorte")
    if f.empty:
        st.info("Sem lotes no recorte. Afrouxe os filtros.")
    else:
        c1, c2 = st.columns(2)
        top_tipos = (f["item_type_normalized"].value_counts().head(15)
                     .rename(index=nice).reset_index())
        top_tipos.columns = ["tipo", "lotes"]
        c1.plotly_chart(px.bar(top_tipos, x="lotes", y="tipo", orientation="h",
                               title="Tipos de peça mais frequentes",
                               color="lotes", color_continuous_scale="Tealgrn")
                        .update_layout(yaxis={"categoryorder": "total ascending"},
                                       coloraxis_showscale=False),
                        width="stretch")
        sit = f["status"].value_counts().reset_index()
        sit.columns = ["situação", "lotes"]
        c2.plotly_chart(px.pie(sit, names="situação", values="lotes", hole=0.55,
                               title="Situação dos lotes"), width="stretch")
        if len(soldf):
            st.markdown("##### Faixas de preço de martelo (vendidos no recorte)")
            bins = [0, 100, 300, 500, 1000, 2500, 5000, 10000, 1e9]
            labels = ["até 100", "100–300", "300–500", "500–1k", "1k–2,5k",
                      "2,5k–5k", "5k–10k", "10k+"]
            faixa = pd.cut(soldf["hammer_price_brl"], bins=bins, labels=labels)
            fc = faixa.value_counts().reindex(labels).reset_index()
            fc.columns = ["faixa (R$)", "lotes"]
            st.plotly_chart(px.bar(fc, x="faixa (R$)", y="lotes",
                                   title="Distribuição por faixa de preço",
                                   color="lotes", color_continuous_scale="Sunsetdark")
                            .update_layout(coloraxis_showscale=False),
                            width="stretch")

# ============================================================================
# 2. Categorias
# ============================================================================
with tabs[2]:
    st.subheader("Liquidez × ticket por tipo de peça")
    st.caption("Cada bolha é um tipo de peça. Direita = vende mais (líquido). "
               "Cima = martelo mais alto (ticket). Tamanho = volume ofertado.")
    g = fin.groupby("item_type_normalized", observed=True).agg(
        ofertados=("lot_id", "count"), vendidos=("sold", "sum"),
        martelo_mediano=("hammer_price_brl", "median"),
        lances_medio=("bid_count", "mean")).reset_index()
    g = g[g["ofertados"] >= 20]
    g["sell_through"] = g["vendidos"] / g["ofertados"]
    g["Tipo"] = g["item_type_normalized"].map(nice)
    if g.empty:
        st.info("Volume insuficiente no recorte.")
    else:
        fig = px.scatter(g, x="sell_through", y="martelo_mediano", size="ofertados",
                         text="Tipo", color="martelo_mediano", log_y=True,
                         color_continuous_scale="Viridis", size_max=55,
                         labels={"sell_through": "sell-through",
                                 "martelo_mediano": "martelo mediano (R$, escala log)"})
        fig.update_traces(textposition="top center")
        fig.update_layout(xaxis_tickformat=".0%", coloraxis_showscale=False, height=560)
        st.plotly_chart(fig, width="stretch")
        show = g.sort_values("sell_through", ascending=False)[
            ["Tipo", "ofertados", "vendidos", "sell_through", "martelo_mediano", "lances_medio"]]
        st.dataframe(show, width="stretch", hide_index=True,
                     column_config={
                         "sell_through": st.column_config.NumberColumn("sell-through", format="%.0f%%"),
                         "martelo_mediano": st.column_config.NumberColumn("martelo mediano", format="R$ %.0f"),
                         "lances_medio": st.column_config.NumberColumn("lances médio", format="%.1f"),
                     })

# ============================================================================
# 3. Designers
# ============================================================================
with tabs[3]:
    st.subheader("Quanto vale cada nome (martelo real de vendas)")
    d = soldf[soldf["designer"] != "—"]
    if d.empty:
        st.info("Nenhuma venda com designer detectado no recorte.")
    else:
        order = d.groupby("designer", observed=True)["hammer_price_brl"].median().sort_values(ascending=False).index
        fig = px.box(d, x="designer", y="hammer_price_brl", color="designer",
                     category_orders={"designer": list(order)}, log_y=True, points="outliers",
                     labels={"hammer_price_brl": "martelo (R$, escala log)", "designer": ""})
        fig.update_layout(showlegend=False, height=520, xaxis_tickangle=-30)
        st.plotly_chart(fig, width="stretch")
        resumo = d.groupby("designer", observed=True).agg(
            vendas=("lot_id", "count"), mediana=("hammer_price_brl", "median"),
            minimo=("hammer_price_brl", "min"), maximo=("hammer_price_brl", "max"),
            lances_medio=("bid_count", "mean")).sort_values("mediana", ascending=False).reset_index()
        st.dataframe(resumo, width="stretch", hide_index=True,
                     column_config={
                         "mediana": st.column_config.NumberColumn("mediana", format="R$ %.0f"),
                         "minimo": st.column_config.NumberColumn("mín", format="R$ %.0f"),
                         "maximo": st.column_config.NumberColumn("máx", format="R$ %.0f"),
                         "lances_medio": st.column_config.NumberColumn("lances médio", format="%.1f"),
                     })
        st.caption("A variação mín–máx é grande porque o match é por palavra-chave e "
                   "mistura linhas/modelos diferentes do mesmo autor. Use como ordem de "
                   "grandeza, não como avaliação de peça específica.")

# ============================================================================
# 4. Casas
# ============================================================================
with tabs[4]:
    st.subheader("Onde comprar barato × quem vende bem")
    h = fin.groupby("house_domain", observed=True).agg(
        finalizados=("lot_id", "count"), vendidos=("sold", "sum"),
        zero_bid=("bid_count", lambda s: (s == 0).mean()),
        martelo_medio=("hammer_price_brl", "mean")).reset_index()
    h = h[h["finalizados"] >= 30]
    h["sell_through"] = h["vendidos"] / h["finalizados"]
    if h.empty:
        st.info("Sem casas com ≥30 finalizados no recorte.")
    else:
        fig = px.scatter(h, x="zero_bid", y="sell_through", size="finalizados",
                         color="martelo_medio", hover_name="house_domain",
                         color_continuous_scale="Plasma", size_max=45,
                         labels={"zero_bid": "taxa sem lance", "sell_through": "sell-through",
                                 "martelo_medio": "martelo médio"})
        fig.update_layout(xaxis_tickformat=".0%", yaxis_tickformat=".0%", height=520)
        st.plotly_chart(fig, width="stretch")
        st.caption("Esquerda-alto = **benchmark** (vende quase tudo). "
                   "Direita = **sourcing** (muito lote sem lance → pechincha/pós-pregão).")
        c1, c2 = st.columns(2)
        c1.markdown("**🛒 Sourcing — maior % sem lance**")
        c1.dataframe(h.sort_values("zero_bid", ascending=False).head(15)[
            ["house_domain", "finalizados", "zero_bid", "sell_through", "martelo_medio"]],
            width="stretch", hide_index=True, column_config={
                "zero_bid": st.column_config.NumberColumn("sem lance", format="%.0f%%"),
                "sell_through": st.column_config.NumberColumn("sell-thru", format="%.0f%%"),
                "martelo_medio": st.column_config.NumberColumn("martelo méd", format="R$ %.0f")})
        c2.markdown("**🏆 Benchmark — maior sell-through**")
        c2.dataframe(h.sort_values("sell_through", ascending=False).head(15)[
            ["house_domain", "finalizados", "sell_through", "martelo_medio"]],
            width="stretch", hide_index=True, column_config={
                "sell_through": st.column_config.NumberColumn("sell-thru", format="%.0f%%"),
                "martelo_medio": st.column_config.NumberColumn("martelo méd", format="R$ %.0f")})

# ============================================================================
# 5. Preços & competição
# ============================================================================
with tabs[5]:
    st.subheader("Como os lances se comportam")
    if fin.empty:
        st.info("Sem finalizados no recorte.")
    else:
        c1, c2 = st.columns(2)
        bc = fin["bid_count"].clip(upper=30)
        c1.plotly_chart(px.histogram(bc, nbins=31, title="Nº de lances por lote (corte em 30)",
                                     labels={"value": "lances", "count": "lotes"})
                        .update_layout(showlegend=False), width="stretch")
        s2 = soldf[soldf["opening_bid_brl"] > 0].copy()
        if len(s2):
            s2["mult"] = (s2["hammer_price_brl"] / s2["opening_bid_brl"]).clip(upper=20)
            c2.plotly_chart(px.histogram(s2, x="mult", nbins=40,
                                         title="Martelo ÷ lance inicial (quantas vezes subiu)",
                                         labels={"mult": "× sobre o inicial"})
                            .update_layout(showlegend=False), width="stretch")
        if len(soldf):
            um = (soldf["bid_count"] == 1).mean()
            zero = (fin["bid_count"] == 0).mean()
            m = st.columns(3)
            m[0].metric("Vendas com 1 lance só", f"{um:.0%}",
                        help="Comprou sozinho, sem disputa.")
            m[1].metric("Lotes sem nenhum lance", f"{zero:.0%}")
            m[2].metric("Martelo p25 / p75",
                        f"{brl(soldf['hammer_price_brl'].quantile(.25))} / "
                        f"{brl(soldf['hammer_price_brl'].quantile(.75))}")
            st.plotly_chart(px.histogram(soldf, x="hammer_price_brl", nbins=60, log_y=True,
                                         title="Distribuição de preço de martelo (Y log)",
                                         labels={"hammer_price_brl": "martelo (R$)"})
                            .update_layout(showlegend=False), width="stretch")

# ============================================================================
# 6. Geografia
# ============================================================================
with tabs[6]:
    st.subheader("Onde estão os lotes (roteiro de garimpo)")
    geo = f[f["uf"] != "?"].groupby("uf", observed=True).agg(
        lotes=("lot_id", "count"),
        martelo_mediano=("hammer_price_brl", "median")).reset_index().sort_values("lotes", ascending=False)
    if geo.empty:
        st.info("Sem UF identificada no recorte.")
    else:
        c1, c2 = st.columns([3, 2])
        c1.plotly_chart(px.bar(geo, x="uf", y="lotes", color="lotes",
                               color_continuous_scale="Blues", title="Lotes por estado")
                        .update_layout(coloraxis_showscale=False), width="stretch")
        c2.dataframe(geo, width="stretch", hide_index=True, column_config={
            "martelo_mediano": st.column_config.NumberColumn("martelo mediano", format="R$ %.0f")})

# ============================================================================
# 7. Oportunidades
# ============================================================================
with tabs[7]:
    st.subheader("Lotes abertos com sinal de compra")
    sig = st.radio("Sinal", ["BUY_NOW", "WATCH", "AVOID"], horizontal=True,
                   captions=["comprar", "observar", "evitar"])
    o = f[(f["status"] == "andamento") & (f["signal"] == sig)].sort_values(
        "est_gross_margin_pct", ascending=False)
    st.markdown(f"**{len(o)} lotes** com sinal `{sig}` no recorte.")
    if not o.empty:
        show = o[["title", "item_type_normalized", "designer", "attribution_strength",
                  "current_bid_brl", "bid_count", "est_resale_base", "est_gross_margin_pct",
                  "max_bid_40pct", "uf", "house_domain", "lot_url"]].copy()
        show["item_type_normalized"] = show["item_type_normalized"].map(nice)
        st.dataframe(show, width="stretch", hide_index=True, column_config={
            "lot_url": st.column_config.LinkColumn("lote", display_text="abrir ↗"),
            "title": st.column_config.TextColumn("título", width="large"),
            "item_type_normalized": "tipo",
            "designer": "designer",
            "attribution_strength": "atribuição",
            "current_bid_brl": st.column_config.NumberColumn("lance atual", format="R$ %.0f"),
            "bid_count": "lances",
            "est_resale_base": st.column_config.NumberColumn("revenda est.", format="R$ %.0f"),
            "est_gross_margin_pct": st.column_config.NumberColumn("margem", format="%.0f%%"),
            "max_bid_40pct": st.column_config.NumberColumn("lance máx (40%)", format="R$ %.0f"),
        })
        st.caption("Triagem conservadora (p25 dos comparáveis × markup de varejo). "
                   "Confirme cada peça no link antes de dar lance.")

# ============================================================================
# 8. Explorar dados
# ============================================================================
with tabs[8]:
    st.subheader("Tabela livre do recorte")
    n = st.slider("Linhas", 50, 3000, 400, step=50)
    cols = ["status", "title", "item_type_normalized", "designer", "preco_ref",
            "bid_count", "sold", "uf", "house_domain", "auction_date", "lot_url"]
    view = f[cols].head(n).copy()
    view["item_type_normalized"] = view["item_type_normalized"].map(nice)
    st.dataframe(view, width="stretch", hide_index=True, column_config={
        "lot_url": st.column_config.LinkColumn("lote", display_text="abrir ↗"),
        "title": st.column_config.TextColumn("título", width="large"),
        "item_type_normalized": "tipo",
        "preco_ref": st.column_config.NumberColumn("preço (martelo/lance)", format="R$ %.0f"),
        "auction_date": st.column_config.DateColumn("data", format="DD/MM/YYYY"),
    })
    st.download_button("⬇️ Baixar recorte filtrado (CSV)",
                       f.drop(columns=["preco_ref"], errors="ignore").to_csv(index=False).encode("utf-8"),
                       file_name="recorte_leiloes.csv", mime="text/csv")
