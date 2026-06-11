"""Exporta os entregáveis: 6 CSVs + relatório executivo + dicionário de dados.
Números no relatório em formato brasileiro (R$ 10.200,00 / 22,7%)."""
from datetime import datetime

import pandas as pd

import config
import db
import metrics


def brl(v) -> str:
    if v is None or pd.isna(v):
        return "—"
    return "R$ " + f"{float(v):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def pctbr(v) -> str:
    if v is None or pd.isna(v):
        return "—"
    return f"{float(v) * 100:.1f}".replace(".", ",") + "%"


def intbr(n) -> str:
    return f"{int(n):,}".replace(",", ".")


def q(conn, sql):
    return pd.read_sql_query(sql, conn)


def export_csvs(conn):
    config.EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
    E = config.EXPORTS_DIR

    q(conn, """SELECT a.house_domain, h.name AS auction_house, a.auction_id,
                      a.auction_datetime, a.uf, a.source_url, a.scraped_at
               FROM auctions a LEFT JOIN auction_houses h USING(house_domain)
               ORDER BY a.auction_datetime DESC""").to_csv(E / "auctions.csv", index=False)

    q(conn, """SELECT l.house_domain, l.lot_id, l.auction_id, l.title, l.uf,
                      l.auction_datetime, l.lot_url, l.thumbnail_url, l.excluded_sensitive,
                      e.item_type_normalized, e.size_class, e.designer, e.attribution_strength,
                      e.material, e.period_hint, e.condition_tier, e.is_pair_or_set,
                      e.matched_keywords,
                      s.status, s.current_bid_brl, s.opening_bid_brl, s.hammer_price_brl,
                      s.bid_count, s.sold,
                      e.est_resale_base, e.est_total_cost, e.est_gross_margin_pct,
                      e.max_bid_40pct, e.confidence, e.signal, e.signal_reasons
               FROM lots l
               LEFT JOIN lot_enrichment e USING(house_domain, lot_id)
               LEFT JOIN lot_snapshots s ON s.house_domain=l.house_domain AND s.lot_id=l.lot_id
                    AND s.scraped_at=(SELECT MAX(scraped_at) FROM lot_snapshots s2
                                      WHERE s2.house_domain=l.house_domain AND s2.lot_id=l.lot_id)
               """).to_csv(E / "lots.csv", index=False)

    house_m = house_metrics(conn)
    house_m.to_csv(E / "auction_house_metrics.csv", index=False)
    cat_m = category_metrics(conn)
    cat_m.to_csv(E / "category_metrics.csv", index=False)

    opp = q(conn, """SELECT l.house_domain, l.lot_id, l.title, l.uf, l.lot_url,
                            e.item_type_normalized, e.designer, e.attribution_strength,
                            e.condition_tier, e.size_class,
                            s.current_bid_brl, s.bid_count,
                            e.est_resale_base, e.est_total_cost, e.est_gross_profit,
                            e.est_gross_margin_pct, e.max_bid_40pct, e.confidence,
                            e.signal, e.signal_reasons
                     FROM lot_enrichment e
                     JOIN lots l USING(house_domain, lot_id)
                     JOIN lot_snapshots s ON s.house_domain=l.house_domain AND s.lot_id=l.lot_id
                          AND s.status='andamento'
                     WHERE e.signal='BUY_NOW' AND l.excluded_sensitive=0
                     ORDER BY e.est_gross_profit DESC, e.confidence DESC""")
    opp.to_csv(E / "opportunity_lots.csv", index=False)

    avoid = q(conn, """SELECT l.house_domain, l.lot_id, l.title, l.uf, l.lot_url,
                              e.item_type_normalized, e.designer, e.attribution_strength,
                              e.condition_tier, e.size_class, s.current_bid_brl, s.bid_count,
                              e.est_resale_base, e.est_gross_margin_pct, e.signal, e.signal_reasons
                       FROM lot_enrichment e
                       JOIN lots l USING(house_domain, lot_id)
                       JOIN lot_snapshots s ON s.house_domain=l.house_domain AND s.lot_id=l.lot_id
                            AND s.status='andamento'
                       WHERE e.signal='AVOID' AND l.excluded_sensitive=0
                         AND s.current_bid_brl <= 2000
                       ORDER BY s.current_bid_brl ASC""")
    avoid.to_csv(E / "avoid_lots.csv", index=False)
    return house_m, cat_m, opp, avoid


