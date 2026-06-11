# Dicionário de dados — leiloes-intel

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
