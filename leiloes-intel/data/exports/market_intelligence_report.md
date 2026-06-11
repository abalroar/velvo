# Relatório de Inteligência de Mercado — LeilõesBR

_Gerado em 11/06/2026 00:39. Coleta de páginas públicas, sem login, com rate limit._

## 1. Resumo executivo

- **Lotes coletados:** 68.000 (8.582 ao vivo, 64.425 finalizados)
- **Casas/leiloeiros mapeados:** 263
- **Lotes vendidos com martelo observado:** 32.520 → **sell-through global 50,5%**
- **Fonte de preço:** martelo REAL de leilões finalizados (últimos ~15 dias), não proxy. Lances ao vivo da busca por categoria.

> **Observed vs inferred.** Martelo, lance, nº de lances e status de venda são _observados_ no site. Tipo de peça, designer, força de atribuição, custos de frete/restauro, valor de revenda estimado, margem e sinais são _inferidos_ por regras determinísticas (ver `data_dictionary.md`).

## 2. Top categorias por sell-through (≥30 lotes finalizados)

| item_type | ofertados | vendidos | sell-through | martelo mediano | zero-bid |
|---|---|---|---|---|---|
| estante | 122 | 81 | 66,4% | R$ 222,50 | 33,6% |
| tapete | 319 | 209 | 65,5% | R$ 460,00 | 32,9% |
| mesa_lateral | 108 | 68 | 63,0% | R$ 285,00 | 37,0% |
| cama | 57 | 35 | 61,4% | R$ 300,50 | 35,1% |
| mesa_de_jantar | 62 | 37 | 59,7% | R$ 300,00 | 37,1% |
| espelho | 149 | 85 | 57,0% | R$ 240,00 | 39,6% |
| cadeira | 209 | 119 | 56,9% | R$ 290,00 | 43,1% |
| armario | 64 | 36 | 56,2% | R$ 85,00 | 43,8% |
| conjunto_de_cadeiras | 65 | 36 | 55,4% | R$ 795,00 | 44,6% |
| fotografia | 249 | 137 | 55,0% | R$ 50,00 | 42,2% |
| outro | 40548 | 21611 | 53,3% | R$ 40,00 | 46,5% |
| porcelana_ceramica | 3097 | 1630 | 52,6% | R$ 100,00 | 46,9% |

## 3. Top categorias por ticket (martelo mediano)

| item_type | martelo mediano | sell-through | ofertados |
|---|---|---|---|
| par_de_poltronas | R$ 3.300,00 | 31,9% | 91 |
| conjunto_de_cadeiras | R$ 795,00 | 55,4% | 65 |
| poltrona | R$ 710,00 | 40,0% | 150 |
| sofa | R$ 610,00 | 47,0% | 66 |
| par_de_cadeiras | R$ 575,00 | 50,0% | 62 |
| aparador | R$ 565,00 | 51,6% | 95 |
| mesa_de_centro | R$ 490,00 | 48,8% | 84 |
| tapete | R$ 460,00 | 65,5% | 319 |
| comoda | R$ 420,00 | 44,3% | 70 |
| escrivaninha | R$ 302,50 | 51,4% | 35 |
| cama | R$ 300,50 | 61,4% | 57 |
| mesa_de_jantar | R$ 300,00 | 59,7% | 62 |

## 4. Categorias de baixa complexidade logística (foco operação solo)

| item_type | sell-through | martelo mediano | ofertados |
|---|---|---|---|
| mesa_lateral | 63,0% | R$ 285,00 | 108 |
| espelho | 57,0% | R$ 240,00 | 149 |
| cadeira | 56,9% | R$ 290,00 | 209 |
| porcelana_ceramica | 52,6% | R$ 100,00 | 3097 |
| prata_metal | 51,1% | R$ 130,00 | 6352 |
| par_de_cadeiras | 50,0% | R$ 575,00 | 62 |
| mesa_de_centro | 48,8% | R$ 490,00 | 84 |
| luminaria_lustre | 48,3% | R$ 186,00 | 712 |
| cristal_vidro | 46,5% | R$ 120,00 | 2588 |
| objeto_decorativo | 45,9% | R$ 150,00 | 222 |
| poltrona | 40,0% | R$ 710,00 | 150 |
| quadro_pintura | 35,2% | R$ 300,00 | 2886 |

## 5. Casas para sourcing (maior zero-bid + volume ≥50)