def house_metrics(conn):
    df = q(conn, """SELECT h.house_domain, h.name, h.uf,
                           SUM(CASE WHEN s.status='finalizado' THEN 1 ELSE 0 END) AS lots_finalizados,
                           SUM(CASE WHEN s.sold=1 THEN 1 ELSE 0 END) AS lots_vendidos,
                           SUM(CASE WHEN s.status='finalizado' AND s.bid_count=0 THEN 1 ELSE 0 END) AS lots_zero_lance,
                           AVG(CASE WHEN s.sold=1 THEN s.hammer_price_brl END) AS martelo_medio,
                           SUM(CASE WHEN s.status='andamento' THEN 1 ELSE 0 END) AS lots_ao_vivo
                    FROM auction_houses h
                    LEFT JOIN lot_snapshots s USING(house_domain)
                    GROUP BY h.house_domain
                    HAVING lots_finalizados > 0 OR lots_ao_vivo > 0""")
    df["sell_through"] = (df["lots_vendidos"] / df["lots_finalizados"]).where(df["lots_finalizados"] > 0)
    df["zero_bid_rate"] = (df["lots_zero_lance"] / df["lots_finalizados"]).where(df["lots_finalizados"] > 0)
    return df.sort_values("lots_finalizados", ascending=False)


def category_metrics(conn):
    df = q(conn, """SELECT e.item_type_normalized AS item_type,
                           SUM(CASE WHEN s.status='finalizado' THEN 1 ELSE 0 END) AS ofertados,
                           SUM(CASE WHEN s.sold=1 THEN 1 ELSE 0 END) AS vendidos,
                           SUM(CASE WHEN s.status='finalizado' AND s.bid_count=0 THEN 1 ELSE 0 END) AS zero_lance,
                           AVG(CASE WHEN s.sold=1 THEN s.hammer_price_brl END) AS martelo_medio,
                           AVG(CASE WHEN s.sold=1 THEN s.bid_count END) AS lances_medio,
                           SUM(CASE WHEN s.status='andamento' THEN 1 ELSE 0 END) AS ao_vivo
                    FROM lot_enrichment e
                    JOIN lots l USING(house_domain, lot_id)
                    JOIN lot_snapshots s ON s.house_domain=e.house_domain AND s.lot_id=e.lot_id
                    WHERE l.excluded_sensitive=0
                    GROUP BY e.item_type_normalized""")
    # mediana de martelo por tipo
    med = q(conn, """SELECT e.item_type_normalized AS item_type, s.hammer_price_brl AS h
                     FROM lot_enrichment e
                     JOIN lot_snapshots s ON s.house_domain=e.house_domain AND s.lot_id=e.lot_id
                     WHERE s.sold=1 AND s.hammer_price_brl>0""")
    medians = med.groupby("item_type")["h"].median().rename("martelo_mediano")
    df = df.merge(medians, on="item_type", how="left")
    df["sell_through"] = (df["vendidos"] / df["ofertados"]).where(df["ofertados"] > 0)
    df["zero_bid_rate"] = (df["zero_lance"] / df["ofertados"]).where(df["ofertados"] > 0)
    return df.sort_values("ofertados", ascending=False)


