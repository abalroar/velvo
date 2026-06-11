"""Cliente HTTP com rate limit global, cache em disco e retries.

Regras éticas: nunca burlar bloqueio — 403 persistente aborta a fase.
Cache evita repetir qualquer request já feito (re-runs quase gratuitos).
"""
import hashlib
import json
import time
from pathlib import Path

import requests

import config

_session = requests.Session()
_session.headers.update({"User-Agent": config.USER_AGENT})
_last_request_at = 0.0


class BlockedError(RuntimeError):
    """403/CAPTCHA persistente: parar a coleta, não contornar."""


def _cache_paths(url: str) -> tuple[Path, Path]:
    h = hashlib.sha1(url.encode()).hexdigest()
    return config.CACHE_DIR / f"{h}.html", config.CACHE_DIR / f"{h}.meta.json"


def get(url: str, use_cache: bool = True, allow_redirects: bool = True) -> str:
    """Retorna o corpo (texto) da URL, respeitando rate limit e cache."""
    global _last_request_at
    body_path, meta_path = _cache_paths(url)
    if use_cache and body_path.exists():
        return body_path.read_text(encoding="utf-8")

    config.CACHE_DIR.mkdir(parents=True, exist_ok=True)
    last_exc = None
    for attempt in range(config.MAX_RETRIES):
        wait = config.RATE_LIMIT_SECONDS - (time.monotonic() - _last_request_at)
        if wait > 0:
            time.sleep(wait)
        _last_request_at = time.monotonic()
        try:
            resp = _session.get(url, timeout=config.REQUEST_TIMEOUT,
                                allow_redirects=allow_redirects)
        except requests.RequestException as exc:
            last_exc = exc
            time.sleep(2 ** attempt)
            continue
        if resp.status_code == 403:
            raise BlockedError(f"403 em {url} — coleta interrompida por respeito ao site")
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
