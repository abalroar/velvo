import Link from "next/link";
import SiteNav from "@/components/site-nav";

export default function Home() {
  return (
    <>
      <SiteNav active={null} />
      <main className="shell">
        <section className="hero" style={{ borderBottom: 0 }}>
          <span className="label">curadoria de objetos & mobiliário vintage</span>
          <h1>
            o <em>garimpo</em> vira<br />vitrine.
          </h1>
          <p>
            garimpamos objetos de vidro, murano, cristal, bronze, porcelana e prata em
            leilões pelo brasil — peça a peça, pelo estado e pela forma. um olhar de galeria
            nórdica para o que o mercado ainda trata como lote.
          </p>
          <p style={{ marginTop: 30, display: "flex", gap: 18, flexWrap: "wrap" }}>
            <Link href="/vitrine" className="cta">ver a vitrine →</Link>
            <Link href="/studio" className="cta cta--ghost">mesa de curadoria</Link>
          </p>
        </section>
      </main>
    </>
  );
}