def portfolio(opp, budget, premium=0.05):
    """Carteira greedy: maior lucro esperado, diversificando por casa, dentro do orçamento."""
    chosen, spent, per_house = [], 0.0, {}
    for _, r in opp.sort_values(["est_gross_profit", "confidence"], ascending=False).iterrows():
        cost = (r["current_bid_brl"] or 0) * (1 + premium)
        if cost <= 0 or spent + cost > budget:
            continue
        if per_house.get(r["house_domain"], 0) >= 4:
            continue
        chosen.append(r)
        spent += cost
        per_house[r["house_domain"]] = per_house.get(r["house_domain"], 0) + 1
        if len(chosen) >= 40:
            break
    return chosen, spent


def md_table(rows, headers):
    out = ["| " + " | ".join(headers) + " |", "|" + "|".join(["---"] * len(headers)) + "|"]
    for r in rows:
        out.append("| " + " | ".join(str(c) for c in r) + " |")
    return "\n".join(out)


def write_report(conn, house_m, cat_m, opp, avoid):
    A = metrics.load_assumptions()
    now = datetime.now().strftime("%d/%m/%Y %H:%M")
    n_lots = conn.execute("SELECT COUNT(*) FROM lots").fetchone()[0]
    n_live = conn.execute("SELECT COUNT(DISTINCT house_domain||lot_id) FROM lot_snapshots WHERE status='andamento'").fetchone()[0]
    n_fin = conn.execute("SELECT COUNT(*) FROM lot_snapshots WHERE status='finalizado'").fetchone()[0]
    n_sold = conn.execute("SELECT COUNT(*) FROM lot_snapshots WHERE sold=1").fetchone()[0]
    n_houses = conn.execute("SELECT COUNT(*) FROM auction_houses").fetchone()[0]
    overall_st = (n_sold / n_fin) if n_fin else 0

    # top categorias por liquidez e por giro/martelo
    catv = cat_m[cat_m["ofertados"] >= 30].copy()
    top_st = catv.sort_values("sell_through", ascending=False).head(12)
    top_ticket = catv.sort_values("martelo_mediano", ascending=False).head(12)
    low_logi = catv[catv["item_type"].isin(
        ["cadeira", "par_de_cadeiras", "poltrona", "mesa_lateral", "mesa_de_centro",
         "luminaria_lustre", "espelho", "quadro_pintura", "gravura", "escultura",
         "porcelana_ceramica", "cristal_vidro", "prata_metal", "objeto_decorativo"])]
    low_logi = low_logi.sort_values("sell_through", ascending=False).head(12)

    # casas para sourcing: alto zero_bid + volume
    hv = house_m[house_m["lots_finalizados"] >= 50].copy()
    src = hv.sort_values("zero_bid_rate", ascending=False).head(15)
    bench = hv.sort_values("sell_through", ascending=False).head(15)

    p30, s30 = portfolio(opp, 30000, A["buyer_premium_pct"])
    p50, s50 = portfolio(opp, 50000, A["buyer_premium_pct"])

    L = []
    L.append("# Relatório de Inteligência de Mercado — LeilõesBR\n")
    L.append(f"_Gerado em {now}. Coleta de páginas públicas, sem login, com rate limit._\n")

    L.append("## 1. Resumo executivo\n")
    L.append(f"- **Lotes coletados:** {intbr(n_lots)} "
             f"({intbr(n_live)} ao vivo, {intbr(n_fin)} finalizados)")
    L.append(f"- **Casas/leiloeiros mapeados:** {n_houses}")
    L.append(f"- **Lotes vendidos com martelo observado:** {intbr(n_sold)}"
             f" → **sell-through global {pctbr(overall_st)}**")
    L.append("- **Fonte de preço:** martelo REAL de leilões finalizados (últimos ~15 dias), "
             "não proxy. Lances ao vivo da busca por categoria.\n")

    L.append("> **Observed vs inferred.** Martelo, lance, nº de lances e status de venda são "
             "_observados_ no site. Tipo de peça, designer, força de atribuição, custos de "
             "frete/restauro, valor de revenda estimado, margem e sinais são _inferidos_ por "
             "regras determinísticas (ver `data_dictionary.md`).\n")

    L.append("## 2. Top categorias por sell-through (≥30 lotes finalizados)\n")
    L.append(md_table(
        [(r.item_type, int(r.ofertados), int(r.vendidos), pctbr(r.sell_through),
          brl(r.martelo_mediano), pctbr(r.zero_bid_rate))
         for r in top_st.itertuples()],
        ["item_type", "ofertados", "vendidos", "sell-through", "martelo mediano", "zero-bid"]))
    L.append("")

    L.append("## 3. Top categorias por ticket (martelo mediano)\n")
    L.append(md_table(
        [(r.item_type, brl(r.martelo_mediano), pctbr(r.sell_through), int(r.ofertados))
         for r in top_ticket.itertuples()],
        ["item_type", "martelo mediano", "sell-through", "ofertados"]))
    L.append("")

    L.append("## 4. Categorias de baixa complexidade logística (foco operação solo)\n")
    L.append(md_table(
        [(r.item_type, pctbr(r.sell_through), brl(r.martelo_mediano), int(r.ofertados))
         for r in low_logi.itertuples()],
        ["item_type", "sell-through", "martelo mediano", "ofertados"]))
    L.append("")

    L.append("## 5. Casas para sourcing (maior zero-bid + volume ≥50)\n")
    L.append(md_table(
        [(r.name or r.house_domain, r.uf or "—", int(r.lots_finalizados),
          pctbr(r.zero_bid_rate), pctbr(r.sell_through), brl(r.martelo_medio))
         for r in src.itertuples()],
        ["casa", "uf", "finalizados", "zero-bid", "sell-through", "martelo médio"]))
    L.append("\n_Zero-bid alto = mais chance de arrematar barato / pós-pregão._\n")

    L.append("## 6. Casas benchmark (maior sell-through, volume ≥50)\n")
    L.append(md_table(
        [(r.name or r.house_domain, r.uf or "—", int(r.lots_finalizados),
          pctbr(r.sell_through), brl(r.martelo_medio))
         for r in bench.itertuples()],
        ["casa", "uf", "finalizados", "sell-through", "martelo médio"]))
    L.append("")

    L.append("## 7. Oportunidades de compra (sinal BUY_NOW)\n")
    L.append("> **Como ler.** Estes são sinais de _triagem_, não lucros garantidos. A revenda é "
             "estimada pelo p25 (conservador) dos martelos de comparáveis × markup de varejo. O "
             "comp agrupa por (tipo, designer), então **não distingue o modelo/linha específico** "
             "(ex.: uma 'Poltrona Cimba' barata herda o comp de poltronas do mesmo designer). "
             "Trate margens altas em itens de lance muito baixo como candidatos a verificar peça a "
             "peça (use a coluna `lot_url` e a amostra de auditoria), não como certezas.\n")
    L.append(f"Total de lotes BUY_NOW: **{len(opp)}**. Top 25 por lucro estimado (conservador):\n")
    L.append(md_table(
        [(r.title[:45] if isinstance(r.title, str) else "—",
          r.item_type_normalized, r.designer or "—",
          brl(r.current_bid_brl), brl(r.est_resale_base),
          pctbr(r.est_gross_margin_pct), brl(r.max_bid_40pct), r.uf or "—")
         for r in opp.head(25).itertuples()],
        ["título", "tipo", "designer", "lance atual", "revenda est.", "margem", "lance máx 40%", "uf"]))
    L.append("")

    L.append("## 8. Carteira sugerida — estoque inicial\n")
    for budget, chosen, spent in [(30000, p30, s30), (50000, p50, s50)]:
        L.append(f"### R$ {budget:,}".replace(",", ".") +
                 f" — {len(chosen)} peças, capital alocado {brl(spent)}\n")
        L.append(md_table(
            [(r["title"][:42] if isinstance(r["title"], str) else "—",
              r["item_type_normalized"], brl(r["current_bid_brl"]),
              brl(r["est_gross_profit"]), pctbr(r["est_gross_margin_pct"]), r["uf"] or "—")
             for r in chosen],
            ["título", "tipo", "lance", "lucro est.", "margem", "uf"]))
        tot_profit = sum(r["est_gross_profit"] for r in chosen)
        L.append(f"\n**Lucro bruto potencial da carteira (estimativa conservadora, a verificar "
                 f"peça a peça): {brl(tot_profit)}** "
                 f"(margem agregada {pctbr(tot_profit / (spent + tot_profit)) if (spent+tot_profit)>0 else '—'}). "
                 f"Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — "
                 f"confirme modelo/linha e autenticidade antes de arrematar.\n")

    L.append("## 9. Lances máximos por tipo de peça (para margem de 40%)\n")
    mb = opp.groupby("item_type_normalized")["max_bid_40pct"].median().sort_values(ascending=False)
    L.append(md_table([(it, brl(v)) for it, v in mb.items()],
                      ["item_type", "lance máx mediano (40% margem)"]))
    L.append("")

    L.append("## 10. Modelo A (casa de leilão) vs Modelo B (garimpo + revenda)\n")
    take = 0.15
    gmv_potential = (cat_m["martelo_mediano"].fillna(0) * cat_m["vendidos"].fillna(0)).sum()
    L.append(f"- **GMV observado** nas casas amostradas (martelo × vendidos): ~{brl(gmv_potential)} "
             "em ~15 dias — denso e pulverizado entre muitas casas.")
    L.append(f"- **Modelo A** com take de {pctbr(take)}: para cobrir OPEX de R$ 10.000 / 15.000 / 25.000 ao mês, "
             f"a casa precisaria de GMV mensal de ~{brl(10000/take)} / {brl(15000/take)} / {brl(25000/take)} "
             "respectivamente. Exige curadoria, captação de consignação e base de compradores — "
             "difícil para operação solo no início.")
    L.append(f"- **Modelo B** já é acionável hoje: {len(opp)} lotes BUY_NOW com margem ≥ "
             f"{pctbr(A['signals']['buy_now']['min_margin_pct'])}, capital inicial de R$ 30k aloca "
             f"{len(p30)} peças. Giro depende de logística — por isso o foco em peças small/medium/large.")
    L.append("\n**Recomendação:** começar pelo **Modelo B** (menor capital travado, risco operacional "
             "menor, lucro por peça verificável com os dados). Migrar para **Modelo A** quando o GMV "
             "mensal de revenda ultrapassar consistentemente ~" + brl(15000/take) +
             " e houver fluxo de consignação — aí o take fixo da casa passa a compensar o OPEX.\n")

    L.append("## 11. Limitações e vieses\n")
    L.append("- Janela de finalizados ≈ últimos 15 dias (rotativa do site); sazonalidade não capturada.")
    L.append("- Algumas casas usam plataforma distinta (≈10% de falhas 404/JSON) e ficam fora da amostra.")
    L.append("- Lotes ao vivo têm só título (descrição completa não disponível sem por-leilão); "
             "atribuição de designer pode ter falso-negativo quando o nome só aparece na descrição.")
    L.append("- Valor de revenda assume preço de mercado = mediana de martelo de comparáveis; "
             "é conservador para venda de varejo no Instagram e tem baixa confiança onde há poucos comps.")
    L.append("- Custos de frete/restauro são premissas (`assumptions.yaml`), não cotações.\n")

    L.append("## 12. Premissas usadas (`assumptions.yaml`)\n")
    L.append("```yaml")
    import yaml
    L.append(yaml.safe_dump(A, allow_unicode=True, sort_keys=False).strip())
    L.append("```")

    (config.EXPORTS_DIR / "market_intelligence_report.md").write_text("\n".join(L), encoding="utf-8")
    print("Relatório escrito.")


