"""Auditoria: assertions automáticas + amostra de 30 lotes para conferência
manual contra as páginas originais. Imprime taxa de erro estimada."""
import random

import db


def check(name, ok, detail=""):
    status = "OK " if ok else "FALHA"
    print(f"[{status}] {name} {detail}")
    return ok


def run():
    conn = db.connect()
    fails = 0

    n_lots = conn.execute("SELECT COUNT(*) FROM lots").fetchone()[0]
    fails += not check("lotes no banco", n_lots > 0, f"({n_lots})")

    # parse de preço: % de snapshots com algum valor
    snaps = conn.execute("SELECT COUNT(*) FROM lot_snapshots").fetchone()[0]
    priced = conn.execute(
        "SELECT COUNT(*) FROM lot_snapshots WHERE COALESCE(current_bid_brl,opening_bid_brl,hammer_price_brl) IS NOT NULL"
    ).fetchone()[0]
    rate = priced / snaps if snaps else 0
    fails += not check("snapshots com preço ≥95%", rate >= 0.95, f"({rate:.1%})")

    # nenhum mojibake típico
    moji = conn.execute(
        "SELECT COUNT(*) FROM lots WHERE title LIKE '%Ã©%' OR title LIKE '%Ã£%' OR title LIKE '%�%'"
    ).fetchone()[0]
    fails += not check("sem mojibake em títulos", moji == 0, f"({moji} suspeitos)")

    # bid_count não-negativo
    neg = conn.execute("SELECT COUNT(*) FROM lot_snapshots WHERE bid_count < 0").fetchone()[0]
    fails += not check("bid_count não-negativo", neg == 0, f"({neg})")

    # BUY_NOW exige atribuição ≥ STATED quando há designer
    bad = conn.execute(
        """SELECT COUNT(*) FROM lot_enrichment
           WHERE signal='BUY_NOW' AND designer IS NOT NULL
             AND attribution_strength IN ('STYLE_OF','MATERIAL_HINT','NONE')""").fetchone()[0]
    fails += not check("BUY_NOW com designer tem atribuição ≥ STATED", bad == 0, f"({bad})")

    # martelo só em lotes vendidos
    bad2 = conn.execute(
        "SELECT COUNT(*) FROM lot_snapshots WHERE hammer_price_brl > 0 AND sold!=1").fetchone()[0]
    fails += not check("martelo apenas em vendidos", bad2 == 0, f"({bad2})")

    # cobertura de comps
    comps = conn.execute("SELECT COUNT(*) FROM lot_snapshots WHERE sold=1 AND hammer_price_brl>0").fetchone()[0]
    fails += not check("comps de martelo suficientes", comps >= 500, f"({comps})")

    print("\n── Amostra de 30 lotes para conferência manual ──")
    rows = conn.execute(
        """SELECT l.house_domain, l.lot_id, l.title, e.item_type_normalized, e.designer,
                  e.attribution_strength, e.signal, e.matched_keywords, l.lot_url
           FROM lots l JOIN lot_enrichment e USING(house_domain, lot_id)
           WHERE l.excluded_sensitive=0""").fetchall()
    with_designer = [r for r in rows if r["designer"]]
    buynow = [r for r in rows if r["signal"] == "BUY_NOW"]
    random.seed(42)
    sample = (random.sample(with_designer, min(10, len(with_designer)))
              + random.sample(buynow, min(10, len(buynow)))
              + random.sample(rows, min(10, len(rows))))
    for r in sample:
        t = (r["title"] or "")[:55]
        print(f"  {r['signal'] or '-':8} | {r['item_type_normalized']:18} | "
              f"{r['designer'] or '-':18} | {r['attribution_strength'] or '-':12} | {t}")
        print(f"           kw=[{r['matched_keywords'] or ''}] {r['lot_url']}")

    print(f"\nResultado: {'TODAS as assertions passaram' if fails == 0 else f'{fails} assertions falharam'}")
    return fails


if __name__ == "__main__":
    run()
