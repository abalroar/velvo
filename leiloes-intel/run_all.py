"""Orquestrador resumível. Cada fase grava no SQLite; o cache em disco torna
re-execuções quase gratuitas. Rode fases isoladas com os scripts individuais."""
import argparse

import enrich
import metrics
import report
import scrape_finalizados
import scrape_historico
import scrape_listings
import validate


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-scrape", action="store_true",
                    help="pula coleta, só re-processa (enrich/metrics/report/validate)")
    ap.add_argument("--max-finalized", type=int, default=0)
    ap.add_argument("--history-days", type=int, default=30,
                    help="janela do histórico por casa (0 = pular fase de histórico)")
    args = ap.parse_args()

    if not args.skip_scrape:
        print("== Fase 1-2: listagens ao vivo por categoria ==")
        import sys
        sys.argv = ["scrape_listings"]
        scrape_listings.main()
        print("\n== Fase 0b: leilões finalizados (martelo real) ==")
        sys.argv = ["scrape_finalizados"] + (["--max", str(args.max_finalized)] if args.max_finalized else [])
        scrape_finalizados.main()
        if args.history_days:
            print(f"\n== Fase 0c: histórico por casa ({args.history_days} dias) ==")
            sys.argv = ["scrape_historico", "--days", str(args.history_days)]
            scrape_historico.main()

    print("\n== Enriquecimento semântico ==")
    enrich.enrich_all()
    print("\n== Métricas e sinais ==")
    metrics.compute()
    print("\n== Exportação ==")
    report.main()
    print("\n== Validação ==")
    validate.run()


if __name__ == "__main__":
    main()
