import Link from "next/link";
import SiteNav from "@/components/site-nav";
import Lissajous from "@/components/lissajous";

export default function Home() {
  return (
    <>
      <SiteNav active={null} />
      <main className="shell">
        <section className="hero hero--art">
          <div className="lissa-wrap">
            <Lissajous a={3} b={4} />
          </div>
          <div className="hero__copy">
            <span className="label">curadoria de objetos &amp; mobiliário vintage</span>
            <h1>
              o <em>garimpo</em> vira vitrine.
            </h1>
            <p>
              garimpamos objetos de vidro, murano, cristal, bronze, porcelana e prata em
              leilões pelo brasil — peça a peça, pelo estado e pela forma. um olhar de
              galeria nórdica para o que o mercado ainda trata como lote.
            </p>
            <p className="hero__cta">
              <Link href="/vitrine" className="cta">ver a vitrine →</Link>
              <Link href="/sobre" className="cta cta--ghost">sobre</Link>
            </p>
          </div>
        </section>
      </main>
    </>
  );
}
