// camada server-only de acesso ao supabase via api rest (postgrest).
// usa a service role key, que NUNCA pode ir para o browser. nenhum import
// deste arquivo deve acontecer em componente client.
import "server-only";

import type { Candidate, Decision } from "./types";
import seedFeed from "./seed-feed.json";

const URL = process.env.SUPABASE_URL?.replace(/\/$/, "");
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

export function supabaseConfigured(): boolean {
  return Boolean(URL && KEY);
}

// modo demonstração: sem supabase configurado, a mesa roda com a rodada curada
// versionada em seed-feed.json (a mesma que o seed.sql escreveria no banco).
// assim o /studio renderiza de verdade num clone limpo (ex.: preview na :8080),
// sem nenhuma credencial externa. com as envs setadas, lê o supabase real.
export function demoMode(): boolean {
  return !supabaseConfigured();
}

function headers(extra: Record<string, string> = {}): Record<string, string> {
  return {
    apikey: KEY as string,
    authorization: `Bearer ${KEY}`,
    "content-type": "application/json",
    ...extra,
  };
}

// fila da mesa: a view curation_feed já entrega a rodada mais recente,
// só queued, sem os já decididos, ordenada por score desc, headroom desc.
export async function fetchFeed(limit = 600): Promise<Candidate[]> {
  if (!supabaseConfigured()) return (seedFeed as Candidate[]).slice(0, limit);
  const res = await fetch(
    `${URL}/rest/v1/curation_feed?select=*&limit=${limit}`,
    { headers: headers(), cache: "no-store" },
  );
  if (!res.ok) {
    throw new Error(`supabase feed ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) as Candidate[];
}

// grava (ou atualiza) a decisão da curadora. upsert por candidate_id.
export async function saveDecision(input: {
  candidate_id: string;
  decision: Decision;
  note?: string | null;
  decided_by?: string | null;
}): Promise<void> {
  if (!supabaseConfigured()) {
    // modo demonstração: aceita a decisão sem persistir (não há banco no preview).
    return;
  }
  const res = await fetch(
    `${URL}/rest/v1/curator_decisions?on_conflict=candidate_id`,
    {
      method: "POST",
      headers: headers({ prefer: "resolution=merge-duplicates,return=minimal" }),
      body: JSON.stringify({
        candidate_id: input.candidate_id,
        decision: input.decision,
        note: input.note ?? null,
        decided_by: input.decided_by ?? null,
        decided_at: new Date().toISOString(),
      }),
      cache: "no-store",
    },
  );
  if (!res.ok) {
    throw new Error(`supabase decision ${res.status}: ${await res.text()}`);
  }
}
