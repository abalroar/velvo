# Plano de Negócios — Cacarecos
### Da casa em Brasília a uma tese de mercado: garimpo, curadoria e dados aplicados ao design brasileiro

> _Documento de trabalho. Reconstrói o racional completo do projeto — motivação pessoal,
> as conversas que mudaram a pergunta, a investigação quantitativa (`leiloes-intel`) e a
> validação externa (caso Antônio) — até a tese de negócio e o produto (`cacarecos-site`,
> ver Anexo A). As referências a conversas com Thaverton e Clara são uma síntese do que
> discutimos; ajuste tom/citações antes de circular externamente._

---

## Sumário executivo

Este projeto nasceu de um problema doméstico — mobiliar uma casa em Brasília sem pagar
preço de antiquário por peça nem comprar móvel novo sem alma — e virou, ao longo de
algumas conversas e de uma investigação de dados, uma tese de negócio: existe um **mercado
de objetos de design e decoração no Brasil que é simultaneamente ilíquido, mal precificado
e mal apresentado**. De um lado, leilões vendem peças de altíssimo valor (móveis de Sergio
Rodrigues, Zalszupin, Tenreiro, Lafer) por uma fração do que valem, porque ninguém está
olhando com método. Do outro, lojas curadas como a **antoniooo.com** vendem objetos
decorativos comuns — vasos, taças, bandejas — por **5 a 8 vezes** o preço de martelo de
itens equivalentes em leilão, sustentadas quase inteiramente por fotografia, nomeação e
apresentação.

A tese do **Cacarecos** é simples: somos a primeira operação a combinar as duas pontas —
**a curadoria/apresentação no nível do Antônio + um motor de precificação construído sobre
1,2 milhão de lotes de leilão reais** (905 mil deles com martelo observado), que nos diz
o que comprar, por quanto, e quanto vale na ponta. Construímos esse motor (`leiloes-intel`)
e ele já aponta **51 oportunidades de compra imediata** com margem conservadora estimada
acima de 40%, incluindo uma carteira-piloto de R$ 30 mil com lucro bruto potencial estimado
de **R$ 128.975 (margem agregada de 81%, ainda a confirmar peça a peça)**.

Este documento conta essa história na ordem em que ela aconteceu — da motivação pessoal,
passando pelas conversas com Thaverton e Clara que deram forma à pergunta, até os números
que validam (ou não) cada parte da tese.

---

## 1. Origem: uma casa em Brasília

O ponto de partida não foi um plano de negócios — foi uma casa vazia. Ao montar a casa em
Brasília, ficou claro rápido que as opções práticas eram ruins: móvel novo de loja é caro
e sem identidade; antiquário de bairro tem peças interessantes a preços arbitrários,
muitas vezes sem nenhuma relação com o que aquilo "deveria" valer; e o caminho mais
honesto — **leilão** — é um universo gigantesco, fragmentado em centenas de casas, sem
nenhuma ferramenta de busca, comparação ou histórico de preços decente.

A primeira constatação foi de consumidor: **dá para mobiliar uma casa inteira com peças
de altíssima qualidade — modernismo brasileiro, design dos anos 50–70, antiguidades — por
uma fração do preço de loja, se alguém tiver paciência para garimpar leilão por leilão**.
A segunda constatação, que levou ao resto deste projeto, foi: **"paciência para garimpar"
é exatamente o tipo de problema que dados resolvem**.

Foi nesse ponto que duas conversas — uma com Thaverton, outra com Clara — transformaram
"vou comprar uns móveis em leilão" em "talvez isso seja um negócio".

---

## 2. Duas conversas que mudaram a pergunta

### 2.1 Thaverton — "isso aqui tem cara de mercado quebrado"

Thaverton é amigo de longa data — nos conhecemos no Itaú BBA, mas a amizade só engrenou
mesmo depois, via Twitter, onde nos seguíamos e trocávamos ideia sobre mercado, alocação e
ineficiências de precificação. Quando contei que estava garimpando leilões para mobiliar a
casa e mostrei alguns exemplos — uma poltrona com assinatura de Sergio Rodrigues saindo por
uma fração do que peças equivalentes alcançam no mercado de revenda — a reação dele foi
imediata e, no fundo, é a pergunta que estrutura este plano inteiro:

