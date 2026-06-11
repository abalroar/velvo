"""Cliente HTTP com rate limit POR DOMÍNIO, cache em disco e retries.

Rate limit por domínio (não global): como a coleta cobre centenas de servidores
independentes, basta manter um ritmo educado por servidor. Várias casas podem
ser coletadas em paralelo sem sobrecarregar nenhum host individual. Backoff
exponencial em 429/5xx recua automaticamente se algum servidor reclamar.

Bloqueio (403) é respeitado: a casa que recusa o acesso é pulada, não burlada.
Cache evita repetir qualquer request já feito (re-runs quase gratuitos).
"""
import hashlib
import json
import threading
import time
from pathlib import Path
from urllib.parse import urlparse

import requests

import config

_session = requests.Session()
_session.headers.update({"User-Agent": config.USER_AGENT})
adapter = requests.adapters.HTTPAdapter(pool_connections=64, pool_maxsize=64)
_session.mount("https://", adapter)
_session.mount("http://", adapter)

# agendamento de próxima janela por domínio (thread-safe)
_sched_lock = threading.Lock()
_domain_next: dict[str, float] = {}


class BlockedError(RuntimeError):
    """403/CAPTCHA: a casa recusa o acesso. Pular e respeitar, não contornar."""


def _cache_paths(url: str) -> tuple[Path, Path]:
    h = hashlib.sha1(url.encode()).hexdigest()
    return config.CACHE_DIR / f"{h}.html", config.CACHE_DIR / f"{h}.meta.json"


def _throttle(url: str):
    """Reserva o próximo slot do domínio sob lock e dorme fora do lock.
    Garante espaçamento >= PER_DOMAIN_DELAY por servidor, mesmo com threads."""
    domain = urlparse(url).netloc.lower()
    delay = config.PER_DOMAIN_DELAY
    with _sched_lock:
        now = time.monotonic()
        start = max(now, _domain_next.get(domain, 0.0))
        _domain_next[domain] = start + delay
    wait = start - time.monotonic()
    if wait > 0:
        time.sleep(wait)


def get(url: str, use_cache: bool = True, allow_redirects: bool = True) -> str:
    """Retorna o corpo (texto) da URL, respeitando rate limit por domínio e cache."""
    body_path, meta_path = _cache_paths(url)
    if use_cache and body_path.exists():
        return body_path.read_text(encoding="utf-8")

    config.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    last_exc = None
    for attempt in range(config.MAX_RETRIES):
        _throttle(url)
        try:
            resp = _session.get(url, timeout=config.REQUEST_TIMEOUT,
                                allow_redirects=allow_redirects)
        except requests.RequestException as exc:
            last_exc = exc
            time.sleep(2 ** attempt)
            continue
        if resp.status_code == 403:
            raise BlockedError(f"403 em {url} — casa recusa o acesso; pulando")
        if resp.status_code == 429 or resp.status_code >= 500:
            time.sleep(5 * (attempt + 1))
            last_exc = RuntimeError(f"HTTP {resp.status_code} em {url}")
            continue
        if resp.status_code != 200:
            raise RuntimeError(f"HTTP {resp.status_code} em {url}")
        # resolve encoding: respeita charset declarado; senão, apparent
        if not resp.encoding or resp.encoding.lower() == "iso-8859-1":
            declared = "charset=" in (resp.headers.get("Content-Type") or "").lower()
            if not declared:
                resp.encoding = resp.apparent_encoding
        text = resp.text
        body_path.write_text(text, encoding="utf-8")
        meta_path.write_text(json.dumps({
            "url": url, "final_url": resp.url, "status": resp.status_code,
            "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "encoding": resp.encoding,
        }), encoding="utf-8")
        return text
    raise RuntimeError(f"Falha após {config.MAX_RETRIES} tentativas em {url}: {last_exc}")


def final_url(url: str) -> str | None:
    """URL final (pós-redirects) registrada no cache, se houver."""
    _, meta_path = _cache_paths(url)
    if meta_path.exists():
        return json.loads(meta_path.read_text(encoding="utf-8")).get("final_url")
    return None
