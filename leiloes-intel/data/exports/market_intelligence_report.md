# Relatório de Inteligência de Mercado — LeilõesBR

_Gerado em 11/06/2026 06:06. Coleta de páginas públicas, sem login, com rate limit._

## 1. Resumo executivo

- **Lotes coletados:** 403.097 (8.582 ao vivo, 520.137 finalizados)
- **Casas/leiloeiros mapeados:** 845
- **Lotes vendidos com martelo observado:** 262.592 → **sell-through global 50,5%**
- **Janela de finalizados observada:** 09/04/2015 a 10/06/2026 (4081 dias).
- **Fonte de preço:** martelo REAL de leilões finalizados, não proxy. Lances ao vivo da busca por categoria.

> **Observed vs inferred.** Martelo, lance, nº de lances e status de venda são _observados_ no site. Tipo de peça, designer, força de atribuição, custos de frete/restauro, valor de revenda estimado, margem e sinais são _inferidos_ por regras determinísticas (ver `data_dictionary.md`).

## 2. Top categorias por sell-through (≥30 lotes finalizados)

| item_type | ofertados | vendidos | sell-through | martelo mediano | zero-bid |
|---|---|---|---|---|---|
| prata_metal | 32375 | 24058 | 74,3% | R$ 110,00 | 25,3% |
| disco_vinil | 18310 | 13053 | 71,3% | R$ 40,00 | 28,2% |
| brinquedo | 55447 | 35107 | 63,3% | R$ 60,00 | 35,5% |
| livro | 11551 | 6946 | 60,1% | R$ 50,00 | 38,9% |
| selo_filatelia | 7645 | 4287 | 56,1% | R$ 27,00 | 43,7% |
| outro | 179764 | 100665 | 56,0% | R$ 30,00 | 43,5% |
| armario | 319 | 178 | 55,8% | R$ 80,00 | 43,6% |
| estante | 573 | 303 | 52,9% | R$ 320,00 | 47,1% |
| escrivaninha | 129 | 68 | 52,7% | R$ 465,00 | 43,4% |
| cama | 279 | 145 | 52,0% | R$ 209,50 | 45,9% |
| espelho | 990 | 509 | 51,4% | R$ 210,00 | 46,1% |
| mesa_lateral | 550 | 281 | 51,1% | R$ 300,00 | 45,6% |

## 3. Top categorias por ticket (martelo mediano)

| item_type | martelo mediano | sell-through | ofertados |
|---|---|---|---|
| par_de_poltronas | R$ 1.900,00 | 23,7% | 459 |
| poltrona | R$ 755,00 | 23,6% | 1029 |
| conjunto_de_cadeiras | R$ 750,50 | 45,1% | 297 |
| comoda | R$ 750,00 | 46,9% | 239 |
| sofa | R$ 632,50 | 34,0% | 312 |
| carrinho_de_cha | R$ 525,00 | 48,4% | 62 |
| escrivaninha | R$ 465,00 | 52,7% | 129 |
| par_de_cadeiras | R$ 465,00 | 31,5% | 441 |
| mesa_de_jantar | R$ 464,00 | 37,4% | 326 |
| mesa_de_centro | R$ 440,00 | 29,0% | 520 |
| aparador | R$ 400,50 | 46,6% | 423 |
| estante | R$ 320,00 | 52,9% | 573 |

## 4. Categorias de baixa complexidade logística (foco operação solo)

| item_type | sell-through | martelo mediano | ofertados |
|---|---|---|---|
| prata_metal | 74,3% | R$ 110,00 | 32375 |
| espelho | 51,4% | R$ 210,00 | 990 |
| mesa_lateral | 51,1% | R$ 300,00 | 550 |
| luminaria_lustre | 47,1% | R$ 147,50 | 3823 |
| porcelana_ceramica | 45,2% | R$ 80,00 | 13616 |
| cadeira | 42,5% | R$ 270,00 | 1350 |
| objeto_decorativo | 38,8% | R$ 85,00 | 1179 |
| cristal_vidro | 33,3% | R$ 95,00 | 15077 |
| quadro_pintura | 33,3% | R$ 135,00 | 15245 |
| par_de_cadeiras | 31,5% | R$ 465,00 | 441 |
| mesa_de_centro | 29,0% | R$ 440,00 | 520 |
| escultura | 23,9% | R$ 160,00 | 14597 |

## 5. Casas para sourcing (maior zero-bid + volume ≥50)

