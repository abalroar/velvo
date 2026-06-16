-- seed da rodada curada velvo (vibe antonio) — schema + 238 candidatos + aprovados.
-- idempotente: rode de novo sem duplicar nem apagar decisoes.
-- batch_id: 2026-w24-curada-visual  |  candidatos: 238  |  aprovados marcados em payload.approved

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


-- politicas p/ a mesa interna ler o catalogo e gravar decisoes com a anon key.
-- (em producao, prefira service role no servidor e remova/estreite estas.)
drop policy if exists anon_read_candidates on curation_candidates;
create policy anon_read_candidates on curation_candidates for select to anon, authenticated using (true);
drop policy if exists anon_write_candidates on curation_candidates;
create policy anon_write_candidates on curation_candidates for all to anon, authenticated using (true) with check (true);
drop policy if exists anon_read_decisions on curator_decisions;
create policy anon_read_decisions on curator_decisions for select to anon, authenticated using (true);
drop policy if exists anon_write_decisions on curator_decisions;
create policy anon_write_decisions on curator_decisions for all to anon, authenticated using (true) with check (true);

begin;

insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('bruceangeirasleiloeiro-com-br-31203696', 'bruceangeirasleiloeiro-com-br-31203696', '2026-w24-curada-visual', 'BRONZE - Escultura em bronze maciço representando gato de corpo alonga', 30.0, 'lance r$ 30', 'Bruce Angeiras Leilões', 'https://bruceangeirasleiloeiro.com.br/peca.asp?Id=31203696', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62664/31203696.jpg', '2026-06-16 19:00', 90.0, 'alta', 'alto', 82.0, null, 'queued', '{"uf": "RJ", "house_name": "Bruce Angeiras Leilões", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": 334.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": true, "tier": "A", "entry_reasons": ["aprovado (tier A)", "bronze escult", "upside ~r$1389", "teto p/ dobrar r$112", "junho"], "risk_reasons": ["liquidez baixa"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rosanavaleleiloes-com-br-29865875', 'rosanavaleleiloes-com-br-29865875', '2026-w24-curada-visual', 'Compoteira em cristal baccarat, transparente lapidado, acompanha prese', 170.0, 'lance r$ 170', 'Rosana Vale Leilões', 'https://rosanavaleleiloes.com.br/peca.asp?Id=29865875', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60441/29865875.jpg', '2026-06-16 19:00', 90.0, 'alta', 'baixo', 66.0, null, 'queued', '{"uf": "RJ", "house_name": "Rosana Vale Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 378.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": true, "tier": "A", "entry_reasons": ["aprovado (tier A)", "baccarat", "upside ~r$1051", "teto p/ dobrar r$236", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-29205816', 'br-ernanileiloeiro-com-br-29205816', '2026-w24-curada-visual', 'Vaso  jarra  porcelana branca  Vista Alegre Coral  15X10X8.', 15.0, 'lance r$ 15', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=29205816', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/29205816.jpg', '2026-06-23 15:00', 90.0, 'alta', 'baixo', 0.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 109.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": true, "tier": "A", "entry_reasons": ["aprovado (tier A)", "vista alegre", "upside ~r$328", "teto p/ dobrar r$15", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tallonileiloes-com-br-31196051', 'tallonileiloes-com-br-31196051', '2026-w24-curada-visual', 'Belissima escultura elaborada por design bronze com marmore, medindo 3', 290.0, 'lance r$ 290', 'Talloni Leilões', 'https://tallonileiloes.com.br/peca.asp?Id=31196051', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62687/31196051.jpg', null, 90.0, 'alta', 'alto', -178.0, null, 'queued', '{"uf": null, "house_name": "Talloni Leilões", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": 61.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": true, "tier": "B", "entry_reasons": ["aprovado (tier B)", "bronze escult", "upside ~r$1116", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('estiloantigoleiloes-com-br-30966705', 'estiloantigoleiloes-com-br-30966705', '2026-w24-curada-visual', 'DÉCADA DE 50- Elegante Solifleur de MURANO ITALIANO, azul cobalto, int', 150.0, 'lance r$ 150', 'Estilo Antigo Leilões', 'https://estiloantigoleiloes.com.br/peca.asp?Id=30966705', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62163/30966705.jpg', null, 90.0, 'alta', 'medio', -126.0, null, 'queued', '{"uf": null, "house_name": "Estilo Antigo Leilões", "material": "murano", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": "anos 50", "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -16.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": true, "tier": "B", "entry_reasons": ["aprovado (tier B)", "opalina", "upside ~r$318", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-29577144', 'br-ernanileiloeiro-com-br-29577144', '2026-w24-curada-visual', 'Cinzeiro em grosso bloco de cristal de Sèvrés, Francês, incolor, image', 38.0, 'lance r$ 38', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=29577144', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/29577144.jpg', '2026-06-22 15:00', 99, 'alta', 'medio', 286.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 2700, "price_band": "R$ 2.500 +", "era": null, "size_class": "peq/med", "est_resale_base": 900, "est_gross_profit": 687.0, "max_bid_40pct": 324.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["sevres", "upside ~r$2361", "teto p/ dobrar r$324", "junho"], "risk_reasons": ["liquidez baixa"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31001243', 'paulaoantiguidades-com-br-31001243', '2026-w24-curada-visual', 'BRENNAND - CONJUNTO DE SEIS XÍCARAS DE CAFÉ EM PORCELANA DOS ANOS 60. ', 270.0, 'lance r$ 270', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31001243', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31001243.jpg', '2026-06-18 19:00', 99, 'alta', 'baixo', 58.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 2520, "price_band": "R$ 2.500 +", "era": "anos 60", "size_class": "peq/med", "est_resale_base": 909, "est_gross_profit": 452.0, "max_bid_40pct": 328.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["brennand", "upside ~r$1950", "teto p/ dobrar r$328", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leiloeslemos-com-br-31162617', 'leiloeslemos-com-br-31162617', '2026-w24-curada-visual', 'ROYAL EUROPE  PEINTE À LA MAIN. Jarra tipo ânfora em porcelana, decora', 260.0, 'lance r$ 260', 'Leilões Lemos', 'https://leiloeslemos.com.br/peca.asp?Id=31162617', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62442/31162617.jpg', null, 99, 'alta', 'medio', 64.0, null, 'queued', '{"uf": null, "house_name": "Leilões Lemos", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 2700, "price_band": "R$ 2.500 +", "era": null, "size_class": "peq/med", "est_resale_base": 900, "est_gross_profit": 454.0, "max_bid_40pct": 324.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["sevres", "upside ~r$2128", "teto p/ dobrar r$324", "sem data"], "risk_reasons": ["liquidez baixa"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-31142026', 'br-ernanileiloeiro-com-br-31142026', '2026-w24-curada-visual', 'Bela garrafa -licoreira, lapidação ao gosto Baccarat, altura 33cm.', 50.0, 'lance r$ 50', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=31142026', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/31142026.jpg', '2026-06-22 15:00', 94.4, 'alta', 'baixo', 186.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "cristal & vidro", "size_label": "médio", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 504.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$1177", "teto p/ dobrar r$236", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31180985', 'cb-leiloeiro-com-br-31180985', '2026-w24-curada-visual', 'MBP05-CONJUNTO DE 6 TAÇAS E CRISTAL (DEMI) TRANSPARENTE LAPIDADO POR F', 75.0, 'lance r$ 75', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31180985', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31180985.jpg', '2026-06-17 19:00', 85.9, 'alta', 'baixo', 161.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 478.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$1150", "teto p/ dobrar r$236", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-31033362', 'prochicleiloes-com-br-31033362', '2026-w24-curada-visual', 'SEMIRAMIS Escultura em bronze, assinado Semiramis 29. Medidas:13cm x 7', 100.0, 'lance r$ 100', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=31033362', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62121/31033362.jpg', null, 72.9, 'alta', 'alto', 12.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "bronze", "size_label": "pequeno", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": 261.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$1315", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163820', 'shoppingdosantiquarios-lel-br-31163820', '2026-w24-curada-visual', 'Escultura em bronze representando bailarina sem assinatura. Altura: 38', 150.0, 'lance r$ 150', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163820', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163820.jpg', null, 66.5, 'alta', 'alto', -38.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": 208.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$1263", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31030236', 'antiguitati-com-br-31030236', '2026-w24-curada-visual', 'Sèvres - Importante caixa de jóias em porcelana decorada a ouro em alt', 900.0, 'lance r$ 900', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31030236', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31030236.jpg', '2026-06-18 19:00', 64.4, 'alta', 'medio', -576.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 2700, "price_band": "R$ 2.500 +", "era": null, "size_class": "peq/med", "est_resale_base": 900, "est_gross_profit": -218.0, "max_bid_40pct": 324.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["sevres", "upside ~r$1456", "teto p/ dobrar r$324", "junho"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063699', 'rrdeco-com-br-31063699', '2026-w24-curada-visual', 'Antiga e rara escultura representando cavalo em ceramica vitrificada n', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063699', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063699.jpg', '2026-07-09 18:00', 63.9, 'alta', 'alto', -53.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "médio", "price_sale": 1719, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 648, "est_gross_profit": 223.0, "max_bid_40pct": 147.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["escult assinada", "upside ~r$1219", "teto p/ dobrar r$147", "julho"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064250', 'rrdeco-com-br-31064250', '2026-w24-curada-visual', 'Antiga e rara escultura em porcelana representando buda com rica polic', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064250', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064250.jpg', '2026-07-11 13:00', 63.9, 'alta', 'alto', -53.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "médio", "price_sale": 1719, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 648, "est_gross_profit": 223.0, "max_bid_40pct": 147.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["escult assinada", "upside ~r$1219", "teto p/ dobrar r$147", "julho"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063668', 'rrdeco-com-br-31063668', '2026-w24-curada-visual', 'Antiga escultura e ou cinzeiro em Bronze , representando Sabio. Peca c', 250.0, 'lance r$ 250', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063668', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063668.jpg', '2026-07-10 13:00', 56.6, 'alta', 'alto', -138.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": 103.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$1158", "teto p/ dobrar r$112", "julho"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30996180', 'rrdeco-com-br-30996180', '2026-w24-curada-visual', 'RR Antiguidades  Antigo porta joias em porcelana com belissimos detalh', 280.0, 'lance r$ 280', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30996180', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62089/30996180.jpg', null, 56.4, 'alta', 'alto', -133.0, null, 'queued', '{"uf": null, "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "médio", "price_sale": 1719, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 648, "est_gross_profit": 139.0, "max_bid_40pct": 147.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["escult assinada", "upside ~r$1135", "teto p/ dobrar r$147", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024800', 'wattenleiloes-com-br-31024800', '2026-w24-curada-visual', 'PAR DE TAÇAS PARA CHAMPAGNE. BACCARAT MONOGRAMADAS B.I. LINDA LAPIDAÇÃ', 280.0, 'lance r$ 280', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024800', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024800.jpg', null, 51.7, 'alta', 'baixo', -44.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 262.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$935", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31003533', 'antiguitati-com-br-31003533', '2026-w24-curada-visual', 'Cristallerie BACCARAT URALINA - Raro copo em cristal dito "Uralina" da', 290.0, 'lance r$ 290', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31003533', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31003533.jpg', '2026-06-18 19:00', 50.8, 'alta', 'baixo', -54.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 252.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$925", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-30944433', 'prochicleiloes-com-br-30944433', '2026-w24-curada-visual', 'Lote de papa migalha, 2 petisqueiras e 1 cremeira em prata 90, sendo a', 45.0, 'lance r$ 45', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=30944433', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62121/30944433.jpg', null, 50.1, 'media', 'medio', 73.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 792, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 468, "est_gross_profit": 278.0, "max_bid_40pct": 118.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["wmf", "upside ~r$579", "teto p/ dobrar r$118", "sem data"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leiloeslemos-com-br-31201957', 'leiloeslemos-com-br-31201957', '2026-w24-curada-visual', 'Capodimonte  Saleiro vintage em porcelana italiana, decorado com a mes', 160.0, 'lance r$ 160', 'Leilões Lemos', 'https://leiloeslemos.com.br/peca.asp?Id=31201957', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62442/31201957.jpg', null, 48.0, 'media', 'baixo', -16.0, null, 'queued', '{"uf": null, "house_name": "Leilões Lemos", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 1184, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 522, "est_gross_profit": 207.0, "max_bid_40pct": 144.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["capodimonte", "upside ~r$823", "teto p/ dobrar r$144", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024799', 'wattenleiloes-com-br-31024799', '2026-w24-curada-visual', 'CINCO TAÇAS PARA VINHO BRANCO. BACCARAT MONOGRAMADAS B.I. LINDA LAPIDA', 320.0, 'lance r$ 320', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024799', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024799.jpg', null, 47.9, 'media', 'baixo', -84.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 220.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$893", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176565', 'rrdeco-com-br-30176565', '2026-w24-curada-visual', 'RR Antiguidades Antiga diferente escultura de origem Egipcia. Peca apa', 400.0, 'lance r$ 400', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176565', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176565.jpg', '2026-07-18 18:00', 45.2, 'alta', 'alto', -288.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -54.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$1000", "teto p/ dobrar r$112", "julho"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31003527', 'antiguitati-com-br-31003527', '2026-w24-curada-visual', 'Cristalerie Baccarat - Par de raros copos para vinho do porto, com ape', 360.0, 'lance r$ 360', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31003527', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31003527.jpg', '2026-06-18 19:00', 44.3, 'media', 'baixo', -124.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 178.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$851", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('oficinacenarioleiloes-com-br-30850756', 'oficinacenarioleiloes-com-br-30850756', '2026-w24-curada-visual', 'BACCARAT - MUG EM CRISTAL MOULLE RUBI E AMBAR COM BELISSIMA DECORAÇÃO ', 380.0, 'lance r$ 380', 'Oficina Cenário Leilões', 'https://oficinacenarioleiloes.com.br/peca.asp?Id=30850756', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61890/30850756.jpg', '2026-06-16 20:00', 42.6, 'media', 'baixo', -144.0, null, 'queued', '{"uf": "SP", "house_name": "Oficina Cenário Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 157.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$830", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('anamelloleiloeira-com-br-31132924', 'anamelloleiloeira-com-br-31132924', '2026-w24-curada-visual', 'BACCARAT - Belíssima e delicada taça alta para vinho em cristal francê', 400.0, 'lance r$ 400', 'Ana Mello Leiloeira', 'https://anamelloleiloeira.com.br/peca.asp?Id=31132924', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61897/31132924.jpg', '2026-06-24 19:00', 41.0, 'media', 'baixo', -164.0, null, 'queued', '{"uf": "RJ", "house_name": "Ana Mello Leiloeira", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 136.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$809", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024911', 'wattenleiloes-com-br-31024911', '2026-w24-curada-visual', 'PEQUENA E ELEGANTE GARRAFA DE CRISTAL BACCARAT COM TAMPA ORIGINAL. PER', 400.0, 'lance r$ 400', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024911', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024911.jpg', null, 41.0, 'media', 'baixo', -164.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 136.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$809", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31001272', 'paulaoantiguidades-com-br-31001272', '2026-w24-curada-visual', 'ANTIGA DEDEIRA DE COLEÇÃO EM PRATA DE LEI. MEDINDO 2 X 1.5 CM', 20.0, 'lance r$ 20', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31001272', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31001272.jpg', '2026-06-18 19:00', 34.0, 'media', 'medio', -13.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 87.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$539", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024916', 'wattenleiloes-com-br-31024916', '2026-w24-curada-visual', 'DUAS LINDAS MAÇANETAS AO ESTILO FAVO DE MEL. CRISTAL BACCARAT. TONALID', 500.0, 'lance r$ 500', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024916', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024916.jpg', null, 33.6, 'media', 'baixo', -264.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 31.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$704", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024855', 'wattenleiloes-com-br-31024855', '2026-w24-curada-visual', 'LOTE COM DUAS MAÇANETAS CRISTAL BACCARAT. UMA FAVO DE MEL TONALIDADE R', 500.0, 'lance r$ 500', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024855', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024855.jpg', null, 33.6, 'media', 'baixo', -264.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": 31.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$704", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063776', 'rrdeco-com-br-31063776', '2026-w24-curada-visual', 'Antigo e raro porta joias caixa em porcelana Capodimonte, tampa com be', 300.0, 'lance r$ 300', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063776', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063776.jpg', '2026-07-10 13:00', 33.5, 'media', 'baixo', -156.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 1184, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 522, "est_gross_profit": 60.0, "max_bid_40pct": 144.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["capodimonte", "upside ~r$676", "teto p/ dobrar r$144", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('jotamleiloes-com-br-30909257', 'jotamleiloes-com-br-30909257', '2026-w24-curada-visual', 'VIDRO, uma (1) cúpula dita cogumelo, confeccionado em vidro opalinado ', 30.0, 'lance r$ 30', 'Imperial JM Leilões', 'https://jotamleiloes.com.br/peca.asp?Id=30909257', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61324/30909257.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Imperial JM Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134926', 'miltrekosleiloes-com-br-31134926', '2026-w24-curada-visual', 'Antigo prato em porcelana opalina Colorex. As fotos fazem parte da des', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134926', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134926.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134923', 'miltrekosleiloes-com-br-31134923', '2026-w24-curada-visual', 'Antiga xicara em porcelana opalina Colorex Triguinho. As fotos fazem p', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134923', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134923.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134922', 'miltrekosleiloes-com-br-31134922', '2026-w24-curada-visual', 'Antiga xicara e pires em porcelana opalina Colorex. As fotos fazem par', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134922', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134922.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134920', 'miltrekosleiloes-com-br-31134920', '2026-w24-curada-visual', 'Antiga tigela em porcelana opalina Colorex, mede 18 cm de diâmetro por', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134920', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134920.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134919', 'miltrekosleiloes-com-br-31134919', '2026-w24-curada-visual', 'Antiga tigela em porcelana opalina Colorex. As fotos fazem parte da de', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134919', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134919.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134918', 'miltrekosleiloes-com-br-31134918', '2026-w24-curada-visual', 'Antiga tigela em porcelana opalina Colorex. As fotos fazem parte da de', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134918', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134918.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134917', 'miltrekosleiloes-com-br-31134917', '2026-w24-curada-visual', 'Antiga travessa em porcelana opalina Colorex. As fotos fazem parte da ', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134917', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134917.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134916', 'miltrekosleiloes-com-br-31134916', '2026-w24-curada-visual', 'Par de antigas xicaras em porcelana opalina Colorex Triguinho. As foto', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134916', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134916.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134915', 'miltrekosleiloes-com-br-31134915', '2026-w24-curada-visual', 'Antiga travessa em porcelana opalina Colorex Triguinho, mede 36 x 26 c', 30.0, 'lance r$ 30', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134915', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134915.jpg', null, 31.1, 'baixa', 'medio', -6.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 110.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$444", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024798', 'wattenleiloes-com-br-31024798', '2026-w24-curada-visual', 'GARRAFA BACCARAT MONOGRAMADA B.I. RICA LAPIDAÇÃO. TAMPA ORIGINAL. PERF', 550.0, 'lance r$ 550', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024798', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024798.jpg', null, 30.1, 'media', 'baixo', -314.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -21.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$652", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31072908', 'paulaoantiguidades-com-br-31072908', '2026-w24-curada-visual', 'ANTIGA PEÇA DE TOUCADOR EM PRATA DE LEI CONTRASTADA. CONFORME FOTOS. P', 40.0, 'lance r$ 40', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31072908', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31072908.jpg', '2026-06-18 19:00', 30.0, 'media', 'medio', -33.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 66.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$518", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31100666', 'cb-leiloeiro-com-br-31100666', '2026-w24-curada-visual', 'PG111-ANTIGO COPINHO DE CRIANÇA (PRATA DE LEI - CONTRASTE 800), APROX.', 44.0, 'lance r$ 44', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31100666', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31100666.jpg', '2026-06-17 19:00', 29.3, 'media', 'medio', -37.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 61.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$513", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134921', 'miltrekosleiloes-com-br-31134921', '2026-w24-curada-visual', 'Par de antigas xicaras em porcelana opalina Colorex. As fotos fazem pa', 40.0, 'lance r$ 40', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134921', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134921.jpg', null, 29.1, 'baixa', 'medio', -16.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 99.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$434", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('miltrekosleiloes-com-br-31134914', 'miltrekosleiloes-com-br-31134914', '2026-w24-curada-visual', 'Antiga travessa em porcelana opalina Colorex Triguinho, mede 36 x 26 c', 40.0, 'lance r$ 40', 'Miltrekos Leilões', 'https://miltrekosleiloes.com.br/peca.asp?Id=31134914', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62586/31134914.jpg', null, 29.1, 'baixa', 'medio', -16.0, null, 'queued', '{"uf": null, "house_name": "Miltrekos Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 99.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$434", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-29409195', 'br-ernanileiloeiro-com-br-29409195', '2026-w24-curada-visual', '''Vista Alegre''. Porcelana branca: dois bowls (13,5x4cm.) e três pequen', 12.0, 'lance r$ 12', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=29409195', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/29409195.jpg', '2026-06-23 15:00', 27.8, 'baixa', 'baixo', 3.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 112.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$331", "teto p/ dobrar r$15", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-31147174', 'prochicleiloes-com-br-31147174', '2026-w24-curada-visual', 'Lote de 2 travessas ovais em vidro opalinado Colorex creme com borda g', 50.0, 'lance r$ 50', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=31147174', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62404/31147174.jpg', null, 27.1, 'baixa', 'medio', -26.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 89.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$423", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-31146851', 'prochicleiloes-com-br-31146851', '2026-w24-curada-visual', 'Lote de prato de bolo e travessa oval em vidro opalinado Colorex creme', 50.0, 'lance r$ 50', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=31146851', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62404/31146851.jpg', null, 27.1, 'baixa', 'medio', -26.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 89.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$423", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-31146810', 'prochicleiloes-com-br-31146810', '2026-w24-curada-visual', 'Prato de bolo e travessa oval em vidro opalinado Colorex creme com bor', 50.0, 'lance r$ 50', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=31146810', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62404/31146810.jpg', null, 27.1, 'baixa', 'medio', -26.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 89.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$423", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-29205823', 'br-ernanileiloeiro-com-br-29205823', '2026-w24-curada-visual', 'Vista Alegre  Portugal  Viva  Castiçal, em porcelana branca, detalhes ', 15.0, 'lance r$ 15', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=29205823', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/29205823.jpg', '2026-06-23 15:00', 26.9, 'baixa', 'baixo', 0.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 109.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$328", "teto p/ dobrar r$15", "junho"], "risk_reasons": []}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063230', 'rrdeco-com-br-31063230', '2026-w24-curada-visual', 'Antigo e raro pequeno pote, porta comprimidos etc...confeccionado reci', 600.0, 'lance r$ 600', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063230', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063230.jpg', '2026-07-09 18:00', 26.9, 'media', 'baixo', -364.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -74.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$599", "teto p/ dobrar r$236", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024796', 'wattenleiloes-com-br-31024796', '2026-w24-curada-visual', 'LINDA GARRAFA BACCARAT. EXPECIONAL LAPIDAÇÃO E TAMPA ORIGINAL. PERFEIT', 600.0, 'lance r$ 600', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024796', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024796.jpg', null, 26.9, 'media', 'baixo', -364.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -74.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$599", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marthapadilhaleiloeira-lel-br-31036149', 'marthapadilhaleiloeira-lel-br-31036149', '2026-w24-curada-visual', '2 BROCHES PRODUZIDOS EM PRATA DE LEI (FLOR) E METAL PRATEADO ( TESOURA', 60.0, 'lance r$ 60', 'Martha Isolda Padilha Leiloeira', 'https://marthapadilhaleiloeira.lel.br/peca.asp?Id=31036149', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62355/31036149.jpg', null, 26.8, 'media', 'medio', -53.0, null, 'queued', '{"uf": null, "house_name": "Martha Isolda Padilha Leiloeira", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 45.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$497", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-30971227', 'prochicleiloes-com-br-30971227', '2026-w24-curada-visual', 'Lote de 2 cúpulas bola em vidro opalinado. Medindo a maior 8cm de boca', 55.0, 'lance r$ 55', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=30971227', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62060/30971227.jpg', null, 26.3, 'baixa', 'medio', -31.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 83.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$418", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-30970976', 'prochicleiloes-com-br-30970976', '2026-w24-curada-visual', 'Lindo prato de bolo em vidro opalinado com relevos na borda. Medindo 3', 55.0, 'lance r$ 55', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=30970976', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62060/30970976.jpg', null, 26.3, 'baixa', 'medio', -31.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 83.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$418", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31050812', 'shoppingdosantiquarios-lel-br-31050812', '2026-w24-curada-visual', 'Duas xícaras com pires em porcelana portuguesa, sendo uma de Coimbra e', 20.0, 'lance r$ 20', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31050812', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31050812.jpg', null, 25.7, 'baixa', 'baixo', -5.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 103.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$323", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casanostraleiloes-com-br-30970681', 'casanostraleiloes-com-br-30970681', '2026-w24-curada-visual', 'Lote c/ 3 miniaturas de medalhões em porcelana, nos formatos: redondo ', 20.0, 'lance r$ 20', 'Casa Nostra Leilões', 'https://casanostraleiloes.com.br/peca.asp?Id=30970681', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/57034/30970681.jpg', '2026-07-18 19:00', 25.6, 'baixa', 'baixo', -5.0, null, 'queued', '{"uf": "SP", "house_name": "Casa Nostra Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 103.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$321", "teto p/ dobrar r$15", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31050862', 'shoppingdosantiquarios-lel-br-31050862', '2026-w24-curada-visual', 'Duas xícaras de café em porcelana francesa Limoges.', 20.0, 'lance r$ 20', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31050862', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31050862.jpg', null, 25.6, 'baixa', 'baixo', -5.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 103.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$321", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rioarteleiloes-com-br-31107923', 'rioarteleiloes-com-br-31107923', '2026-w24-curada-visual', 'Colher decorativa em prata de lei, de elegante composição naturalista,', 70.0, 'lance r$ 70', 'Rio Arte Leilões', 'https://rioarteleiloes.com.br/peca.asp?Id=31107923', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62093/31107923.jpg', null, 25.5, 'media', 'medio', -63.0, null, 'queued', '{"uf": null, "house_name": "Rio Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 34.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$486", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31100661', 'cb-leiloeiro-com-br-31100661', '2026-w24-curada-visual', 'PG98-BELÍSSIMO ABRIDOR DE CORRESPONDÊNCIA EM PRATA 835 (PRATA DE LEI),', 75.0, 'lance r$ 75', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31100661', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31100661.jpg', '2026-06-17 19:00', 24.7, 'media', 'medio', -68.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 29.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$481", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31100659', 'cb-leiloeiro-com-br-31100659', '2026-w24-curada-visual', 'PG99-BELÍSSIMO ABRIDOR DE CORRESPONDÊNCIA COM FIGURA DE "FONTE COM SER', 75.0, 'lance r$ 75', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31100659', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31100659.jpg', '2026-06-17 19:00', 24.7, 'media', 'medio', -68.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 29.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$481", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('anamelloleiloeira-com-br-30103178', 'anamelloleiloeira-com-br-30103178', '2026-w24-curada-visual', 'LIMOGES - Manteigueira / porta chá em porcelana francesa. Em ótimo est', 25.0, 'lance r$ 25', 'Ana Mello Leiloeira', 'https://anamelloleiloeira.com.br/peca.asp?Id=30103178', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60770/30103178.jpg', '2026-06-17 19:00', 24.6, 'baixa', 'baixo', -10.0, null, 'queued', '{"uf": "RJ", "house_name": "Ana Mello Leiloeira", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 98.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$316", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('mbantiguidades-com-br-31190337', 'mbantiguidades-com-br-31190337', '2026-w24-curada-visual', 'Sofisticado conjunto composto por prato para bolo e 4 pratos sobremesa', 80.0, 'lance r$ 80', 'MB Antiguidades', 'https://mbantiguidades.com.br/peca.asp?Id=31190337', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62380/31190337.jpg', '2026-06-15 15:00', 24.2, 'media', 'medio', -73.0, null, 'queued', '{"uf": "RJ", "house_name": "MB Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 24.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$476", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tamiriscarvalholeiloeira-com-br-30253097', 'tamiriscarvalholeiloeira-com-br-30253097', '2026-w24-curada-visual', 'Par de abotuaduras em prata 925 quadrado com centro de pedras brancas', 80.0, 'lance r$ 80', 'Tamiris Carvalho Leiloeira', 'https://tamiriscarvalholeiloeira.com.br/peca.asp?Id=30253097', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61656/30253097.jpg', '2026-06-15 19:00', 24.2, 'media', 'medio', -73.0, null, 'queued', '{"uf": "RJ", "house_name": "Tamiris Carvalho Leiloeira", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 24.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$476", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31103985', 'paulaoantiguidades-com-br-31103985', '2026-w24-curada-visual', 'ANTIGO PRATO DE COLEÇÃO EM PORCELANA PORTUGUESA VISTA ALEGRE. DECORAÇÃ', 30.0, 'lance r$ 30', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31103985', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31103985.jpg', '2026-06-18 19:00', 23.5, 'baixa', 'baixo', -15.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 93.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$312", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31051357', 'shoppingdosantiquarios-lel-br-31051357', '2026-w24-curada-visual', 'Dois pratos de porcelana, sendo um inglês e outro francês de Limoges. ', 30.0, 'lance r$ 30', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31051357', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31051357.jpg', null, 23.5, 'baixa', 'baixo', -15.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 93.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$310", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31108405', 'cb-leiloeiro-com-br-31108405', '2026-w24-curada-visual', 'LM76-COPINHO EM PRATA DE LEI (CONTRASTE 833); APROX. 6cm X 8cm E PESO ', 85.0, 'lance r$ 85', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31108405', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31108405.jpg', '2026-06-17 19:00', 23.4, 'media', 'medio', -78.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 18.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$470", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31088649', 'paulaoantiguidades-com-br-31088649', '2026-w24-curada-visual', 'PRATA DE LEI - ANTIGO CORDÃO EM PRATA DE LEI TEOR 925 MLS. PESO TOTAL ', 90.0, 'lance r$ 90', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31088649', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31088649.jpg', '2026-06-18 19:00', 22.8, 'media', 'medio', -83.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 13.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$465", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31108407', 'cb-leiloeiro-com-br-31108407', '2026-w24-curada-visual', 'LM77-MINI TACHO EM PRATA DE LEI (CONTRASTE "PER-WELSOM 925"), APROX. 1', 98.0, 'lance r$ 98', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31108407', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31108407.jpg', '2026-06-17 19:00', 22.0, 'media', 'medio', -91.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": 5.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$457", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31108401', 'cb-leiloeiro-com-br-31108401', '2026-w24-curada-visual', 'LM75-MINI BANDEJA COM FORMATO REDONDO, EM PRATA DE LEI, TROFÉU DE GOLF', 105.0, 'lance r$ 105', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31108401', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31108401.jpg', '2026-06-17 19:00', 21.1, 'baixa', 'medio', -98.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -3.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$449", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('cb-leiloeiro-com-br-31108399', 'cb-leiloeiro-com-br-31108399', '2026-w24-curada-visual', 'LM74-MINI BANDEJA COM FORMATO REDONDO, EM PRATA DE LEI, TROFÉU DE GOLF', 105.0, 'lance r$ 105', 'CB - Carvalho Borges Leiloeiro', 'https://cb-leiloeiro.com.br/peca.asp?Id=31108399', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61720/31108399.jpg', '2026-06-17 19:00', 21.1, 'baixa', 'medio', -98.0, null, 'queued', '{"uf": "ES", "house_name": "CB - Carvalho Borges Leiloeiro", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -3.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$449", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31026535', 'antiguitati-com-br-31026535', '2026-w24-curada-visual', 'Baccarat - Service de nuit em opalina branca decorada a ouro, composto', 700.0, 'lance r$ 700', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31026535', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31026535.jpg', '2026-06-18 19:00', 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31026517', 'antiguitati-com-br-31026517', '2026-w24-curada-visual', 'Baccarat - Raro perfumeiro e sua tampa em opalina de Bacarat finamente', 700.0, 'lance r$ 700', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31026517', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31026517.jpg', '2026-06-18 19:00', 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024854', 'wattenleiloes-com-br-31024854', '2026-w24-curada-visual', 'LINDO PAR DE MAÇANETAS AO ESTILO FAVO DE MEL. CRISTAL BACCARAT. TONALI', 700.0, 'lance r$ 700', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024854', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024854.jpg', null, 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024853', 'wattenleiloes-com-br-31024853', '2026-w24-curada-visual', 'LINDO PAR DE MAÇANETAS AO ESTILO FAVO DE MEL. CRISTAL BACCARAT. TONALI', 700.0, 'lance r$ 700', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024853', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024853.jpg', null, 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024822', 'wattenleiloes-com-br-31024822', '2026-w24-curada-visual', 'LINDO PAR DE MAÇANETAS AO ESTILO FAVO DE MEL. CRISTAL BACCARAT. TONALI', 700.0, 'lance r$ 700', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024822', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024822.jpg', null, 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024821', 'wattenleiloes-com-br-31024821', '2026-w24-curada-visual', 'LINDO PAR DE MAÇANETAS AO ESTILO FAVO DE MEL. CRISTAL BACCARAT. TONALI', 700.0, 'lance r$ 700', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024821', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024821.jpg', null, 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024820', 'wattenleiloes-com-br-31024820', '2026-w24-curada-visual', 'LINDO PAR DE MAÇANETAS AO ESTILO FAVO DE MEL. CRISTAL BACCARAT. TONALI', 700.0, 'lance r$ 700', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024820', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024820.jpg', null, 20.7, 'media', 'baixo', -464.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -179.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$494", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31026525', 'antiguitati-com-br-31026525', '2026-w24-curada-visual', 'Caixa com tampa em opalina azul, guarnição em bronze dourado, tampa co', 100.0, 'lance r$ 100', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31026525', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31026525.jpg', '2026-06-18 19:00', 20.0, 'baixa', 'medio', -76.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 36.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$371", "teto p/ dobrar r$24", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leilaomirianneto-com-br-31036531', 'leilaomirianneto-com-br-31036531', '2026-w24-curada-visual', 'VIDRO ARCOPAL FRANCE - Doze xícaras para café com onze  pires, confecc', 100.0, 'lance r$ 100', 'Casa de Leilões Mirian Neto', 'https://leilaomirianneto.com.br/peca.asp?Id=31036531', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61571/31036531.jpg', null, 20.0, 'baixa', 'medio', -76.0, null, 'queued', '{"uf": null, "house_name": "Casa de Leilões Mirian Neto", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 36.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$371", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('estiloantigoleiloes-com-br-30970538', 'estiloantigoleiloes-com-br-30970538', '2026-w24-curada-visual', 'VISTA ALEGRE- PERIODO ART DÉCO- Trio para chá de coleção, cerca de 192', 50.0, 'lance r$ 50', 'Estilo Antigo Leilões', 'https://estiloantigoleiloes.com.br/peca.asp?Id=30970538', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62163/30970538.jpg', null, 19.8, 'baixa', 'baixo', -35.0, null, 'queued', '{"uf": null, "house_name": "Estilo Antigo Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": "art déco", "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 72.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$291", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('estiloantigoleiloes-com-br-30967308', 'estiloantigoleiloes-com-br-30967308', '2026-w24-curada-visual', 'VISTA ALEGRE- PERIODO ART DÉCO- Trio para chá de coleção, cerca de 192', 50.0, 'lance r$ 50', 'Estilo Antigo Leilões', 'https://estiloantigoleiloes.com.br/peca.asp?Id=30967308', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62163/30967308.jpg', null, 19.8, 'baixa', 'baixo', -35.0, null, 'queued', '{"uf": null, "house_name": "Estilo Antigo Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": "art déco", "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 72.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$291", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('estiloantigoleiloes-com-br-30967303', 'estiloantigoleiloes-com-br-30967303', '2026-w24-curada-visual', 'VISTA ALEGRE- PERIODO ART DÉCO- Trio para chá de coleção, cerca de 192', 50.0, 'lance r$ 50', 'Estilo Antigo Leilões', 'https://estiloantigoleiloes.com.br/peca.asp?Id=30967303', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62163/30967303.jpg', null, 19.8, 'baixa', 'baixo', -35.0, null, 'queued', '{"uf": null, "house_name": "Estilo Antigo Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": "art déco", "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 72.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$291", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31130918', 'antiguitati-com-br-31130918', '2026-w24-curada-visual', 'Colher de chá em prata portuguesa contraste P coroado, séc. XIX, peso ', 120.0, 'lance r$ 120', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31130918', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31130918.jpg', '2026-06-19 19:00', 19.6, 'baixa', 'medio', -113.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -18.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$434", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('estiloantigoleiloes-com-br-30967313', 'estiloantigoleiloes-com-br-30967313', '2026-w24-curada-visual', 'SÉC XIX/XX- Bela lapiseira de PRATA PORTUGUESA COM CONTRASTE DE OURIVE', 120.0, 'lance r$ 120', 'Estilo Antigo Leilões', 'https://estiloantigoleiloes.com.br/peca.asp?Id=30967313', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62163/30967313.jpg', null, 19.6, 'baixa', 'medio', -113.0, null, 'queued', '{"uf": null, "house_name": "Estilo Antigo Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -18.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$434", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marthapadilhaleiloeira-lel-br-31036124', 'marthapadilhaleiloeira-lel-br-31036124', '2026-w24-curada-visual', 'ANTIGO TERÇO CONFECCIONADO EM PRATA DE LEI, MEDINDO 37CM.', 120.0, 'lance r$ 120', 'Martha Isolda Padilha Leiloeira', 'https://marthapadilhaleiloeira.lel.br/peca.asp?Id=31036124', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62355/31036124.jpg', null, 19.6, 'baixa', 'medio', -113.0, null, 'queued', '{"uf": null, "house_name": "Martha Isolda Padilha Leiloeira", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -18.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$434", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063552', 'rrdeco-com-br-31063552', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 135.0, 'lance r$ 135', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063552', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063552.jpg', '2026-07-10 13:00', 18.2, 'baixa', 'medio', -128.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -34.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$418", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31072921', 'paulaoantiguidades-com-br-31072921', '2026-w24-curada-visual', 'ANTIGA BOLSA EM MALHA DE PRATA DE LEI. CONFORME FOTOS. PESANDO 60 GRAM', 140.0, 'lance r$ 140', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31072921', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31072921.jpg', '2026-06-18 19:00', 17.7, 'baixa', 'medio', -133.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -39.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$413", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063417', 'rrdeco-com-br-31063417', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 140.0, 'lance r$ 140', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063417', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063417.jpg', '2026-07-09 18:00', 17.7, 'baixa', 'medio', -133.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -39.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$413", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176378', 'rrdeco-com-br-30176378', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 140.0, 'lance r$ 140', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176378', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176378.jpg', '2026-07-16 15:00', 17.7, 'baixa', 'medio', -133.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -39.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$413", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('danielchaiebleiloeiro-com-br-31098946', 'danielchaiebleiloeiro-com-br-31098946', '2026-w24-curada-visual', 'Lustre de bronze com cupúla de vidro opalinado róseo - comp. 85cm (tot', 70.0, 'lance r$ 70', 'Daniel Chaieb - Leiloeiro Oficial', 'https://danielchaiebleiloeiro.com.br/peca.asp?Id=31098946', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62501/31098946.jpg', '2026-06-18 14:00', 16.9, 'baixa', 'medio', -70.0, null, 'queued', '{"uf": "RS", "house_name": "Daniel Chaieb - Leiloeiro Oficial", "material": "cristal & vidro", "size_label": "grande", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 270, "est_gross_profit": 8.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$342", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31104001', 'paulaoantiguidades-com-br-31104001', '2026-w24-curada-visual', 'ANTIGA PETISQUEIRA DE COLEÇÃO EM PORCELANA PORTUGUESA VISTA ALEGRE PAD', 70.0, 'lance r$ 70', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31104001', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31104001.jpg', '2026-06-18 19:00', 16.7, 'baixa', 'baixo', -55.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 51.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$270", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-30571047', 'shoppingdosantiquarios-lel-br-30571047', '2026-w24-curada-visual', 'Prato em porcelana da manufatura Limoges com ouro na borda. Diâmetro: ', 70.0, 'lance r$ 70', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=30571047', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/30571047.jpg', null, 16.6, 'baixa', 'baixo', -55.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 51.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$268", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-29423251', 'br-ernanileiloeiro-com-br-29423251', '2026-w24-curada-visual', 'Limoges: Pequenino prato, decorativo, em porcelana francesa. Ao centro', 72.0, 'lance r$ 72', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=29423251', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/29423251.jpg', '2026-06-23 15:00', 16.4, 'baixa', 'baixo', -57.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 49.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$266", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rioarteleiloes-com-br-31107980', 'rioarteleiloes-com-br-31107980', '2026-w24-curada-visual', 'Colher em prata 925, contrastada, apresentando lâmina em formato foliá', 160.0, 'lance r$ 160', 'Rio Arte Leilões', 'https://rioarteleiloes.com.br/peca.asp?Id=31107980', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62093/31107980.jpg', null, 15.9, 'baixa', 'medio', -153.0, null, 'queued', '{"uf": null, "house_name": "Rio Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -60.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$392", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('ciclosleiloes-com-br-31112678', 'ciclosleiloes-com-br-31112678', '2026-w24-curada-visual', 'Rosenthal Madeline da década de 1930 -  porcelana Alemão Rosenthal é u', 98.0, 'lance r$ 98', 'Ciclos Leilões', 'https://ciclosleiloes.com.br/peca.asp?Id=31112678', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61115/31112678.jpg', '2026-06-18 14:00', 14.9, 'baixa', 'baixo', -74.0, null, 'queued', '{"uf": "RS", "house_name": "Ciclos Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 504, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 38.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["rosenthal", "upside ~r$256", "teto p/ dobrar r$24", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31028049', 'antiguitati-com-br-31028049', '2026-w24-curada-visual', 'Rosenthal Germany - Oveiro em porcelana no padrão "Pine Needles", base', 100.0, 'lance r$ 100', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31028049', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31028049.jpg', '2026-06-18 19:00', 14.7, 'baixa', 'baixo', -76.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 504, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 36.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["rosenthal", "upside ~r$254", "teto p/ dobrar r$24", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-30875866', 'casaamarelaleiloes-net-br-30875866', '2026-w24-curada-visual', 'Vaso de cristal baccarat azul, lapidação dedão. Mede: 9 cm de diâmetro', 800.0, 'lance r$ 800', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=30875866', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61976/30875866.jpg', null, 14.7, 'baixa', 'baixo', -564.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -284.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$389", "teto p/ dobrar r$236", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176363', 'rrdeco-com-br-30176363', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 180.0, 'lance r$ 180', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176363', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176363.jpg', '2026-07-16 15:00', 14.2, 'baixa', 'medio', -173.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -81.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$371", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176913', 'rrdeco-com-br-30176913', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 180.0, 'lance r$ 180', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176913', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176913.jpg', '2026-07-18 18:00', 14.2, 'baixa', 'medio', -173.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -81.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$371", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('jotamleiloes-com-br-31024186', 'jotamleiloes-com-br-31024186', '2026-w24-curada-visual', 'OURIVERSARIA GAÚCHA, uma (1) bomba para chimarrão confeccionado em PRA', 180.0, 'lance r$ 180', 'Imperial JM Leilões', 'https://jotamleiloes.com.br/peca.asp?Id=31024186', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61324/31024186.jpg', null, 14.2, 'baixa', 'medio', -173.0, null, 'queued', '{"uf": null, "house_name": "Imperial JM Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -81.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$371", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marthapadilhaleiloeira-lel-br-31036123', 'marthapadilhaleiloeira-lel-br-31036123', '2026-w24-curada-visual', 'ANTIGO TERÇO PRODUZIDO EM PRATA DE LEI, MEDINDO 45CM.', 180.0, 'lance r$ 180', 'Martha Isolda Padilha Leiloeira', 'https://marthapadilhaleiloeira.lel.br/peca.asp?Id=31036123', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62355/31036123.jpg', null, 14.2, 'baixa', 'medio', -173.0, null, 'queued', '{"uf": null, "house_name": "Martha Isolda Padilha Leiloeira", "material": "prata & metal", "size_label": "grande", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -81.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$371", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leiloeslemos-com-br-31198829', 'leiloeslemos-com-br-31198829', '2026-w24-curada-visual', 'Limoges  Joieiro em porcelana francesa pintada à mão, com delicada dec', 90.0, 'lance r$ 90', 'Leilões Lemos', 'https://leiloeslemos.com.br/peca.asp?Id=31198829', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62442/31198829.jpg', null, 14.0, 'baixa', 'baixo', -75.0, null, 'queued', '{"uf": null, "house_name": "Leilões Lemos", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 30.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$247", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('br-ernanileiloeiro-com-br-29393361', 'br-ernanileiloeiro-com-br-29393361', '2026-w24-curada-visual', '''Vista Alegre'' : Xícara  de chá e pires, em porcelana  portuguesa. Dec', 92.0, 'lance r$ 92', 'Ernani Leiloeiro Oficial', 'https://br.ernanileiloeiro.com.br/peca.asp?Id=29393361', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/56361/29393361.jpg', '2026-06-23 15:00', 13.9, 'baixa', 'baixo', -77.0, null, 'queued', '{"uf": "RJ", "house_name": "Ernani Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 28.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$247", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tamiriscarvalholeiloeira-com-br-30254223', 'tamiriscarvalholeiloeira-com-br-30254223', '2026-w24-curada-visual', 'Cordão em prata 925 com trabalho geometrico e pedras / Tam: 40cm/ Peso', 190.0, 'lance r$ 190', 'Tamiris Carvalho Leiloeira', 'https://tamiriscarvalholeiloeira.com.br/peca.asp?Id=30254223', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61656/30254223.jpg', '2026-06-15 19:00', 13.5, 'baixa', 'medio', -183.0, null, 'queued', '{"uf": "RJ", "house_name": "Tamiris Carvalho Leiloeira", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -92.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$360", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30177295', 'rrdeco-com-br-30177295', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 190.0, 'lance r$ 190', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30177295', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30177295.jpg', '2026-07-16 15:00', 13.5, 'baixa', 'medio', -183.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -92.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$360", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vmescritarteleiloes-com-br-31093299', 'vmescritarteleiloes-com-br-31093299', '2026-w24-curada-visual', 'Lote composto de três xícaras para chá, e seus pires, em porcelana esm', 100.0, 'lance r$ 100', 'VM Escritório de Arte', 'https://vmescritarteleiloes.com.br/peca.asp?Id=31093299', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62422/31093299.jpg', '2026-06-18 20:00', 12.9, 'baixa', 'baixo', -85.0, null, 'queued', '{"uf": "SP", "house_name": "VM Escritório de Arte", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 19.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$239", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('santayana-com-br-31214720', 'santayana-com-br-31214720', '2026-w24-curada-visual', 'Linda violeteira em porcelana francesa Limoges de 18x7 cm, com estampa', 100.0, 'lance r$ 100', 'Santayana Leilões', 'https://santayana.com.br/peca.asp?Id=31214720', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62339/31214720.jpg', '2026-06-22 19:00', 12.8, 'baixa', 'baixo', -85.0, null, 'queued', '{"uf": "RS", "house_name": "Santayana Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": 19.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$237", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176620', 'rrdeco-com-br-30176620', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176620', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176620.jpg', '2026-07-16 15:00', 12.7, 'baixa', 'medio', -193.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -102.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$350", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176346', 'rrdeco-com-br-30176346', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176346', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176346.jpg', '2026-07-16 15:00', 12.7, 'baixa', 'medio', -193.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -102.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$350", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176260', 'rrdeco-com-br-30176260', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176260', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176260.jpg', '2026-07-16 15:00', 12.7, 'baixa', 'medio', -193.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -102.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$350", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176850', 'rrdeco-com-br-30176850', '2026-w24-curada-visual', 'RR Antiguidades Antigo e rara colher comemorativa em prata de lei. Pec', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176850', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176850.jpg', '2026-07-18 18:00', 12.7, 'baixa', 'medio', -193.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -102.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$350", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31202998', 'casaamarelaleiloes-net-br-31202998', '2026-w24-curada-visual', 'Par de pequenos cinzeiros de prata de lei contrastada, borda recortada', 200.0, 'lance r$ 200', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31202998', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31202998.jpg', null, 12.7, 'baixa', 'medio', -193.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -102.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$350", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('jotamleiloes-com-br-31024164', 'jotamleiloes-com-br-31024164', '2026-w24-curada-visual', 'PRATA DE LEI, par (2) de fivelas de sapato confeccionadas em PRATA DE ', 200.0, 'lance r$ 200', 'Imperial JM Leilões', 'https://jotamleiloes.com.br/peca.asp?Id=31024164', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61324/31024164.jpg', null, 12.7, 'baixa', 'medio', -193.0, null, 'queued', '{"uf": null, "house_name": "Imperial JM Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -102.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$350", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('jotamleiloes-com-br-31076184', 'jotamleiloes-com-br-31076184', '2026-w24-curada-visual', 'TERMO-REY, três (3) tigelas confeccionados em vidro opalinado na tonal', 172.0, 'lance r$ 172', 'Imperial JM Leilões', 'https://jotamleiloes.com.br/peca.asp?Id=31076184', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61324/31076184.jpg', null, 12.6, 'baixa', 'medio', -148.0, null, 'queued', '{"uf": null, "house_name": "Imperial JM Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -40.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$295", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leiloeslemos-com-br-31160863', 'leiloeslemos-com-br-31160863', '2026-w24-curada-visual', 'Rosenthal Selb-Germany Helena. Xícara de café com pires e prato de bol', 120.0, 'lance r$ 120', 'Leilões Lemos', 'https://leiloeslemos.com.br/peca.asp?Id=31160863', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62442/31160863.jpg', null, 12.3, 'baixa', 'baixo', -96.0, null, 'queued', '{"uf": null, "house_name": "Leilões Lemos", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 504, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": 15.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["rosenthal", "upside ~r$233", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-30944578', 'prochicleiloes-com-br-30944578', '2026-w24-curada-visual', 'Lote de castiçal em porcelana, castiçal, vaso e enfeite em demicristal', 40.0, 'lance r$ 40', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=30944578', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62121/30944578.jpg', null, 11.4, 'baixa', 'medio', -40.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -1.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$233", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rosanavaleleiloes-com-br-30188755', 'rosanavaleleiloes-com-br-30188755', '2026-w24-curada-visual', 'WMF - Vaso Jungendstil, em cristal transparente e lapidado, com boca e', 360.0, 'lance r$ 360', 'Rosana Vale Leilões', 'https://rosanavaleleiloes.com.br/peca.asp?Id=30188755', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60441/30188755.jpg', '2026-06-16 19:00', 10.8, 'baixa', 'medio', -242.0, null, 'queued', '{"uf": "RJ", "house_name": "Rosana Vale Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 792, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 468, "est_gross_profit": -53.0, "max_bid_40pct": 118.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["wmf", "upside ~r$249", "teto p/ dobrar r$118", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-30884068', 'paulaoantiguidades-com-br-30884068', '2026-w24-curada-visual', 'VISTA ALEGRE - CONJUNTO DE SEIS XÍCARAS DE CHÁ COM PIRES EM PORCELANA ', 120.0, 'lance r$ 120', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=30884068', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/30884068.jpg', '2026-06-18 19:00', 10.7, 'baixa', 'baixo', -105.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -2.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$218", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063575', 'rrdeco-com-br-31063575', '2026-w24-curada-visual', 'RR Antiguidades  Antigo pequeno prato decorativo em porcelana Francesa', 120.0, 'lance r$ 120', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063575', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063575.jpg', '2026-07-09 18:00', 10.7, 'baixa', 'baixo', -105.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -2.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$216", "teto p/ dobrar r$15", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-31033028', 'prochicleiloes-com-br-31033028', '2026-w24-curada-visual', 'Lote de vaso solifleur em porcelana, cinzeiro em vidro e castiçal em m', 45.0, 'lance r$ 45', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=31033028', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62121/31033028.jpg', null, 10.7, 'baixa', 'medio', -45.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -7.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$228", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063049', 'rrdeco-com-br-31063049', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 230.0, 'lance r$ 230', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063049', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063049.jpg', '2026-07-11 13:00', 10.5, 'baixa', 'medio', -223.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -134.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$318", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176971', 'rrdeco-com-br-30176971', '2026-w24-curada-visual', 'RR Antiguidades Antigo e raro Estilete com cabo confeccionado em prata', 230.0, 'lance r$ 230', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176971', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176971.jpg', '2026-07-17 18:00', 10.5, 'baixa', 'medio', -223.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -134.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$318", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176962', 'rrdeco-com-br-30176962', '2026-w24-curada-visual', 'RR Antiguidades Antigo e raro Instrumento de Manicure, Lamina com cabo', 230.0, 'lance r$ 230', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176962', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176962.jpg', '2026-07-17 18:00', 10.5, 'baixa', 'medio', -223.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -134.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$318", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30996161', 'rrdeco-com-br-30996161', '2026-w24-curada-visual', 'RR Antiguidades  Antigo porta joias em porcelana com belissimos detalh', 240.0, 'lance r$ 240', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30996161', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62089/30996161.jpg', null, 9.8, 'baixa', 'medio', -233.0, null, 'queued', '{"uf": null, "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -144.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$308", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tamiriscarvalholeiloeira-com-br-30252927', 'tamiriscarvalholeiloeira-com-br-30252927', '2026-w24-curada-visual', 'Ane em prata 925 masculino com Orixa no centro OGUM / Aro: 24 / Peso: ', 250.0, 'lance r$ 250', 'Tamiris Carvalho Leiloeira', 'https://tamiriscarvalholeiloeira.com.br/peca.asp?Id=30252927', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61656/30252927.jpg', '2026-06-15 19:00', 9.1, 'baixa', 'medio', -243.0, null, 'queued', '{"uf": "RJ", "house_name": "Tamiris Carvalho Leiloeira", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -155.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$297", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-31033288', 'prochicleiloes-com-br-31033288', '2026-w24-curada-visual', 'Lote de vaso floreira em porcelana, castiçal em porcelana e cachepot e', 60.0, 'lance r$ 60', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=31033288', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62121/31033288.jpg', null, 8.9, 'baixa', 'medio', -60.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -22.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$212", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rioarteleiloes-com-br-31107283', 'rioarteleiloes-com-br-31107283', '2026-w24-curada-visual', 'Porta-caixa de fósforos em prata esterlina inglesa (.925), de linhas s', 260.0, 'lance r$ 260', 'Rio Arte Leilões', 'https://rioarteleiloes.com.br/peca.asp?Id=31107283', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62093/31107283.jpg', null, 8.4, 'baixa', 'medio', -253.0, null, 'queued', '{"uf": null, "house_name": "Rio Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -165.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$287", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('paulaoantiguidades-com-br-31103867', 'paulaoantiguidades-com-br-31103867', '2026-w24-curada-visual', 'ESCULTURA EM PRATA DE LEI TEOR 925 MLS REPRESENTANDO UM VIOLNISTA DO E', 220.0, 'lance r$ 220', 'Leilões Paulão antiguidades', 'https://paulaoantiguidades.com.br/peca.asp?Id=31103867', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61966/31103867.jpg', '2026-06-18 19:00', 8, 'baixa', 'medio', -220.0, null, 'queued', '{"uf": "RJ", "house_name": "Leilões Paulão antiguidades", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 234, "est_gross_profit": -183.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$269", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tamiriscarvalholeiloeira-com-br-30252177', 'tamiriscarvalholeiloeira-com-br-30252177', '2026-w24-curada-visual', 'Cordão em prata 925 masculino / tam: 58cm / Peso: 16,8grs', 298.0, 'lance r$ 298', 'Tamiris Carvalho Leiloeira', 'https://tamiriscarvalholeiloeira.com.br/peca.asp?Id=30252177', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61656/30252177.jpg', '2026-06-15 19:00', 8, 'baixa', 'medio', -291.0, null, 'queued', '{"uf": "RJ", "house_name": "Tamiris Carvalho Leiloeira", "material": "prata & metal", "size_label": "grande", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -205.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$247", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31026529', 'antiguitati-com-br-31026529', '2026-w24-curada-visual', 'Excepcional caixa em opalina azul finamente decorada com flores em pol', 250.0, 'lance r$ 250', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31026529', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31026529.jpg', '2026-06-18 19:00', 8, 'baixa', 'medio', -226.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -121.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$213", "teto p/ dobrar r$24", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('delonleiloes-com-br-30939457', 'delonleiloes-com-br-30939457', '2026-w24-curada-visual', 'Magnífico Lustre Pendente com Cúpula em Vidro Opalinado Séc. XX. |  Es', 200.0, 'lance r$ 200', 'Delon Leilões', 'https://delonleiloes.com.br/peca.asp?Id=30939457', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61492/30939457.jpg', '2026-06-16 19:00', 8, 'baixa', 'medio', -200.0, null, 'queued', '{"uf": "RJ", "house_name": "Delon Leilões", "material": "cristal & vidro", "size_label": "médio", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 270, "est_gross_profit": -129.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$206", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vapordaarte-com-br-31154736', 'vapordaarte-com-br-31154736', '2026-w24-curada-visual', 'Grande Placa Prata de lei Nossa Senhora de Fátima Peso total 39g. medi', 380.0, 'lance r$ 380', 'Vapor da Arte Leilões', 'https://vapordaarte.com.br/peca.asp?Id=31154736', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62450/31154736.jpg', '2026-06-15 16:00', 8, 'baixa', 'medio', -373.0, null, 'queued', '{"uf": "SP", "house_name": "Vapor da Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -291.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$161", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120012', 'marirodriguesleiloeira-com-br-31120012', '2026-w24-curada-visual', 'Açucareiro inglês em prata 925 mls, de elegante feitura em estilo Art ', 400.0, 'lance r$ 400', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120012', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120012.jpg', '2026-06-17 15:00', 8, 'baixa', 'medio', -393.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -312.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$140", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('anamelloleiloeira-com-br-30103010', 'anamelloleiloeira-com-br-30103010', '2026-w24-curada-visual', 'ROSENTHAL - Prato de bolo em porcelana alemã com tema floral e ricamen', 220.0, 'lance r$ 220', 'Ana Mello Leiloeira', 'https://anamelloleiloeira.com.br/peca.asp?Id=30103010', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60770/30103010.jpg', '2026-06-17 19:00', 8, 'baixa', 'baixo', -196.0, null, 'queued', '{"uf": "RJ", "house_name": "Ana Mello Leiloeira", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 504, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -90.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["rosenthal", "upside ~r$128", "teto p/ dobrar r$24", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120122', 'marirodriguesleiloeira-com-br-31120122', '2026-w24-curada-visual', 'SAINT-LOUIS  Licoreiro em cristal overlay vermelho, padrão Trianon. Fr', 440.0, 'lance r$ 440', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120122', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120122.jpg', '2026-06-16 15:00', 8, 'baixa', 'medio', -433.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -354.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$98", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rosanavaleleiloes-com-br-29880152', 'rosanavaleleiloes-com-br-29880152', '2026-w24-curada-visual', 'Art Déco - Par de candelabros provavelmente europeus, em vidro artísti', 120.0, 'lance r$ 120', 'Rosana Vale Leilões', 'https://rosanavaleleiloes.com.br/peca.asp?Id=29880152', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60441/29880152.jpg', '2026-06-16 19:00', 8, 'baixa', 'medio', -120.0, null, 'queued', '{"uf": "RJ", "house_name": "Rosana Vale Leilões", "material": "prata & metal", "size_label": "médio", "price_sale": 414, "price_band": "até R$ 800", "era": "art déco", "size_class": "medio", "est_resale_base": 162, "est_gross_profit": -145.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$89", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120365', 'marirodriguesleiloeira-com-br-31120365', '2026-w24-curada-visual', 'Conjunto em prata europeia contrastada, composto por porta-paliteiro e', 450.0, 'lance r$ 450', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120365', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120365.jpg', '2026-06-15 15:00', 8, 'baixa', 'medio', -443.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -365.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$87", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('santayana-com-br-30909794', 'santayana-com-br-30909794', '2026-w24-curada-visual', 'Bomba para chimarrão em prata de lei com bocal e detalhes em ouro baix', 520.0, 'lance r$ 520', 'Santayana Leilões', 'https://santayana.com.br/peca.asp?Id=30909794', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61474/30909794.jpg', '2026-06-15 14:00', 8, 'baixa', 'medio', -513.0, null, 'queued', '{"uf": "RS", "house_name": "Santayana Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -438.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$14", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vmescritarteleiloes-com-br-31074617', 'vmescritarteleiloes-com-br-31074617', '2026-w24-curada-visual', 'Estojo contendo doze colheres para café em prata de lei nacional compo', 550.0, 'lance r$ 550', 'VM Escritório de Arte', 'https://vmescritarteleiloes.com.br/peca.asp?Id=31074617', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62422/31074617.jpg', '2026-06-17 20:00', 8, 'baixa', 'medio', -543.0, null, 'queued', '{"uf": "SP", "house_name": "VM Escritório de Arte", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -470.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-18", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('ciclosleiloes-com-br-31191405', 'ciclosleiloes-com-br-31191405', '2026-w24-curada-visual', 'CASTIÇAL / Escultura Lindíssimo porta velas com figura de Jovem anjo c', 228.0, 'lance r$ 228', 'Ciclos Leilões', 'https://ciclosleiloes.com.br/peca.asp?Id=31191405', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61115/31191405.jpg', '2026-06-18 14:00', 8, 'baixa', 'medio', -228.0, null, 'queued', '{"uf": "RS", "house_name": "Ciclos Leilões", "material": "prata & metal", "size_label": "médio", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 162, "est_gross_profit": -259.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$-24", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tamiriscarvalholeiloeira-com-br-30252916', 'tamiriscarvalholeiloeira-com-br-30252916', '2026-w24-curada-visual', 'Cordão em prata 925 masculino / Tam: 72cm / Peso: 35grs', 630.0, 'lance r$ 630', 'Tamiris Carvalho Leiloeira', 'https://tamiriscarvalholeiloeira.com.br/peca.asp?Id=30252916', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61656/30252916.jpg', '2026-06-15 19:00', 8, 'baixa', 'medio', -623.0, null, 'queued', '{"uf": "RJ", "house_name": "Tamiris Carvalho Leiloeira", "material": "prata & metal", "size_label": "grande", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -554.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-102", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vmescritarteleiloes-com-br-31088240', 'vmescritarteleiloes-com-br-31088240', '2026-w24-curada-visual', 'Par de porta-ovo poché, com présentoir, lavrado em prata de lei norte-', 750.0, 'lance r$ 750', 'VM Escritório de Arte', 'https://vmescritarteleiloes.com.br/peca.asp?Id=31088240', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62422/31088240.jpg', '2026-06-17 20:00', 8, 'baixa', 'medio', -743.0, null, 'queued', '{"uf": "SP", "house_name": "VM Escritório de Arte", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -680.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-228", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120009', 'marirodriguesleiloeira-com-br-31120009', '2026-w24-curada-visual', 'Cigarreira de bolso em prata de lei 925 sterling, de elegante desenho ', 800.0, 'lance r$ 800', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120009', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120009.jpg', '2026-06-16 15:00', 8, 'baixa', 'medio', -793.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -732.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-280", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('danielchaiebleiloeiro-com-br-31098863', 'danielchaiebleiloeiro-com-br-31098863', '2026-w24-curada-visual', 'Antigo conjunto de jarra e bacia em porcelana francesa de Limoges deco', 600.0, 'lance r$ 600', 'Daniel Chaieb - Leiloeiro Oficial', 'https://danielchaiebleiloeiro.com.br/peca.asp?Id=31098863', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62501/31098863.jpg', '2026-06-18 14:00', 8, 'baixa', 'baixo', -585.0, null, 'queued', '{"uf": "RS", "house_name": "Daniel Chaieb - Leiloeiro Oficial", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -506.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$-288", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120072', 'marirodriguesleiloeira-com-br-31120072', '2026-w24-curada-visual', 'Cinzeiro de prata portuguesa do Porto, contraste Águia, II Título, 833', 900.0, 'lance r$ 900', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120072', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120072.jpg', '2026-06-16 15:00', 8, 'baixa', 'medio', -893.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -837.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-385", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('tamiriscarvalholeiloeira-com-br-30253426', 'tamiriscarvalholeiloeira-com-br-30253426', '2026-w24-curada-visual', 'Cordão em prata 925 masculino / Tam: 58cm / Peso:35grs', 950.0, 'lance r$ 950', 'Tamiris Carvalho Leiloeira', 'https://tamiriscarvalholeiloeira.com.br/peca.asp?Id=30253426', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61656/30253426.jpg', '2026-06-15 19:00', 8, 'baixa', 'medio', -943.0, null, 'queued', '{"uf": "RJ", "house_name": "Tamiris Carvalho Leiloeira", "material": "prata & metal", "size_label": "grande", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -890.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-438", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31130465', 'marirodriguesleiloeira-com-br-31130465', '2026-w24-curada-visual', 'BOLSA FEMININA  Bolsa de mão em prata de lei, com estrutura superior r', 980.0, 'lance r$ 980', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31130465', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31130465.jpg', '2026-06-17 15:00', 8, 'baixa', 'medio', -973.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -921.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-469", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('bruceangeirasleiloeiro-com-br-31203646', 'bruceangeirasleiloeiro-com-br-31203646', '2026-w24-curada-visual', 'PRATA - Vaso elaborado em prata 800 (contraste no fundo) apresentando ', 1000.0, 'lance r$ 1.000', 'Bruce Angeiras Leilões', 'https://bruceangeirasleiloeiro.com.br/peca.asp?Id=31203646', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62664/31203646.jpg', '2026-06-16 19:00', 8, 'baixa', 'medio', -993.0, null, 'queued', '{"uf": "RJ", "house_name": "Bruce Angeiras Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -942.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-490", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vapordaarte-com-br-31154802', 'vapordaarte-com-br-31154802', '2026-w24-curada-visual', 'Caixa Prata de Lei Oval com tampa incrustada. Pedra de Ágata  138g. Pe', 1100.0, 'lance r$ 1.100', 'Vapor da Arte Leilões', 'https://vapordaarte.com.br/peca.asp?Id=31154802', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62450/31154802.jpg', '2026-06-15 16:00', 8, 'baixa', 'medio', -1093.0, null, 'queued', '{"uf": "SP", "house_name": "Vapor da Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1047.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-595", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120042', 'marirodriguesleiloeira-com-br-31120042', '2026-w24-curada-visual', 'Conjunto composto por 2 copos e 2 porta-guardanapos em prata de lei. A', 1140.0, 'lance r$ 1.140', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120042', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120042.jpg', '2026-06-15 15:00', 8, 'baixa', 'medio', -1133.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1089.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-637", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120254', 'marirodriguesleiloeira-com-br-31120254', '2026-w24-curada-visual', 'BACCARAT  Conjunto com 8 taças para vinho em cristal overlay rubi, com', 1800.0, 'lance r$ 1.800', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120254', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120254.jpg', '2026-06-16 15:00', 8, 'baixa', 'baixo', -1564.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -1334.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$-661", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120253', 'marirodriguesleiloeira-com-br-31120253', '2026-w24-curada-visual', 'BACCARAT  Conjunto com 8 taças para vinho em cristal overlay rubi, com', 1800.0, 'lance r$ 1.800', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120253', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120253.jpg', '2026-06-16 15:00', 8, 'baixa', 'baixo', -1564.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -1334.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$-661", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vmescritarteleiloes-com-br-31091307', 'vmescritarteleiloes-com-br-31091307', '2026-w24-curada-visual', 'Aparelho para jantar de porcelana esmaltada francesa, manufatura de Li', 1000.0, 'lance r$ 1.000', 'VM Escritório de Arte', 'https://vmescritarteleiloes.com.br/peca.asp?Id=31091307', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62422/31091307.jpg', '2026-06-18 20:00', 8, 'baixa', 'baixo', -985.0, null, 'queued', '{"uf": "SP", "house_name": "VM Escritório de Arte", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -926.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$-708", "teto p/ dobrar r$15", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120367', 'marirodriguesleiloeira-com-br-31120367', '2026-w24-curada-visual', 'Elegante pegador de aspargos em prata de lei alemã, teor 800 mls, apre', 1250.0, 'lance r$ 1.250', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120367', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120367.jpg', '2026-06-15 15:00', 8, 'baixa', 'medio', -1243.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1205.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-753", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31130534', 'marirodriguesleiloeira-com-br-31130534', '2026-w24-curada-visual', 'COMENDA DA ORDEM DO LIBERTADOR  Venezuela, conjunto honorífico compost', 1200.0, 'lance r$ 1.200', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31130534', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31130534.jpg', '2026-06-16 15:00', 8, 'baixa', 'medio', -1200.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 234, "est_gross_profit": -1212.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-760", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vapordaarte-com-br-31161897', 'vapordaarte-com-br-31161897', '2026-w24-curada-visual', 'Par de saleiros europeu prata de lei - 163gr - 8 x 5 x 6', 1300.0, 'lance r$ 1.300', 'Vapor da Arte Leilões', 'https://vapordaarte.com.br/peca.asp?Id=31161897', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62450/31161897.jpg', '2026-06-15 16:00', 8, 'baixa', 'medio', -1293.0, null, 'queued', '{"uf": "SP", "house_name": "Vapor da Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1257.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-805", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31003545', 'antiguitati-com-br-31003545', '2026-w24-curada-visual', 'Cristallerie BACCARAT -  Raro conjunto de licoreira e seis copos de pé', 2200.0, 'lance r$ 2.200', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31003545', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31003545.jpg', '2026-06-18 19:00', 8, 'baixa', 'baixo', -1964.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -1754.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$-1081", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120366', 'marirodriguesleiloeira-com-br-31120366', '2026-w24-curada-visual', 'Açucareiro com a respectiva concha em prata inglesa contrastada, teor ', 1600.0, 'lance r$ 1.600', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120366', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120366.jpg', '2026-06-15 15:00', 8, 'baixa', 'medio', -1593.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1572.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-1120", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120135', 'marirodriguesleiloeira-com-br-31120135', '2026-w24-curada-visual', 'BACCARAT  Conjunto com 4 belíssimas e raras taças em cristal double ru', 2401.0, 'lance r$ 2.401', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120135', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120135.jpg', '2026-06-16 15:00', 8, 'baixa', 'baixo', -2165.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -1965.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$-1292", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31125950', 'marirodriguesleiloeira-com-br-31125950', '2026-w24-curada-visual', 'Caixa retangular confeccionada em prata de lei 900 mls, com tampa leve', 2200.0, 'lance r$ 2.200', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31125950', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31125950.jpg', '2026-06-17 15:00', 8, 'baixa', 'medio', -2193.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -2202.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-1750", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rosanavaleleiloes-com-br-30188788', 'rosanavaleleiloes-com-br-30188788', '2026-w24-curada-visual', 'Paliteiro em prata sem contraste base quadrangular sustentando travess', 2500.0, 'lance r$ 2.500', 'Rosana Vale Leilões', 'https://rosanavaleleiloes.com.br/peca.asp?Id=30188788', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60441/30188788.jpg', '2026-06-16 19:00', 8, 'baixa', 'medio', -2493.0, null, 'queued', '{"uf": "RJ", "house_name": "Rosana Vale Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -2517.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-2065", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vmescritarteleiloes-com-br-31077586', 'vmescritarteleiloes-com-br-31077586', '2026-w24-curada-visual', 'Urna, com tampa, de prata de lei brasileira, contraste "MFS Coroa", te', 2600.0, 'lance r$ 2.600', 'VM Escritório de Arte', 'https://vmescritarteleiloes.com.br/peca.asp?Id=31077586', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62422/31077586.jpg', '2026-06-17 20:00', 8, 'baixa', 'medio', -2600.0, null, 'queued', '{"uf": "SP", "house_name": "VM Escritório de Arte", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 234, "est_gross_profit": -2682.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-2230", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31030237', 'antiguitati-com-br-31030237', '2026-w24-curada-visual', 'Sévres - Rara e excepcional caixa em porcelana de Sévres, marca no fun', 4500.0, 'lance r$ 4.500', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31030237', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31030237.jpg', '2026-06-18 19:00', 8, 'baixa', 'medio', -4176.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 2700, "price_band": "R$ 2.500 +", "era": null, "size_class": "peq/med", "est_resale_base": 900, "est_gross_profit": -3998.0, "max_bid_40pct": 324.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["sevres", "upside ~r$-2324", "teto p/ dobrar r$324", "junho"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31026520', 'antiguitati-com-br-31026520', '2026-w24-curada-visual', 'Rara e excepcional fruteira em opalina de Baccarat, finamente decorada', 3500.0, 'lance r$ 3.500', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31026520', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31026520.jpg', '2026-06-18 19:00', 8, 'baixa', 'baixo', -3264.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 716, "est_gross_profit": -3119.0, "max_bid_40pct": 236.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$-2446", "teto p/ dobrar r$236", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('antiguitati-com-br-31030238', 'antiguitati-com-br-31030238', '2026-w24-curada-visual', 'Berlin - Raríssima Snuff Box em porcelana da manufatura Berlin, montag', 3000.0, 'lance r$ 3.000', 'Antiguitati Leilões', 'https://antiguitati.com.br/peca.asp?Id=31030238', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62159/31030238.jpg', '2026-06-18 19:00', 8, 'baixa', 'medio', -2993.0, null, 'queued', '{"uf": "RJ", "house_name": "Antiguitati Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -3042.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-2590", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vapordaarte-com-br-31161793', 'vapordaarte-com-br-31161793', '2026-w24-curada-visual', 'Par de Candelabro de prata de lei Sterling 925 - 900gr - 16 x 20 diâme', 8500.0, 'lance r$ 8.500', 'Vapor da Arte Leilões', 'https://vapordaarte.com.br/peca.asp?Id=31161793', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62450/31161793.jpg', '2026-06-15 16:00', 8, 'baixa', 'medio', -8500.0, null, 'queued', '{"uf": "SP", "house_name": "Vapor da Arte Leilões", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 234, "est_gross_profit": -8877.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-8425", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120522', 'marirodriguesleiloeira-com-br-31120522', '2026-w24-curada-visual', 'Lustre francês para seis luzes, executado em elegante estrutura metáli', 12000.0, 'lance r$ 12.000', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120522', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120522.jpg', '2026-06-17 15:00', 8, 'baixa', 'baixo', -11821.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "cristal & vidro", "size_label": "médio", "price_sale": 1440, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "medio", "est_resale_base": 716, "est_gross_profit": -12104.0, "max_bid_40pct": 179.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["baccarat", "upside ~r$-11431", "teto p/ dobrar r$179", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('santayana-com-br-30909877', 'santayana-com-br-30909877', '2026-w24-curada-visual', 'Bandeja em prata de lei 833, pesando 1,9 kg., com gravação na superfíc', 13300.0, 'lance r$ 13.300', 'Santayana Leilões', 'https://santayana.com.br/peca.asp?Id=30909877', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61474/30909877.jpg', '2026-06-15 14:00', 8, 'baixa', 'medio', -13293.0, null, 'queued', '{"uf": "RS", "house_name": "Santayana Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -13857.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-13405", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vapordaarte-com-br-31154766', 'vapordaarte-com-br-31154766', '2026-w24-curada-visual', 'Floreira em prata de lei alemã século XIX, fino acabamento em prata ci', 13500.0, 'lance r$ 13.500', 'Vapor da Arte Leilões', 'https://vapordaarte.com.br/peca.asp?Id=31154766', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62450/31154766.jpg', '2026-06-15 16:00', 8, 'baixa', 'medio', -13493.0, null, 'queued', '{"uf": "SP", "house_name": "Vapor da Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -14067.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-13615", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('vapordaarte-com-br-31198612', 'vapordaarte-com-br-31198612', '2026-w24-curada-visual', 'Sopeira em Prata de Lei e Presentoir em Prata de Lei Contraste Águia 8', 18000.0, 'lance r$ 18.000', 'Vapor da Arte Leilões', 'https://vapordaarte.com.br/peca.asp?Id=31198612', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62450/31198612.jpg', '2026-06-15 16:00', 8, 'baixa', 'medio', -17993.0, null, 'queued', '{"uf": "SP", "house_name": "Vapor da Arte Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -18792.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-18340", "teto p/ dobrar r$7", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('marirodriguesleiloeira-com-br-31120360', 'marirodriguesleiloeira-com-br-31120360', '2026-w24-curada-visual', 'Par de belíssimos e elegantes candelabros em prata brasileira fundida ', 22450.0, 'lance r$ 22.450', 'Marilaine Rodrigues - Leiloeira Pública', 'https://marirodriguesleiloeira.com.br/peca.asp?Id=31120360', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61251/31120360.jpg', '2026-06-15 15:00', 8, 'baixa', 'medio', -22450.0, null, 'queued', '{"uf": "RJ", "house_name": "Marilaine Rodrigues - Leiloeira Pública", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 234, "est_gross_profit": -23525.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-23073", "teto p/ dobrar r$0", "junho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176891', 'rrdeco-com-br-30176891', '2026-w24-curada-visual', 'RR Antiguidades Antigo e raro abotoador de sapatos com cabo confeccion', 270.0, 'lance r$ 270', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176891', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176891.jpg', '2026-07-16 15:00', 8, 'baixa', 'medio', -263.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -176.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$276", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176385', 'rrdeco-com-br-30176385', '2026-w24-curada-visual', 'RR Antiguidades Antiga colher comemorativa confeccionada em prata de l', 280.0, 'lance r$ 280', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176385', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176385.jpg', '2026-07-17 18:00', 8, 'baixa', 'medio', -273.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -186.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$266", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176680', 'rrdeco-com-br-30176680', '2026-w24-curada-visual', 'RR Antiguidades Antigo raro prato decorativo confeccionado em porcelan', 290.0, 'lance r$ 290', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176680', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176680.jpg', '2026-07-17 18:00', 8, 'baixa', 'medio', -283.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -197.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$255", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176864', 'rrdeco-com-br-30176864', '2026-w24-curada-visual', 'RR Antiguidades Antiga pequena Salva em prata de lei Portuguesa beliss', 300.0, 'lance r$ 300', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176864', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176864.jpg', '2026-07-16 15:00', 8, 'baixa', 'medio', -293.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -207.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$245", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176736', 'rrdeco-com-br-30176736', '2026-w24-curada-visual', 'RR Antiguidades Antiga pequena Salva em prata de lei Portuguesa beliss', 300.0, 'lance r$ 300', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176736', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176736.jpg', '2026-07-17 18:00', 8, 'baixa', 'medio', -293.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -207.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$245", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176483', 'rrdeco-com-br-30176483', '2026-w24-curada-visual', 'RR Antiguidades Antiga pequena Salva em prata de lei Portuguesa beliss', 300.0, 'lance r$ 300', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176483', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176483.jpg', '2026-07-18 18:00', 8, 'baixa', 'medio', -293.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -207.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$245", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176322', 'rrdeco-com-br-30176322', '2026-w24-curada-visual', 'RR Antiguidades Antiga pequena Salva em prata de lei Portuguesa beliss', 300.0, 'lance r$ 300', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176322', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176322.jpg', '2026-07-18 18:00', 8, 'baixa', 'medio', -293.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -207.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$245", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063569', 'rrdeco-com-br-31063569', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 320.0, 'lance r$ 320', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063569', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063569.jpg', '2026-07-09 18:00', 8, 'baixa', 'medio', -313.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -228.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$224", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176451', 'rrdeco-com-br-30176451', '2026-w24-curada-visual', 'RR Antiguidades Antigo trio de colheres comemorativas em prata de lei.', 350.0, 'lance r$ 350', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176451', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176451.jpg', '2026-07-16 15:00', 8, 'baixa', 'medio', -343.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -260.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$192", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30177102', 'rrdeco-com-br-30177102', '2026-w24-curada-visual', 'RR Antiguidades Antiga rara agulha confeccionada em metal e cabo em pr', 390.0, 'lance r$ 390', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30177102', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30177102.jpg', '2026-07-17 18:00', 8, 'baixa', 'medio', -383.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -302.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$150", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30177110', 'rrdeco-com-br-30177110', '2026-w24-curada-visual', 'RR Antiguidades Antigo castical confeccionado em bronze ricamente trab', 120.0, 'lance r$ 120', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30177110', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30177110.jpg', '2026-07-17 18:00', 8, 'baixa', 'medio', -120.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -85.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$149", "teto p/ dobrar r$0", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176302', 'rrdeco-com-br-30176302', '2026-w24-curada-visual', 'Antigo prato decorativo para parede em porcelana francesa pintada com ', 190.0, 'lance r$ 190', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176302', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176302.jpg', '2026-07-17 18:00', 8, 'baixa', 'baixo', -175.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -75.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$142", "teto p/ dobrar r$15", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30177039', 'rrdeco-com-br-30177039', '2026-w24-curada-visual', 'RR Antiguidades Antigo e diferenciado castical enfeite em vidro transl', 130.0, 'lance r$ 130', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30177039', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30177039.jpg', '2026-07-16 15:00', 8, 'baixa', 'medio', -130.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -96.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$139", "teto p/ dobrar r$0", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064062', 'rrdeco-com-br-31064062', '2026-w24-curada-visual', 'Antigo e diferenciado castical confeccionado em porcelana em formato d', 130.0, 'lance r$ 130', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064062', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064062.jpg', '2026-07-11 13:00', 8, 'baixa', 'medio', -130.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -96.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$139", "teto p/ dobrar r$0", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064040', 'rrdeco-com-br-31064040', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 420.0, 'lance r$ 420', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064040', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064040.jpg', '2026-07-10 13:00', 8, 'baixa', 'medio', -413.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -333.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$119", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063701', 'rrdeco-com-br-31063701', '2026-w24-curada-visual', 'Antigo e raro par de paliteiros confeccionados em porcelana com beliss', 490.0, 'lance r$ 490', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063701', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063701.jpg', '2026-07-10 13:00', 8, 'baixa', 'medio', -483.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -407.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$45", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064147', 'rrdeco-com-br-31064147', '2026-w24-curada-visual', 'Antigo e raro pequeno enfeite representando Flores confeccionado em pr', 500.0, 'lance r$ 500', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064147', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064147.jpg', '2026-07-10 13:00', 8, 'baixa', 'medio', -493.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -417.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$35", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064065', 'rrdeco-com-br-31064065', '2026-w24-curada-visual', 'Antigo e raro pequeno enfeite representando Flores confeccionado em pr', 500.0, 'lance r$ 500', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064065', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064065.jpg', '2026-07-10 13:00', 8, 'baixa', 'medio', -493.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -417.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$35", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176884', 'rrdeco-com-br-30176884', '2026-w24-curada-visual', 'RR Antiguidades Antigo diferenciado castical confeccionado em bronze c', 250.0, 'lance r$ 250', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176884', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176884.jpg', '2026-07-17 18:00', 8, 'baixa', 'medio', -250.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "bronze", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -222.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$13", "teto p/ dobrar r$0", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063430', 'rrdeco-com-br-31063430', '2026-w24-curada-visual', 'RRDECO ANTIGUIDADES Antigo e raro porta comprimidos confeccionado em p', 550.0, 'lance r$ 550', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063430', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063430.jpg', '2026-07-09 18:00', 8, 'baixa', 'medio', -543.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -470.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-18", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064260', 'rrdeco-com-br-31064260', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 550.0, 'lance r$ 550', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064260', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064260.jpg', '2026-07-10 13:00', 8, 'baixa', 'medio', -543.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -470.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-18", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063732', 'rrdeco-com-br-31063732', '2026-w24-curada-visual', 'Antigo e raro par de cinzeiros em prata de lei 925 com belissima decor', 650.0, 'lance r$ 650', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063732', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063732.jpg', '2026-07-11 13:00', 8, 'baixa', 'medio', -643.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -575.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-123", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31063482', 'rrdeco-com-br-31063482', '2026-w24-curada-visual', 'Antigo e raro porta joias confeccionado em porcelana Francesa decorado', 650.0, 'lance r$ 650', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31063482', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31063482.jpg', '2026-07-10 13:00', 8, 'baixa', 'baixo', -635.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -558.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$-341", "teto p/ dobrar r$15", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30176782', 'rrdeco-com-br-30176782', '2026-w24-curada-visual', 'RR Antiguidades Antiga Salva em prata de lei Portuguesa com belissima ', 980.0, 'lance r$ 980', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30176782', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/60187/30176782.jpg', '2026-07-16 15:00', 8, 'baixa', 'medio', -973.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -921.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-469", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-31064004', 'rrdeco-com-br-31064004', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 1600.0, 'lance r$ 1.600', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=31064004', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62091/31064004.jpg', '2026-07-09 18:00', 8, 'baixa', 'medio', -1593.0, null, 'queued', '{"uf": "RJ", "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1572.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-1120", "teto p/ dobrar r$7", "julho"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('prochicleiloes-com-br-30971079', 'prochicleiloes-com-br-30971079', '2026-w24-curada-visual', 'Lote de faca de fruta e abre cartas com pega em prata de lei. Medidas:', 320.0, 'lance r$ 320', 'Pró Chic Leilões', 'https://prochicleiloes.com.br/peca.asp?Id=30971079', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62060/30971079.jpg', null, 8, 'baixa', 'medio', -313.0, null, 'queued', '{"uf": null, "house_name": "Pró Chic Leilões", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -228.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$224", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leocolecoes-com-br-31128979', 'leocolecoes-com-br-31128979', '2026-w24-curada-visual', 'Candelabro antigo em porcelana, em bom estado de conservação', 20.0, 'lance r$ 20', 'Leo Antiguidade e coleções', 'https://leocolecoes.com.br/peca.asp?Id=31128979', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62511/31128979.jpg', null, 8, 'baixa', 'medio', -20.0, null, 'queued', '{"uf": null, "house_name": "Leo Antiguidade e coleções", "material": "prata & metal", "size_label": "médio", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 162, "est_gross_profit": -40.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$194", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-30909637', 'shoppingdosantiquarios-lel-br-30909637', '2026-w24-curada-visual', 'Par de travessas em porcelana portuguesa Vista Alegre. Decoração de fl', 150.0, 'lance r$ 150', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=30909637', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/30909637.jpg', null, 8, 'baixa', 'baixo', -135.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -33.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$186", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-30876545', 'casaamarelaleiloes-net-br-30876545', '2026-w24-curada-visual', 'Castiçal de bronze . Mede: 50 cm de alt', 100.0, 'lance r$ 100', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=30876545', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61976/30876545.jpg', null, 8, 'baixa', 'medio', -100.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "bronze", "size_label": "grande", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -64.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$170", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30996471', 'rrdeco-com-br-30996471', '2026-w24-curada-visual', 'RRDECO ANTIGUIDADES Antigo conjunto de 5 pratos de sobremesa confeccio', 300.0, 'lance r$ 300', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30996471', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62089/30996471.jpg', null, 8, 'baixa', 'medio', -276.0, null, 'queued', '{"uf": null, "house_name": "RR DECO Antiguidades", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -174.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$161", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leiloeslemos-com-br-31201618', 'leiloeslemos-com-br-31201618', '2026-w24-curada-visual', 'Vista Alegre  Modelo Jardim Roberto Simões  Conjunto com 5 pratos fund', 180.0, 'lance r$ 180', 'Leilões Lemos', 'https://leiloeslemos.com.br/peca.asp?Id=31201618', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62442/31201618.jpg', null, 8, 'baixa', 'baixo', -165.0, null, 'queued', '{"uf": null, "house_name": "Leilões Lemos", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -65.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$155", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('velhavelharialeiloes-com-br-31165503', 'velhavelharialeiloes-com-br-31165503', '2026-w24-curada-visual', 'CORRENTE EM PRATA 925 COM DESIGN DE ELOS TRANÇADOS, FREQUENTEMENTE IDE', 387.0, 'lance r$ 387', 'Velha Velharia Antiguidades', 'https://velhavelharialeiloes.com.br/peca.asp?Id=31165503', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62560/31165503.jpg', null, 8, 'baixa', 'medio', -380.0, null, 'queued', '{"uf": null, "house_name": "Velha Velharia Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -299.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$153", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('jotamleiloes-com-br-30234203', 'jotamleiloes-com-br-30234203', '2026-w24-curada-visual', 'BRONZE. um (1) castiçal confeccionado em bronze representando cobra na', 120.0, 'lance r$ 120', 'Imperial JM Leilões', 'https://jotamleiloes.com.br/peca.asp?Id=30234203', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61324/30234203.jpg', null, 8, 'baixa', 'medio', -120.0, null, 'queued', '{"uf": null, "house_name": "Imperial JM Leilões", "material": "bronze", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -85.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$149", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31010519', 'casaamarelaleiloes-net-br-31010519', '2026-w24-curada-visual', 'Duas molduras para porta retrato de prata de lei inglesa teor 925  fab', 400.0, 'lance r$ 400', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31010519', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61976/31010519.jpg', null, 8, 'baixa', 'medio', -393.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -312.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$140", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163538', 'shoppingdosantiquarios-lel-br-31163538', '2026-w24-curada-visual', 'Garfo de sobremesa em prata portuguesa, contraste "P Coroa", do século', 400.0, 'lance r$ 400', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163538', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163538.jpg', null, 8, 'baixa', 'medio', -393.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -312.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$140", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('aureaantiguidades-com-br-30123826', 'aureaantiguidades-com-br-30123826', '2026-w24-curada-visual', 'Caixa porta-pílulas ART DECÔ, Década de 20/30, em prata europeia, lavr', 400.0, 'lance r$ 400', 'Áurea Antiguidades', 'https://aureaantiguidades.com.br/peca.asp?Id=30123826', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61010/30123826.jpg', null, 8, 'baixa', 'medio', -393.0, null, 'queued', '{"uf": null, "house_name": "Áurea Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": "art déco", "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -312.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$140", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rioarteleiloes-com-br-31124520', 'rioarteleiloes-com-br-31124520', '2026-w24-curada-visual', 'CONJUNTO VISTA ALEGRE PARA CAFÉ / CHÁ, 4 PEÇAS.Conjunto em porcelana V', 200.0, 'lance r$ 200', 'Rio Arte Leilões', 'https://rioarteleiloes.com.br/peca.asp?Id=31124520', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62093/31124520.jpg', null, 8, 'baixa', 'baixo', -185.0, null, 'queued', '{"uf": null, "house_name": "Rio Arte Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 488, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -86.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["vista alegre", "upside ~r$134", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30996032', 'rrdeco-com-br-30996032', '2026-w24-curada-visual', 'Antigo e raro porta joias em porcelana pintada a mao. Peca estimada da', 200.0, 'lance r$ 200', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30996032', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62089/30996032.jpg', null, 8, 'baixa', 'baixo', -185.0, null, 'queued', '{"uf": null, "house_name": "RR DECO Antiguidades", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 486, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 252, "est_gross_profit": -86.0, "max_bid_40pct": 15.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["limoges", "upside ~r$132", "teto p/ dobrar r$15", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30996496', 'rrdeco-com-br-30996496', '2026-w24-curada-visual', 'RR Antiguidades  Antigo castical enfeite em vidro murano. Peca estimad', 160.0, 'lance r$ 160', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30996496', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62089/30996496.jpg', null, 8, 'baixa', 'medio', -160.0, null, 'queued', '{"uf": null, "house_name": "RR DECO Antiguidades", "material": "murano", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -127.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$107", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163763', 'shoppingdosantiquarios-lel-br-31163763', '2026-w24-curada-visual', 'Grande prato em porcelana alemã, marca da manufatura de Meissen, com d', 350.0, 'lance r$ 350', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163763', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163763.jpg', null, 8, 'baixa', 'baixo', -292.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 585, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 342, "est_gross_profit": -159.0, "max_bid_40pct": 58.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["meissen", "upside ~r$67", "teto p/ dobrar r$58", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('raildacosta-com-br-31113491', 'raildacosta-com-br-31113491', '2026-w24-curada-visual', 'DESPOJADOR - prata de lei 800, borda fenestrada decorada com guirlanda', 480.0, 'lance r$ 480', 'Railda Costa - Leiloeira Oficial', 'https://raildacosta.com.br/peca.asp?Id=31113491', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62402/31113491.jpg', null, 8, 'baixa', 'medio', -473.0, null, 'queued', '{"uf": null, "house_name": "Railda Costa - Leiloeira Oficial", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -396.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$56", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31154225', 'casaamarelaleiloes-net-br-31154225', '2026-w24-curada-visual', 'F. BARBEDIENNE. Escultura em bronze fundido com pátina marrom escura, ', 1300.0, 'lance r$ 1.300', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31154225', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31154225.jpg', null, 8, 'baixa', 'alto', -1188.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -999.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$55", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('jotamleiloes-com-br-30234190', 'jotamleiloes-com-br-30234190', '2026-w24-curada-visual', 'BRONZES, par (2) de candelabros para 3 velas confeccionados em bronze,', 180.0, 'lance r$ 180', 'Imperial JM Leilões', 'https://jotamleiloes.com.br/peca.asp?Id=30234190', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61324/30234190.jpg', null, 8, 'baixa', 'medio', -180.0, null, 'queued', '{"uf": null, "house_name": "Imperial JM Leilões", "material": "bronze", "size_label": "médio", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 162, "est_gross_profit": -208.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$26", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('rrdeco-com-br-30995687', 'rrdeco-com-br-30995687', '2026-w24-curada-visual', 'RR AntiguidadesCordao em prata de lei trabalhada. Peca em prata pura t', 520.0, 'lance r$ 520', 'RR DECO Antiguidades', 'https://rrdeco.com.br/peca.asp?Id=30995687', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62089/30995687.jpg', null, 8, 'baixa', 'medio', -513.0, null, 'queued', '{"uf": null, "house_name": "RR DECO Antiguidades", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -438.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$14", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31129510', 'casaamarelaleiloes-net-br-31129510', '2026-w24-curada-visual', 'Conjunto composto de: pequeno bowl de murano ass. Kosta Boda. 11 x 6 c', 400.0, 'lance r$ 400', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31129510', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31129510.jpg', null, 8, 'baixa', 'medio', -376.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "murano", "size_label": "pequeno", "price_sale": 576, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -279.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["murano assin/esc", "upside ~r$6", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31202441', 'casaamarelaleiloes-net-br-31202441', '2026-w24-curada-visual', 'Torso de bronze polido e rústico, sobre base de madeira patinado de pr', 1500.0, 'lance r$ 1.500', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31202441', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31202441.jpg', null, 8, 'baixa', 'alto', -1388.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -1209.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$-155", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31129490', 'casaamarelaleiloes-net-br-31129490', '2026-w24-curada-visual', 'Jacqueline Terpins. Elegante vaso de formato cilíndrico e silhueta lev', 800.0, 'lance r$ 800', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31129490', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31129490.jpg', null, 8, 'baixa', 'medio', -776.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "cristal & vidro", "size_label": "pequeno", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 270, "est_gross_profit": -699.0, "max_bid_40pct": 24.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$-364", "teto p/ dobrar r$24", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163546', 'shoppingdosantiquarios-lel-br-31163546', '2026-w24-curada-visual', 'Rara tamboladeira, provador de vinho, em prata francesa do século XVII', 900.0, 'lance r$ 900', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163546', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163546.jpg', null, 8, 'baixa', 'medio', -893.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -837.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-385", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('raildacosta-com-br-31113392', 'raildacosta-com-br-31113392', '2026-w24-curada-visual', 'CANDELABROS (par) - espessurados a prata pé circular pequeno guilhocha', 580.0, 'lance r$ 580', 'Railda Costa - Leiloeira Oficial', 'https://raildacosta.com.br/peca.asp?Id=31113392', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62402/31113392.jpg', null, 8, 'baixa', 'medio', -580.0, null, 'queued', '{"uf": null, "house_name": "Railda Costa - Leiloeira Oficial", "material": "prata & metal", "size_label": "médio", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 162, "est_gross_profit": -628.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$-394", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024872', 'wattenleiloes-com-br-31024872', '2026-w24-curada-visual', 'MEISSEN. LINDO PRATO FUNDO EM PORCELANA MEISSEN. CORES BRANCO, VERDE E', 800.0, 'lance r$ 800', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024872', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024872.jpg', null, 8, 'baixa', 'baixo', -742.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 585, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 342, "est_gross_profit": -632.0, "max_bid_40pct": 58.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["meissen", "upside ~r$-406", "teto p/ dobrar r$58", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31203024', 'casaamarelaleiloes-net-br-31203024', '2026-w24-curada-visual', 'Copo de prata de lei 833, regional, corpo em gomilados torcidos e barr', 1000.0, 'lance r$ 1.000', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31203024', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31203024.jpg', null, 8, 'baixa', 'medio', -993.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -942.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-490", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('leiloesrbraga-com-br-30959219', 'leiloesrbraga-com-br-30959219', '2026-w24-curada-visual', 'IMPONENTE CASTIÇAL EM CRISTAL SÉCULO PASSADO COM TRABALHO EM METAL EM ', 750.0, 'lance r$ 750', 'Leilões Braga', 'https://leiloesrbraga.com.br/peca.asp?Id=30959219', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61597/30959219.jpg', null, 8, 'baixa', 'medio', -750.0, null, 'queued', '{"uf": null, "house_name": "Leilões Braga", "material": "prata & metal", "size_label": "pequeno", "price_sale": 414, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 162, "est_gross_profit": -747.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["candelabro", "upside ~r$-512", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024818', 'wattenleiloes-com-br-31024818', '2026-w24-curada-visual', 'PRATO PORCELANA MEISSEN. RICA DECORAÇÃO EM RELEVO, REPRESENTANDO PARRE', 1200.0, 'lance r$ 1.200', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024818', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024818.jpg', null, 8, 'baixa', 'baixo', -1142.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 585, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 342, "est_gross_profit": -1052.0, "max_bid_40pct": 58.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["meissen", "upside ~r$-826", "teto p/ dobrar r$58", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31204187', 'casaamarelaleiloes-net-br-31204187', '2026-w24-curada-visual', 'Jarra decorativa de porcelana Capodimonte, polícroma e dourada. Corpo ', 1850.0, 'lance r$ 1.850', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31204187', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31204187.jpg', null, 8, 'baixa', 'baixo', -1706.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "porcelana & cerâmica", "size_label": "pequeno", "price_sale": 1184, "price_band": "R$ 800 – 1.500", "era": null, "size_class": "peq/med", "est_resale_base": 522, "est_gross_profit": -1567.0, "max_bid_40pct": 144.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["capodimonte", "upside ~r$-951", "teto p/ dobrar r$144", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163532', 'shoppingdosantiquarios-lel-br-31163532', '2026-w24-curada-visual', 'Conjunto de garfo trinchante e faca para assado em prata portuguesa, c', 1500.0, 'lance r$ 1.500', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163532', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163532.jpg', null, 8, 'baixa', 'medio', -1493.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1467.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-1015", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163392', 'shoppingdosantiquarios-lel-br-31163392', '2026-w24-curada-visual', 'Par de mostardeiras em prata inglesa vitoriana. Contraste da cidade de', 1500.0, 'lance r$ 1.500', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163392', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163392.jpg', null, 8, 'baixa', 'medio', -1493.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1467.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-1015", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163247', 'shoppingdosantiquarios-lel-br-31163247', '2026-w24-curada-visual', 'Espátula para peixe em prata portuguesa, contraste P Coroa, da Cidade ', 1500.0, 'lance r$ 1.500', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163247', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163247.jpg', null, 8, 'baixa', 'medio', -1493.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -1467.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-1015", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163437', 'shoppingdosantiquarios-lel-br-31163437', '2026-w24-curada-visual', 'Conjunto de garfo e espa´tula para peixe em prata inglesa vitoriana. C', 2500.0, 'lance r$ 2.500', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163437', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163437.jpg', null, 8, 'baixa', 'medio', -2493.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -2517.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-2065", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('wattenleiloes-com-br-31024859', 'wattenleiloes-com-br-31024859', '2026-w24-curada-visual', 'LINDÍSSIMO LUSTRE ESTILO OVERLAY EM OPALINA BRANCA, RICAMENTE DECORADO', 2500.0, 'lance r$ 2.500', 'Watten Leilões', 'https://wattenleiloes.com.br/peca.asp?Id=31024859', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62002/31024859.jpg', null, 8, 'baixa', 'medio', -2500.0, null, 'queued', '{"uf": null, "house_name": "Watten Leilões", "material": "cristal & vidro", "size_label": "médio", "price_sale": 630, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 270, "est_gross_profit": -2544.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["opalina", "upside ~r$-2209", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163771', 'shoppingdosantiquarios-lel-br-31163771', '2026-w24-curada-visual', 'JOE DESCOMPS (1869 - 1950) - Escultura em bronze Art Deco representand', 4500.0, 'lance r$ 4.500', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163771', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163771.jpg', null, 8, 'baixa', 'alto', -4388.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": "art déco", "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -4359.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$-3305", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31196597', 'casaamarelaleiloes-net-br-31196597', '2026-w24-curada-visual', 'Bela escultura de bronze dourado na figura de Samurai em suas vestes c', 5000.0, 'lance r$ 5.000', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31196597', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31196597.jpg', null, 8, 'baixa', 'alto', -4888.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -4884.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$-3830", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31201756', 'casaamarelaleiloes-net-br-31201756', '2026-w24-curada-visual', 'Gennaro CHIURAZZI. (1842-1906). Pandant de esculturas de bronze patina', 18000.0, 'lance r$ 18.000', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31201756', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31201756.jpg', null, 8, 'baixa', 'alto', -17888.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -18534.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$-17480", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('casaamarelaleiloes-net-br-31154532', 'casaamarelaleiloes-net-br-31154532', '2026-w24-curada-visual', 'Gennaro CHIURAZZI. (1842-1906). Chiurazzi Napoli, Furietti Centauros. ', 18000.0, 'lance r$ 18.000', 'Casa Amarela Leilões de Arte', 'https://casaamarelaleiloes.net.br/peca.asp?Id=31154532', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/62495/31154532.jpg', null, 8, 'baixa', 'alto', -17888.0, null, 'queued', '{"uf": null, "house_name": "Casa Amarela Leilões de Arte", "material": "bronze", "size_label": "médio", "price_sale": 1710, "price_band": "R$ 1.500 – 2.500", "era": null, "size_class": "medio", "est_resale_base": 576, "est_gross_profit": -18534.0, "max_bid_40pct": 112.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["bronze escult", "upside ~r$-17480", "teto p/ dobrar r$112", "sem data"], "risk_reasons": ["liquidez baixa", "acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31163952', 'shoppingdosantiquarios-lel-br-31163952', '2026-w24-curada-visual', 'Par de candelabros para 4 velas, reversíveis para castiçais. Prata por', 32000.0, 'lance r$ 32.000', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31163952', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31163952.jpg', null, 8, 'baixa', 'medio', -32000.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "médio", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "medio", "est_resale_base": 234, "est_gross_profit": -33552.0, "max_bid_40pct": 0.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-33100", "teto p/ dobrar r$0", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();
insert into curation_candidates (candidate_id, product_slug, batch_id, title, price_brl, price_label, source_house, source_url, image_url, auction_ends, score, priority, risk, headroom, bid_count, status, payload, refreshed_at)
values ('shoppingdosantiquarios-lel-br-31164083', 'shoppingdosantiquarios-lel-br-31164083', '2026-w24-curada-visual', 'Excepcional ostensório em prata brasileira. Contraste 10 dinheiros do ', 75000.0, 'lance r$ 75.000', 'Shopping dos Antiquários', 'https://shoppingdosantiquarios.lel.br/peca.asp?Id=31164083', 'https://d1o6h00a1h5k7q.cloudfront.net/imagens/img_m/61843/31164083.jpg', null, 8, 'baixa', 'medio', -74993.0, null, 'queued', '{"uf": null, "house_name": "Shopping dos Antiquários", "material": "prata & metal", "size_label": "pequeno", "price_sale": 720, "price_band": "até R$ 800", "era": null, "size_class": "peq/med", "est_resale_base": 234, "est_gross_profit": -78642.0, "max_bid_40pct": 7.0, "signal": "CURADA_VISUAL", "approved": false, "tier": null, "entry_reasons": ["prata lei/contr", "upside ~r$-78190", "teto p/ dobrar r$7", "sem data"], "risk_reasons": ["acima do teto p/ dobrar"]}'::jsonb, '2026-06-16T00:06:59Z')
on conflict (candidate_id) do update set
  product_slug=excluded.product_slug, batch_id=excluded.batch_id, title=excluded.title,
  price_brl=excluded.price_brl, price_label=excluded.price_label, source_house=excluded.source_house,
  source_url=excluded.source_url, image_url=excluded.image_url, auction_ends=excluded.auction_ends,
  score=excluded.score, priority=excluded.priority, risk=excluded.risk, headroom=excluded.headroom,
  bid_count=excluded.bid_count,
  status=case when curation_candidates.status in ('hidden','archived') then curation_candidates.status else 'queued' end,
  payload=excluded.payload, refreshed_at=excluded.refreshed_at, updated_at=now();

update curation_candidates set status='archived', updated_at=now()
where batch_id <> '2026-w24-curada-visual' and status='queued';
commit;