> _"Isso não é sobre gostar de móvel antigo. Isso é um book de arbitragem. Se você consegue
> mostrar, com dados, que existe um spread consistente entre o preço de martelo e o preço
> de revenda — e que esse spread varia de forma previsível por categoria, por designer, por
> estado de conservação — você não tem um hobby, você tem uma estratégia. A pergunta não é
> 'qual poltrona é bonita', é 'qual é o tamanho da ineficiência e ela é repetível?'"_

Foi essa provocação — tipicamente de quem passou anos olhando para spreads e
ineficiências de mercado num banco de investimento — que transformou a busca por móveis
em um projeto de **coleta e análise de dados**. Se o mercado de leilões brasileiro é
realmente ineficiente (fragmentado, sem agregador de preços, sem histórico público
acessível), então **construir essa régua de preços é, por si só, a vantagem competitiva**:
quem souber o "preço justo" antes dos outros, ganha.

Essa conversa gerou a pergunta que abre a Seção 4: dado que existem ~850 casas de leilão
no Brasil rodando a mesma plataforma white-label, com históricos públicos, **é possível
raspar isso de forma ética e construir uma base de preços comparáveis em escala?**

### 2.2 Clara — "o objeto certo, contado direito, vale outra coisa"

Clara é designer, com pós-graduação em curadoria de arte, e foi quem trouxe o contraponto
necessário: dados sozinhos não vendem nada. Ao olhar os mesmos achados de leilão que
empolgaram o Thaverton, a reação dela foi sobre a outra ponta da cadeia — o que acontece
**depois** da compra:

> _"Você pode comprar a poltrona certa pelo preço certo e ainda assim não vender, porque
> ninguém vai pagar por uma 'poltrona usada de leilão'. As pessoas pagam por uma peça que
> tem nome, tem história, tem uma foto que parece capa de revista. Olha o Antônio — ele não
> está vendendo objeto, está vendendo um ponto de vista. A curadoria É o produto. Se vocês
> têm os dados para saber o que comprar, falta saber **como apresentar** o que vocês
> compraram."_

Foi a Clara quem trouxe o **antoniooo.com** como referência — uma loja pequena, sem
operação sofisticada por trás (tema de Nuvemshop, fotografia própria, nomes poéticos tipo
"Centro Furta-cor" ou "Vaso Zebrati"), mas que claramente conseguia cobrar múltiplos do
valor "objeto" pelo valor "peça curada". A provocação dela foi: **conseguimos replicar
esse nível de apresentação, mas usando os dados do Thaverton para escolher peças melhores
e precificar com mais confiança do que o Antônio (que, pelo que vimos, precifica no
feeling)?**

Essas duas conversas, juntas, definem os dois eixos do negócio:

| Eixo | Quem trouxe | Pergunta | Resposta deste documento |
|---|---|---|---|
| **Aquisição / preço** | Thaverton | O mercado de leilão é ineficiente de forma mensurável e repetível? | Seção 4 — sim, e construímos a régua (`leiloes-intel`) |
| **Apresentação / venda** | Clara | É possível cobrar múltiplos do preço de aquisição com curadoria/storytelling? | Seção 5 — sim, o Antônio já prova isso na prática |

---

## 3. A pergunta de negócio: Modelo A vs. Modelo B

Com as duas provocações na mesa, ficaram claros dois caminhos possíveis:

- **Modelo A — Casa de leilão/curadoria própria.** Operar como agregador/leiloeiro,
  competindo diretamente com as ~850 casas mapeadas. Exige licença, estrutura jurídica,
  capital de giro muito maior, e relacionamento com consignantes. Tempo de maturação longo.
- **Modelo B — Garimpo + curadoria + revenda direta (estilo Antônio).** Comprar peças
  selecionadas em leilões (papel de **comprador**, não de leiloeiro), restaurar/preparar,
  fotografar e revender com curadoria e storytelling via e-commerce próprio + redes
  sociais. Capital inicial pequeno (testável com R$ 30–50 mil), ciclo de aprendizado
  rápido, e — crucialmente — **é exatamente o modelo que o Antônio já validou no mercado**,
  só que sem a vantagem de dados que temos.

Dado o objetivo (validar rápido, capital inicial modesto, aproveitar uma vantagem de dados
que já temos pronta), **a tese deste plano é o Modelo B**, com uma camada adicional que
nenhum concorrente observado tem: **precificação por comparáveis reais de leilão**, exposta
no produto como um componente de prova de valor ("PriceProof" — ver Seção 7). O Modelo A
não é descartado — é a evolução natural se o Modelo B validar a tese de dados e a operação
crescer a ponto de internalizar o próprio leilão.

---

## 4. A régua: o que construímos (`leiloes-intel`)

