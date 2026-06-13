# Cacarecos · Curadoria

Painel interno que **roda sozinho** e entrega à curadora uma fila de peças de
leilão **pré-selecionadas por critérios objetivos** — ela só faz a curadoria
humana (narrativa, gosto), tipo Tinder: vê uma peça por vez e decide
**Fica / Passa / Talvez**. Zero chat.

```
leiloes-intel (banco de leilões)                  Supabase (Postgres)
        │                                          ┌── candidates (fila)
        ▼   funil objetivo (pipeline/)             │
  estágio 0  filtro SQL: categoria-alvo, porte, foto, não-sensível
  economia   comp de leilão × markup → margem; cortes de margem/lance
  estágio 1  similaridade visual c/ o acervo do Antônio (CLIP, opcional)
  score      margem + fit visual + prazo  ──upsert──▶ candidates
        ▲                                          └── decisions (Fica/Passa/Talvez)
   cron (GitHub Actions, a cada 4h)                         ▲
                                                            │
                                          web/ (Next.js, Vercel) — o "Tinder"
```

A curadora **nunca** vê o funil; ela consome `curation_feed` (candidatos ainda
não decididos, melhores primeiro) e suas escolhas vão para `decisions`.

## Estrutura

```
pipeline/        Motor Python (roda no cron). Não depende de chat nem de IA generativa.
  config.py            critérios objetivos (categorias, margem, frete, pesos do score)
  stage0_filter.py     pré-filtro SQL sobre lotes AO VIVO do leiloes-intel
  economics.py         revenda estimada, margem, lance máx; cortes
  stage1_embed.py      similaridade visual com o Antônio (open_clip, opcional)
  run_pipeline.py      orquestra → grava no Supabase + JSON local
  comp_medians.json    medianas de martelo por categoria (geradas do banco)
  antonio_images.txt   392 fotos do acervo do Antônio = "régua de gosto" do estágio 1
supabase/schema.sql    tabelas candidates/decisions + view curation_feed + RLS
web/                   Site Next.js (Vercel): swipe estilo Tinder
.github/workflows/curadoria.yml   cron que renova a fila
```
> O `.yml` do cron fica na **raiz do repo** (`baratex/.github/workflows/`), não aqui.

## Critérios objetivos (o que garante que ela só vê peça com potencial)

Tudo em `pipeline/config.py`:

- **Categoria-alvo**: só o que o Antônio vende (cristal/vidro, porcelana, prata,
  objeto decorativo, escultura, luminária, espelho, mesas de apoio, arte). O resto
  nunca chega à fila.
- **Porte**: small/medium (logística simples).
- **Foto + não-sensível**: sem imagem ou categoria sensível → fora.
- **Margem ≥ 45%** sobre revenda conservadora (comp de leilão × 2,5, com piso por
  porte), e **lance atual ≤ 50% da revenda**. Sem potencial de revenda → fora.
- **Score** = margem (0,5) + fit visual (0,35) + prazo do leilão (0,15).
  Sem o estágio 1, o peso visual vai para a margem.

Resultado real da última rodada: **8,5k lotes ao vivo → 5,9k na categoria/porte →
2,3k passam nos cortes → top 600 na fila**, margens 63–82%.

## Setup (uma vez)

### 1. Supabase
1. Crie um projeto em supabase.com (free tier).
2. SQL Editor → cole e rode `supabase/schema.sql`.
3. Pegue em Settings → API: `Project URL`, a `anon` key (site) e a `service_role` key (pipeline).

### 2. Popular a fila pela primeira vez
Onde você tem o `leiloes.sqlite` (este ambiente / seu Mac):
```bash
cd pipeline
python run_pipeline.py --db ../../leiloes-intel/data/leiloes.sqlite --no-visual --seed-only
SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python push_seed.py
```
(ou direto: `SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python run_pipeline.py --db ... --no-visual`)

### 3. Site (Vercel)
```bash
cd web && npm install && npm run dev   # local
```
`.env.local` (e variáveis no Vercel):
```
NEXT_PUBLIC_SUPABASE_URL=https://SEU-PROJETO.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
```
Deploy: importe `cacarecos-curadoria/web` na Vercel, configure as duas env vars, deploy.

### 4. Automação (rodar sozinho)
No GitHub: Settings → Secrets → Actions: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`
(a **service** key). O workflow `curadoria.yml` renova a fila a cada 4h.
Rode a primeira vez manualmente (Actions → Run workflow) para validar.

## Estágio 1 (similaridade visual) — quando ligar

Por enquanto o funil entrega estágios 0 + economia (objetivo, sem IA pesada).
Para ligar o ranqueamento visual pelo acervo do Antônio:
```bash
pip install -r pipeline/requirements-visual.txt        # torch + open_clip
python run_pipeline.py --db ...                        # sem --no-visual
```
ou dispare o workflow com a opção **visual = true**. Ele computa o embedding das
392 fotos do Antônio (`antonio_images.txt`) e ranqueia cada candidato pela peça
mais parecida — derrubando, por exemplo, gravuras genéricas em favor de objetos
com a cara do acervo.

## Próximo (estágio 2, futuro)

Rerank curatorial com Claude (lê a foto, pontua estado/estilo e sugere nome
poético). A coluna `suggested_name` e o gancho já existem; é plugar a chave.
