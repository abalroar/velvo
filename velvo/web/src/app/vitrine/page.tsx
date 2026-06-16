// vitrine — a experiência do cliente final. lê a rodada curada (supabase real
// ou seed local em modo demonstração) e a apresenta como catálogo navegável,
// com filtros por material, tamanho, preço e época.
import { fetchFeed, demoMode } from "@/lib/supabase";
import type { Candidate } from "@/lib/types";
import SiteNav from "@/components/site-nav";
import Vitrine from "@/components/vitrine";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function VitrinePage() {
  let feed: Candidate[] = [];
  try {
    feed = await fetchFeed();
  } catch {
    feed = [];
  }

  return (
    <>
      <SiteNav active="vitrine" />
      <main className="shell">
        <header className="hero">
          <span className="label">objetos garimpados · curadoria velvo</span>
          <h1>
            peças <em>raras</em>, escolhidas uma a uma.
          </h1>
          <p>
            vidro soprado, murano, cristal lapidado, bronze, porcelana de manufatura e prata —
            garimpados em leilões pelo brasil e selecionados pelo olho, não pelo volume.
            {demoMode() ? " mostra a rodada atual em modo demonstração." : ""}
          </p>
        </header>
        <Vitrine items={feed} />
      </main>
    </>
  );
}
