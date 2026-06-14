// api server-side opcional: devolve a fila atual (para refetch sem recarregar
// a página). também usa só a service role no servidor.
import { NextResponse } from "next/server";

import { fetchFeed, supabaseConfigured } from "@/lib/supabase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  if (!supabaseConfigured()) {
    return NextResponse.json({ ok: false, error: "supabase não configurado", feed: [] }, { status: 503 });
  }
  try {
    const feed = await fetchFeed();
    return NextResponse.json({ ok: true, feed });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err?.message || "falha", feed: [] }, { status: 502 });
  }
}
