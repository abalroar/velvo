"""Configuração central do leiloes-intel.

Somente páginas públicas, sem login. Coleta respeitosa: rate limit global,
cache em disco, user-agent identificável.
"""
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
CACHE_DIR = BASE_DIR / "cache"
EXPORTS_DIR = DATA_DIR / "exports"
DB_PATH = DATA_DIR / "leiloes.sqlite"

BASE_URL = "https://www.leiloesbr.com.br"
USER_AGENT = "baratex-market-research/0.1 (pesquisa de mercado; contato: matheusjprates@gmail.com)"
# Rate limit POR DOMÍNIO: cada servidor individual vê no máx. 1 req a cada N s.
# A velocidade global vem da paralelização entre casas (MAX_WORKERS), não de
# acelerar um único host.
PER_DOMAIN_DELAY = 1.0
RATE_LIMIT_SECONDS = PER_DOMAIN_DELAY  # compat
MAX_WORKERS = 8
REQUEST_TIMEOUT = 40
MAX_RETRIES = 3

# Categorias-alvo (nomes EXATOS da navegação do site; hex = latin-1).
# A tese é mobiliário modernista, arte, antiguidades e decoração.
TARGET_CATEGORIES = [
    "Mobiliário",
    "Móveis",
    "Cadeira",
    "Poltrona",
    "Sofá",
    "Mesa",
    "Mesa Auxiliar",
    "Mesa de Centro",
    "Aparador",
    "Banco",
    "Armário",
    "Estante",
    "Cama",
    "Espelhos",
    "Lustres",
    "Cristais",
    "Murano",
    "Vidro",
    "Porcelana",
    "Porcelanas / Cerâmicas",
    "Quadros",
    "Pinturas e Gravuras",
    "Gravuras",
    "Serigrafias",
    "Esculturas",
    "Bronze",
    "Pratas",
    "Prata de Lei",
    "Tapetes",
    "Tapeçaria",
]

# Categorias sensíveis/fora da tese: nunca coletadas; lotes que mencionem
# esses termos no título/descrição são marcados excluded_sensitive=1.
SENSITIVE_KEYWORDS = [
    "espada", "punhal", "adaga", "baioneta", "revolver", "pistola", "fuzil",
    "espingarda", "municao", "marfim", "presa de elefante", "taxidermia",
    "plumaria", "pele de onca", "carapaca de tartaruga", "erotic", "erotica",
    "nu artistico explicito",
]


def category_hex(name: str) -> str:
    """Codifica o nome da categoria como o site espera (hex de Latin-1)."""
    return name.encode("latin-1").hex().upper()


def search_url(name: str, page: int = 1, per_page: int = 126) -> str:
    return (
        f"{BASE_URL}/busca_andamento.asp?pesquisa=&gbl=0&op=2&v={per_page}"
        f"&tp=|{category_hex(name)}|&b=0&pag={page}"
    )


# ----------------------------------------------------------------------------
# Dicionário semântico (tudo em forma normalizada: sem acentos, minúsculas).
# enrich.normalize() aplica a mesma normalização ao texto antes do match.
# ----------------------------------------------------------------------------

# designer_slug -> lista de aliases normalizados
DESIGNERS = {
    "sergio_rodrigues": ["sergio rodrigues"],
    "joaquim_tenreiro": ["tenreiro"],
    "jorge_zalszupin": ["zalszupin", "l'atelier", "l atelier", "latelier"],
    "jose_zanine_caldas": ["zanine"],
    "lina_bo_bardi": ["lina bo bardi"],
    "percival_lafer": ["lafer"],
    "jean_gillon": ["jean gillon", "italma"],
    "hauner_eisler_forma": ["carlo hauner", "martin eisler", "moveis forma", "forma s.a", "forma moveis"],
    "geraldo_de_barros": ["geraldo de barros", "unilabor", "hobjeto"],
    "moveis_cimo": ["cimo"],
    "oca": ["moveis oca", " oca "],
    "celina": ["celina decoracoes", "moveis celina", "celina moveis"],
    "giuseppe_scapinelli": ["scapinelli"],
    "carlo_fongaro": ["fongaro"],
    "michel_arnoult": ["michel arnoult", "mobilia contemporanea"],
    "branco_e_preto": ["branco & preto", "branco e preto"],
    "dominici": ["dominici"],
    "lustres_pelotas": ["lustres pelotas"],
    "abraham_palatnik": ["palatnik"],
    "athos_bulcao": ["athos bulcao"],
    "burle_marx": ["burle marx"],
    "di_cavalcanti": ["di cavalcanti"],
    "portinari": ["portinari"],
    "volpi": ["volpi"],
    "djanira": ["djanira"],
    "tarsila": ["tarsila do amaral"],
    "ciccillo_others": [],  # placeholder p/ expansão
}

