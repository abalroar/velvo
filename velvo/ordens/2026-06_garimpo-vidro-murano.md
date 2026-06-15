# Ordem de compra — garimpo de vidro / Murano / objetos decorativos

_Recorte: leilões **ao vivo** encerrando entre 15 e 30 de junho de 2026. Orçamento
teto: R$ 5.000. Foco: objetos pequenos de vidro, vasos, Murano, cristal — bem
conservados, vibe decorativa ("Antônio objetos"). Fonte: `leiloes-intel/data/exports/lots.parquet`
(8.420 lotes ao vivo, 5.070 encerrando em junho). Gerado em 15/06/2026._

> **Aviso honesto.** Os preços de revenda aqui são âncoras de **martelo real** de
> comparáveis vendidos (não o comp genérico do pipeline, que marca todo vidro como
> AVOID). Ainda assim são estimativas de triagem: vidro exige conferência peça a
> peça (autenticidade da marca, estado real na foto, risco de quebra no transporte).

---

## 1. Veredito de viabilidade (resumo)

**O nicho que você pediu — vidro/Murano/vasos pequenos — é o de pior economia de
toda a base.** Não é opinião; é o que os dados mostram:

| segmento | sell-through | martelo mediano | leitura |
|---|---|---|---|
| cristal_vidro | **41,0%** | R$ 85 | pior liquidez + menor ticket |
| escultura | 33,7% | R$ 170 | pior liquidez |
| objeto_decorativo | 47,9% | R$ 120 | baixo ticket |
| porcelana_ceramica | 51,1% | R$ 72 | baixo ticket |
| Murano (todos) | 38,6% | R$ 120 | ~60% nem vende |
| Murano assinado | 37,1% | R$ 200 | idem |

Três forças derrubam a margem nesse nicho:
1. **Ticket baixo** — a peça típica revende por R$ 150–680, não milhares.
2. **Liquidez baixa** — ~40% de sell-through significa que o capital fica parado;
   ~60% das peças nem encontram comprador no leilão (e na revenda é parecido).
3. **Custo logístico fixo por remessa** — frete de entrada (Correios frágil) +
   embalagem ≈ **R$ 70/peça** antes do item, mais o risco de quebra no transporte
   (~7%). Em peça de R$ 30–120, esse custo fixo **come a margem inteira**.

**Conclusão:** o *site* é barato de operar (ponto de equilíbrio de ~1 peça/mês — ver
§4); **o que inviabiliza não é o custo do site, é a economia unitária do nicho.**

- Como **negócio escalável** só de vidro pequeno: **não fecha.** A oferta de vidro
  de marca subvalorizado é fina demais (1–4 lotes qualificados por semana) e ilíquida.
- Como **operação curada de baixo overhead**, virando poucas peças de marca
  verificadas por mês (Baccarat/Daum/Lalique/Murano assinado pegos cedo e baratos):
  **marginalmente viável** — R$ 100–450 líquidos por peça boa. Mas você usa só uma
  fração dos R$ 5.000, porque a oferta qualificada **não existe** neste volume.

---

## 2. A oferta de junho não absorve R$ 5.000

Pool premium (marca reconhecível, bem conservado, encerra 15–30/jun): **46 lotes**.
Quase todos já com lance **acima** do teto que permite dobrar:

- **Baccarat (15 lotes)** — mediana de lance R$ 700; a maioria já passou do teto viável.
- **Saint-Louis / WMF** — já com lance **acima** da própria âncora de revenda (margem negativa).
- **Cristal lapidado genérico (16 lotes)** — comp ~R$ 120; com lance mediano R$ 110
  já não dobra após logística.
- **Murano (3 lotes)** — lances R$ 20–100; só o mais barato tem folga marginal.

**Quanto dá para alocar com disciplina de lance-teto neste recorte: ~R$ 700–1.000**,
não R$ 5.000. Forçar o orçamento aqui = comprar lotes de margem negativa.

---

## 3. Ordem de compra (com lance-teto — são leilões ao vivo)

Regra de ouro: **respeite o lance-teto.** O preço sobe; acima do teto a peça deixa
de dobrar. P&L assume comprador paga frete de saída; quebra esperada 7%.

### Tier A — comprar (genuíno, dobra com folga)

