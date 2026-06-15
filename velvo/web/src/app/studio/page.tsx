// mesa de curadoria. server component: lê a fila do supabase server-side
// (service role nunca chega ao browser) e entrega ao board client.
import { fetchFeed, demoMode } from "@/lib/supabase";
import type { Candidate } from "@/lib/types";
import CuratorBoard from "@/components/curator-board";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function StudioPage({
  searchParams,
}: {
  searchParams?: { lista?: string };
}) {
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

  const totalCount = feed.length;
  const approvedCount = feed.filter((c) => c.payload?.approved).length;
  const view = searchParams?.lista === "aprovados" ? "aprovados" : "todos";
  const shown = view === "aprovados" ? feed.filter((c) => c.payload?.approved) : feed;

  const batch = shown[0]?.batch_id ?? feed[0]?.batch_id ?? null;
  return (
    <CuratorBoard
      initialFeed={shown}
      batchId={batch}
      demo={demoMode()}
      view={view}
      totalCount={totalCount}
      approvedCount={approvedCount}
    />
  );
}
