import Link from "next/link";

export default function Home() {
  return (
    <div className="wrap">
      <div className="topbar">
        <span className="brand">velvo</span>
      </div>
      <div className="notice">
        <p>mesa de curadoria interna.</p>
        <p>
          a fila e as decisões ficam em <Link href="/studio">/studio</Link> —
          rodada curada (vibe antonio): vidro, murano, esculturas e centros de mesa
          garimpados dos leilões abertos.
        </p>
      </div>
    </div>
  );
}
