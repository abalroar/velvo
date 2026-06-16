-- schema da curadoria velvo no supabase/postgres.
-- idempotente: pode rodar de novo sem perder dados.
-- tudo em caixa baixa nos valores de texto controlados pela aplicação.

-- ---------------------------------------------------------------------------
-- candidatos da rodada semanal
-- ---------------------------------------------------------------------------
create table if not exists curation_candidates (
  candidate_id  text primary key,            -- chave estável por lote (house-lotid)
  product_slug  text not null,               -- mesmo valor; compat com o front
  batch_id      text not null,               -- rodada semanal, ex: 2026-w24
  title         text not null,
  price_brl     numeric,                     -- lance atual / inicial em reais
  price_label   text,                        -- rótulo pronto, ex: "lance atual r$ 1.100"
  source_house  text,                        -- casa de leilão
  source_url    text,                        -- link do lote
  image_url     text,                        -- foto (cloudfront)
  auction_ends  timestamptz,                 -- encerramento
  score         numeric,                     -- 0..100, ordena a fila
  priority      text,                         -- alta / media / baixa
  risk          text,                         -- baixo / medio / alto
  headroom      numeric,                     -- folga: max_bid_40pct - lance atual
  bid_count     integer default 0,
  status        text not null default 'queued'
                check (status in ('queued','hidden','archived','unavailable')),
  payload       jsonb not null default '{}'::jsonb,  -- reconstrói o candidato no front
  refreshed_at  timestamptz not null default now(),  -- carimbo da rodada
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists idx_candidates_feed
  on curation_candidates (batch_id, status, score desc, headroom desc);
create index if not exists idx_candidates_refreshed
  on curation_candidates (refreshed_at desc);

-- ---------------------------------------------------------------------------
-- decisões da curadora (persistem entre rodadas; nunca apagadas pelo seed)
-- ---------------------------------------------------------------------------
create table if not exists curator_decisions (
  candidate_id  text primary key
                references curation_candidates(candidate_id) on update cascade,
  decision      text not null check (decision in ('fica','talvez','passa')),
  note          text,
  decided_by    text,
  decided_at    timestamptz not null default now()
);

create index if not exists idx_decisions_decided_at
  on curator_decisions (decided_at desc);

-- mantém updated_at em dia
create or replace function touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_candidates_touch on curation_candidates;
create trigger trg_candidates_touch before update on curation_candidates
  for each row execute function touch_updated_at();

-- ---------------------------------------------------------------------------
-- a fila da mesa: rodada mais recente, queued, ainda não decidida,
-- ordenada por score desc, headroom desc.
-- drop antes do create: se já existir uma view com colunas diferentes,
-- "create or replace" falha (42P16: cannot drop columns from view).
-- ---------------------------------------------------------------------------
drop view if exists curation_feed;
create view curation_feed as
select c.*
from curation_candidates c
where c.status = 'queued'
  and c.batch_id = (
        select batch_id from curation_candidates
        order by refreshed_at desc nulls last
        limit 1)
  and not exists (
        select 1 from curator_decisions d
        where d.candidate_id = c.candidate_id)
order by c.score desc, c.headroom desc nulls last;

-- ---------------------------------------------------------------------------
-- rls: trancado. ninguém com a anon key lê/escreve direto.
-- todo acesso da aplicação é server-side com a service role (que ignora rls).
-- a curadora nunca fala direto com o supabase: passa pelas api routes da vercel.
-- ---------------------------------------------------------------------------
alter table curation_candidates enable row level security;
alter table curator_decisions  enable row level security;
-- sem policies para anon/authenticated => negado por padrão. service role passa.
