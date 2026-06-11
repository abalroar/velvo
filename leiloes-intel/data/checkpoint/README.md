# Checkpoint de dados crus (para retomar a coleta caso o container recicle)

O cache HTTP completo está dividido em partes (limite de 100 MB/arquivo do GitHub).

## Restaurar
```bash
cd leiloes-intel
cat data/checkpoint/cache.tar.gz.part* > /tmp/cache.tar.gz
mkdir -p cache && tar xzf /tmp/cache.tar.gz -C cache
python run_all.py --skip-scrape   # reprocessa do banco; ou rode a coleta lendo o cache
```

O SQLite (`data/leiloes.sqlite`) é reconstruível a partir do cache e por isso
não é versionado. Os entregáveis prontos ficam em `data/exports/`
(`lots.parquet` é o que o dashboard usa).
