// api server-side: registra a decisão da curadora no supabase.
// a service role key fica só aqui no servidor (vercel), nunca no browser.
import { NextRequest, NextResponse } from "next/server";

import { saveDecision, supabaseConfigured } from "@/lib/supabase";
import type { Decision } from "@/lib/types";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const VALID: Decision[] = ["fica", "talvez", "passa"];

export async function POST(req: NextRequest) {
  if (!supabaseConfigured()) {
    return NextResponse.json(
      { ok: false, error: "supabase não configurado no servidor" },
      { status: 503 },
    );
  }
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ ok: false, error: "json inválido" }, { status: 400 });
  }

  const candidate_id = String(body?.candidate_id || "").trim();
  const decision = String(body?.decision || "").trim() as Decision;
  if (!candidate_id || !VALID.includes(decision)) {
    return NextResponse.json(
      { ok: false, error: "candidate_id e decision (fica|talvez|passa) obrigatórios" },
      { status: 400 },
    );
  }

  try {
    await saveDecision({
      candidate_id,
      decision,
      note: body?.note ? String(body.note).slice(0, 2000) : null,
      decided_by: body?.decided_by ? String(body.decided_by).slice(0, 120) : null,
    });
    return NextResponse.json({ ok: true });
  } catch (err: any) {
    return NextResponse.json(
      { ok: false, error: err?.message || "falha ao salvar" },
      { status: 502 },
    );
  }
}