| casa | uf | finalizados | zero-bid | sell-through | martelo médio |
|---|---|---|---|---|---|
| Sol Mar e Lua Leilões | SP | 233 | 100,0% | 0,0% | — |
| CH Collection - Numismática, Joias e Colecionáveis | PR | 386 | 100,0% | 0,0% | — |
| Leilões Bruno Francesco | RJ | 270 | 100,0% | 0,0% | — |
| Artway Leilões | PR | 251 | 100,0% | 0,0% | — |
| Mundo em Artes Leilões | SP | 168 | 100,0% | 0,0% | — |
| Atenas Antiquário e Casa de leilões | RJ | 213 | 100,0% | 0,0% | — |
| Coleções e Afins | MG | 600 | 98,7% | 1,3% | R$ 24,25 |
| Dell Fanny Jóias Leilões | RJ | 778 | 98,1% | 1,9% | R$ 4.420,00 |
| Bons Tempos Leilões | RJ | 580 | 96,9% | 3,1% | R$ 2.623,33 |
| Vale Arte Leilões | SP | 518 | 95,8% | 4,2% | R$ 1.104,55 |
| Alvura Leilões Gestora de Ativos | PR | 770 | 95,6% | 4,4% | R$ 824,79 |
| Via Arte Leilões | SP | 452 | 95,6% | 4,4% | R$ 600,00 |
| Bradg Brazilian Art e Design Gallery | PR | 200 | 95,5% | 4,0% | R$ 162,38 |
| Clássicos Modernos Leilões | RJ | 477 | 95,2% | 4,6% | R$ 1.288,64 |
| Eternno Leilões | RJ | 766 | 94,3% | 5,7% | R$ 1.318,41 |

_Zero-bid alto = mais chance de arrematar barato / pós-pregão._

## 6. Casas benchmark (maior sell-through, volume ≥50)

| casa | uf | finalizados | sell-through | martelo médio |
|---|---|---|---|---|
| Nossa Coleção | SP | 451 | 99,6% | R$ 107,07 |
| Acervo do Garimpeiro | SP | 414 | 97,8% | R$ 84,92 |
| Galeria República da Arte | PR | 200 | 97,5% | R$ 123,64 |
| IP Selos | MT | 230 | 96,5% | R$ 29,50 |
| Pariz Moedas | PR | 290 | 95,5% | R$ 89,35 |
| PRH Leilões | RS | 570 | 95,4% | R$ 47,49 |
| Fátima Garcia Leilões | RJ | 310 | 95,2% | R$ 92,69 |
| Rivaldo Dantas Leilões | SP | 2425 | 93,2% | R$ 159,95 |
| Clube Filatélico do Brasil | SP | 325 | 93,2% | R$ 26,24 |
| Disco de Vinil | RJ | 406 | 92,4% | R$ 57,42 |
| São Jorge Leilões | SP | 156 | 92,3% | R$ 343,12 |
| Nosso Passado Mobiliário | RJ | 98 | 91,8% | R$ 4.726,18 |
| Claudio Firmino Leiloeiro | RJ | 1538 | 91,2% | R$ 59,57 |
| Felipe Souza Leiloeiro | RJ | 100 | 91,0% | R$ 561,99 |
| Ocolecionnador | RJ | 350 | 90,6% | R$ 61,44 |

## 7. Oportunidades de compra (sinal BUY_NOW)

> **Como ler.** Estes são sinais de _triagem_, não lucros garantidos. A revenda é estimada pelo p25 (conservador) dos martelos de comparáveis × markup de varejo. O comp agrupa por (tipo, designer), então **não distingue o modelo/linha específico** (ex.: uma 'Poltrona Cimba' barata herda o comp de poltronas do mesmo designer). Trate margens altas em itens de lance muito baixo como candidatos a verificar peça a peça (use a coluna `lot_url` e a amostra de auditoria), não como certezas.

Total de lotes BUY_NOW: **31**. Top 25 por lucro estimado (conservador):

