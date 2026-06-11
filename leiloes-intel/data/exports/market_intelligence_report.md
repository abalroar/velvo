# Relatório de Inteligência de Mercado — LeilõesBR

_Gerado em 11/06/2026 12:44. Coleta de páginas públicas, sem login, com rate limit._

## 1. Resumo executivo

- **Lotes coletados:** 1.211.869 (8.582 ao vivo, 1.682.827 finalizados)
- **Casas/leiloeiros mapeados:** 845
- **Lotes vendidos com martelo observado:** 905.295 → **sell-through global 53,8%**
- **Janela de finalizados observada:** 14/01/2015 a 10/06/2026 (4166 dias).
- **Fonte de preço:** martelo REAL de leilões finalizados, não proxy. Lances ao vivo da busca por categoria.

> **Observed vs inferred.** Martelo, lance, nº de lances e status de venda são _observados_ no site. Tipo de peça, designer, força de atribuição, custos de frete/restauro, valor de revenda estimado, margem e sinais são _inferidos_ por regras determinísticas (ver `data_dictionary.md`).

## 2. Top categorias por sell-through (≥30 lotes finalizados)

| item_type | ofertados | vendidos | sell-through | martelo mediano | zero-bid |
|---|---|---|---|---|---|
| disco_vinil | 79258 | 60740 | 76,6% | R$ 43,00 | 22,8% |
| prata_metal | 75962 | 52885 | 69,6% | R$ 120,00 | 28,7% |
| carrinho_de_cha | 485 | 326 | 67,2% | R$ 1.000,00 | 24,9% |
| conjunto_de_cadeiras | 2371 | 1589 | 67,0% | R$ 2.100,00 | 26,1% |
| selo_filatelia | 35226 | 23240 | 66,0% | R$ 15,00 | 33,5% |
| sofa | 3162 | 2003 | 63,3% | R$ 2.600,00 | 28,0% |
| brinquedo | 135445 | 85606 | 63,2% | R$ 60,00 | 35,6% |
| par_de_poltronas | 3360 | 2119 | 63,1% | R$ 3.600,00 | 28,9% |
| mesa_lateral | 2855 | 1763 | 61,8% | R$ 460,00 | 31,4% |
| mesa_de_centro | 3262 | 1923 | 59,0% | R$ 1.100,00 | 34,9% |
| poltrona | 5780 | 3379 | 58,5% | R$ 2.100,00 | 33,7% |
| cama | 1420 | 827 | 58,2% | R$ 400,00 | 37,7% |

## 3. Top categorias por ticket (martelo mediano)

| item_type | martelo mediano | sell-through | ofertados |
|---|---|---|---|
| par_de_poltronas | R$ 3.600,00 | 63,1% | 3360 |
| sofa | R$ 2.600,00 | 63,3% | 3162 |
| conjunto_de_cadeiras | R$ 2.100,00 | 67,0% | 2371 |
| poltrona | R$ 2.100,00 | 58,5% | 5780 |
| mesa_de_jantar | R$ 1.900,00 | 55,6% | 1924 |
| escrivaninha | R$ 1.400,00 | 55,1% | 1054 |
| aparador | R$ 1.100,00 | 54,3% | 2858 |
| mesa_de_centro | R$ 1.100,00 | 59,0% | 3262 |
| carrinho_de_cha | R$ 1.000,00 | 67,2% | 485 |
| comoda | R$ 850,00 | 55,1% | 1152 |
| par_de_cadeiras | R$ 800,00 | 51,8% | 1811 |
| estante | R$ 650,00 | 55,4% | 2679 |

## 4. Categorias de baixa complexidade logística (foco operação solo)

| item_type | sell-through | martelo mediano | ofertados |
|---|---|---|---|
| prata_metal | 69,6% | R$ 120,00 | 75962 |
| mesa_lateral | 61,8% | R$ 460,00 | 2855 |
| mesa_de_centro | 59,0% | R$ 1.100,00 | 3262 |
| poltrona | 58,5% | R$ 2.100,00 | 5780 |
| espelho | 56,6% | R$ 350,00 | 4434 |
| cadeira | 55,3% | R$ 550,00 | 5923 |
| par_de_cadeiras | 51,8% | R$ 800,00 | 1811 |
| porcelana_ceramica | 51,1% | R$ 72,00 | 52320 |
| luminaria_lustre | 50,5% | R$ 200,00 | 14150 |
| objeto_decorativo | 47,9% | R$ 120,00 | 4747 |
| cristal_vidro | 41,0% | R$ 85,00 | 46806 |
| escultura | 33,7% | R$ 170,00 | 45292 |

