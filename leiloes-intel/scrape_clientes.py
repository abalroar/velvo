"""Descobre TODAS as casas clientes da plataforma via clientes.asp (paginado)
e as registra em auction_houses. ~36 páginas, ~1 request/página."""
import re
from datetime import datetime

import config
import db
import http_client

CARD_RE = re.compile(
    r'href="https?://(?:www\.)?([a-z0-9.-]+)"[^>]*>\s*<img[^>]+alt="([^"]+)"', re.I)
LASTPAGE_RE = re.compile(r'clientes\.asp\?pag=(\d+)')
SKIP_DOMAINS = ("leiloesbr", "facebook", "instagram", "twitter", "youtube",
                "pinterest", "tiktok", "google", "cloudfront", "whatsapp")


def main():
    conn = db.connect()
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    first = http_client.get(f"{config.BASE_URL}/clientes.asp")
    last_page = max((int(m) for m in LASTPAGE_RE.findall(first)), default=1)
    print(f"Páginas de clientes: {last_page}")
    found = {}
    for page in range(1, last_page + 1):
        html = first if page == 1 else http_client.get(
            f"{config.BASE_URL}/clientes.asp?pag={page}")
        for domain, name in CARD_RE.findall(html):
            domain = domain.lower().strip(".")
            if any(s in domain for s in SKIP_DOMAINS):
                continue
            found.setdefault(domain, name.strip())
    novos = 0
    for domain, name in sorted(found.items()):
        cur = conn.execute(
            """INSERT INTO auction_houses (house_domain, name, first_seen, last_seen)
               VALUES (?,?,?,?)
               ON CONFLICT(house_domain) DO UPDATE SET
                 name=COALESCE(auction_houses.name, excluded.name),
                 last_seen=excluded.last_seen""",
            (domain, name, now, now))
        novos += cur.rowcount
    conn.commit()
    total = conn.execute("SELECT COUNT(*) FROM auction_houses").fetchone()[0]
    print(f"Clientes na vitrine: {len(found)} | casas no banco agora: {total}")


if __name__ == "__main__":
    main()