| casa | uf | finalizados | zero-bid | sell-through | martelo médio |
|---|---|---|---|---|---|
| Atenas Antiquário e Casa de leilões | RJ | 213 | 100,0% | 0,0% | — |
| CH Collection - Numismática, Joias e Colecionáveis | PR | 386 | 100,0% | 0,0% | — |
| Leilões Bruno Francesco | RJ | 270 | 100,0% | 0,0% | — |
| Sol Mar e Lua Leilões | SP | 233 | 100,0% | 0,0% | — |
| Coleções e Afins | MG | 600 | 98,7% | 1,3% | R$ 24,25 |
| Dell Fanny Jóias Leilões | RJ | 2121 | 95,8% | 4,1% | R$ 4.923,15 |
| Vale Arte Leilões | SP | 518 | 95,8% | 4,2% | R$ 1.104,55 |
| Via Arte Leilões | SP | 452 | 95,6% | 4,4% | R$ 600,00 |
| Clássicos Modernos Leilões | RJ | 5077 | 95,4% | 4,4% | R$ 1.265,99 |
| Bons Tempos Leilões | RJ | 9647 | 94,5% | 5,2% | R$ 3.684,06 |
| Eternno Leilões | RJ | 766 | 94,3% | 5,7% | R$ 1.318,41 |
| Alvura Leilões Gestora de Ativos | PR | 3617 | 94,1% | 5,7% | R$ 343,26 |
| Extrema Leilões | MG | 295 | 93,2% | 6,8% | R$ 1.566,00 |
| Bradg Brazilian Art e Design Gallery | PR | 14379 | 92,3% | 7,4% | R$ 205,38 |
| Bardi Leilões | nan | 445 | 92,1% | 7,9% | R$ 314,46 |

_Zero-bid alto = mais chance de arrematar barato / pós-pregão._

## 6. Casas benchmark (maior sell-through, volume ≥50)

| casa | uf | finalizados | sell-through | martelo médio |
|---|---|---|---|---|
| Mania Comics | nan | 4230 | 100,0% | R$ 211,19 |
| Nossa Coleção | SP | 451 | 99,6% | R$ 107,07 |
| Saturno Leilões | nan | 16200 | 99,1% | R$ 8,49 |
| Acervo Cult - Colecionismo Para Todos | nan | 3065 | 97,8% | R$ 100,71 |
| Ernani Leiloeiro Oficial | RJ | 889 | 97,8% | R$ 343,85 |
| Galeria República da Arte | PR | 200 | 97,5% | R$ 123,64 |
| IP Selos | MT | 230 | 96,5% | R$ 29,50 |
| Pariz Moedas | PR | 290 | 95,5% | R$ 89,35 |
| PRH Leilões | RS | 570 | 95,4% | R$ 47,49 |
| Fátima Garcia Leilões | RJ | 310 | 95,2% | R$ 92,69 |
| Acervo do Garimpeiro | SP | 1428 | 95,1% | R$ 76,66 |
| Rivaldo Dantas Leilões | SP | 2425 | 93,2% | R$ 159,95 |
| Escafandro Discos - Antiguidades e Colecionáveis | nan | 736 | 92,5% | R$ 209,83 |
| Disco de Vinil | RJ | 406 | 92,4% | R$ 57,42 |
| São Jorge Leilões | SP | 156 | 92,3% | R$ 343,12 |

## 7. Oportunidades de compra (sinal BUY_NOW)

> **Como ler.** Estes são sinais de _triagem_, não lucros garantidos. A revenda é estimada pelo p25 (conservador) dos martelos de comparáveis × markup de varejo. O comp agrupa por (tipo, designer), então **não distingue o modelo/linha específico** (ex.: uma 'Poltrona Cimba' barata herda o comp de poltronas do mesmo designer). Trate margens altas em itens de lance muito baixo como candidatos a verificar peça a peça (use a coluna `lot_url` e a amostra de auditoria), não como certezas.

Total de lotes BUY_NOW: **16**. Top 25 por lucro estimado (conservador):

| título | tipo | designer | lance atual | revenda est. | margem | lance máx 40% | uf |
|---|---|---|---|---|---|---|---|
| ROBIN DAY - par de cadeiras anos 70 de plásti | par_de_cadeiras | jorge_zalszupin | R$ 500,00 | R$ 28.800,00 | 97,2% | R$ 16.174,29 | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | giuseppe_scapinelli | R$ 150,00 | R$ 10.440,00 | 95,3% | R$ 4.962,86 | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | giuseppe_scapinelli | R$ 150,00 | R$ 10.440,00 | 95,3% | R$ 4.962,86 | nan |
| Scapinelli - Mesa de jantar em caviúna. Medid | cadeira | giuseppe_scapinelli | R$ 2.000,00 | R$ 10.440,00 | 60,9% | R$ 3.820,00 | SP |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 do p | poltrona | sergio_rodrigues | R$ 260,00 | R$ 17.820,00 | 83,1% | R$ 2.996,19 | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 700,00 | R$ 6.210,00 | 83,8% | R$ 3.291,43 | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 750,00 | R$ 6.210,00 | 83,0% | R$ 3.291,43 | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 em | banco | sergio_rodrigues | R$ 240,00 | R$ 6.210,00 | 72,3% | R$ 2.148,57 | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine". Est | banco | sergio_rodrigues | R$ 1.400,00 | R$ 6.210,00 | 72,0% | R$ 3.291,43 | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine". Est | banco | sergio_rodrigues | R$ 1.400,00 | R$ 6.210,00 | 72,0% | R$ 3.291,43 | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeira e | poltrona | sergio_rodrigues | R$ 570,00 | R$ 17.820,00 | 64,7% | R$ 2.139,05 | nan |
| Rara Poltrona, Sergio Rodrigues - Produzida e | poltrona | sergio_rodrigues | R$ 2.800,00 | R$ 17.820,00 | 47,6% | R$ 3.281,90 | SP |
| Mesa de centro em madeira nobre pintada de ro | mesa_de_centro | percival_lafer | R$ 320,00 | R$ 2.259,00 | 45,8% | R$ 409,62 | nan |
| Percival Lafer mesa de centro em madeira com  | mesa_de_centro | percival_lafer | R$ 350,00 | R$ 2.259,00 | 43,8% | R$ 409,62 | SP |
| Joaquim Tenreiro:  Par de poltronas,  design  | par_de_poltronas | joaquim_tenreiro | R$ 0,00 | R$ 3.420,00 | 53,1% | R$ 145,79 | RJ |
| Par de Poltronas, Estilo Luís XVI, em Madeira | par_de_poltronas | nan | R$ 120,00 | R$ 3.420,00 | 42,3% | R$ 145,79 | SP |

