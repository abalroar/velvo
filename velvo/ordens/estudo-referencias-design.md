# Estudo de referências — curadoria de móveis e objetos vintage (Noruega · Suécia · Espanha)

_Base para o redesign do velvo. Objetivo: distanciar a marca em tipografia, design
e menu de filtros (material/tamanho/preço) na experiência do cliente final.
Pesquisa em 16/06/2026._

---

## 1. As referências, por país

### Suécia — o padrão-ouro da galeria
- **Modernity** (Estocolmo/Londres, [modernity.se](https://www.modernity.se/)) — aberta em 1998 por
  Andrew Duncanson. Vende vidro, cerâmica, iluminação e mobiliário nórdico do séc. XX
  para colecionadores e museus (MoMA, LACMA, Cooper Hewitt). Site já eleito "Best of
  the Web" pela Forbes. **Linguagem:** museu — branco quase total, fotografia grande
  sobre fundo neutro, legenda curta (designer · peça · ano · material), serifa
  refinada, zero ruído de "promoção".
- **Jackson Design** (Estocolmo, [jacksons.se](https://www.jacksons.se/)) — desde 1981, um dos maiores
  acervos de design escandinavo e internacional do séc. XX. Mesma gramática de galeria:
  grade sóbria, ficha técnica enxuta, autoridade pela contenção.

### Noruega — o curador-autor
- **Fuglen** (Oslo/Tóquio, vende via [Pamono](https://www.pamono.com/dealers/fuglen)) — galeria + café +
  bar desde 1963. Foco em mobiliário e **objetos** nórdicos mid-century com viés
  japonês. Lição: a **assinatura do curador** é o produto; a vitrine é editorial,
  não um depósito.
- **Capsule** (nórdico online) — importa peças da Dinamarca, Suécia, Finlândia e
  Noruega; mostra como organizar um acervo pulverizado por **coleção** e proveniência.

### Espanha — o vintage escandinavo "handpicked"
- **Noak Room** (Barcelona, Poblenou, [noakroom.com](https://www.noakroom.com/)) — desde 2014, Martin
  Noaksson e Sara Salas. Cada peça dos anos 50/60/70, **escolhida a dedo**, importada
  da Escandinávia. Lição: narrativa de garimpo + estado impecável + foto limpa =
  preço premium num mercado quente.

### Marketplaces — a gramática de filtros (material/tamanho/preço)
- **Pamono** ([pamono.com](https://www.pamono.com/)) — **sidebar com facetas** expansíveis: preço, estilo,
  época, país, **cor, dimensões, material**, designer/fabricante. É o mapa exato do
  menu que você pediu.
- **Selency** ([selency.fr](https://www.selency.fr/)) — categorias hierárquicas + facetas de **cor**
  (`colorFacet`) e material, grade orientada à imagem, preço (e desconto) abaixo do card.
- **Vinterior** ([vinterior.co](https://www.vinterior.co/)) — marketplace de vintage com forte filtro e
  selo de sustentabilidade.

---

## 2. O que esses negócios têm em comum (e que vira regra de design)

1. **Fotografia é o produto.** Fundo neutro, peça centrada, luz que revela material.
   Tudo no layout serve a isso (muito branco, pouca interface).
2. **Legenda de museu, não de e-commerce.** Título curto, material, época, dimensão,
   preço. Sem "compre já", sem badge gritando.
3. **Serifa para autoridade, grotesca para função.** Display serifado (clima de
   catálogo de leilão/galeria) + sans neutra para navegação e dados.
4. **Paleta quente e silenciosa.** Off-white, cinzas quentes, tinta quase preta, um
   acento sóbrio. Nada satura — a cor vem das peças.
5. **Facetas claras e numeradas.** Material, dimensão/tamanho, preço, cor, época —
   com contagem por opção. O usuário "compõe" o recorte.
6. **A curadoria é a marca.** O nome do curador / o critério de seleção aparece. Poucas
   peças, bem editadas, valem mais que catálogo infinito.

---

## 3. Como isso foi aplicado no velvo (o que mudou)

| dimensão | antes | agora |
|---|---|---|
| **tipografia** | system-ui (genérica) | **Fraunces** (serifa editorial, alto contraste) nos títulos/wordmark + **Inter** na interface |
| **paleta** | branco neutro | off-white quente de galeria (#f4f1ea), tinta #1b1813, acento oliva-tabaco discreto |
| **layout** | mesa estreita única | **vitrine larga** (1240px) com hero editorial + grade de produtos 3 colunas, fotografia em retrato 4:5 |
| **menu de filtros** | inexistente | **rail de facetas**: material · tamanho · preço · época, com contagem por opção, chips de filtro ativo e "limpar tudo" |
| **cards** | card arredondado de leilão | moldura de galeria, título serifado, legenda-museu (material · tamanho · uf) e **preço de vitrine**; selo "curadoria" nas aprovadas |
| **navegação** | só /studio | **/** (manifesto) · **/vitrine** (cliente) · **/studio** (curadoria interna) |
| **caixa baixa** | mantida | mantida como assinatura — agora com serifa, fica sofisticada em vez de "tech" |

### Os filtros, em detalhe (o que você pediu)
- **material**: cristal & vidro · murano · bronze · porcelana & cerâmica · prata & metal
  (derivado da marca/segmento de cada peça).
- **tamanho**: pequeno · médio · grande (inferido das dimensões no título; cai no porte
  de frete — pequeno = Correios, grande = transportadora).
- **preço**: até R$ 800 · R$ 800–1.500 · R$ 1.500–2.500 · R$ 2.500+ (preço de **vitrine**
  = varejo curado, na faixa do antonio R$ 520–3.400).
- **época**: anos 50 · 60 · 70 · art déco · art nouveau (quando o título sinaliza).

Cada faceta soma (multi-seleção), mostra contagem e vira chip removível na barra de
resultados, com ordenação por curadoria / preço.

---

## 4. Próximos passos sugeridos (para fechar o nível das referências)

1. **Fotografia própria** das peças arrematadas (fundo neutro, mesma luz) — hoje a
   vitrine usa a foto da casa de leilão; trocar por foto velvo é o maior salto de marca.
2. **Página de peça** (não só link pro leilão): ficha de museu (material, dimensões,
   época, estado, proveniência) + galeria de ângulos.
3. **Coleções editoriais** (ex.: "vidro soprado", "bronze escultórico", "mesa posta")
   — como Modernity/Fuglen organizam por narrativa, não só por categoria.
4. **Cor como faceta** (Pamono/Selency) quando houver foto própria com fundo controlado.
5. **História do curador** numa página "sobre" — a autoridade de Noak Room/Modernity
   vem de quem escolhe.

_Referências citadas: Modernity (modernity.se), Jackson Design (jacksons.se), Fuglen
(via Pamono), Capsule, Noak Room (noakroom.com), Pamono (pamono.com), Selency
(selency.fr), Vinterior (vinterior.co)._
