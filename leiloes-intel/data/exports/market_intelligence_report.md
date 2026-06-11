# Relatório de Inteligência de Mercado — LeilõesBR

_Gerado em 11/06/2026 11:45. Coleta de páginas públicas, sem login, com rate limit._

## 1. Resumo executivo

- **Lotes coletados:** 821.534 (8.582 ao vivo, 961.839 finalizados)
- **Casas/leiloeiros mapeados:** 845
- **Lotes vendidos com martelo observado:** 511.995 → **sell-through global 53,2%**
- **Janela de finalizados observada:** 14/01/2015 a 10/06/2026 (4166 dias).
- **Fonte de preço:** martelo REAL de leilões finalizados, não proxy. Lances ao vivo da busca por categoria.

> **Observed vs inferred.** Martelo, lance, nº de lances e status de venda são _observados_ no site. Tipo de peça, designer, força de atribuição, custos de frete/restauro, valor de revenda estimado, margem e sinais são _inferidos_ por regras determinísticas (ver `data_dictionary.md`).

## 2. Top categorias por sell-through (≥30 lotes finalizados)

| item_type | ofertados | vendidos | sell-through | martelo mediano | zero-bid |
|---|---|---|---|---|---|
| disco_vinil | 56787 | 43713 | 77,0% | R$ 40,00 | 22,6% |
| conjunto_de_cadeiras | 1373 | 978 | 71,2% | R$ 1.700,00 | 23,5% |
| prata_metal | 44493 | 31605 | 71,0% | R$ 100,00 | 28,0% |
| carrinho_de_cha | 248 | 174 | 70,2% | R$ 1.050,00 | 24,6% |
| mesa_lateral | 1684 | 1136 | 67,5% | R$ 440,00 | 27,2% |
| par_de_poltronas | 1934 | 1284 | 66,4% | R$ 3.100,00 | 28,1% |
| sofa | 1798 | 1193 | 66,4% | R$ 2.300,00 | 26,5% |
| escrivaninha | 494 | 325 | 65,8% | R$ 1.200,00 | 28,1% |
| selo_filatelia | 22992 | 15019 | 65,3% | R$ 15,00 | 34,3% |
| mesa_de_centro | 1816 | 1132 | 62,3% | R$ 1.000,00 | 33,1% |
| brinquedo | 64158 | 39972 | 62,3% | R$ 60,00 | 36,6% |
| cama | 924 | 568 | 61,5% | R$ 300,00 | 35,0% |

## 3. Top categorias por ticket (martelo mediano)

| item_type | martelo mediano | sell-through | ofertados |
|---|---|---|---|
| par_de_poltronas | R$ 3.100,00 | 66,4% | 1934 |
| sofa | R$ 2.300,00 | 66,4% | 1798 |
| poltrona | R$ 2.000,00 | 59,3% | 3219 |
| conjunto_de_cadeiras | R$ 1.700,00 | 71,2% | 1373 |
| mesa_de_jantar | R$ 1.600,00 | 57,3% | 1109 |
| escrivaninha | R$ 1.200,00 | 65,8% | 494 |
| aparador | R$ 1.100,00 | 59,2% | 1698 |
| carrinho_de_cha | R$ 1.050,00 | 70,2% | 248 |
| mesa_de_centro | R$ 1.000,00 | 62,3% | 1816 |
| comoda | R$ 850,00 | 61,2% | 672 |
| par_de_cadeiras | R$ 685,00 | 53,5% | 1063 |
| estante | R$ 665,00 | 58,6% | 1660 |

## 4. Categorias de baixa complexidade logística (foco operação solo)