Para responder à pergunta do Thaverton — "o spread é mensurável e repetível?" — construímos
um pipeline de coleta e análise contra a LeilõesBR, o maior agregador de leiloeiros do
país, cobrindo páginas públicas de busca, catálogos e históricos de leilões finalizados.

### 4.1 Método (resumo — detalhes no Anexo B)

- **Coleta ética**: apenas páginas públicas, sem login, sem captcha bypass; rate limit por
  domínio; cache em disco; identificação via User-Agent; casas que retornaram 403 foram
  respeitadas e puladas (nunca contornadas).
- **Escala alcançada**: **845 casas de leilão mapeadas**, **1.211.869 lotes coletados**
  (8.582 ao vivo + o restante finalizados), cobrindo a janela de **14/01/2015 a
  10/06/2026** (~11,5 anos de histórico).
- **Preço real, não estimado**: **905.295 lotes têm martelo (preço final de venda)
  observado diretamente na página da casa** — não é proxy, é o preço que alguém de fato
  pagou. Sell-through global: **53,8%** (a outra metade não vende e frequentemente é
  re-ofertada — uma fonte adicional de oportunidade).
- **Classificação determinística (sem LLM)**: cada lote é classificado por tipo de objeto
  (poltrona, mesa de centro, sofá, etc.), material, era, e — o mais importante —
  **atribuição de designer**, com um nível de confiança auditável (de "documentado/com
  etiqueta" até "sem atribuição"). Hoje temos **18.119 lotes com atribuição forte
  (DOCUMENTED/STATED)** a um designer reconhecido — cerca de 1,5% da base, mas é exatamente
  essa "agulha no palheiro" que captura o maior spread.

### 4.2 O que os dados confirmam sobre a tese do Thaverton

**1) Existe um prêmio de designer mensurável.** Peças atribuídas a Sergio Rodrigues (2.464
lotes, mediana de martelo de **R$ 6.000**, n=1.726 vendidas) batem o martelo a **~3x** o
valor de uma poltrona genérica e sem atribuição no mesmo período (mediana **R$ 1.900–2.100**,
n≈2.834–5.780). Esse prêmio se repete para Zalszupin, Tenreiro, Lafer, Scapinelli, Palatnik
— ou seja, **o nome do designer move o preço de forma sistemática**, não é ruído.

**2) Existem categorias de "alto giro, baixa complexidade"** — ideais para uma operação
solo no começo: prata/metal (75.962 lotes ofertados, 69,6% de sell-through, mediana
**R$ 120**), cristal/vidro (46.806, 41,0%, mediana **R$ 85**), porcelana/cerâmica (52.320,
51,1%, mediana **R$ 72**), espelhos, mesas laterais, poltronas individuais. São itens
pequenos, fáceis de transportar e fotografar, com liquidez de compra alta (muita oferta) e,
como veremos na Seção 5, **margem de revenda enorme quando comparados ao preço do Antônio**.

**3) O funil de oportunidades é estreito, mas real.** Dos 1,2 milhão de lotes, o motor de
sinais (regras de margem mínima ≥40% sobre o **p25 conservador** dos comparáveis, mais
exigência de atribuição e checagem de itens "acessório" como almofadas isoladas) classifica:

| Sinal | Quantidade | Significado |
|---|---:|---|
| BUY_NOW | 51 | Margem conservadora ≥40%, atribuição ≥ STATED, baixa competição |
| WATCH | 82 | Margem intermediária ou confiança média — acompanhar |
| AVOID | 8.397 | Margem baixa, "estilo de" caro sem documentação, restauro pesado, ou item acessório |

**4) Uma carteira-piloto de R$ 30 mil já é "comprável" hoje.** O motor monta uma carteira
de **40 peças, capital alocado R$ 29.631**, com **lucro bruto potencial estimado em
R$ 128.975 (margem agregada de 81,3%, calculada de forma conservadora pelo p25 dos
comparáveis)**. Exemplos de cabeça de lista:

- Mesa de centro **Abraham Palatnik**: lance atual R$ 1.100 → revenda estimada
  R$ 46.350 (margem 88,4%)
- Poltrona **Sergio Rodrigues "Cimba"**: lance R$ 260 → revenda estimada R$ 14.819
  (margem 84,3%)
- Par de poltronas **Joaquim Tenreiro**: lance R$ 0 (zero-bid) → revenda estimada
  R$ 31.950 (margem 83,5%)

