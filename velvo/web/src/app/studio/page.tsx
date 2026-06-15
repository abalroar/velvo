// mesa de curadoria. server component: lê a fila do supabase server-side
// (service role nunca chega ao browser) e entrega ao board client.
import { fetchFeed, demoMode } from "@/lib/supabase";
import type { Candidate } from "@/lib/types";
import CuratorBoard from "@/components/curator-board";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function StudioPage() {
  let feed: Candidate[] = [];
  let error: string | null = null;
  try {
    feed = await fetchFeed();
  } catch (e: any) {
    error = e?.message || "falha ao ler a fila";
  }

  if (error) {
    return (
      <div className="wrap">
        <div className="topbar"><span className="brand">velvo · studio</span></div>
        <div className="notice"><p>{error}</p></div>
      </div>
    );
  }

  const batch = feed[0]?.batch_id ?? null;
  return <CuratorBoard initialFeed={feed} batchId={batch} demo={demoMode()} />;
}