## 5. Casas para sourcing (maior zero-bid + volume ≥50)

| casa | uf | finalizados | zero-bid | sell-through | martelo médio |
|---|---|---|---|---|---|
| Leilões Bruno Francesco | RJ | 270 | 100,0% | 0,0% | — |
| Sol Mar e Lua Leilões | SP | 233 | 100,0% | 0,0% | — |
| CH Collection - Numismática, Joias e Colecionáveis | PR | 386 | 100,0% | 0,0% | — |
| Casa de Leilões Guedes e Guedes | nan | 651 | 99,1% | 0,9% | R$ 157,50 |
| Coleções e Afins | MG | 600 | 98,7% | 1,3% | R$ 24,25 |
| 24K Joias Leilões | nan | 801 | 97,6% | 2,4% | R$ 1.625,79 |
| Oficina Cenário Leilões | nan | 452 | 96,5% | 3,1% | R$ 942,86 |
| Comitiva Artes e Leilões | nan | 2442 | 95,9% | 3,9% | R$ 1.770,83 |
| Vale Arte Leilões | SP | 518 | 95,8% | 4,2% | R$ 1.104,55 |
| Clássicos Modernos Leilões | RJ | 7860 | 95,4% | 4,4% | R$ 1.290,35 |
| Dell Fanny Jóias Leilões | RJ | 9625 | 95,3% | 4,4% | R$ 3.357,57 |
| Bons Tempos Leilões | RJ | 9936 | 94,5% | 5,2% | R$ 3.708,23 |
| Alvura Leilões Gestora de Ativos | PR | 4074 | 94,4% | 5,4% | R$ 336,40 |
| Eternno Leilões | RJ | 766 | 94,3% | 5,7% | R$ 1.318,41 |
| Castejón Branco Leilões | nan | 99 | 93,9% | 6,1% | R$ 131,67 |

_Zero-bid alto = mais chance de arrematar barato / pós-pregão._

## 6. Casas benchmark (maior sell-through, volume ≥50)

| casa | uf | finalizados | sell-through | martelo médio |
|---|---|---|---|---|
| Mania Comics | nan | 7276 | 100,0% | R$ 212,46 |
| Nossa Coleção | SP | 451 | 99,6% | R$ 107,07 |
| Vitrine das Antiguidades | SP | 258 | 99,2% | R$ 52,80 |
| Saturno Leilões | nan | 28500 | 99,1% | R$ 8,57 |
| Velho Armazém Leilões | nan | 110 | 99,1% | R$ 77,16 |
| Acervo Cult - Colecionismo Para Todos | nan | 5019 | 97,8% | R$ 100,31 |
| Filatélica MG Leilões | nan | 16676 | 97,7% | R$ 24,36 |
| Galeria República da Arte | PR | 200 | 97,5% | R$ 123,64 |
| Pariz Moedas | PR | 290 | 95,5% | R$ 89,35 |
| PRH Leilões | RS | 570 | 95,4% | R$ 47,49 |
| RH Leilões | nan | 300 | 95,3% | R$ 25,13 |
| Acervo do Garimpeiro | SP | 2856 | 95,1% | R$ 76,66 |
| Escafandro Discos - Antiguidades e Colecionáveis | nan | 12762 | 94,9% | R$ 120,25 |
| Colecionários | nan | 870 | 94,5% | R$ 54,88 |
| Ernani Leiloeiro Oficial | RJ | 953 | 93,7% | R$ 353,20 |

## 7. Oportunidades de compra (sinal BUY_NOW)

> **Como ler.** Estes são sinais de _triagem_, não lucros garantidos. A revenda é estimada pelo p25 (conservador) dos martelos de comparáveis × markup de varejo. O comp agrupa por (tipo, designer), então **não distingue o modelo/linha específico** (ex.: uma 'Poltrona Cimba' barata herda o comp de poltronas do mesmo designer). Trate margens altas em itens de lance muito baixo como candidatos a verificar peça a peça (use a coluna `lot_url` e a amostra de auditoria), não como certezas.

