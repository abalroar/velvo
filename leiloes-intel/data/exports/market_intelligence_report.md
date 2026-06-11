# Relatório de Inteligência de Mercado — LeilõesBR

_Gerado em 11/06/2026 05:47. Coleta de páginas públicas, sem login, com rate limit._

## 1. Resumo executivo

- **Lotes coletados:** 256.468 (8.582 ao vivo, 349.665 finalizados)
- **Casas/leiloeiros mapeados:** 845
- **Lotes vendidos com martelo observado:** 186.363 → **sell-through global 53,3%**
- **Janela de finalizados observada:** 16/08/2022 a 10/06/2026 (1395 dias).
- **Fonte de preço:** martelo REAL de leilões finalizados, não proxy. Lances ao vivo da busca por categoria.

> **Observed vs inferred.** Martelo, lance, nº de lances e status de venda são _observados_ no site. Tipo de peça, designer, força de atribuição, custos de frete/restauro, valor de revenda estimado, margem e sinais são _inferidos_ por regras determinísticas (ver `data_dictionary.md`).

## 2. Top categorias por sell-through (≥30 lotes finalizados)

| item_type | ofertados | vendidos | sell-through | martelo mediano | zero-bid |
|---|---|---|---|---|---|
| prata_metal | 44798 | 27789 | 62,0% | R$ 120,00 | 37,8% |
| armario | 222 | 129 | 58,1% | R$ 60,00 | 41,9% |
| outro | 249018 | 136568 | 54,8% | R$ 40,00 | 44,7% |
| tapete | 772 | 421 | 54,5% | R$ 260,00 | 43,4% |
| escrivaninha | 81 | 43 | 53,1% | R$ 350,00 | 43,2% |
| estante | 349 | 184 | 52,7% | R$ 230,00 | 48,7% |
| luminaria_lustre | 2380 | 1224 | 51,4% | R$ 150,00 | 47,5% |
| espelho | 589 | 301 | 51,1% | R$ 160,00 | 46,3% |
| mesa_lateral | 309 | 154 | 49,8% | R$ 190,00 | 47,9% |
| mesa | 3862 | 1890 | 48,9% | R$ 80,00 | 49,9% |
| fotografia | 598 | 290 | 48,5% | R$ 50,00 | 50,3% |
| porcelana_ceramica | 8271 | 3830 | 46,3% | R$ 80,00 | 52,7% |

## 3. Top categorias por ticket (martelo mediano)

| item_type | martelo mediano | sell-through | ofertados |
|---|---|---|---|
| par_de_poltronas | R$ 1.315,00 | 25,5% | 204 |
| poltrona | R$ 525,00 | 26,5% | 468 |
| conjunto_de_cadeiras | R$ 525,00 | 42,0% | 176 |
| sofa | R$ 485,00 | 31,2% | 173 |
| comoda | R$ 422,00 | 43,5% | 131 |
| carrinho_de_cha | R$ 420,00 | 44,1% | 34 |
| aparador | R$ 380,00 | 45,2% | 230 |
| par_de_cadeiras | R$ 367,50 | 34,4% | 218 |
| escrivaninha | R$ 350,00 | 53,1% | 81 |
| mesa_de_jantar | R$ 265,00 | 40,0% | 185 |
| mesa_de_centro | R$ 265,00 | 29,2% | 301 |
| tapete | R$ 260,00 | 54,5% | 772 |

## 4. Categorias de baixa complexidade logística (foco operação solo)

| item_type | sell-through | martelo mediano | ofertados |
|---|---|---|---|
| prata_metal | 62,0% | R$ 120,00 | 44798 |
| luminaria_lustre | 51,4% | R$ 150,00 | 2380 |
| espelho | 51,1% | R$ 160,00 | 589 |
| mesa_lateral | 49,8% | R$ 190,00 | 309 |
| porcelana_ceramica | 46,3% | R$ 80,00 | 8271 |
| objeto_decorativo | 43,0% | R$ 71,00 | 798 |
| cadeira | 41,8% | R$ 189,50 | 748 |
| quadro_pintura | 36,4% | R$ 100,00 | 7500 |
| cristal_vidro | 35,5% | R$ 80,00 | 9131 |
| par_de_cadeiras | 34,4% | R$ 367,50 | 218 |
| escultura | 33,8% | R$ 120,00 | 6114 |
| mesa_de_centro | 29,2% | R$ 265,00 | 301 |

## 5. Casas para sourcing (maior zero-bid + volume ≥50)