## 8. Carteira sugerida — estoque inicial

### R$ 30.000 — 14 peças, capital alocado R$ 12.043,50

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| ROBIN DAY - par de cadeiras anos 70 de plá | par_de_cadeiras | R$ 500,00 | R$ 27.960,00 | 97,2% | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 8.707,50 | 95,3% | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 8.707,50 | 95,3% | nan |
| Scapinelli - Mesa de jantar em caviúna. Me | cadeira | R$ 2.000,00 | R$ 5.565,00 | 60,9% | SP |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 5.537,00 | 83,1% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 5.205,00 | 83,8% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 5.152,50 | 83,0% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.470,00 | 72,0% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.470,00 | 72,0% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 4.311,50 | 64,7% | nan |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 3.170,00 | 47,6% | SP |
| Mesa de centro em madeira nobre pintada de | mesa_de_centro | R$ 320,00 | R$ 747,50 | 45,8% | nan |
| Percival Lafer mesa de centro em madeira c | mesa_de_centro | R$ 350,00 | R$ 716,00 | 43,8% | SP |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 495,80 | 42,3% | SP |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 85.215,30** (margem agregada 87,6%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

### R$ 50.000 — 14 peças, capital alocado R$ 12.043,50

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| ROBIN DAY - par de cadeiras anos 70 de plá | par_de_cadeiras | R$ 500,00 | R$ 27.960,00 | 97,2% | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 8.707,50 | 95,3% | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 8.707,50 | 95,3% | nan |
| Scapinelli - Mesa de jantar em caviúna. Me | cadeira | R$ 2.000,00 | R$ 5.565,00 | 60,9% | SP |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 5.537,00 | 83,1% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 5.205,00 | 83,8% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 5.152,50 | 83,0% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.470,00 | 72,0% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.470,00 | 72,0% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 4.311,50 | 64,7% | nan |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 3.170,00 | 47,6% | SP |
| Mesa de centro em madeira nobre pintada de | mesa_de_centro | R$ 320,00 | R$ 747,50 | 45,8% | nan |
| Percival Lafer mesa de centro em madeira c | mesa_de_centro | R$ 350,00 | R$ 716,00 | 43,8% | SP |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 495,80 | 42,3% | SP |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 85.215,30** (margem agregada 87,6%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

## 9. Lances máximos por tipo de peça (para margem de 40%)

| item_type | lance máx mediano (40% margem) |
|---|---|
| par_de_cadeiras | R$ 16.174,29 |
| cadeira | R$ 4.962,86 |
| banco | R$ 3.291,43 |
| poltrona | R$ 2.996,19 |
| mesa_de_centro | R$ 409,62 |
| par_de_poltronas | R$ 145,79 |

## 10. Modelo A (casa de leilão) vs Modelo B (garimpo + revenda)

- **GMV observado** nas casas amostradas (martelo × vendidos): ~R$ 16.565.172,50 na janela de 09/04/2015 a 10/06/2026 (4081 dias) — denso e pulverizado entre muitas casas.
- **Modelo A** com take de 15,0%: para cobrir OPEX de R$ 10.000 / 15.000 / 25.000 ao mês, a casa precisaria de GMV mensal de ~R$ 66.666,67 / R$ 100.000,00 / R$ 166.666,67 respectivamente. Exige curadoria, captação de consignação e base de compradores — difícil para operação solo no início.
- **Modelo B** já é acionável hoje: 16 lotes BUY_NOW com margem ≥ 40,0%, capital inicial de R$ 30k aloca 14 peças. Giro depende de logística — por isso o foco em peças small/medium/large.

**Recomendação:** começar pelo **Modelo B** (menor capital travado, risco operacional menor, lucro por peça verificável com os dados). Migrar para **Modelo A** quando o GMV mensal de revenda ultrapassar consistentemente ~R$ 100.000,00 e houver fluxo de consignação — aí o take fixo da casa passa a compensar o OPEX.

## 11. Limitações e vieses

- Janela de finalizados observada: 09/04/2015 a 10/06/2026 (4081 dias); sazonalidade anual não capturada.
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