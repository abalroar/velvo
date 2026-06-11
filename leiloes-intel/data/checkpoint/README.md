# Checkpoint de dados crus (comprimidos) para retomar a coleta caso o container recicle.
# leiloes.sqlite.gz: banco completo. cache.tar.gz: respostas HTTP cacheadas.
# Recriar: gunzip leiloes.sqlite.gz -> data/leiloes.sqlite ; tar xzf cache.tar.gz -C ../cache