Total de lotes BUY_NOW: **51**. Top 25 por lucro estimado (conservador):

| título | tipo | designer | lance atual | revenda est. | margem | lance máx 40% | uf |
|---|---|---|---|---|---|---|---|
| Abraham Palatnik - Mesa de centro com tampo e | mesa_de_centro | abraham_palatnik | R$ 1.100,00 | R$ 46.350,00 | 88,4% | R$ 12.709,16 | SP |
| RR Antiguidades Antigo quadro representando c | cristal_vidro | moveis_cimo | R$ 400,00 | R$ 12.060,00 | 92,6% | R$ 4.077,14 | RJ |
| Mesa lateral, confeccionada em madeira nobre, | mesa_lateral | branco_e_preto | R$ 160,00 | R$ 7.560,00 | 93,5% | R$ 3.600,00 | RJ |
| Mesa lateral, confeccionada em madeira nobre, | mesa_lateral | branco_e_preto | R$ 180,00 | R$ 7.560,00 | 93,2% | R$ 3.600,00 | RJ |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 do p | poltrona | sergio_rodrigues | R$ 260,00 | R$ 14.819,40 | 84,3% | R$ 3.279,05 | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeira e | poltrona | sergio_rodrigues | R$ 570,00 | R$ 14.819,40 | 67,2% | R$ 2.421,90 | nan |
| Par de Poltronas, Anos 70 - Produzidas em esp | par_de_poltronas | percival_lafer | R$ 4.000,00 | R$ 18.900,00 | 49,2% | R$ 4.824,76 | SP |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 700,00 | R$ 9.720,00 | 78,9% | R$ 2.468,57 | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 750,00 | R$ 9.720,00 | 77,8% | R$ 2.468,57 | RJ |
| Rara Poltrona, Sergio Rodrigues - Produzida e | poltrona | sergio_rodrigues | R$ 2.800,00 | R$ 14.819,40 | 51,2% | R$ 3.564,76 | SP |
| PERCIVAL LAFER - Poltrona  do design brasilei | poltrona | percival_lafer | R$ 1.200,00 | R$ 9.720,00 | 66,5% | R$ 2.561,90 | RJ |
| PERCIVAL LAFER - Poltrona  do design brasilei | poltrona | percival_lafer | R$ 1.200,00 | R$ 9.720,00 | 66,5% | R$ 2.561,90 | RJ |
| PERCIVAL LAFER - Poltrona  do design brasilei | poltrona | percival_lafer | R$ 1.200,00 | R$ 9.720,00 | 66,5% | R$ 2.561,90 | RJ |
| EUGENIO PROENÇA SIGAUD (1899-1979) - " Nature | quadro_pintura | joaquim_tenreiro | R$ 220,00 | R$ 12.780,00 | 86,8% | R$ 1.902,86 | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 em | banco | sergio_rodrigues | R$ 240,00 | R$ 9.720,00 | 63,9% | R$ 1.325,71 | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine". Est | banco | sergio_rodrigues | R$ 1.400,00 | R$ 9.720,00 | 63,5% | R$ 2.468,57 | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine". Est | banco | sergio_rodrigues | R$ 1.400,00 | R$ 9.720,00 | 63,5% | R$ 2.468,57 | RJ |
| ROBIN DAY - par de cadeiras anos 70 de plásti | par_de_cadeiras | jorge_zalszupin | R$ 500,00 | R$ 5.760,00 | 79,0% | R$ 1.902,86 | RJ |
| Percival Lafer (São Paulo, SP, 12 de abril de | poltrona | percival_lafer | R$ 1.800,00 | R$ 9.720,00 | 54,8% | R$ 2.561,90 | nan |
| Joaquim Tenreiro:  Par de poltronas,  design  | par_de_poltronas | joaquim_tenreiro | R$ 0,00 | R$ 31.950,00 | 83,5% | R$ 1.379,05 | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | giuseppe_scapinelli | R$ 150,00 | R$ 7.200,00 | 86,4% | R$ 1.542,86 | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | giuseppe_scapinelli | R$ 150,00 | R$ 7.200,00 | 86,4% | R$ 1.542,86 | nan |
| CELINA DECORAÇÕES-BELO PAR DE MESAS LATERAIS  | outro | celina | R$ 850,00 | R$ 6.030,00 | 69,2% | R$ 1.902,86 | nan |
| Sergio Rodrigues - Mesa de centro de dois and | mesa_de_centro | sergio_rodrigues | R$ 1.200,00 | R$ 7.740,00 | 44,9% | R$ 1.452,99 | SP |
| GIUSEPE SCAPINELLI- MARACANÃ  singular mesa l | mesa_lateral | giuseppe_scapinelli | R$ 600,00 | R$ 5.220,00 | 70,9% | R$ 1.509,43 | RJ |

## 8. Carteira sugerida — estoque inicial

### R$ 30.000 — 40 peças, capital alocado R$ 29.631,00

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| Abraham Palatnik - Mesa de centro com tamp | mesa_de_centro | R$ 1.100,00 | R$ 22.252,70 | 88,4% | SP |
| RR Antiguidades Antigo quadro representand | cristal_vidro | R$ 400,00 | R$ 6.795,00 | 92,6% | RJ |
| Mesa lateral, confeccionada em madeira nob | mesa_lateral | R$ 160,00 | R$ 6.312,00 | 93,5% | RJ |
| Mesa lateral, confeccionada em madeira nob | mesa_lateral | R$ 180,00 | R$ 6.291,00 | 93,2% | RJ |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 6.032,00 | 84,3% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 4.806,50 | 67,2% | nan |
| Par de Poltronas, Anos 70 - Produzidas em  | par_de_poltronas | R$ 4.000,00 | R$ 4.610,00 | 49,2% | SP |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 3.765,00 | 78,9% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 3.712,50 | 77,8% | RJ |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 3.665,00 | 51,2% | SP |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.590,00 | 66,5% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.590,00 | 66,5% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.590,00 | 66,5% | RJ |
| EUGENIO PROENÇA SIGAUD (1899-1979) - " Nat | quadro_pintura | R$ 220,00 | R$ 3.279,00 | 86,8% | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 | banco | R$ 240,00 | R$ 3.048,00 | 63,9% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 3.030,00 | 63,5% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 3.030,00 | 63,5% | RJ |
| ROBIN DAY - par de cadeiras anos 70 de plá | par_de_cadeiras | R$ 500,00 | R$ 2.985,00 | 79,0% | RJ |
| Percival Lafer (São Paulo, SP, 12 de abril | poltrona | R$ 1.800,00 | R$ 2.960,00 | 54,8% | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 2.722,50 | 86,4% | nan |
| CELINA DECORAÇÕES-BELO PAR DE MESAS LATERA | outro | R$ 850,00 | R$ 2.617,50 | 69,2% | nan |
| Sergio Rodrigues - Mesa de centro de dois  | mesa_de_centro | R$ 1.200,00 | R$ 2.449,40 | 44,9% | SP |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 1.871,00 | 73,5% | SP |
| Par de poltronas estofadas com tecido list | par_de_poltronas | R$ 150,00 | R$ 1.839,50 | 72,2% | RS |
| Par de poltronas de diretor em metal com a | par_de_poltronas | R$ 290,00 | R$ 1.692,50 | 66,5% | RS |
| Autor Desconhecido - Banco Ripado - O banc | banco | R$ 220,00 | R$ 1.629,00 | 48,9% | SP |
| Par de poltronas em ferro tubular anos 60  | par_de_poltronas | R$ 390,00 | R$ 1.587,50 | 62,3% | SP |
| Par de Poltronas Giratórias, Anos 70 - Apr | par_de_poltronas | R$ 400,00 | R$ 1.577,00 | 61,9% | SP |
| Par de poltronas - Anos 50. Produzidas em  | par_de_poltronas | R$ 400,00 | R$ 1.577,00 | 61,9% | SP |
| Par de poltronas estilo Wingback clássica  | par_de_poltronas | R$ 400,00 | R$ 1.577,00 | 61,9% | RS |
| Par de poltronas rústicas em madeira -med. | par_de_poltronas | R$ 450,00 | R$ 1.524,50 | 59,9% | RS |
| Par de poltronas estofadas. Altura do enco | par_de_poltronas | R$ 500,00 | R$ 1.472,00 | 57,8% | nan |
| Par de poltronas contemporâneas estofadas  | par_de_poltronas | R$ 300,00 | R$ 1.382,00 | 54,3% | RS |
| Par de poltronas em excelente estado, esto | par_de_poltronas | R$ 800,00 | R$ 1.157,00 | 45,4% | nan |
| SERGIO RODRIGUES-BELA MESA DE APOIO EXECUT | mesa_lateral | R$ 480,00 | R$ 1.003,50 | 56,5% | nan |
| Lote de 4 cadeiras de plástico Tramontina  | conjunto_de_cadeiras | R$ 120,00 | R$ 854,00 | 55,8% | RS |
| Mesa de centro em madeira nobre pintada de | mesa_de_centro | R$ 320,00 | R$ 806,00 | 47,6% | nan |
| Poltrona estilo Luiz Felipe Volterie em ma | poltrona | R$ 100,00 | R$ 785,00 | 54,5% | RJ |
| Percival Lafer mesa de centro em madeira c | mesa_de_centro | R$ 350,00 | R$ 774,50 | 45,8% | SP |
| Antiga poltrona vintage de madeira com um  | poltrona | R$ 150,00 | R$ 732,50 | 50,9% | RJ |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 128.974,60** (margem agregada 81,3%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

### R$ 50.000 — 40 peças, capital alocado R$ 29.631,00

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| Abraham Palatnik - Mesa de centro com tamp | mesa_de_centro | R$ 1.100,00 | R$ 22.252,70 | 88,4% | SP |
| RR Antiguidades Antigo quadro representand | cristal_vidro | R$ 400,00 | R$ 6.795,00 | 92,6% | RJ |
| Mesa lateral, confeccionada em madeira nob | mesa_lateral | R$ 160,00 | R$ 6.312,00 | 93,5% | RJ |
| Mesa lateral, confeccionada em madeira nob | mesa_lateral | R$ 180,00 | R$ 6.291,00 | 93,2% | RJ |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 6.032,00 | 84,3% | RJ |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 4.806,50 | 67,2% | nan |
| Par de Poltronas, Anos 70 - Produzidas em  | par_de_poltronas | R$ 4.000,00 | R$ 4.610,00 | 49,2% | SP |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 3.765,00 | 78,9% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 3.712,50 | 77,8% | RJ |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 3.665,00 | 51,2% | SP |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.590,00 | 66,5% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.590,00 | 66,5% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.590,00 | 66,5% | RJ |
| EUGENIO PROENÇA SIGAUD (1899-1979) - " Nat | quadro_pintura | R$ 220,00 | R$ 3.279,00 | 86,8% | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 | banco | R$ 240,00 | R$ 3.048,00 | 63,9% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 3.030,00 | 63,5% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 3.030,00 | 63,5% | RJ |
| ROBIN DAY - par de cadeiras anos 70 de plá | par_de_cadeiras | R$ 500,00 | R$ 2.985,00 | 79,0% | RJ |
| Percival Lafer (São Paulo, SP, 12 de abril | poltrona | R$ 1.800,00 | R$ 2.960,00 | 54,8% | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 2.722,50 | 86,4% | nan |
| CELINA DECORAÇÕES-BELO PAR DE MESAS LATERA | outro | R$ 850,00 | R$ 2.617,50 | 69,2% | nan |
| Sergio Rodrigues - Mesa de centro de dois  | mesa_de_centro | R$ 1.200,00 | R$ 2.449,40 | 44,9% | SP |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 1.871,00 | 73,5% | SP |
| Par de poltronas estofadas com tecido list | par_de_poltronas | R$ 150,00 | R$ 1.839,50 | 72,2% | RS |
| Par de poltronas de diretor em metal com a | par_de_poltronas | R$ 290,00 | R$ 1.692,50 | 66,5% | RS |
| Autor Desconhecido - Banco Ripado - O banc | banco | R$ 220,00 | R$ 1.629,00 | 48,9% | SP |
| Par de poltronas em ferro tubular anos 60  | par_de_poltronas | R$ 390,00 | R$ 1.587,50 | 62,3% | SP |
| Par de Poltronas Giratórias, Anos 70 - Apr | par_de_poltronas | R$ 400,00 | R$ 1.577,00 | 61,9% | SP |
| Par de poltronas - Anos 50. Produzidas em  | par_de_poltronas | R$ 400,00 | R$ 1.577,00 | 61,9% | SP |
| Par de poltronas estilo Wingback clássica  | par_de_poltronas | R$ 400,00 | R$ 1.577,00 | 61,9% | RS |
| Par de poltronas rústicas em madeira -med. | par_de_poltronas | R$ 450,00 | R$ 1.524,50 | 59,9% | RS |
| Par de poltronas estofadas. Altura do enco | par_de_poltronas | R$ 500,00 | R$ 1.472,00 | 57,8% | nan |
| Par de poltronas contemporâneas estofadas  | par_de_poltronas | R$ 300,00 | R$ 1.382,00 | 54,3% | RS |
| Par de poltronas em excelente estado, esto | par_de_poltronas | R$ 800,00 | R$ 1.157,00 | 45,4% | nan |
| SERGIO RODRIGUES-BELA MESA DE APOIO EXECUT | mesa_lateral | R$ 480,00 | R$ 1.003,50 | 56,5% | nan |
| Lote de 4 cadeiras de plástico Tramontina  | conjunto_de_cadeiras | R$ 120,00 | R$ 854,00 | 55,8% | RS |
| Mesa de centro em madeira nobre pintada de | mesa_de_centro | R$ 320,00 | R$ 806,00 | 47,6% | nan |
| Poltrona estilo Luiz Felipe Volterie em ma | poltrona | R$ 100,00 | R$ 785,00 | 54,5% | RJ |
| Percival Lafer mesa de centro em madeira c | mesa_de_centro | R$ 350,00 | R$ 774,50 | 45,8% | SP |
| Antiga poltrona vintage de madeira com um  | poltrona | R$ 150,00 | R$ 732,50 | 50,9% | RJ |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 128.974,60** (margem agregada 81,3%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

## 9. Lances máximos por tipo de peça (para margem de 40%)

| item_type | lance máx mediano (40% margem) |
|---|---|
| cristal_vidro | R$ 4.077,14 |
| mesa_lateral | R$ 2.554,72 |
| banco | R$ 2.468,57 |
| poltrona | R$ 2.421,90 |
| par_de_cadeiras | R$ 1.902,86 |
| quadro_pintura | R$ 1.902,86 |
| outro | R$ 1.902,86 |
| cadeira | R$ 1.542,86 |
| mesa_de_centro | R$ 948,02 |
| par_de_poltronas | R$ 931,62 |
| conjunto_de_cadeiras | R$ 350,48 |

## 10. Modelo A (casa de leilão) vs Modelo B (garimpo + revenda)

- **GMV observado** nas casas amostradas (martelo × vendidos): ~R$ 99.197.394,00 na janela de 14/01/2015 a 10/06/2026 (4166 dias) — denso e pulverizado entre muitas casas.
- **Modelo A** com take de 15,0%: para cobrir OPEX de R$ 10.000 / 15.000 / 25.000 ao mês, a casa precisaria de GMV mensal de ~R$ 66.666,67 / R$ 100.000,00 / R$ 166.666,67 respectivamente. Exige curadoria, captação de consignação e base de compradores — difícil para operação solo no início.
- **Modelo B** já é acionável hoje: 51 lotes BUY_NOW com margem ≥ 40,0%, capital inicial de R$ 30k aloca 40 peças. Giro depende de logística — por isso o foco em peças small/medium/large.

**Recomendação:** começar pelo **Modelo B** (menor capital travado, risco operacional menor, lucro por peça verificável com os dados). Migrar para **Modelo A** quando o GMV mensal de revenda ultrapassar consistentemente ~R$ 100.000,00 e houver fluxo de consignação — aí o take fixo da casa passa a compensar o OPEX.

## 11. Limitações e vieses

- Janela de finalizados observada: 14/01/2015 a 10/06/2026 (4166 dias); sazonalidade anual não capturada.
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