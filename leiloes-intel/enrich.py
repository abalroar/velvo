"""Classificação semântica determinística (sem LLM, auditável).

Lê lots (título + descrição), grava lot_enrichment. Tudo é regenerável:
a tabela é limpa e reconstruída a cada execução. Cada inferência guarda
matched_keywords e matched_snippet para auditoria em segundos.
"""
import re
import unicodedata
from datetime import datetime

import config
import db


def normalize(text: str | None) -> str:
    if not text:
        return ""
    t = unicodedata.normalize("NFD", text)
    t = "".join(c for c in t if unicodedata.category(c) != "Mn")
    return re.sub(r"\s+", " ", t.lower()).strip()


def snippet_around(text: str, idx: int, width: int = 60) -> str:
    return text[max(0, idx - width): idx + width].strip()


def detect_item_type(norm: str) -> tuple[str, str]:
    for item_type, pattern, size in config.ITEM_TYPE_RULES:
        if re.search(pattern, norm):
            return item_type, size
    return "outro", "medium"


def detect_designer(norm: str) -> tuple[str | None, list[str], int]:
    """Retorna (designer_slug, keywords casadas, posição do match)."""
    for slug, aliases in config.DESIGNERS.items():
        for alias in aliases:
            if not alias:
                continue
            idx = norm.find(alias)
            if idx != -1:
                return slug, [alias], idx
    return None, [], -1


def detect_materials(norm: str) -> list[str]:
    return [m for m in config.NOBLE_MATERIALS if m in norm]


def detect_period(norm: str) -> str | None:
    for p in config.PERIOD_HINTS:
        if p in norm:
            return p
    return None


def attribution_strength(norm: str, designer: str | None, materials: list[str],
                         period: str | None, designer_idx: int) -> str:
    if designer:
        window = norm[max(0, designer_idx - 60): designer_idx + 60]
        if any(k in window for k in config.ATTR_STYLE_OF):
            return "STYLE_OF"
        if any(k in window for k in config.ATTR_ATTRIBUTED):
            return "ATTRIBUTED"
        if any(k in norm for k in config.ATTR_DOCUMENTED):
            return "DOCUMENTED"
        return "STATED"
    if materials and period:
        return "MATERIAL_HINT"
    return "NONE"


def condition_tier(norm: str) -> str:
    # Padrão = none: a maioria dos lotes é vendida no estado e revendida sem
    # restauro. "light"/"heavy" só com evidência explícita de desgaste/dano.
    if any(k in norm for k in ["no estado", "necessita restauro", "para restauro",
                                "com faltas", "danificad", "quebrad", "trincad", "faltando",
                                "restauro", "bicad", "lascad"]):
        return "heavy"
    if any(k in norm for k in ["marcas de uso", "sinais de uso", "desgaste",
                                "pequenos defeitos", "craquelad", "necessita limpeza"]):
        return "light"
    return "none"


def is_sensitive(norm: str) -> bool:
    return any(k in norm for k in config.SENSITIVE_KEYWORDS)


def is_pair_or_set(item_type: str, norm: str) -> bool:
    return ("par_" in item_type or "conjunto_" in item_type
            or bool(re.search(r"\bpar de\b|\bconjunto de\b|\bjogo de\b", norm)))


def enrich_all():
    conn = db.connect()
    conn.execute("DELETE FROM lot_enrichment")
    rows = conn.execute("SELECT house_domain, lot_id, title, description FROM lots").fetchall()
    now = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    sensitive_count = 0
    for r in rows:
        text = f"{r['title'] or ''} . {r['description'] or ''}"
        norm = normalize(text)
        sensitive = is_sensitive(norm)
        if sensitive:
            sensitive_count += 1
        item_type, size = detect_item_type(norm)
        designer, kws, didx = detect_designer(norm)
        materials = detect_materials(norm)
        period = detect_period(norm)
        attr = attribution_strength(norm, designer, materials, period, didx)
        cond = condition_tier(norm)
        pair = is_pair_or_set(item_type, norm)

        matched = []
        snippet = ""
        if designer:
            matched.append(f"designer:{kws[0]}")
            snippet = snippet_around(norm, didx)
        matched += [f"material:{m}" for m in materials]
        if period:
            matched.append(f"periodo:{period}")

        conn.execute(
            """INSERT OR REPLACE INTO lot_enrichment
               (house_domain, lot_id, item_type_normalized, macro_category, size_class,
                designer, attribution_strength, matched_keywords, matched_snippet, material,
                period_hint, condition_tier, is_pair_or_set)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (r["house_domain"], r["lot_id"], item_type, config.macro_of(item_type), size,
             designer, attr, ", ".join(matched), snippet, ", ".join(materials) or None,
             period, cond, 1 if pair else 0))
        # propaga flag sensível para lots
        if sensitive:
            conn.execute("UPDATE lots SET excluded_sensitive=1 WHERE house_domain=? AND lot_id=?",
                         (r["house_domain"], r["lot_id"]))
    conn.commit()
    print(f"Enriquecidos {len(rows)} lotes | sensíveis marcados: {sensitive_count}")
    designers = conn.execute(
        "SELECT designer, COUNT(*) c FROM lot_enrichment WHERE designer IS NOT NULL "
        "GROUP BY designer ORDER BY c DESC").fetchall()
    print("Designers detectados:", {d["designer"]: d["c"] for d in designers})


if __name__ == "__main__":
    enrich_all()
