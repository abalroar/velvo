"""Sobe um queue_seed.json já gerado para o Supabase (bootstrap rápido).

Útil para popular a fila na primeira vez sem precisar do banco de 920MB —
você gera o seed onde tem o leiloes.sqlite (ex.: Claude web / seu Mac) com
`run_pipeline.py --seed-only` e depois roda isto apontando para o Supabase.

  SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python push_seed.py
"""
import json
import math
import os
import urllib.request
from pathlib import Path

rows = json.loads((Path(__file__).parent / "out" / "queue_seed.json").read_text())
url = os.environ["SUPABASE_URL"].rstrip("/")
key = os.environ["SUPABASE_SERVICE_KEY"]
clean = [
    {k: (None if isinstance(v, float) and not math.isfinite(v) else v) for k, v in r.items()}
    for r in rows
]
req = urllib.request.Request(
    f"{url}/rest/v1/candidates?on_conflict=candidate_id",
    data=json.dumps(clean, ensure_ascii=False).encode(),
    method="POST",
    headers={
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    },
)
with urllib.request.urlopen(req, timeout=60) as resp:
    print(f"upsert {len(clean)} candidatos -> HTTP {resp.status}")
