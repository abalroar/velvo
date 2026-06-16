import Link from "next/link";

export default function SiteNav({ active }: { active?: "vitrine" | "sobre" | "studio" | null }) {
  return (
    <nav className="site-nav">
      <div className="site-nav__inner">
        <Link href="/" className="brandblock">
          <span className="wordmark">uma.uma</span>
          <span className="tagline">objetos garimpados</span>
        </Link>
        <div className="nav-links">
          <Link href="/vitrine" className={active === "vitrine" ? "on" : ""}>vitrine</Link>
          <Link href="/sobre" className={active === "sobre" ? "on" : ""}>sobre</Link>
          <Link href="/studio" className={active === "studio" ? "on" : ""}>curadoria</Link>
        </div>
      </div>
    </nav>
  );
}
