# velvo · studio (web)

next.js app router. a mesa de curadoria em `/studio`: uma peça por vez, imagem
grande, preço, casa, encerramento, razões de entrada, riscos, nota e
fica / talvez / passa, com link do lote.

tudo em caixa baixa. a fila vem do supabase **server-side** (a service role key
fica só no servidor; nunca vai pro browser). decisões vão para o supabase por
api route, também server-side. localstorage é só amortecedor: se a internet
cair na hora de decidir, a decisão fica em fila no navegador e é reenviada
depois — nunca é a fonte da verdade.

## rodar local

```bash
cp .env.example .env.local   # preencha SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY
npm install
npm run dev                  # http://localhost:3000/studio
```

## deploy na vercel

1. importe o repo na vercel com root directory = `velvo-curadoria/web`.
2. em project settings → environment variables, adicione:

   | nome | valor | escopo |
   |---|---|---|
   | `SUPABASE_URL` | `https://xxxx.supabase.co` | production + preview |
   | `SUPABASE_SERVICE_ROLE_KEY` | a service role (secreta) | production + preview |
   | `STUDIO_ACCESS_CODE` | senha opcional p/ trancar /studio | production + preview |

   nenhuma tem prefixo `NEXT_PUBLIC` — todas ficam no servidor.
3. deploy. a curadora abre `https://seu-app.vercel.app/studio` de qualquer pc.

se `STUDIO_ACCESS_CODE` estiver definido, o browser pede usuário/senha (basic
auth): usuário qualquer, senha = o código.

## endpoints

- `GET /studio` — renderiza a fila (server component lê `curation_feed`).
- `GET /api/curator/feed` — a fila em json (para refetch).
- `POST /api/curator/decisions` — `{ candidate_id, decision, note?, decided_by? }`,
  `decision ∈ {fica, talvez, passa}`.

## contrato com o pipeline

o app só depende do schema em `../supabase/schema.sql`. qualquer front (inclusive
o sitezinhoi do codex) que leia `curation_feed` e poste em
`/api/curator/decisions` com o mesmo formato funciona sem mudar o pipeline.
