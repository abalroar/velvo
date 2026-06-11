"""Fase 0: descoberta best-effort de dados públicos de leilões finalizados
e venda pós-pregão (preço de martelo). Não burla nada: só lê HTML/JS público
e testa URLs candidatas encontradas neles. Resultados em recon_findings."""
import re
from datetime import datetime
from urllib.parse import urljoin

import config
import db
import http_client

PAGES = [
    f"{config.BASE_URL}/",
    f"{config.BASE_URL}/leiloesfinalizados.asp",
    f"{config.BASE_URL}/catalogo.asp",
]

ASP_RE = re.compile(r"""["'(]([a-z_0-9/]+\.asp(?:\?[^"')\s]*)?)["')]""", re.I)
AJAX_RE = re.compile(r"""["']((?:https?:)?//[^"']*ajax[^"']*|/?ajax/[^"']+)["']""", re.I)
SCRIPT_RE = re.compile(r'<script[^>]+src="([^"]+)"', re.I)
POSPREGAO_RE = re.compile(r'href="([^"]*p[oó]s[^"]*pregao[^"]*|[^"]*pospregao[^"]*)"', re.I)


def log(conn, url, kind, note):
    conn.execute("INSERT INTO recon_findings (url, kind, note, scraped_at) VALUES (?,?,?,?)",
                 (url, kind, note[:500], datetime.now().strftime("%Y-%m-%dT%H:%M:%S")))
    conn.commit()
    print(f"[{kind}] {url} :: {note[:120]}")


def main():
    conn = db.connect()
    endpoints, scripts = set(), set()
    for page in PAGES:
        try:
            html = http_client.get(page)
        except Exception as exc:
            log(conn, page, "erro", str(exc))
            continue
        for m in POSPREGAO_RE.finditer(html):
            log(conn, urljoin(page, m.group(1)), "pospregao_link", "link de pós-pregão na página")
        for m in AJAX_RE.finditer(html):
            endpoints.add(urljoin(page, m.group(1)))
        for m in SCRIPT_RE.finditer(html):
            src = urljoin(page, m.group(1))
            if "googletagmanager" not in src and "gtag" not in src:
                scripts.add(src)
    # procurar endpoints dentro dos JS próprios do site
    for src in sorted(scripts)[:12]:
        try:
            js = http_client.get(src)
        except Exception:
            continue
        for m in ASP_RE.finditer(js):
            cand = m.group(1)
            if any(k in cand.lower() for k in ("final", "pregao", "encerr", "lista", "busca", "json")):
                endpoints.add(urljoin(config.BASE_URL + "/", cand))
        for m in AJAX_RE.finditer(js):
            endpoints.add(urljoin(config.BASE_URL + "/", m.group(1)))
    # testar candidatos (GET simples; sem brute force)
    for ep in sorted(endpoints)[:15]:
        if "infosite_whats" in ep:
            continue
        try:
            body = http_client.get(ep)
        except Exception as exc:
            log(conn, ep, "candidato_erro", str(exc))
            continue
        is_json = body.lstrip()[:1] in "[{"
        has_price = "R$" in body and re.search(r"\d+,\d{2}", body) is not None
        log(conn, ep, "candidato",
            f"json={is_json} preco={has_price} bytes={len(body)} amostra={body.strip()[:150]!r}")
    print("\nRecon concluído. Ver tabela recon_findings.")


if __name__ == "__main__":
    main()
