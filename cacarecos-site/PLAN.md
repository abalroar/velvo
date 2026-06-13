# Plano — Site curado estilo Antônio (projeto "cacarecos")

_Etapa de planejamento. Reverse-engineering do antoniooo.com + arquitetura para
construir do zero um site com UI impecável no mesmo espírito, mas com a nossa
vantagem de dados de mercado._

---

## 1. Reverse-engineering do antoniooo.com (baseado no código real do site)

### Stack atual dele (o que descobri inspecionando o HTML/CSS)
- **Plataforma:** Nuvemshop (Tiendanube) — não é código próprio. CDN `mitiendanube.com`.
- **Tema:** `uyuni` (tema pago da Nuvemshop), customizado.
- **Pagamento/checkout:** Nuvem Pago, parcelamento 12x, frete grátis.
- **Conclusão:** o que parece "site sob medida lindo" é, na verdade, **um bom tema + curadoria de fotos + disciplina visual**. Isso é libertador: o nível de UI dele é alcançável, e dá para **superar** com um site próprio.

### Sistema de design extraído (tokens reais)
| Token | Valor real no site |
|---|---|
| Tipografia | **Golos Text** (Google Fonts), pesos 400 e 700 — única família, títulos e corpo |
| Tamanho base | 14px (corpo), 10–12px (legendas/preço), 18–24px (títulos) |
| Paleta | **#000 e #fff dominam** (204×/97×); `#fafafa` (seções), `#ccc` (linhas finas) |
| Cor de acento | quase ausente — só ícones sociais/estados. **A cor vem das fotos dos objetos.** |
| Grid | gutter de 15px, container fluido, cards em carrossel/grade |
| Bordas | 1px solid/dashed, raio mínimo → estética **editorial, recortada, sem "cara de template"** |

### Por que o site dele transmite sofisticação (minhas conclusões)
1. **Monocromia radical.** A UI é preto-no-branco; toda a cor é das peças. Isso faz cada objeto "saltar" como numa galeria.
2. **Uma fonte só, bem espaçada.** Sem ruído tipográfico. Golos Text é neutra, contemporânea, levemente humanista.
3. **Foto é o produto.** Fundo branco/neutro consistente, enquadramento padronizado, sombra suave. **80% da percepção de qualidade está na foto, não no código.**
4. **Nomes como curadoria.** "Centro Furta-cor", "Vaso Zebrati", "Botija Asa Puente" — cada peça tem nome próprio e história. É storytelling, não SKU.
5. **Navegação por atributo sensorial** — por **Cor, Matéria e Tipo de Objeto**, não por categoria fria. Combina com a forma como decorador/colecionador pensa.
6. **Escassez honesta.** Peça única → "Esgotado" fica visível. Cria urgência real e prova de demanda.

### Principais suspeitas (a confirmar, mas prováveis)
- Catálogo girado **manualmente** (sem automação de sourcing) — gargalo dele, oportunidade nossa.
- Fotografia provavelmente própria/padronizada (lightbox, fundo neutro) — é o maior custo operacional invisível.
- Sem inteligência de precificação: preços parecem definidos por feeling (spread de 3–9× sobre martelo, sem método aparente). **Aqui mora nossa vantagem.**

---

## 2. A tese do nosso site (o que nos diferencia)

O Antônio é lindo, mas é "só" uma loja. Nós temos **905 mil preços de martelo reais**. O nosso site pode ser **a vitrine do Antônio + um cérebro de precificação/sourcing por trás**:
- Cada peça precificada com base em comparáveis reais (não no feeling).
- Sourcing alimentado pela base de leilões (sabemos onde comprar barato).
- Opcional: uma camada "pública" (loja bonita) e uma "interna" (painel de arbitragem que já construímos).

Em UI, a meta é **igualar o Antônio e superar em três pontos**: performance (site estático rápido), ficha técnica rica (proveniência, dimensões, era) e prova de valor ("peça similar batível em leilão a R$X").

---

## 3. Stack proposta (build do zero)

| Camada | Escolha | Porquê |
|---|---|---|
| Framework | **Next.js (App Router) + React + TypeScript** | SSR/SSG, SEO, Vercel 1-clique; padrão de e-commerce moderno |
| Estilo | **Tailwind CSS** + tokens próprios | replica o sistema do Antônio com precisão e disciplina |
| UI kit | **shadcn/ui** (Radix) | componentes acessíveis, headless, estilizáveis ao nosso gosto |
| Tipografia | **Golos Text** ou alternativa premium (ver §6) | mesma pegada |
| Imagens | `next/image` + CDN (Cloudinary/Vercel) | foto é o produto: precisa de zoom, lazy, formatos modernos |
| Dados/catálogo | **Markdown/JSON no início** → depois headless CMS (Sanity) ou Postgres | começa simples, versionável |
| Carrinho/checkout | **Fase 2:** Shopify Hydrogen headless OU Stripe + Nuvem Pago | não reinventar pagamento |
| Deploy | **Vercel** | estático/edge, rápido, grátis para começar |
| Análise interna | reusar o pipeline `leiloes-intel` como API de precificação | conecta as duas metades |