| casa | uf | finalizados | zero-bid | sell-through | martelo médio |
|---|---|---|---|---|---|
| Sol Mar e Lua Leilões | SP | 233 | 100,0% | 0,0% | — |
| Atenas Antiquário e Casa de leilões | RJ | 213 | 100,0% | 0,0% | — |
| CH Collection - Numismática, Joias e Colecionáveis | PR | 386 | 100,0% | 0,0% | — |
| Leilões Bruno Francesco | RJ | 270 | 100,0% | 0,0% | — |
| Mundo em Artes Leilões | SP | 168 | 100,0% | 0,0% | — |
| Coleções e Afins | MG | 600 | 98,7% | 1,3% | R$ 24,25 |
| Dell Fanny Jóias Leilões | RJ | 1678 | 96,4% | 3,6% | R$ 4.649,02 |
| Vale Arte Leilões | SP | 518 | 95,8% | 4,2% | R$ 1.104,55 |
| Via Arte Leilões | SP | 452 | 95,6% | 4,4% | R$ 600,00 |
| Bradg Brazilian Art e Design Gallery | PR | 200 | 95,5% | 4,0% | R$ 162,38 |
| Clássicos Modernos Leilões | RJ | 3731 | 95,3% | 4,4% | R$ 1.273,49 |
| Bons Tempos Leilões | RJ | 1187 | 95,0% | 5,0% | R$ 2.750,31 |
| Eternno Leilões | RJ | 766 | 94,3% | 5,7% | R$ 1.318,41 |
| Alvura Leilões Gestora de Ativos | PR | 3617 | 94,1% | 5,7% | R$ 343,26 |
| Extrema Leilões | MG | 295 | 93,2% | 6,8% | R$ 1.566,00 |

_Zero-bid alto = mais chance de arrematar barato / pós-pregão._

## 6. Casas benchmark (maior sell-through, volume ≥50)

| casa | uf | finalizados | sell-through | martelo médio |
|---|---|---|---|---|
| Mania Comics | nan | 4230 | 100,0% | R$ 211,19 |
| Nossa Coleção | SP | 451 | 99,6% | R$ 107,07 |
| Saturno Leilões | nan | 13000 | 99,0% | R$ 8,37 |
| Acervo Cult - Colecionismo Para Todos | nan | 2405 | 98,0% | R$ 94,06 |
| Galeria República da Arte | PR | 200 | 97,5% | R$ 123,64 |
| IP Selos | MT | 230 | 96,5% | R$ 29,50 |
| Pariz Moedas | PR | 290 | 95,5% | R$ 89,35 |
| PRH Leilões | RS | 570 | 95,4% | R$ 47,49 |
| Fátima Garcia Leilões | RJ | 310 | 95,2% | R$ 92,69 |
| Acervo do Garimpeiro | SP | 714 | 95,1% | R$ 76,66 |
| Rivaldo Dantas Leilões | SP | 2425 | 93,2% | R$ 159,95 |
| Clube Filatélico do Brasil | SP | 325 | 93,2% | R$ 26,24 |
| Disco de Vinil | RJ | 406 | 92,4% | R$ 57,42 |
| São Jorge Leilões | SP | 156 | 92,3% | R$ 343,12 |
| Nosso Passado Mobiliário | RJ | 98 | 91,8% | R$ 4.726,18 |

## 7. Oportunidades de compra (sinal BUY_NOW)

> **Como ler.** Estes são sinais de _triagem_, não lucros garantidos. A revenda é estimada pelo p25 (conservador) dos martelos de comparáveis × markup de varejo. O comp agrupa por (tipo, designer), então **não distingue o modelo/linha específico** (ex.: uma 'Poltrona Cimba' barata herda o comp de poltronas do mesmo designer). Trate margens altas em itens de lance muito baixo como candidatos a verificar peça a peça (use a coluna `lot_url` e a amostra de auditoria), não como certezas.

Total de lotes BUY_NOW: **7**. Top 25 por lucro estimado (conservador):

| título | tipo | designer | lance atual | revenda est. | margem | lance máx 40% | uf |
|---|---|---|---|---|---|---|---|
| SERGIO RODRIGUES- CIMBA poltrona anos 80 do p | poltrona | sergio_rodrigues | R$ 260,00 | R$ 22.590,00 | 86,4% | R$ 3.896,19 | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeira e | poltrona | sergio_rodrigues | R$ 570,00 | R$ 22.590,00 | 71,5% | R$ 3.039,05 | nan |
| Rara Poltrona, Sergio Rodrigues - Produzida e | poltrona | sergio_rodrigues | R$ 2.800,00 | R$ 22.590,00 | 57,6% | R$ 4.181,90 | SP |
| Burle Marx - "paisagismo", óleo s/tela, 50 x  | quadro_pintura | burle_marx | R$ 3.500,00 | R$ 14.400,00 | 52,4% | R$ 4.474,29 | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 700,00 | R$ 6.210,00 | 49,2% | R$ 874,29 | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 750,00 | R$ 6.210,00 | 46,6% | R$ 874,29 | RJ |
| Joaquim Tenreiro:  Par de poltronas,  design  | par_de_poltronas | joaquim_tenreiro | R$ 0,00 | R$ 2.367,00 | 46,9% | R$ 67,62 | RJ |

