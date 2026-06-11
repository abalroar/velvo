# Checkpoint de dados crus (para retomar a coleta caso o container recicle)

- **cache.tar.gz** — todas as respostas HTTP cacheadas (fonte crua completa).
- O banco `data/leiloes.sqlite` é reconstruível a partir do cache:

```bash
mkdir -p cache && tar xzf data/checkpoint/cache.tar.gz -C cache
python run_all.py            # re-raspa lendo o cache (sem rede) e reprocessa
```

O SQLite comprimido passou de 100 MB (limite do GitHub), por isso não é
versionado — o cache acima cumpre o papel de recuperação.

Os entregáveis prontos ficam em `data/exports/` (inclui `lots.parquet`,
que o dashboard usa direto).