| # | lote | casa / link | lance atual | **lance-teto** | revenda~ | net esperado | encerra |
|---|---|---|---|---|---|---|---|
| 1 | **Compoteira em cristal Baccarat**, transparente lapidada | rosanavaleleiloes.com.br — [Id 29865875](https://rosanavaleleiloes.com.br/peca.asp?Id=29865875) | R$ 170 | **R$ 256** | ~R$ 677 | **~R$ 290–380** | 16/jun RJ |

Peça única de marca real, estado declarado bom, porte pequeno (envio Correios ok).
É o melhor lote do recorte: a R$ 170 dá 2,7×; mesmo no teto R$ 256 ainda dobra.

### Tier B — verificar a foto e só então dar lance (baixo ticket, volume fino)

Só compre se a foto confirmar estado impecável e a peça for genuinamente bonita.
Net por peça é pequeno (R$ 30–120); é volume, não tacada.

| # | lote | casa / link | lance | **lance-teto** | revenda~ | encerra |
|---|---|---|---|---|---|---|
| 2 | **Jarro em vidro de Murano**, bojo em pêra | bruceangeirasleiloeiro.com.br — [Id 31203683](https://bruceangeirasleiloeiro.com.br/peca.asp?Id=31203683) | R$ 20 | **R$ 30** | ~R$ 204 | 16/jun RJ |

> **Não constam** nesta ordem: lotes "ao gosto Baccarat" / "estilo X" (atribuição
> fraca — valem como vidro genérico, ~R$ 90), Saint-Louis/WMF já acima da âncora,
> e Baccarat de R$ 700+ (sem folga). Todos foram avaliados e reprovados na economia.

**Capital comprometido na ordem: ~R$ 200–290** (lances-teto somados). O restante dos
R$ 5.000 **fica em caixa** — não há oferta de vidro que o justifique neste mês.

---

## 4. Economia unitária e do site

### Stack de custo por peça (vendedor)
| item | R$ | nota |
|---|---|---|
| comissão do comprador | lance × 5% | confirmado (TAXA_LEILOEIRO=5) |
| frete de entrada (casa→você) | ~45 | Correios PAC frágil pequeno |
| embalagem de revenda | ~25 | caixa dupla p/ vidro |
| frete de saída (→cliente) | 30–45 | **normalmente pago pelo comprador** |
| restauro | 0 | só compramos peça limpa |
| perda por quebra (transporte) | ~7% do valor | risco real em vidro |

### Custo de operar o site
| cenário | custo/mês | equilíbrio |
|---|---|---|
| **free tier** — Vercel Hobby + Supabase Free + domínio (~R$ 40/ano) + Pix | **~R$ 10** | < 1 peça-boa/mês |
| **pago** — Vercel Pro ($20) + Supabase Pro ($25) | **~R$ 250** | ~1 peça-boa/mês (net ~R$ 250) |

O site **não** é o gargalo: começa quase de graça e o equilíbrio é trivial. O gargalo
é achar peça-boa em volume.

### P&L de referência (net = revenda×0,93 − custo all-in)
| cenário | lance | all-in | revenda | net esp. | múltiplo |
|---|---|---|---|---|---|
| Baccarat compoteira (no teto) | 256 | 339 | 677 | **+291** | 2,0× |
| Baccarat compoteira (lance atual) | 170 | 248 | 677 | **+381** | 2,7× |
| Murano jarro (no teto) | 30 | 102 | 204 | **+88** | 2,0× |
| cristal lapidado genérico | 110 | 186 | 204 | +4 | 1,1× |
| Saint-Louis taças (lance atual) | 440 | 532 | 272 | **−279** | 0,5× |

---

## 5. Recomendação

1. **Compre o lote 1 (Baccarat compoteira)** com lance-teto R$ 256. É o único do mês
   que dobra com folga e baixa logística.
2. **Lote 2 só se a foto confirmar** estado impecável; é margem fina.
3. **Não force os R$ 5.000 em vidro.** A oferta não existe. Se quer usar o capital
   agora, ele rende muito mais na faixa de **maior spread absoluto** que o relatório
   já mapeia (peças de designer / mobiliário decorativo: Sergio Rodrigues, Lafer,
   mesas laterais), onde o lucro por peça é R$ 1.000–6.000 — ao custo de logística
   maior. Vidro pequeno é bom para *complementar* a vitrine, não para sustentá-la.
4. **Rodar a curadoria semanal** (`pipeline/run_weekly.py`) e pegar Baccarat/Daum/
   Lalique/Murano **assinado** sempre nas primeiras horas do leilão, antes de subir o
   lance — é aí que mora o 2×.

_Premissas em `leiloes-intel/assumptions.yaml`; âncoras de revenda recalculadas a
partir do martelo real de comparáveis vendidos por marca (Baccarat n=768, Murano
n=1846, Lalique n=120, Daum n=30, Saint-Louis n=227)._