| título | tipo | designer | lance atual | revenda est. | margem | lance máx 40% | uf |
|---|---|---|---|---|---|---|---|
| SERGIO RODRIGUES- CIMBA poltrona anos 80 do p | poltrona | sergio_rodrigues | R$ 260,00 | R$ 37.710,00 | 95,9% | R$ 14.850,48 | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeira e | poltrona | sergio_rodrigues | R$ 570,00 | R$ 37.710,00 | 91,4% | R$ 13.993,33 | nan |
| Rara Poltrona, Sergio Rodrigues - Produzida e | poltrona | sergio_rodrigues | R$ 2.800,00 | R$ 37.710,00 | 87,3% | R$ 15.136,19 | SP |
| Sérgio rodrigues, 1 unidade de poltrona  Tião | poltrona | sergio_rodrigues | R$ 7.250,00 | R$ 37.710,00 | 70,2% | R$ 15.136,19 | RJ |
| Poltrona Killin, Sérgio Rodrigues. Estrutura  | poltrona | sergio_rodrigues | R$ 8.000,00 | R$ 37.710,00 | 67,3% | R$ 15.136,19 | RJ |
| Poltrona Killin - Sérgio Rodrigues. Estrutura | poltrona | sergio_rodrigues | R$ 8.000,00 | R$ 37.710,00 | 67,3% | R$ 15.136,19 | RJ |
| SERGIO RODRIGUES - Poltrona Tete em madeira d | poltrona | sergio_rodrigues | R$ 13.500,00 | R$ 37.710,00 | 46,3% | R$ 15.136,19 | RJ |
| Burle Marx - "paisagismo", óleo s/tela, 50 x  | quadro_pintura | burle_marx | R$ 3.500,00 | R$ 14.400,00 | 52,4% | R$ 4.474,29 | RJ |
| Joaquim Tenreiro:  Par de poltronas,  design  | par_de_poltronas | joaquim_tenreiro | R$ 0,00 | R$ 5.940,00 | 85,0% | R$ 1.573,45 | RJ |
| Par de Poltronas, Estilo Luís XVI, em Madeira | par_de_poltronas | nan | R$ 120,00 | R$ 5.940,00 | 81,6% | R$ 1.573,45 | SP |
| Par de poltronas estofadas com tecido listrad | par_de_poltronas | nan | R$ 150,00 | R$ 5.940,00 | 80,7% | R$ 1.573,45 | RS |
| Par de poltronas de diretor em metal com asse | par_de_poltronas | nan | R$ 290,00 | R$ 5.940,00 | 76,7% | R$ 1.573,45 | RS |
| Par de poltronas em ferro tubular anos 60 ,na | par_de_poltronas | nan | R$ 390,00 | R$ 5.940,00 | 73,9% | R$ 1.573,45 | SP |
| Par de Poltronas Giratórias, Anos 70 - Aprese | par_de_poltronas | nan | R$ 400,00 | R$ 5.940,00 | 73,6% | R$ 1.573,45 | SP |
| Par de poltronas - Anos 50. Produzidas em mad | par_de_poltronas | nan | R$ 400,00 | R$ 5.940,00 | 73,6% | R$ 1.573,45 | SP |
| Par de poltronas estilo Wingback clássica com | par_de_poltronas | nan | R$ 400,00 | R$ 5.940,00 | 73,6% | R$ 1.573,45 | RS |
| Par de poltronas - Anos 60. Com pés palito, a | par_de_poltronas | nan | R$ 420,00 | R$ 5.940,00 | 73,0% | R$ 1.573,45 | SP |
| Par de poltronas rústicas em madeira -med. 82 | par_de_poltronas | nan | R$ 450,00 | R$ 5.940,00 | 72,1% | R$ 1.573,45 | RS |
| Par de poltronas estofadas. Altura do encosto | par_de_poltronas | nan | R$ 500,00 | R$ 5.940,00 | 70,7% | R$ 1.573,45 | nan |
| Par de Poltronas antigas - Produzidas em made | par_de_poltronas | nan | R$ 500,00 | R$ 5.940,00 | 70,7% | R$ 1.573,45 | SP |
| Par de poltronas contemporâneas estofadas em  | par_de_poltronas | nan | R$ 300,00 | R$ 5.940,00 | 68,3% | R$ 1.287,73 | RS |
| Par de poltronas - Anos 70. Com pés maciços,  | par_de_poltronas | nan | R$ 600,00 | R$ 5.940,00 | 67,8% | R$ 1.573,45 | SP |
| Par de poltronas em excelente estado, estofad | par_de_poltronas | nan | R$ 800,00 | R$ 5.940,00 | 62,1% | R$ 1.573,45 | nan |
| WALTER GERDAU-BELO PAR DE POLTRONAS EXECUTADO | par_de_poltronas | nan | R$ 980,00 | R$ 5.940,00 | 57,0% | R$ 1.573,45 | nan |
| Um excepcional e raríssimo par de poltronas o | par_de_poltronas | nan | R$ 1.100,00 | R$ 5.940,00 | 53,5% | R$ 1.573,45 | SP |

## 8. Carteira sugerida — estoque inicial

