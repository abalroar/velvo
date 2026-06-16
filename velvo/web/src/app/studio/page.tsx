// mesa de curadoria. avalia a fila de todos os leilões em andamento; cada
// "fica" passa a constituir a vitrine. server component: lê a fila server-side.
import { fetchFeed, demoMode } from "@/lib/supabase";
import type { Candidate } from "@/lib/types";
import SiteNav from "@/components/site-nav";
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
      <>
        <SiteNav active="studio" />
        <div className="wrap">
          <div className="notice"><p>{error}</p></div>
        </div>
      </>
    );
  }

  const batch = feed[0]?.batch_id ?? null;
  return (
    <>
      <SiteNav active="studio" />
      <CuratorBoard initialFeed={feed} batchId={batch} demo={demoMode()} />
    </>
  );
}
