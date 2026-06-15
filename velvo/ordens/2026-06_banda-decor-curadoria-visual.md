# Ordem de compra — banda decorativa de maior spread (curadoria visual)

_Recorte: leilões **ao vivo** da base, banda escultural/decorativa de marca (vibe
[Antonio objetos](https://www.antoniooo.com/)). Orçamento teto R$ 5.000. Curadoria
em duas camadas: (1) economia com **âncoras de martelo real por subsegmento**;
(2) **inspeção visual peça a peça das imagens** — fora tudo que parece desgastado,
empoeirado, riscado, kitsch ou "antiquário carregado". Gerado em 15/06/2026._

> **Limite do dado (honesto e importante).** A base local é um **snapshot de ~10–11/jun/2026**.
> "Tudo que está aberto hoje (15/jun)" eu filtrei por encerramento ≥ 15/jun: **135
> lotes-banda seguem abertos** (89 em junho, 46 em julho) + 103 sem data no snapshot.
> Vários lotes ótimos que achei **já encerraram** (10–11/jun). Para varrer de fato o
> que abriu depois do snapshot, é preciso rodar o scrape de novo (`run_all.py`) — o
> método abaixo roda igual sobre dados frescos. Lista completa do que está aberto:
> `velvo/ordens/2026-06_banda-decor_aberto.csv` (238 linhas, com link e thumbnail).

---

## 1. O que muda ao subir de banda

O exercício anterior (vidro/Murano pequeno) topava em revenda ~R$ 680 e net R$ 30–120.
Subindo para **escultura / centro de mesa / vaso escultórico de marca**, alinhado ao
Antonio (que vende R$ 520–3.400), o **spread absoluto por peça** salta para
**R$ 300–1.400** — agora cobre folgado a logística e o overhead. Âncoras reais
(martelo de comparáveis vendidos × 1,8):

| subsegmento | sell-through | retalho conservador | retalho bom exemplar (p75) |
|---|---|---|---|
| Brennand (cerâmica) | 51% | R$ 900 | R$ 2.520 |
| Sèvres | 39% | R$ 900 | R$ 2.700 |
| bronze/escultura assinada | 29–33% | R$ 580–650 | R$ 1.700 |
| Baccarat | 52% | R$ 716 | R$ 1.440 |
| Daum | 53% | R$ 855 | R$ 1.910 |
| Capodimonte | 56% | R$ 522 | R$ 1.184 |
| Christofle | 59% | R$ 486 | R$ 990 |
| Palatnik | **65%** | R$ 1.350 | R$ 2.160 |

A liquidez ainda é o calcanhar (escultura/bronze giram devagar, ~30%); por isso a
**foto vende** — peça impecável e bem fotografada é o que destrava o giro e o preço.

---

## 2. A curadoria visual (eu olhei as imagens)

Baixei as thumbnails (cloudfront) e avaliei uma a uma. **Aprovado** = forma limpa,
escultural, sem desgaste aparente, estética Antonio. **Reprovado**, com motivo:

- ❌ abotoaduras / anel de Orixá / bolsa de malha de prata → **joia/acessório**, não decor.
- ❌ Buda risonho, divindade dourada sentada, bronze "tribal" cru → **kitsch/carregado**.
- ❌ pratinhos e xícaras Vista Alegre/Colorex/Limoges → **louça comum**, não peça-statement.
- ❌ "cristal ao gosto Baccarat" / "Old Sèvres ... Shelley" → **atribuição falsa** (vale como vidro genérico).

---

## 3. Ordem de compra (curada, com lance-teto)

P&L: `net = retalho×0,93 − (lance×1,05 + logística)`. Logística: peça pequena/média
R$ 110 (Correios frágil/transportadora) · escultura média R$ 170. Frete de saída
normalmente pago pelo comprador. **Respeite o lance-teto** (são leilões ao vivo).

### Tier A — comprar agora (aberto em junho, visual aprovado)

| peça | casa / link | lance | **teto** | net conserv. | net bom exemplar | encerra |
|---|---|---|---|---|---|---|
| **Gato em bronze maciço** (escultura limpa, pátina dourada) | bruceangeirasleiloeiro — [Id 31203696](https://bruceangeirasleiloeiro.com.br/peca.asp?Id=31203696) | R$ 30 | **R$ 112** | +R$ 248 | **+R$ 1.300** | 16/jun RJ |
| **Compoteira em cristal Baccarat** lapidado, c/ tampa | rosanavaleleiloes — [Id 29865875](https://rosanavaleleiloes.com.br/peca.asp?Id=29865875) | R$ 170 | **R$ 236** | +R$ 308 | **+R$ 980** | 16/jun RJ |
| **Vaso/jarra Vista Alegre Coral** (acento barato) | ernanileiloeiro — [Id 29205816](https://br.ernanileiloeiro.com.br/peca.asp?Id=29205816) | R$ 15 | **R$ 60** | +R$ 61 | +R$ 280 | 23/jun RJ |

### Tier B — verificar status no site e dar lance (sem data no snapshot; visual forte)

| peça | casa / link | lance | **teto** | net bom exemplar | obs |
|---|---|---|---|---|---|
| **Escultura modernista latão + base de mármore** (esferas em anel) | tallonileiloes — [Id 31196051](https://tallonileiloes.com.br/peca.asp?Id=31196051) | R$ 290 | **R$ 400** | **+R$ 1.000** | a peça mais "Antonio" do lote |
| **Solifleur Murano azul cobalto, anos 50** (vaso de haste fina) | estiloantigoleiloes — [Id 30966705](https://estiloantigoleiloes.com.br/peca.asp?Id=30966705) | R$ 150 | **R$ 200** | +R$ 290 | hero visual; só ao teto |

### Tier C — julho (abre depois; planejar)

| peça | casa / link | lance | encerra | net bom exemplar |
|---|---|---|---|---|
| **Cavalo escultórico em cerâmica azul** (design lúdico) | miguelsalles — [Id 30062533](https://miguelsalles.com.br/peca.asp?Id=30062533) | R$ 200 | 09/jul RJ | +R$ 1.200 |

> Lotes Baccarat (pato/marreco, bowl pesado, licoreira) e a jarra **Daum** que eu
> aprovei visualmente **já encerraram** (10–11/jun) — entram no playbook da próxima rodada.

---

## 4. P&L da cesta e veredito de viabilidade

**Cesta executável hoje (Tier A + B, comprando no teto):**

| | capital (teto) | net conservador | net bom exemplar |
|---|---|---|---|
| Tier A | R$ 408 | +R$ 617 | +R$ 2.560 |
| Tier B | R$ 600 | +R$ 240 | +R$ 1.290 |
| **Total** | **~R$ 1.000** | **+R$ 860** | **+R$ 3.850** |

Mesmo subindo de banda, **a oferta curável de junho não chega perto de R$ 5.000** —
sobra ~R$ 4.000 em caixa. **O gargalo nunca é o capital; é o fluxo de peças
visualmente impecáveis e bem atribuídas.**

### Viабilidade (banda decorativa de maior spread)
- **Muito melhor que vidro barato.** Net R$ 300–1.400 por peça boa cobre folgado
  logística (~R$ 110–170) + overhead do site (~R$ 1–25/peça). Margem saudável.
- **O site não é o gargalo:** free tier (~R$ 10/mês), equilíbrio em <1 peça/mês.
- **É viável como drop curado e visual** (estilo Antonio) **se** você rodar o scrape
  semanal e garimpar 5–15 peças impecáveis por semana **no conjunto de todos os
  leilões abertos** (não neste único snapshot). Aí o giro sustenta o negócio.
- **Não é** uma máquina de alocar capital de uma vez: você cicla valores pequenos
  rápido (compra R$ 30–400, vende R$ 500–2.500), não estaciona R$ 5.000.

### Recomendação operacional
1. Compre **Gato de bronze** e **Compoteira Baccarat** ainda hoje/amanhã (teto acima).
2. Confirme no site se **escultura latão+mármore** e **solifleur Murano** seguem abertos; se sim, lance até o teto — são as peças de maior apelo visual.
3. **Rode `run_all.py` para um snapshot fresco de 15/jun** e regenere esta lista —
   é onde aparece a oferta que abriu nos últimos dias.
4. Trate a **foto** como parte do produto: fundo neutro, peça centrada (padrão Antonio).
   É o que transforma um martelo de R$ 200 em revenda de R$ 800–2.500.

_Comps recalculados do martelo real de vendidos por subsegmento (Brennand n=123,
bronze n=2.262, escultura assinada n=1.722, Baccarat n=768, Daum n=30, Sèvres n=133,
Christofle n=287, Palatnik n=462). Imagens inspecionadas via cache cloudfront._