# materiais nobres / sinais de época (normalizados)
NOBLE_MATERIALS = [
    "jacaranda", "caviuna", "pau ferro", "peroba", "imbuia", "freijo",
    "cerejeira", "palhinha", "couro natural",
]
PERIOD_HINTS = [
    "anos 50", "anos 60", "anos 70", "decada de 50", "decada de 60",
    "decada de 70", "anos 1950", "anos 1960", "anos 1970", "midcentury",
    "mid century", "modernista", "modernismo", "brutalista",
]

# attribution_strength: keywords de contexto (normalizadas)
ATTR_DOCUMENTED = ["assinad", "etiqueta", "selo de", "marca de fogo", "certificado", "documentad", "plaqueta"]
ATTR_ATTRIBUTED = ["atribuid"]
ATTR_STYLE_OF = ["no estilo", "ao gosto", "a maneira de", "estilo de", "no gosto", "inspirad", "manner of"]

# item_type_normalized: (tipo, regex normalizada, size_class)
# Ordem importa: do mais específico para o mais genérico.
ITEM_TYPE_RULES = [
    ("par_de_poltronas",      r"par de poltronas|02 poltronas|2 poltronas|duas poltronas", "large"),
    ("conjunto_de_cadeiras",  r"(conjunto|jogo) de (\d+ )?cadeiras|\b(quatro|seis|oito|4|6|8|10|12) cadeiras", "large"),
    ("par_de_cadeiras",       r"par de cadeiras|02 cadeiras|2 cadeiras|duas cadeiras", "medium"),
    ("poltrona",              r"poltrona", "large"),
    ("sofa",                  r"\bsofa\b|\bcanape\b|\bnamoradeira\b", "xl"),
    ("cadeira",               r"cadeira", "medium"),
    ("banco",                 r"\bbanqueta\b|\bbanco\b|\bmocho\b", "medium"),
    ("mesa_de_centro",        r"mesa de centro", "large"),
    ("mesa_lateral",          r"mesa lateral|mesa auxiliar|mesa de apoio|mesa de canto", "medium"),
    ("mesa_de_jantar",        r"mesa de jantar|mesa eliptica|mesa redonda|mesa retangular", "xl"),
    ("escrivaninha",          r"escrivaninha|mesa desk|\bdesk\b|secretaire", "large"),
    ("carrinho_de_cha",       r"carrinho de cha|carrinho bar|carro de cha", "large"),
    ("mesa",                  r"\bmesa\b", "large"),
    ("aparador",              r"aparador|\bbuffet\b|\bbufe\b|credenza|balcao", "xl"),
    ("comoda",                r"\bcomoda\b|chiffonier|gaveteiro", "xl"),
    ("estante",               r"estante|prateleira", "xl"),
    ("armario",               r"armario|guarda roupa|guarda-roupa|roupeiro|arquivo", "xl"),
    ("cama",                  r"\bcama\b|cabeceira", "xl"),
    ("cristaleira",           r"cristaleira|vitrine", "xl"),
    ("escultura",             r"escultura|\bbusto\b|\btorso\b", "medium"),
    ("luminaria_lustre",      r"lustre|luminaria|abajur|plafon|arandela|pendente", "medium"),
    ("espelho",               r"espelho", "large"),
    ("tapete",                r"tapete|tapecaria", "large"),
    ("quadro_pintura",        r"oleo sobre|ost\b|osm\b|acrilica sobre|tecnica mista|pintura|\btela\b", "medium"),
    ("gravura",               r"gravura|serigrafia|litografia|xilogravura|linoleo", "small"),
    ("fotografia",            r"fotografia", "small"),
    # colecionáveis fora da tese (antes de prata/porcelana p/ ter prioridade de identidade)
    ("moeda",                 r"\bmoeda\b|\bmoedas\b|numismatic|cunhada em", "small"),
    ("cedula",                r"\bcedula\b|\bcedulas\b|papel moeda", "small"),
    ("medalha",               r"\bmedalha|comenda|condecorac", "small"),
    ("selo_filatelia",        r"\bselo\b|\bselos\b|filateli|carimbo postal|bloco postal|inteiro postal|sobrescrito", "small"),
    ("joia",                  r"\bjoia\b|\banel\b|\baneis\b|brinco|\bcolar\b|pulseira|gargantilha|pingente|\bbroche\b|bracelete|alianca|berloque|ouro 18k|ouro 750|brilhante|diamante", "small"),
    ("relogio",               r"\brelogio", "small"),
    ("disco_vinil",           r"\bvinil\b|long play|\bcompacto\b|\blp\b", "small"),
    ("livro",                 r"\blivro\b|\blivros\b|\bgibi\b|quadrinho|\brevista\b", "medium"),
    ("brinquedo",             r"brinquedo|\bminiatura\b|action figure|\bboneca\b|\bboneco\b|autorama", "small"),
    ("porcelana_ceramica",    r"porcelana|ceramica|faianca|\blouca\b", "small"),
    ("cristal_vidro",         r"cristal|murano|\bvidro\b|baccarat|demi cristal|opalina", "small"),
    ("prata_metal",           r"\bprata\b|prata de lei|\bbronze\b|estanho|metal espessurado|casquinha", "small"),
    ("objeto_decorativo",     r"vaso|jarra|floreira|centro de mesa|enfeite|escultura de mesa|caixa decorativa", "small"),
    ("livro_arte",            r"catalogo de arte", "small"),
]