### R$ 30.000 — 12 peças, capital alocado R$ 29.956,50

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 26.282,00 | 95,9% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 25.056,50 | 91,4% | nan |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 23.915,00 | 87,3% | SP |
| Sérgio rodrigues, 1 unidade de poltrona  T | poltrona | R$ 7.250,00 | R$ 19.242,50 | 70,2% | RJ |
| Poltrona Killin, Sérgio Rodrigues. Estrutu | poltrona | R$ 8.000,00 | R$ 18.455,00 | 67,3% | RJ |
| Poltrona Killin - Sérgio Rodrigues. Estrut | poltrona | R$ 8.000,00 | R$ 18.455,00 | 67,3% | RJ |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 2.994,20 | 81,6% | SP |
| Par de poltronas estofadas com tecido list | par_de_poltronas | R$ 150,00 | R$ 2.962,70 | 80,7% | RS |
| Par de poltronas de diretor em metal com a | par_de_poltronas | R$ 290,00 | R$ 2.815,70 | 76,7% | RS |
| Par de poltronas em ferro tubular anos 60  | par_de_poltronas | R$ 390,00 | R$ 2.710,70 | 73,9% | SP |
| Par de Poltronas Giratórias, Anos 70 - Apr | par_de_poltronas | R$ 400,00 | R$ 2.700,20 | 73,6% | SP |
| Par de poltronas contemporâneas estofadas  | par_de_poltronas | R$ 300,00 | R$ 2.505,20 | 68,3% | RS |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 148.094,70** (margem agregada 83,2%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

### R$ 50.000 — 19 peças, capital alocado R$ 49.980,00

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 26.282,00 | 95,9% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 25.056,50 | 91,4% | nan |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 23.915,00 | 87,3% | SP |
| Sérgio rodrigues, 1 unidade de poltrona  T | poltrona | R$ 7.250,00 | R$ 19.242,50 | 70,2% | RJ |
| Poltrona Killin, Sérgio Rodrigues. Estrutu | poltrona | R$ 8.000,00 | R$ 18.455,00 | 67,3% | RJ |
| Poltrona Killin - Sérgio Rodrigues. Estrut | poltrona | R$ 8.000,00 | R$ 18.455,00 | 67,3% | RJ |
| SERGIO RODRIGUES - Poltrona Tete em madeir | poltrona | R$ 13.500,00 | R$ 12.680,00 | 46,3% | RJ |
| Burle Marx - "paisagismo", óleo s/tela, 50 | quadro_pintura | R$ 3.500,00 | R$ 4.335,00 | 52,4% | RJ |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 2.994,20 | 81,6% | SP |
| Par de poltronas estofadas com tecido list | par_de_poltronas | R$ 150,00 | R$ 2.962,70 | 80,7% | RS |
| Par de poltronas de diretor em metal com a | par_de_poltronas | R$ 290,00 | R$ 2.815,70 | 76,7% | RS |
| Par de poltronas em ferro tubular anos 60  | par_de_poltronas | R$ 390,00 | R$ 2.710,70 | 73,9% | SP |
| Par de Poltronas Giratórias, Anos 70 - Apr | par_de_poltronas | R$ 400,00 | R$ 2.700,20 | 73,6% | SP |
| Par de poltronas - Anos 50. Produzidas em  | par_de_poltronas | R$ 400,00 | R$ 2.700,20 | 73,6% | SP |
| Par de poltronas estilo Wingback clássica  | par_de_poltronas | R$ 400,00 | R$ 2.700,20 | 73,6% | RS |
| Par de poltronas - Anos 60. Com pés palito | par_de_poltronas | R$ 420,00 | R$ 2.679,20 | 73,0% | SP |
| Par de poltronas rústicas em madeira -med. | par_de_poltronas | R$ 450,00 | R$ 2.647,70 | 72,1% | RS |
| Par de poltronas estofadas. Altura do enco | par_de_poltronas | R$ 500,00 | R$ 2.595,20 | 70,7% | nan |
| Berg - 1977 - Gravura giclê, em tela assin | quadro_pintura | R$ 200,00 | R$ 1.230,00 | 71,9% | PE |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 177.157,00** (margem agregada 78,0%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

## 9. Lances máximos por tipo de peça (para margem de 40%)

| item_type | lance máx mediano (40% margem) |
|---|---|
| poltrona | R$ 15.136,19 |
| par_de_poltronas | R$ 1.573,45 |
| quadro_pintura | R$ 720,00 |

## 10. Modelo A (casa de leilão) vs Modelo B (garimpo + revenda)

- **GMV observado** nas casas amostradas (martelo × vendidos): ~R$ 2.777.754,00 em ~15 dias — denso e pulverizado entre muitas casas.
- **Modelo A** com take de 15,0%: para cobrir OPEX de R$ 10.000 / 15.000 / 25.000 ao mês, a casa precisaria de GMV mensal de ~R$ 66.666,67 / R$ 100.000,00 / R$ 166.666,67 respectivamente. Exige curadoria, captação de consignação e base de compradores — difícil para operação solo no início.
- **Modelo B** já é acionável hoje: 31 lotes BUY_NOW com margem ≥ 40,0%, capital inicial de R$ 30k aloca 12 peças. Giro depende de logística — por isso o foco em peças small/medium/large.

**Recomendação:** começar pelo **Modelo B** (menor capital travado, risco operacional menor, lucro por peça verificável com os dados). Migrar para **Modelo A** quando o GMV mensal de revenda ultrapassar consistentemente ~R$ 100.000,00 e houver fluxo de consignação — aí o take fixo da casa passa a compensar o OPEX.

## 11. Limitações e vieses

- Janela de finalizados ≈ últimos 15 dias (rotativa do site); sazonalidade não capturada.
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