> **Importante (limite da régua):** os comparáveis agrupam por (tipo de objeto, designer),
> não por modelo/linha específico — uma peça rara do mesmo designer "herda" o comparável de
> peças mais comuns. Por isso, **toda margem alta em lance muito baixo é um candidato a
> verificação manual (peça a peça)**, não uma certeza. O motor serve para **triagem em
> escala** — ele faz o trabalho de olhar 1,2 milhão de lotes que uma pessoa jamais olharia,
> reduzindo o universo a 51+82 candidatos para inspeção humana.

---

## 5. A prova externa: o caso Antônio (antoniooo.com)

A pergunta da Clara — "conseguimos cobrar como o Antônio, com mais dados do que ele?" —
exigiu entender o Antônio de verdade. Fizemos o reverse-engineering completo da loja
(população total, via sitemap: **392 produtos**) e a leitura de tecnologia por trás dela.

### 5.1 O que o Antônio realmente é

- **Plataforma**: Nuvemshop (Tiendanube), tema pago "uyuni" customizado — **não é um site
  sob medida**. CDN `mitiendanube.com`, checkout via Nuvem Pago, parcelamento em 12x.
- **Sistema de design**: uma família tipográfica só (Golos Text), paleta quase
  monocromática (preto/branco dominam, com `#fafafa` e `#ccc` como apoio), grids simples,
  bordas finas. **A sofisticação visual vem de disciplina e fotografia, não de
  engenharia.** Isso é, ao mesmo tempo, uma confirmação da tese da Clara (apresentação é o
  produto) e uma boa notícia para nós: **o nível de UI dele é replicável** com um stack
  moderno (Next.js + Tailwind), e dá para superar.
- **Curadoria por atributo sensorial**: navegação por Cor, Matéria e Tipo — não por
  categoria fria. Nomes próprios para cada peça ("Centro Furta-cor", "Vaso Zebrati"),
  storytelling em vez de SKU.

### 5.2 Os números do Antônio (população completa, 392/392 produtos)

| Métrica | Valor |
|---|---|
| Catálogo total | 392 produtos |
| Esgotados (`OutOfStock`) | 247 (**63,0%**) |
| Em estoque | 145 (37,0%) |
| Ticket médio (catálogo todo) | R$ 904,77 |
| Ticket médio (itens já esgotados) | R$ 791,54 |
| Mediana de preço | R$ 580 (p25 R$ 390 / p75 R$ 980) |
| Faturamento histórico estimado (esgotados × ticket médio) | **~R$ 195.500** (acumulado, não anual — sem dados de data de venda) |

Um sell-through de 63% em um catálogo pequeno, **curado manualmente, sem inteligência de
precificação visível**, é um forte sinal de demanda real para este formato de negócio — e é
exatamente o tipo de validação externa que dá confiança para entrar no Modelo B.

### 5.3 A arbitragem: cruzando Antônio com `leiloes-intel`

O catálogo do Antônio é majoritariamente **decoração pequena** — vasos, ânforas, taças,
arandelas, baldes de gelo, objetos de prata e cristal — exatamente as categorias de "alto
giro, baixa complexidade" da Seção 4.2. Cruzando os preços dele com as medianas de martelo
das categorias equivalentes na nossa base:

| Categoria (leilão) | Mediana de martelo (leilão) | Mediana de preço (Antônio) | Spread aproximado |
|---|---:|---:|---:|
| Prata/metal | R$ 120 | R$ 580 (mediana geral do catálogo) | **~5x** |
| Cristal/vidro | R$ 85 | R$ 580 | **~7x** |
| Porcelana/cerâmica | R$ 72 | R$ 580 | **~8x** |
| Objeto decorativo | R$ 120 | R$ 580 | **~5x** |

Isso **confirma empiricamente a suspeita original do Thaverton** — registrada já no
reverse-engineering inicial ("spread de 3–9x sobre martelo, sem método aparente de
precificação") — e mostra que **mesmo as categorias "menores" (sem designer, sem
atribuição) sustentam spreads de varejo de 5 a 8 vezes** quando bem apresentadas. O Antônio
provavelmente precifica por feeling/comparação com concorrência, não por dados — **é
exatamente a lacuna que o `leiloes-intel` preenche**.

---

## 6. Síntese: a tese de negócio

Juntando as três pernas:

1. **Thaverton (mercado)**: o leilão brasileiro é fragmentado e ineficiente; é possível
   medir o spread de forma sistemática — e já medimos, em 1,2 milhão de lotes.