# Família (macro-categoria) por item_type — permite incluir/excluir grupos
# inteiros no dashboard (ex.: tirar Numismática/Filatelia da análise de móveis).
MACRO_BY_TYPE = {
    # Mobiliário
    "cadeira": "Mobiliário", "par_de_cadeiras": "Mobiliário",
    "conjunto_de_cadeiras": "Mobiliário", "poltrona": "Mobiliário",
    "par_de_poltronas": "Mobiliário", "sofa": "Mobiliário", "banco": "Mobiliário",
    "mesa_de_centro": "Mobiliário", "mesa_lateral": "Mobiliário",
    "mesa_de_jantar": "Mobiliário", "mesa": "Mobiliário", "aparador": "Mobiliário",
    "comoda": "Mobiliário", "estante": "Mobiliário", "armario": "Mobiliário",
    "cama": "Mobiliário", "escrivaninha": "Mobiliário", "cristaleira": "Mobiliário",
    "carrinho_de_cha": "Mobiliário",
    # Arte
    "quadro_pintura": "Arte", "gravura": "Arte", "escultura": "Arte", "fotografia": "Arte",
    # Decoração
    "luminaria_lustre": "Decoração", "espelho": "Decoração", "tapete": "Decoração",
    "objeto_decorativo": "Decoração", "porcelana_ceramica": "Decoração",
    "cristal_vidro": "Decoração", "prata_metal": "Decoração",
    # Colecionáveis (fora da tese de móveis/arte/decoração)
    "moeda": "Numismática", "cedula": "Numismática", "medalha": "Numismática",
    "selo_filatelia": "Filatelia", "joia": "Joias", "relogio": "Relógios",
    "disco_vinil": "Discos", "livro": "Livros", "livro_arte": "Livros",
    "brinquedo": "Brinquedos",
    "outro": "Outro",
}


def macro_of(item_type: str) -> str:
    return MACRO_BY_TYPE.get(item_type, "Outro")


# Casas: porte do frete por size_class (premissas em assumptions.yaml)