| item_type | sell-through | martelo mediano | ofertados |
|---|---|---|---|
| prata_metal | 71,0% | R$ 100,00 | 44493 |
| mesa_lateral | 67,5% | R$ 440,00 | 1684 |
| mesa_de_centro | 62,3% | R$ 1.000,00 | 1816 |
| espelho | 59,6% | R$ 350,00 | 2764 |
| poltrona | 59,3% | R$ 2.000,00 | 3219 |
| cadeira | 56,0% | R$ 500,00 | 3407 |
| porcelana_ceramica | 54,7% | R$ 71,00 | 31473 |
| luminaria_lustre | 53,8% | R$ 185,00 | 8279 |
| par_de_cadeiras | 53,5% | R$ 685,00 | 1063 |
| objeto_decorativo | 47,4% | R$ 108,00 | 2690 |
| cristal_vidro | 43,3% | R$ 85,00 | 28203 |
| quadro_pintura | 34,1% | R$ 180,00 | 33906 |

## 5. Casas para sourcing (maior zero-bid + volume ≥50)

| casa | uf | finalizados | zero-bid | sell-through | martelo médio |
|---|---|---|---|---|---|
| Leilões Bruno Francesco | RJ | 270 | 100,0% | 0,0% | — |
| Sol Mar e Lua Leilões | SP | 233 | 100,0% | 0,0% | — |
| CH Collection - Numismática, Joias e Colecionáveis | PR | 386 | 100,0% | 0,0% | — |
| Coleções e Afins | MG | 600 | 98,7% | 1,3% | R$ 24,25 |
| Oficina Cenário Leilões | nan | 226 | 96,5% | 3,1% | R$ 942,86 |
| Vale Arte Leilões | SP | 518 | 95,8% | 4,2% | R$ 1.104,55 |
| Via Arte Leilões | SP | 452 | 95,6% | 4,4% | R$ 600,00 |
| Clássicos Modernos Leilões | RJ | 5554 | 95,4% | 4,4% | R$ 1.268,03 |
| Dell Fanny Jóias Leilões | RJ | 8967 | 95,3% | 4,3% | R$ 3.225,65 |
| Bons Tempos Leilões | RJ | 9647 | 94,5% | 5,2% | R$ 3.684,06 |
| Eternno Leilões | RJ | 766 | 94,3% | 5,7% | R$ 1.318,41 |
| Alvura Leilões Gestora de Ativos | PR | 3617 | 94,1% | 5,7% | R$ 343,26 |
| Extrema Leilões | MG | 295 | 93,2% | 6,8% | R$ 1.566,00 |
| DRJ Leilões | SP | 425 | 93,2% | 6,8% | R$ 2.140,69 |
| Bardi Leilões | nan | 445 | 92,1% | 7,9% | R$ 314,46 |

_Zero-bid alto = mais chance de arrematar barato / pós-pregão._

## 6. Casas benchmark (maior sell-through, volume ≥50)

| casa | uf | finalizados | sell-through | martelo médio |
|---|---|---|---|---|
| Mania Comics | nan | 4230 | 100,0% | R$ 211,19 |
| Nossa Coleção | SP | 451 | 99,6% | R$ 107,07 |
| Saturno Leilões | nan | 18500 | 99,1% | R$ 8,48 |
| Acervo Cult - Colecionismo Para Todos | nan | 3346 | 97,8% | R$ 100,31 |
| Ernani Leiloeiro Oficial | RJ | 889 | 97,8% | R$ 343,85 |
| Filatélica MG Leilões | nan | 8338 | 97,7% | R$ 24,36 |
| Galeria República da Arte | PR | 200 | 97,5% | R$ 123,64 |
| Pariz Moedas | PR | 290 | 95,5% | R$ 89,35 |
| PRH Leilões | RS | 570 | 95,4% | R$ 47,49 |
| Acervo do Garimpeiro | SP | 1428 | 95,1% | R$ 76,66 |
| Escafandro Discos - Antiguidades e Colecionáveis | nan | 6013 | 95,0% | R$ 114,91 |
| Rivaldo Dantas Leilões | SP | 2425 | 93,2% | R$ 159,95 |
| São Jorge Leilões | SP | 156 | 92,3% | R$ 343,12 |
| Nosso Passado Mobiliário | RJ | 98 | 91,8% | R$ 4.726,18 |
| Vila Rica Moedas | nan | 18263 | 90,6% | R$ 836,92 |