## 8. Carteira sugerida — estoque inicial

### R$ 30.000 — 6 peças, capital alocado R$ 9.009,00

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 7.112,00 | 86,4% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 5.886,50 | 71,5% | nan |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 4.745,00 | 57,6% | SP |
| Burle Marx - "paisagismo", óleo s/tela, 50 | quadro_pintura | R$ 3.500,00 | R$ 4.335,00 | 52,4% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 975,00 | 49,2% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 922,50 | 46,6% | RJ |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 23.976,00** (margem agregada 72,7%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

### R$ 50.000 — 6 peças, capital alocado R$ 9.009,00

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 7.112,00 | 86,4% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 5.886,50 | 71,5% | nan |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 4.745,00 | 57,6% | SP |
| Burle Marx - "paisagismo", óleo s/tela, 50 | quadro_pintura | R$ 3.500,00 | R$ 4.335,00 | 52,4% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 975,00 | 49,2% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 922,50 | 46,6% | RJ |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 23.976,00** (margem agregada 72,7%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

## 9. Lances máximos por tipo de peça (para margem de 40%)

| item_type | lance máx mediano (40% margem) |
|---|---|
| quadro_pintura | R$ 4.474,29 |
| poltrona | R$ 3.896,19 |
| banco | R$ 874,29 |
| par_de_poltronas | R$ 67,62 |

## 10. Modelo A (casa de leilão) vs Modelo B (garimpo + revenda)

- **GMV observado** nas casas amostradas (martelo × vendidos): ~R$ 11.185.116,50 na janela de 16/08/2022 a 10/06/2026 (1395 dias) — denso e pulverizado entre muitas casas.
- **Modelo A** com take de 15,0%: para cobrir OPEX de R$ 10.000 / 15.000 / 25.000 ao mês, a casa precisaria de GMV mensal de ~R$ 66.666,67 / R$ 100.000,00 / R$ 166.666,67 respectivamente. Exige curadoria, captação de consignação e base de compradores — difícil para operação solo no início.
- **Modelo B** já é acionável hoje: 7 lotes BUY_NOW com margem ≥ 40,0%, capital inicial de R$ 30k aloca 6 peças. Giro depende de logística — por isso o foco em peças small/medium/large.

**Recomendação:** começar pelo **Modelo B** (menor capital travado, risco operacional menor, lucro por peça verificável com os dados). Migrar para **Modelo A** quando o GMV mensal de revenda ultrapassar consistentemente ~R$ 100.000,00 e houver fluxo de consignação — aí o take fixo da casa passa a compensar o OPEX.

## 11. Limitações e vieses

- Janela de finalizados observada: 16/08/2022 a 10/06/2026 (1395 dias); sazonalidade anual não capturada.
- Algumas casas usam plataforma distinta (≈10% de falhas 404/JSON) e ficam fora da amostra.
- Lotes ao vivo têm só título (descrição completa não disponível sem por-leilão); atribuição de designer pode ter falso-negativo quando o nome só aparece na descrição.
- Valor de revenda assume preço de mercado = mediana de martelo de comparáveis; é conservador para venda de varejo no Instagram e tem baixa confiança onde há poucos comps.
- Custos de frete/restauro são premissas (`assumptions.yaml`), não cotações.

## 12. Premissas usadas (`assumptions.yaml`)

```yaml
buyer_premium_pct: 0.05
resale_channel_fee_pct: 0.0
shipping_brl:
  small: 80
  medium: 180
  large: 350
  xl: 600
packaging_brl:
  small: 40
  medium: 90
  large: 200
  xl: 350
restoration_brl:
  none: 0
  light: 300
  heavy: 1200
resale:
  min_comps: 5
  retail_markup_over_hammer: 1.8
  fallback_markup_over_hammer: 1.8
signals:
  buy_now:
    min_margin_pct: 0.4
    max_logistics_size: large
    min_attribution_for_designer_claim: STATED
    max_bid_count: 8
    min_confidence: 0.55
  watch:
    min_margin_pct: 0.25
    min_confidence: 0.4
capital_scenarios_brl:
- 30000
- 50000
```