DATA_DICT = """# Dicionário de dados — leiloes-intel

Convenção: **OBSERVED** = extraído diretamente das páginas públicas do site.
**INFERRED** = derivado por regras determinísticas (config.py / metrics.py).

## auctions.csv (OBSERVED)
| campo | descrição |
|---|---|
| house_domain | domínio da casa de leilão (chave) |
| auction_house | nome do leiloeiro/galeria |
| auction_id | id do leilão na plataforma |
| auction_datetime | data/hora do pregão (ISO ou DD/MM/AAAA) |
| uf | estado |
| source_url | URL da casa |

## lots.csv
| campo | tipo | descrição |
|---|---|---|
| house_domain, lot_id | OBSERVED | chave do lote |
| title, description | OBSERVED | texto do lote (descrição só para finalizados) |
| uf, auction_datetime, lot_url, thumbnail_url | OBSERVED | metadados |
| status | OBSERVED | andamento / finalizado |
| current_bid_brl | OBSERVED | lance atual (ao vivo) |
| opening_bid_brl | OBSERVED | lance inicial (finalizados) |
| hammer_price_brl | OBSERVED | preço de martelo (finalizados vendidos) |
| bid_count | OBSERVED | nº de lances |
| sold | OBSERVED | 1 se "Lote vendido" |
| excluded_sensitive | INFERRED | 1 se menciona categoria sensível (fora das métricas) |
| item_type_normalized | INFERRED | classe normalizada (cadeira, poltrona, mesa_de_centro...) |
| size_class | INFERRED | small/medium/large/xl → bracket de frete |
| designer | INFERRED | designer/autor detectado por keyword |
| attribution_strength | INFERRED | DOCUMENTED>STATED>ATTRIBUTED>STYLE_OF>MATERIAL_HINT>NONE |
| material, period_hint | INFERRED | material nobre / sinal de época |
| condition_tier | INFERRED | none/light/heavy (estado → custo de restauro) |
| matched_keywords | INFERRED | termos que dispararam a classificação (auditoria) |
| est_resale_base | INFERRED | valor de revenda estimado (mediana de comps de martelo) |
| est_total_cost | INFERRED | lance×(1+comissão) + frete + embalagem + restauro |
| est_gross_margin_pct | INFERRED | (revenda - custo) / revenda |
| max_bid_40pct | INFERRED | lance máximo p/ manter 40% de margem |
| confidence | INFERRED | 0–1, baseado em nº de comps, atribuição e descrição |
| signal | INFERRED | BUY_NOW / WATCH / AVOID |
| signal_reasons | INFERRED | critérios disparados |

## auction_house_metrics.csv / category_metrics.csv (INFERRED a partir de OBSERVED)
Agregados de liquidez: sell_through = vendidos/ofertados; zero_bid_rate = lotes
sem lance/ofertados; martelo_medio/mediano; lances_medio (bid intensity).

## opportunity_lots.csv — lotes ao vivo com signal=BUY_NOW, ordenados por lucro esperado.
## avoid_lots.csv — lotes ao vivo baratos (≤R$2.000) com signal=AVOID (armadilhas de capital).

## Regras de atribuição (resumo)
- DOCUMENTED: "assinado", "etiqueta", "selo", "marca de fogo", "certificado".
- ATTRIBUTED: "atribuído a".
- STYLE_OF: "no estilo", "ao gosto", "à maneira de".
- MATERIAL_HINT: material nobre (jacarandá, caviúna...) + época (anos 50/60) sem designer.
"""


def main():
    conn = db.connect()
    house_m, cat_m, opp, avoid = export_csvs(conn)
    write_report(conn, house_m, cat_m, opp, avoid)
    (config.EXPORTS_DIR / "data_dictionary.md").write_text(DATA_DICT, encoding="utf-8")
    print(f"Exportado para {config.EXPORTS_DIR}")


if __name__ == "__main__":
    main()
