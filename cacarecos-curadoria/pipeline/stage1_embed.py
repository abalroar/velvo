"""Estágio 1 — similaridade visual com o acervo do Antônio (open-source, sem chave).

A régua do "bom gosto" vem das fotos das peças que o Antônio de fato vende.
Computamos embeddings das imagens dele uma vez (o "vetor de gosto"), e para cada
candidato medimos a similaridade de cosseno com a peça mais próxima do acervo.
Saída: antonio_fit_visual em [0,1], objetivo e reproduzível, sem prompt.

Usa open_clip (CLIP ViT-B/32) em CPU. Pesado de instalar, mas roda bem no cron.
Se as dependências/torch não estiverem presentes, o pipeline segue sem esta
coluna (score cai para margem+prazo) — assim o estágio 0 nunca fica bloqueado.
"""
import hashlib
import io
import urllib.request
from pathlib import Path

CACHE = Path(__file__).parent / "out" / "img_cache"
UA = "cacarecos-curadoria/0.1 (pesquisa de mercado; contato: matheusjprates@gmail.com)"


def _available() -> bool:
    try:
        import open_clip  # noqa: F401
        import torch  # noqa: F401
        from PIL import Image  # noqa: F401
        return True
    except Exception:
        return False


def _fetch(url: str) -> bytes | None:
    CACHE.mkdir(parents=True, exist_ok=True)
    cp = CACHE / (hashlib.sha1(url.encode()).hexdigest() + ".img")
    if cp.exists():
        return cp.read_bytes()
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        data = urllib.request.urlopen(req, timeout=20).read()
        cp.write_bytes(data)
        return data
    except Exception:
        return None


class Embedder:
    def __init__(self):
        import open_clip
        import torch

        self.torch = torch
        self.model, _, self.preprocess = open_clip.create_model_and_transforms(
            "ViT-B-32", pretrained="laion2b_s34b_b79k"
        )
        self.model.eval()

    def embed_urls(self, urls: list[str]):
        import numpy as np
        from PIL import Image

        vecs, idx = [], []
        for i, u in enumerate(urls):
            raw = _fetch(u)
            if not raw:
                continue
            try:
                img = Image.open(io.BytesIO(raw)).convert("RGB")
            except Exception:
                continue
            t = self.preprocess(img).unsqueeze(0)
            with self.torch.no_grad():
                v = self.model.encode_image(t)
                v = v / v.norm(dim=-1, keepdim=True)
            vecs.append(v.cpu().numpy()[0])
            idx.append(i)
        if not vecs:
            return np.zeros((0, 512)), []
        return np.vstack(vecs), idx


def antonio_fit(candidate_thumbs: list[str], antonio_image_urls: list[str]) -> list[float | None]:
    """Devolve antonio_fit_visual por candidato (mesma ordem). None se indisponível."""
    if not _available() or not antonio_image_urls:
        return [None] * len(candidate_thumbs)
    import numpy as np

    emb = Embedder()
    ant_vecs, _ = emb.embed_urls(antonio_image_urls)
    if ant_vecs.shape[0] == 0:
        return [None] * len(candidate_thumbs)
    cand_vecs, cand_idx = emb.embed_urls(candidate_thumbs)
    out: list[float | None] = [None] * len(candidate_thumbs)
    if cand_vecs.shape[0] == 0:
        return out
    sims = cand_vecs @ ant_vecs.T          # cosseno (vetores normalizados)
    nearest = sims.max(axis=1)             # similaridade à peça mais próxima do Antônio
    # normaliza de [~0.5,1] para [0,1] de forma estável
    for j, i in enumerate(cand_idx):
        out[i] = float(max(0.0, min(1.0, (nearest[j] - 0.5) / 0.5)))
    return out