2. **Clara (produto)**: apresentação/curadoria multiplica valor por 5–8x mesmo em objetos
   comuns — o Antônio prova isso vendendo 63% do catálogo sem nenhuma inteligência de
   dados por trás.
3. **Dados (`leiloes-intel`)**: temos hoje 51 oportunidades de compra com margem
   conservadora ≥40%, mais 82 em observação, extraídas de uma base que nenhum concorrente
   no espaço de decoração/design parece ter.

**A tese do Cacarecos é: ser o Antônio, mas comprando certo.** Mesma disciplina visual,
mesma curadoria por atributo sensorial (cor/matéria/tipo), mesmo storytelling por peça —
mas com **cada aquisição validada contra comparáveis reais de leilão antes de comprar**, e
com uma ficha técnica que nenhum concorrente oferece (proveniência estimada, faixa de valor
de comparáveis, "PriceProof").

O Modelo A (casa de leilão própria) permanece como horizonte de médio prazo: se o Modelo B
validar a tese — sell-through comparável ou superior ao Antônio, ciclo de capital saudável
— a base de dados e o relacionamento com casas de leilão constroem naturalmente a opção de
**internalizar o leilão** (consignação própria, plataforma de descoberta para outros
compradores). Por ora, o caminho de menor capital e maior velocidade de aprendizado é o
Modelo B.

---

## 7. Produto: o site Cacarecos

A especificação técnica completa (reverse-engineering do sistema de design do Antônio,
stack proposto — Next.js + Tailwind + shadcn/ui + Vercel —, arquitetura de informação,
inventário de componentes e tokens de design) está no **Anexo A (`PLAN.md`)**. Os pontos
centrais, em linha com esta tese:

- **Fase 1** é um catálogo institucional estático — mesmo nível visual do Antônio — sem
  checkout, para validar curadoria/apresentação rápido.
- **Diferencial**: o componente **PriceProof**, que expõe — peça a peça — a faixa de
  comparáveis de leilão que sustenta o preço de venda. É a materialização, na UI, da
  vantagem de dados da Seção 4.
- Navegação por **Cor, Matéria e Tipo de Objeto** (eixo sensorial, herdado do Antônio, que
  a Clara identificou como acerto de UX para esse público).
- Ficha técnica rica (proveniência, dimensões, era, estado) — onde a curadoria da Clara se
  expressa em texto/storytelling por peça.

---

## 8. Operação e cadeia de valor

```
SOURCING                 AQUISIÇÃO            PREPARO/CURADORIA        VENDA
(leiloes-intel:          (lance/arremate +    (restauro leve,          (site Cacarecos +
sinais BUY_NOW/WATCH,    buyer premium 5%      fotografia padrão,       redes sociais,
51+82 candidatos,        + frete + restauro)   nome/história da peça    storytelling,
re-scoreado              )                     — papel da Clara)        navegação sensorial)
periodicamente)
```

**Considerações geográficas**: a base mostra forte concentração de casas de leilão e
sell-through em **SP, RJ, RS, PR e MG**; Brasília/DF tem presença pequena no mapa atual.
Operacionalmente isso significa: (a) a aquisição inicial provavelmente acontece "remota"
(arremate online, retirada/transporte terceirizado) nas praças SE/Sul; (b) o frete entra no
custo total de aquisição (já modelado em `assumptions.yaml` por faixa de porte:
pequeno/médio/grande/XL); (c) o e-commerce, por ser nacional, não depende de o estoque
físico estar em Brasília — mas o "showroom"/casa do fundador em Brasília pode funcionar como
vitrine viva e estúdio fotográfico inicial.

**Papéis**:
- **Sourcing e precificação** — motor `leiloes-intel`, re-rodado periodicamente para
  re-scorear o mercado (preços de leilão mudam, novas peças entram).
- **Curadoria, nome, história, fotografia** — papel natural para a Clara, dada a formação
  em curadoria de arte; é o componente que, pela leitura do caso Antônio, **explica a maior
  parte do spread de varejo**.
- **Capital e operação/dados** — papel do fundador, com possível conselho/sparring
  contínuo do Thaverton sobre alocação de capital e leitura do "book" de oportunidades como
  portfólio (diversificação por casa, por UF, por categoria).

---

## 9. Plano financeiro inicial (piloto)

Usando a carteira sugerida pelo motor como cenário-base de piloto:

