import { SupabaseClient, createClient } from "@supabase/supabase-js";

// O site usa a ANON key (pública). Ela só lê a fila e grava decisões — as
// políticas RLS impedem alterar a fila. O pipeline usa a service key (no cron).
// Cliente criado sob demanda (lazy) para não quebrar o build quando as env vars
// ainda não existem (prerender). Em runtime, no navegador, elas estão presentes.
let _client: SupabaseClient | null = null;

function client(): SupabaseClient {
  if (_client) return _client;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) {
    throw new Error(
      "Configure NEXT_PUBLIC_SUPABASE_URL e NEXT_PUBLIC_SUPABASE_ANON_KEY (.env.local / Vercel)."
    );
  }
  _client = createClient(url, anon, { auth: { persistSession: false } });
  return _client;
}

export type Candidate = {
  candidate_id: string;
  title: string;
  thumbnail_url: string;
  lot_url: string;
  uf: string | null;
  item_type: string | null;
  size_class: string | null;
  material: string | null;
  period_hint: string | null;
  condition_tier: string | null;
  is_pair_or_set: boolean | null;
  designer: string | null;
  attribution_strength: string | null;
  auction_datetime: string | null;
  current_bid_brl: number | null;
  comp_median: number | null;
  retail_anchor: number | null;
  est_allin_cost: number | null;
  est_margin_pct: number | null;
  max_bid_brl: number | null;
  antonio_fit_visual: number | null;
  suggested_name: string | null;
  score: number | null;
};

export type Verdict = "keep" | "pass" | "maybe";

export async function fetchFeed(limit = 50): Promise<Candidate[]> {
  const { data, error } = await client()
    .from("curation_feed")
    .select("*")
    .limit(limit);
  if (error) throw error;
  return (data ?? []) as Candidate[];
}

export async function decide(
  candidate_id: string,
  verdict: Verdict,
  note?: string
) {
  const { error } = await client()
    .from("decisions")
    .upsert(
      { candidate_id, verdict, note: note || null },
      { onConflict: "candidate_id" }
    );
  if (error) throw error;
}
