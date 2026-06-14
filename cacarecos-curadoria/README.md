# cacarecos-curadoria

pipeline semanal + mesa de curadoria da velvo. transforma o sqlite grande de
leilões numa fila limpa de candidatos no supabase, e a curadora decide
fica / talvez / passa de qualquer pc, pela url da vercel.

```
cacarecos-curadoria/
  pipeline/
    run_weekly.py     gera a rodada e escreve um seed.sql idempotente
    push_weekly.py    envia a rodada direto ao supabase via api rest
    candidates.py     leitura da fonte + scoring + geração do sql
    weekly.py         orquestração compartilhada pelos dois comandos
    build_sqlite_from_exports.py   helper de dev (reconstrói o sqlite do export)
  supabase/
    schema.sql        curation_candidates, curator_decisions, view curation_feed
    seed_weekly.sql   a rodada gerada (entregável, versionado)
    README.md         setup + queries
  web/                next.js (/studio) para a vercel
```

## como funciona a operação semanal

1. `run_weekly.py` lê os lotes **ao vivo** do `leiloes.sqlite` (status andamento,
   sem categorias sensíveis), pontua cada um e escolhe os melhores 600.
2. cada rodada recebe um `batch_id` (semana iso, ex. `2026-w24`) e um
   `refreshed_at`. o seed é **idempotente**: re-rodar não duplica nada.
3. o seed faz upsert em `curation_candidates` e **nunca** toca em
   `curator_decisions`. candidatos de semanas anteriores que não voltam viram
   `archived` (saem da feed, ficam no histórico).
4. a view `curation_feed` mostra **só a rodada mais recente**, só `queued`,
   **excluindo os já decididos**, ordenada por `score desc, headroom desc`.
5. a curadora abre `/studio` na vercel e decide. cada decisão vai para o
   supabase por uma api route server-side e some da fila.

### o que é cada campo do score

- **score** (0–100): blend de vibe (murano/cristal/vidro/luminária/objeto
  decorativo/prata/porcelana/escultura), acesso (preço de entrada trabalhável),
  upside econômico (margem/folga vinda do leiloes-intel) e liveness (encerra em
  breve, algum interesse). ordena a fila.
- **priority**: alta / media / baixa, por faixa de score (com piso para buy_now).
- **risk**: baixo / medio / alto. flags em `payload.risk_reasons`
  (estado/restauro, atribuição fraca, margem apertada, parte elétrica, etc.).
- **headroom** (folga): `max_bid_40pct - lance atual`. positivo = ainda há
  espaço para dar lance mantendo ~40% de margem.

---

## entrega — as 7 respostas

### 1. onde está o script semanal
`cacarecos-curadoria/pipeline/run_weekly.py` (gera o seed) e
`cacarecos-curadoria/pipeline/push_weekly.py` (envia direto ao supabase).

### 2. onde está o seed.sql
`cacarecos-curadoria/supabase/seed_weekly.sql` (a rodada).
o schema fica em `cacarecos-curadoria/supabase/schema.sql`.

### 3. quantos candidatos entraram na rodada
**600 candidatos** no `batch_id 2026-w24` — todos com foto (cloudfront), link do
lote, casa, preço, lances e encerramento. recorte da rodada:

- 555 são da vibe decorativa (cristal/vidro/luminária/prata/porcelana/escultura).
- 34 são oportunidades econômicas buy_now.
- prioridade: alta 48 · media 383 · baixa 169.
- risco: baixo 39 · medio 516 · alto 45.

vieram de **8.420 lotes ao vivo** lidos (4.374 elegíveis depois dos filtros;
ficaram os 600 de maior score).

### 4. quais comandos rodo toda semana
na máquina onde está o sqlite grande:

```bash
cd cacarecos-curadoria
pip install -r pipeline/requirements.txt   # uma vez

# a) gerar o seed.sql e colar no supabase
python pipeline/run_weekly.py \
  --db /home/user/baratex/leiloes-intel/data/leiloes.sqlite \
  --out supabase/seed_weekly.sql

# b) OU enviar direto ao supabase (sem copiar/colar)
SUPABASE_URL=https://xxxx.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=eyJ... \
python pipeline/push_weekly.py \
  --db /home/user/baratex/leiloes-intel/data/leiloes.sqlite
```

sem o sqlite por perto, os dois comandos caem automaticamente no export
`leiloes-intel/data/exports/lots.parquet` + thumbnails do cache http — mesmo
resultado, então rodam igual em qualquer clone limpo.

`--limit` muda o tamanho da rodada (default 600). `--batch` força um `batch_id`.

### 5. quais envs coloco na vercel
project settings → environment variables (nenhuma com `NEXT_PUBLIC`):

| nome | valor |
|---|---|
| `SUPABASE_URL` | `https://xxxx.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | a service role (secreta, server-side) |
| `STUDIO_ACCESS_CODE` | opcional: senha p/ trancar /studio |

a service role **não** vai pro browser — só as api routes a usam.

### 6. quais queries rodo no supabase
ver `supabase/README.md`. as principais:

```sql
-- a fila que a curadora vê (deve bater com /studio)
select title, price_label, priority, risk, score, headroom
from curation_feed limit 50;

-- contagem por status na rodada
select batch_id, status, count(*) from curation_candidates
group by batch_id, status order by batch_id desc;

-- lista de compra (os "fica")
select c.title, c.price_label, c.source_house, c.source_url, d.note
from curator_decisions d join curation_candidates c using (candidate_id)
where d.decision = 'fica' order by d.decided_at desc;
```

### 7. como confirmar que a curadora em outro pc vê a fila real
1. rode o schema e carregue o seed (passos 1–4).
2. confira no supabase: `select count(*) from curation_feed;` deve dar 600.
3. abra `https://seu-app.vercel.app/studio` em **outro** pc/celular (rede
   diferente). a primeira peça deve ser a mesma do topo de `curation_feed`
   (maior score), com a foto cloudfront e o botão "ver lote na casa".
4. clique **passa** numa peça e rode de novo `select count(*) from
   curation_feed;` — deve cair para 599, e a peça decidida aparece em
   `select * from curator_decisions;`. isso prova que a decisão foi para o
   supabase (server-side), não para o navegador.
5. recarregue o /studio no outro pc: a peça decidida não volta.

> nota sobre os dados: o `leiloes.sqlite` cheio (~920mb) é regenerável e fica
> fora do git. neste ambiente ele foi reconstruído a partir do
> `lots.parquet` + cache http (com `build_sqlite_from_exports.py`), o que
> recuperou 100% das imagens dos lotes ao vivo. na sua máquina, com o sqlite
> real, o comando do passo 4 funciona direto.

---

## relação com o sitezinhoi (codex)

o sitezinhoi/velvo é a referência visual/produto e vive na sua máquina. o
`web/` aqui é a mesma mesa conectada ao banco real — serve para você verificar a
operação ponta a ponta hoje. os dois falam o mesmo contrato: a view
`curation_feed` e o `POST /api/curator/decisions`. para apontar o sitezinhoi
para a fila real, basta ele ler `curation_feed` e postar decisões nesse formato,
com as mesmas envs server-side.
