-- Esquema do painel de curadoria (Supabase / Postgres).
-- Rode isto no SQL Editor do seu projeto Supabase uma vez.

-- 1) Fila de candidatos (escrita pelo pipeline com a service key; lida pelo site).
create table if not exists candidates (
  candidate_id        text primary key,         -- "<casa>|<lote>"
  house_domain        text,
  lot_id              text,
  title               text,
  thumbnail_url       text,
  lot_url             text,
  uf                  text,
  item_type           text,
  size_class          text,
  material            text,
  period_hint         text,
  condition_tier      text,
  is_pair_or_set      boolean,
  designer            text,
  attribution_strength text,
  auction_datetime    text,
  current_bid_brl     numeric,
  bid_count           integer,
  comp_median         numeric,
  retail_anchor       numeric,
  est_allin_cost      numeric,
  est_margin_pct      numeric,
  max_bid_brl         numeric,
  antonio_fit_visual  numeric,
  suggested_name      text,
  score               numeric,
  refreshed_at        timestamptz default now()
);
create index if not exists candidates_score_idx on candidates (score desc);

-- 2) Decisões da curadora (Fica / Passa / Talvez + nota).
create table if not exists decisions (
  id            bigint generated always as identity primary key,
  candidate_id  text not null references candidates(candidate_id) on delete cascade,
  verdict       text not null check (verdict in ('keep','pass','maybe')),
  note          text,
  decided_by    text default 'curadora',
  decided_at    timestamptz default now()
);
-- uma decisão por candidato (a última vence): upsert por candidate_id
create unique index if not exists decisions_candidate_uniq on decisions (candidate_id);

-- 3) Feed da curadora: candidatos ainda não decididos, melhores primeiro.
create or replace view curation_feed as
  select c.*
  from candidates c
  left join decisions d on d.candidate_id = c.candidate_id
  where d.candidate_id is null
  order by c.score desc;

-- 4) RLS: o site usa a anon key. Leitura da fila/feed liberada; gravar decisão liberada.
alter table candidates enable row level security;
alter table decisions  enable row level security;

drop policy if exists candidates_read on candidates;
create policy candidates_read on candidates for select using (true);

drop policy if exists decisions_read on decisions;
create policy decisions_read on decisions for select using (true);

drop policy if exists decisions_write on decisions;
create policy decisions_write on decisions for insert with check (true);

drop policy if exists decisions_update on decisions;
create policy decisions_update on decisions for update using (true) with check (true);

-- Observação: o pipeline grava em `candidates` com a SERVICE ROLE key, que ignora RLS.
-- A anon key (usada no site) só lê candidatos e grava decisões — não altera a fila.