**Decisão-chave:** Fase 1 é um **catálogo institucional estático** (sem checkout) — entrega UI impecável rápido. Checkout entra na Fase 2, headless, sem nos prender a tema.

---

## 4. Arquitetura de informação (sitemap)

```
/                      Home — hero editorial + Novidades + Categorias + Coleções
/objetos               Grade completa, com filtros (Cor · Matéria · Tipo · Preço · Era)
/objetos/[slug]        Página da peça — galeria, ficha técnica, história, similares
/colecoes              Curadorias temáticas (ex.: "Murano dos anos 60")
/colecoes/[slug]       Coleção
/sobre                 Manifesto/curadoria
/contato
(interno) /studio      Painel de arbitragem/precificação (nosso dashboard, protegido)
```
Filtros por **Cor/Matéria/Tipo** (como o Antônio) — eixo sensorial, não categórico.

---

## 5. Inventário de componentes (o que construir)

- **Nav** minimalista (logo wordmark + menu por atributo + busca + carrinho)
- **ProductCard** — foto dominante, nome, preço, badge "Esgotado", hover sutil
- **ProductGrid** — masonry/grid responsivo, gutter 16px
- **Gallery** — zoom/lightbox (foto é tudo)
- **SpecSheet** — ficha: matéria, dimensões, era, proveniência, estado
- **PriceProof** _(nosso diferencial)_ — "comparáveis em leilão: R$X–Y"
- **CollectionStrip**, **Filters** (facetas), **Footer**, **EmptyState/SoldOut**

---

## 6. Tokens de design (ponto de partida, espelhando o Antônio)

```
cores:   tinta #0a0a0a · papel #ffffff · névoa #fafafa · linha #e5e5e5 · esgotado #999
fontes:  display/corpo "Golos Text" (ou Söhne/Suisse como upgrade premium)
escala:  12 / 14 / 16 / 20 / 28 / 40 px
grid:    gutter 16px · container 1280px · cards 2-3-4 col (mobile/tablet/desktop)
raio:    0–4px (editorial, recortado)
sombra:  quase nenhuma; profundidade via espaço em branco
motion:  fade/scale 150–250ms; hover de imagem discreto
```
Regra de ouro herdada do Antônio: **a UI é preto-e-branco; a cor é das peças.**

---

## 7. Fases de execução

1. **Fundação** — Next.js + Tailwind + tokens + Golos Text; layout base e Nav/Footer. Deploy vazio na Vercel.
2. **Catálogo estático** — modelar peça (JSON/MD); Home + /objetos + /objetos/[slug] com dados de exemplo (podemos semear com os do Antônio só para layout, ou peças nossas). Filtros por atributo.
3. **Polimento de UI** — galeria/zoom, responsivo, microinterações, estados (esgotado, vazio), performance (Lighthouse 95+).
4. **Diferencial de dados** — componente PriceProof puxando comparáveis da base `leiloes-intel`; opcional /studio interno.
5. **Comércio (opcional)** — checkout headless (Stripe/Nuvem Pago/Shopify), estoque, e-mails.

Fase 1–3 entregam um site **visualmente no nível do Antônio**. Fase 4 é onde passamos ele.

---

## 8. Riscos e decisões em aberto (para você decidir)
- **Comprar vs. construir:** se o objetivo é *vender já*, um tema Nuvemshop/Shopify entrega 80% do visual em dias. Construir do zero só compensa pelo **diferencial de dados** e controle total de UI. (Recomendo construir, dado seu objetivo de produto.)
- **Fonte:** Golos Text (grátis, idêntica ao dele) vs. uma fonte premium (Söhne/Suisse) para destacar. 
- **Fotografia:** é o maior fator de qualidade e o nosso maior custo/dependência. Definir padrão (fundo, luz, enquadramento) antes de escalar.
- **Conteúdo inicial:** começamos com peças reais nossas ou mockup? Define o ritmo da Fase 2.

---

## 9. Próximo passo sugerido
Montar o esqueleto da **Fase 1** (Next.js + Tailwind + tokens + Home com 6–8 peças mock no visual exato) e subir na Vercel — um protótipo navegável para validar o look antes de investir em catálogo/checkout.