## 7. Oportunidades de compra (sinal BUY_NOW)

> **Como ler.** Estes são sinais de _triagem_, não lucros garantidos. A revenda é estimada pelo p25 (conservador) dos martelos de comparáveis × markup de varejo. O comp agrupa por (tipo, designer), então **não distingue o modelo/linha específico** (ex.: uma 'Poltrona Cimba' barata herda o comp de poltronas do mesmo designer). Trate margens altas em itens de lance muito baixo como candidatos a verificar peça a peça (use a coluna `lot_url` e a amostra de auditoria), não como certezas.

Total de lotes BUY_NOW: **47**. Top 25 por lucro estimado (conservador):

| título | tipo | designer | lance atual | revenda est. | margem | lance máx 40% | uf |
|---|---|---|---|---|---|---|---|
| Abraham Palatnik - Mesa de centro com tampo e | mesa_de_centro | abraham_palatnik | R$ 1.100,00 | R$ 29.700,00 | 85,9% | R$ 10.113,56 | SP |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 do p | poltrona | sergio_rodrigues | R$ 260,00 | R$ 16.380,00 | 85,5% | R$ 3.613,33 | RJ |
| EUGENIO PROENÇA SIGAUD (1899-1979) - " Nature | quadro_pintura | joaquim_tenreiro | R$ 220,00 | R$ 12.780,00 | 92,4% | R$ 3.528,51 | RJ |
| Par de Poltronas, Anos 70 - Produzidas em esp | par_de_poltronas | percival_lafer | R$ 4.000,00 | R$ 20.700,00 | 54,6% | R$ 5.452,19 | SP |
| SERGIO RODRIGUES - poltronas IAB em madeira e | poltrona | sergio_rodrigues | R$ 570,00 | R$ 16.380,00 | 69,7% | R$ 2.756,19 | nan |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 700,00 | R$ 11.520,00 | 83,3% | R$ 3.188,57 | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido em  | banco | sergio_rodrigues | R$ 750,00 | R$ 11.520,00 | 82,5% | R$ 3.188,57 | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 em | banco | sergio_rodrigues | R$ 240,00 | R$ 11.520,00 | 71,4% | R$ 2.045,71 | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine". Est | banco | sergio_rodrigues | R$ 1.400,00 | R$ 11.520,00 | 71,1% | R$ 3.188,57 | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine". Est | banco | sergio_rodrigues | R$ 1.400,00 | R$ 11.520,00 | 71,1% | R$ 3.188,57 | RJ |
| Joaquim Tenreiro - "galo", pintura s/madeira, | quadro_pintura | joaquim_tenreiro | R$ 2.000,00 | R$ 12.780,00 | 64,2% | R$ 3.528,51 | RJ |
| Rara Poltrona, Sergio Rodrigues - Produzida e | poltrona | sergio_rodrigues | R$ 2.800,00 | R$ 16.380,00 | 54,9% | R$ 3.899,05 | SP |
| ROBIN DAY - par de cadeiras anos 70 de plásti | par_de_cadeiras | jorge_zalszupin | R$ 500,00 | R$ 7.317,00 | 81,6% | R$ 2.211,43 | RJ |
| PERCIVAL LAFER - Poltrona  do design brasilei | poltrona | percival_lafer | R$ 1.200,00 | R$ 9.720,00 | 65,9% | R$ 2.510,48 | RJ |
| PERCIVAL LAFER - Poltrona  do design brasilei | poltrona | percival_lafer | R$ 1.200,00 | R$ 9.720,00 | 65,9% | R$ 2.510,48 | RJ |
| PERCIVAL LAFER - Poltrona  do design brasilei | poltrona | percival_lafer | R$ 1.200,00 | R$ 9.720,00 | 65,9% | R$ 2.510,48 | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | giuseppe_scapinelli | R$ 150,00 | R$ 8.460,00 | 88,7% | R$ 1.902,86 | nan |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | giuseppe_scapinelli | R$ 150,00 | R$ 8.460,00 | 88,7% | R$ 1.902,86 | nan |
| CELINA DECORAÇÕES-BELO PAR DE MESAS LATERAIS  | outro | celina | R$ 850,00 | R$ 7.200,00 | 74,2% | R$ 2.314,29 | nan |
| Percival Lafer (São Paulo, SP, 12 de abril de | poltrona | percival_lafer | R$ 1.800,00 | R$ 9.720,00 | 54,0% | R$ 2.510,48 | nan |
| Sergio Rodrigues (Oca) - Excepcional e rara l | mesa | sergio_rodrigues | R$ 1.000,00 | R$ 11.880,00 | 50,2% | R$ 1.547,62 | SP |
| SYLVIO PINTO  (Rio de Janeiro, RJ, 1918  idem | quadro_pintura | joaquim_tenreiro | R$ 3.500,00 | R$ 12.780,00 | 40,5% | R$ 3.528,51 | nan |
| Sergio Rodrigues - Mesa de centro de dois and | mesa_de_centro | sergio_rodrigues | R$ 1.200,00 | R$ 7.920,90 | 45,4% | R$ 1.483,33 | SP |
| Joaquim Tenreiro:  Par de poltronas,  design  | par_de_poltronas | joaquim_tenreiro | R$ 0,00 | R$ 26.280,00 | 80,8% | R$ 1.109,05 | RJ |
| GIUSEPE SCAPINELLI- MARACANÃ  singular mesa l | mesa_lateral | giuseppe_scapinelli | R$ 600,00 | R$ 4.230,00 | 70,4% | R$ 1.479,86 | RJ |

## 8. Carteira sugerida — estoque inicial

### R$ 30.000 — 25 peças, capital alocado R$ 29.956,50

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| Abraham Palatnik - Mesa de centro com tamp | mesa_de_centro | R$ 1.100,00 | R$ 17.710,40 | 85,9% | SP |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 6.617,00 | 85,5% | RJ |
| EUGENIO PROENÇA SIGAUD (1899-1979) - " Nat | quadro_pintura | R$ 220,00 | R$ 6.123,90 | 92,4% | RJ |
| Par de Poltronas, Anos 70 - Produzidas em  | par_de_poltronas | R$ 4.000,00 | R$ 5.708,00 | 54,6% | SP |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 5.391,50 | 69,7% | nan |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 5.025,00 | 83,3% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 4.972,50 | 82,5% | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 | banco | R$ 240,00 | R$ 4.308,00 | 71,4% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.290,00 | 71,1% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.290,00 | 71,1% | RJ |
| Joaquim Tenreiro - "galo", pintura s/madei | quadro_pintura | R$ 2.000,00 | R$ 4.254,90 | 64,2% | RJ |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 4.250,00 | 54,9% | SP |
| ROBIN DAY - par de cadeiras anos 70 de plá | par_de_cadeiras | R$ 500,00 | R$ 3.525,00 | 81,6% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.500,00 | 65,9% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.500,00 | 65,9% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.500,00 | 65,9% | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 3.352,50 | 88,7% | nan |
| CELINA DECORAÇÕES-BELO PAR DE MESAS LATERA | outro | R$ 850,00 | R$ 3.337,50 | 74,2% | nan |
| Percival Lafer (São Paulo, SP, 12 de abril | poltrona | R$ 1.800,00 | R$ 2.870,00 | 54,0% | nan |
| Sergio Rodrigues (Oca) - Excepcional e rar | mesa | R$ 1.000,00 | R$ 2.825,00 | 50,2% | SP |
| SYLVIO PINTO  (Rio de Janeiro, RJ, 1918  i | quadro_pintura | R$ 3.500,00 | R$ 2.679,90 | 40,5% | nan |
| Sergio Rodrigues - Mesa de centro de dois  | mesa_de_centro | R$ 1.200,00 | R$ 2.502,50 | 45,4% | SP |
| Autor Desconhecido - Banco Ripado - O banc | banco | R$ 220,00 | R$ 1.629,00 | 48,9% | SP |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 1.484,00 | 68,7% | SP |
| Par de poltronas estofadas com tecido list | par_de_poltronas | R$ 150,00 | R$ 1.452,50 | 67,2% | RS |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 109.099,10** (margem agregada 78,5%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

### R$ 50.000 — 40 peças, capital alocado R$ 35.994,00

| título | tipo | lance | lucro est. | margem | uf |
|---|---|---|---|---|---|
| Abraham Palatnik - Mesa de centro com tamp | mesa_de_centro | R$ 1.100,00 | R$ 17.710,40 | 85,9% | SP |
| SERGIO RODRIGUES- CIMBA poltrona anos 80 d | poltrona | R$ 260,00 | R$ 6.617,00 | 85,5% | RJ |
| EUGENIO PROENÇA SIGAUD (1899-1979) - " Nat | quadro_pintura | R$ 220,00 | R$ 6.123,90 | 92,4% | RJ |
| Par de Poltronas, Anos 70 - Produzidas em  | par_de_poltronas | R$ 4.000,00 | R$ 5.708,00 | 54,6% | SP |
| SERGIO RODRIGUES - poltronas IAB em madeir | poltrona | R$ 570,00 | R$ 5.391,50 | 69,7% | nan |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 700,00 | R$ 5.025,00 | 83,3% | RJ |
| SÉRGIO RODRIGUES - Banco Mocho. Esculpido  | banco | R$ 750,00 | R$ 4.972,50 | 82,5% | RJ |
| SERGIO RODRIGUES - MARCOS banqueta anos 60 | banco | R$ 240,00 | R$ 4.308,00 | 71,4% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.290,00 | 71,1% | RJ |
| SÉRGIO RODRIGUES - Banco de Bar - "Nine".  | banco | R$ 1.400,00 | R$ 4.290,00 | 71,1% | RJ |
| Joaquim Tenreiro - "galo", pintura s/madei | quadro_pintura | R$ 2.000,00 | R$ 4.254,90 | 64,2% | RJ |
| Rara Poltrona, Sergio Rodrigues - Produzid | poltrona | R$ 2.800,00 | R$ 4.250,00 | 54,9% | SP |
| ROBIN DAY - par de cadeiras anos 70 de plá | par_de_cadeiras | R$ 500,00 | R$ 3.525,00 | 81,6% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.500,00 | 65,9% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.500,00 | 65,9% | RJ |
| PERCIVAL LAFER - Poltrona  do design brasi | poltrona | R$ 1.200,00 | R$ 3.500,00 | 65,9% | RJ |
| JOSEPH SCAPINELLI- Par de cadeira anos 60 | cadeira | R$ 150,00 | R$ 3.352,50 | 88,7% | nan |
| CELINA DECORAÇÕES-BELO PAR DE MESAS LATERA | outro | R$ 850,00 | R$ 3.337,50 | 74,2% | nan |
| Percival Lafer (São Paulo, SP, 12 de abril | poltrona | R$ 1.800,00 | R$ 2.870,00 | 54,0% | nan |
| Sergio Rodrigues (Oca) - Excepcional e rar | mesa | R$ 1.000,00 | R$ 2.825,00 | 50,2% | SP |
| SYLVIO PINTO  (Rio de Janeiro, RJ, 1918  i | quadro_pintura | R$ 3.500,00 | R$ 2.679,90 | 40,5% | nan |
| Sergio Rodrigues - Mesa de centro de dois  | mesa_de_centro | R$ 1.200,00 | R$ 2.502,50 | 45,4% | SP |
| Carlo Hauner e Martin Eisler - Elegante pa | par_de_poltronas | R$ 1.100,00 | R$ 2.135,00 | 42,4% | SP |
| Autor Desconhecido - Banco Ripado - O banc | banco | R$ 220,00 | R$ 1.629,00 | 48,9% | SP |
| Par de Poltronas, Estilo Luís XVI, em Made | par_de_poltronas | R$ 120,00 | R$ 1.484,00 | 68,7% | SP |
| Par de poltronas estofadas com tecido list | par_de_poltronas | R$ 150,00 | R$ 1.452,50 | 67,2% | RS |
| Par de poltronas de diretor em metal com a | par_de_poltronas | R$ 290,00 | R$ 1.305,50 | 60,4% | RS |
| Par de poltronas em ferro tubular anos 60  | par_de_poltronas | R$ 390,00 | R$ 1.200,50 | 55,6% | SP |
| Par de Poltronas Giratórias, Anos 70 - Apr | par_de_poltronas | R$ 400,00 | R$ 1.190,00 | 55,1% | SP |
| Par de poltronas - Anos 50. Produzidas em  | par_de_poltronas | R$ 400,00 | R$ 1.190,00 | 55,1% | SP |
| Par de poltronas estilo Wingback clássica  | par_de_poltronas | R$ 400,00 | R$ 1.190,00 | 55,1% | RS |
| Par de poltronas rústicas em madeira -med. | par_de_poltronas | R$ 450,00 | R$ 1.137,50 | 52,7% | RS |
| Par de poltronas estofadas. Altura do enco | par_de_poltronas | R$ 500,00 | R$ 1.085,00 | 50,2% | nan |
| SERGIO RODRIGUES-BELA MESA DE APOIO EXECUT | mesa_lateral | R$ 480,00 | R$ 1.080,00 | 58,2% | nan |
| Par de poltronas contemporâneas estofadas  | par_de_poltronas | R$ 300,00 | R$ 995,00 | 46,1% | RS |
| Lote de 4 cadeiras de plástico Tramontina  | conjunto_de_cadeiras | R$ 120,00 | R$ 701,00 | 50,9% | RS |
| Mesa de centro em madeira nobre pintada de | mesa_de_centro | R$ 320,00 | R$ 698,00 | 44,1% | nan |
| Percival Lafer mesa de centro em madeira c | mesa_de_centro | R$ 350,00 | R$ 666,50 | 42,1% | SP |
| Poltrona estilo Luiz Felipe Volterie em ma | poltrona | R$ 100,00 | R$ 655,40 | 50,0% | RJ |
| Antiga poltrona vintage de madeira com um  | poltrona | R$ 150,00 | R$ 602,90 | 46,0% | RJ |

**Lucro bruto potencial da carteira (estimativa conservadora, a verificar peça a peça): R$ 124.931,40** (margem agregada 77,6%). Driver: peças de designer (Sergio Rodrigues, Burle Marx) com lance ainda baixo — confirme modelo/linha e autenticidade antes de arrematar.

## 9. Lances máximos por tipo de peça (para margem de 40%)

| item_type | lance máx mediano (40% margem) |
|---|---|
| quadro_pintura | R$ 3.528,51 |
| banco | R$ 3.188,57 |
| poltrona | R$ 2.510,48 |
| outro | R$ 2.314,29 |
| par_de_cadeiras | R$ 2.211,43 |
| cadeira | R$ 1.902,86 |
| mesa | R$ 1.547,62 |
| mesa_lateral | R$ 1.141,07 |
| mesa_de_centro | R$ 932,33 |
| par_de_poltronas | R$ 710,48 |
| conjunto_de_cadeiras | R$ 263,05 |

## 10. Modelo A (casa de leilão) vs Modelo B (garimpo + revenda)

- **GMV observado** nas casas amostradas (martelo × vendidos): ~R$ 48.636.637,00 na janela de 14/01/2015 a 10/06/2026 (4166 dias) — denso e pulverizado entre muitas casas.
- **Modelo A** com take de 15,0%: para cobrir OPEX de R$ 10.000 / 15.000 / 25.000 ao mês, a casa precisaria de GMV mensal de ~R$ 66.666,67 / R$ 100.000,00 / R$ 166.666,67 respectivamente. Exige curadoria, captação de consignação e base de compradores — difícil para operação solo no início.
- **Modelo B** já é acionável hoje: 47 lotes BUY_NOW com margem ≥ 40,0%, capital inicial de R$ 30k aloca 25 peças. Giro depende de logística — por isso o foco em peças small/medium/large.

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