"""Parâmetros objetivos do funil de curadoria.

Tudo que decide "o que a curadora enxerga" mora aqui — uma única fonte,
versionável. Mudar um número aqui muda o funil inteiro de forma reproduzível.
"""

# Categorias-alvo: o que o Antônio realmente vende (objetos decorativos curáveis),
# mais peças pequenas de mobiliário de apoio. Tudo fora disso não chega à curadora.
FIT_ITEM_TYPES = {
    "cristal_vidro",
    "porcelana_ceramica",
    "prata_metal",
    "objeto_decorativo",
    "escultura",
    "luminaria_lustre",
    "espelho",
    "mesa_lateral",
    "mesa_de_centro",
    "quadro_pintura",
    "gravura",
}

# Portes aceitos (logística simples). xl/large entram só para alguns tipos.
FIT_SIZE_CLASSES = {"small", "medium"}

# Frete estimado por porte (R$) — espelha leiloes-intel/assumptions.yaml.
FRETE_BRL = {"small": 80, "medium": 180, "large": 350, "xl": 600, None: 180}

# Ágio do comprador no leilão.
BUYER_PREMIUM_PCT = 0.05

# Markup de revenda sobre o martelo de comparáveis. Conservador: o spread real
# observado no Antônio é de 5–8x; usamos 2,5x para a régua de margem.
RETAIL_MARKUP_OVER_COMP = 2.5

# Piso de revenda por porte (R$) — uma peça curada não sai por menos que isto,
# mesmo que o comp da categoria seja baixo. Calibrado pela distribuição do Antônio.
RETAIL_FLOOR_BRL = {"small": 280, "medium": 420, "large": 700, "xl": 1200, None: 280}

# Só vê a curadora quem passa nestes cortes objetivos:
MIN_MARGIN_PCT = 0.45          # margem conservadora mínima
MAX_BID_VS_RETAIL = 0.50       # lance atual <= 50% da revenda estimada
MIN_COMPS = 30                 # categoria precisa de >=30 comps p/ ter mediana confiável

# Quantos candidatos manter na fila por rodada (ranqueados por score).
QUEUE_LIMIT = 600

# Pesos do score de ranqueamento (0..1 cada termo, normalizados).
W_MARGIN = 0.5                 # quão lucrativa
W_VISUAL = 0.35                # similaridade visual com o acervo do Antônio (estágio 1)
W_DEADLINE = 0.15              # urgência (leilão fechando antes)


def macro_ok(item_type: str) -> bool:
    return item_type in FIT_ITEM_TYPES
