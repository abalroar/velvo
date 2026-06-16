import Link from "next/link";

export default function SiteNav({ active }: { active?: "vitrine" | "studio" | null }) {
  return (
    <nav className="site-nav">
      <div className="site-nav__inner">
        <Link href="/" className="wordmark">velvo</Link>
        <div className="nav-links">
          <Link href="/vitrine" className={active === "vitrine" ? "on" : ""}>vitrine</Link>
          <Link href="/studio" className={active === "studio" ? "on" : ""}>curadoria</Link>
        </div>
      </div>
    </nav>
  );
}
