// vitrine — a loja. mostra só as peças escolhidas (decisão "fica" na mesa).
// é o "uma a uma": o que passou pela curadoria constitui a vitrine.
import { fetchStorefront, demoMode } from "@/lib/supabase";
import type { Candidate } from "@/lib/types";
import SiteNav from "@/components/site-nav";
import Vitrine from "@/components/vitrine";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function VitrinePage() {
  let feed: Candidate[] = [];
  try {
    feed = await fetchStorefront();
  } catch {
    feed = [];
  }

  return (
    <>
      <SiteNav active="vitrine" />
      <main className="shell">
        <header className="hero">
          <span className="label">a vitrine · peças escolhidas uma a uma</span>
          <h1>
            o que <em>ficou</em>.
          </h1>
          <p>
            cada peça aqui passou pela mesa de curadoria — escolhida uma a uma, pelo
            estado e pela forma. vidro, murano, cristal, bronze, porcelana e prata
            garimpados em leilões pelo brasil.
            {demoMode() ? " mostra a seleção atual em modo demonstração." : ""}
          </p>
        </header>
        {feed.length === 0 ? (
          <div className="empty-grid" style={{ paddingTop: 60 }}>
            <h3>a vitrine ainda está sendo montada</h3>
            <p>as peças aparecem aqui à medida que recebem “fica” na <a data-keep-case href="/studio">mesa de curadoria</a>.</p>
          </div>
        ) : (
          <Vitrine items={feed} />
        )}
      </main>
    </>
  );
}
