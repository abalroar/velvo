# supabase — curadoria velvo

duas tabelas e uma view. tudo server-side: a curadora nunca fala direto com o
supabase, sempre pelas api routes da vercel.

## setup (uma vez)

1. crie um projeto no supabase.
2. no sql editor, rode `schema.sql` inteiro. cria:
   - `curation_candidates` — a fila semanal.
   - `curator_decisions` — fica / talvez / passa + nota.
   - `curation_feed` — view: rodada mais recente, só queued, sem os já
     decididos, ordenada por `score desc, headroom desc`.
   - rls ligado, sem policies para anon → ninguém lê/escreve com a anon key.
     a service role ignora rls e é usada só no servidor.

## carga semanal

duas formas (escolha uma):

- **seed.sql**: rode `pipeline/run_weekly.py` para gerar `seed_weekly.sql` e
  cole no sql editor (ou `psql`). idempotente.
- **push direto**: `pipeline/push_weekly.py` com as envs do supabase faz upsert
  via api rest, sem copiar/colar.

a carga é idempotente: re-rodar não duplica candidatos e nunca apaga
`curator_decisions`. candidatos de rodadas anteriores que não voltam viram
`status = 'archived'` (saem da feed, ficam no histórico).

## queries do dia a dia

```sql
-- a fila que a curadora vê (deve bater com /studio)
select candidate_id, title, price_label, priority, risk, score, headroom
from curation_feed
limit 50;

-- quantos candidatos na rodada mais recente, por status
select batch_id, status, count(*)
from curation_candidates
group by batch_id, status
order by batch_id desc, status;

-- decisões da semana
select d.decided_at, d.decision, d.decided_by, c.title, c.source_url
from curator_decisions d
join curation_candidates c using (candidate_id)
order by d.decided_at desc;

-- só os "fica" (lista de compra)
select c.title, c.price_label, c.source_house, c.source_url, d.note
from curator_decisions d
join curation_candidates c using (candidate_id)
where d.decision = 'fica'
order by d.decided_at desc;

-- progresso: decididos x pendentes na rodada atual
select
  (select count(*) from curation_feed) as pendentes,
  (select count(*) from curator_decisions) as decididos_total;
```

## reverter uma decisão

```sql
delete from curator_decisions where candidate_id = 'casa-123';
-- volta para a feed se ainda for da rodada mais recente e estiver queued
```