| Item | Valor |
|---|---:|
| Capital alocado (aquisição, lance) | R$ 29.631 |
| Nº de peças | 40 |
| Custo total estimado (lance × 1,05 buyer premium + frete + restauro) | incluso no modelo |
| Lucro bruto potencial estimado (conservador, p25) | R$ 128.975 |
| Margem agregada estimada | 81,3% |

Leituras importantes:

- Esses números são **estimativas de triagem**, não lucro garantido — cada peça precisa de
  verificação manual de modelo/linha/autenticidade antes do lance (especialmente as de
  designer, onde o comp pode estar "inflado" por peças mais raras do mesmo nome — ver
  ressalva da Seção 4.2).
- O ciclo de capital (tempo entre arremate e venda) ainda não está medido — é a maior
  incógnita do plano e deve ser o primeiro aprendizado do piloto.
- Um segundo cenário de R$ 50 mil mantém a mesma carteira de 40 peças (capital alocado
  igual, R$ 29.631) com folga de caixa para frete/restauro imprevistos e para cobrir o
  hiato entre compra e venda — recomendado para o piloto real.

---

## 10. Riscos e limitações (declarados, não escondidos)

- **Observed vs. inferred**: martelo, lance e status de venda são observados diretamente
  nas páginas das casas. Tipo de objeto, atribuição de designer, custo de restauro, valor
  de revenda e sinal de compra são **inferidos por regras determinísticas** — auditáveis
  (cada inferência grava o trecho de texto que a gerou), mas não são fato.
- **Risco de atribuição**: "documentado" (etiqueta/assinatura) é raro (1,5% da base);
  "atribuído"/"estilo de" carrega risco de autenticidade que só inspeção física resolve.
- **Risco de restauro**: peças "no estado" podem custar muito mais para recuperar do que o
  modelo assume — o tier de restauro (`none/light/heavy`) é estimado por palavra-chave, não
  por vistoria.
- **Risco de liquidez de saída**: o caso Antônio mostra 63% de sell-through em ~392 peças,
  mas não temos visibilidade do tempo médio de venda dele — o nosso pode ser maior até
  construirmos audiência.
- **Concentração geográfica**: oferta concentrada em SE/Sul; fundador em Brasília — custo e
  tempo de logística precisam ser validados no piloto, não só modelados.
- **Ética de coleta**: mantida deliberadamente conservadora (rate limit por domínio, sem
  bypass de bloqueios, sem dados pessoais de arrematantes, exclusão de categorias
  sensíveis). Isso é uma escolha de princípio, não apenas de risco legal — e é parte do
  posicionamento de marca (compra/curadoria responsável).

---

## 11. Roadmap

1. **Validar piloto de aquisição** — escolher 3–5 peças do conjunto BUY_NOW (priorizando
   atribuição DOCUMENTED/STATED e categorias de baixo porte/logística simples: prata,
   cristal, mesas laterais), arrematar, medir custo real (frete + restauro) vs. estimado.
2. **Construir o esqueleto do site (Fase 1 do Anexo A)** — Next.js + Tailwind + tokens,
   Home + `/objetos` + `/objetos/[slug]`, com as 3–5 peças do piloto fotografadas e
   redigidas pela Clara.
3. **Medir ciclo de venda** — tempo entre publicação e venda das peças-piloto; ajustar
   canal (site próprio vs. Instagram vs. ambos).
4. **Re-rodar `leiloes-intel`** periodicamente (o pipeline é resumível/idempotente) para
   manter a régua de preços atualizada e re-scorear novas oportunidades.
5. **Componente PriceProof** — assim que houver confiança na apresentação de comparáveis,
   integrar ao site (Fase 4 do Anexo A).
6. **Decisão Modelo A** — revisitar a opção de casa de leilão própria apenas após o piloto
   validar sell-through e ciclo de capital do Modelo B.

---

## Anexos

- **Anexo A** — Especificação técnica do site (`PLAN.md`, mesma pasta): reverse-engineering
  do sistema de design do Antônio, stack, sitemap, componentes, tokens.
- **Anexo B** — Metodologia completa de coleta e enriquecimento de dados: `leiloes-intel/`
  (`config.py`, `enrich.py`, `metrics.py`, `assumptions.yaml`,
  `data/exports/data_dictionary.md`, `data/exports/market_intelligence_report.md`).
- **Anexo C** — Dados do Antônio: `/tmp/scrape_antonio.py` e `antonio_produtos.csv`
  (reverse-engineering da loja antoniooo.com, 392/392 produtos) — ainda não versionados no
  repositório; candidatos a uma aba "Benchmark/Arbitragem" no dashboard.
