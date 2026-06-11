"""Schema SQLite e helpers. Convenção: tabelas de fatos observados
(lots, lot_snapshots, auctions, auction_houses) só recebem dados do HTML;
tudo inferido vive em lot_enrichment (DROP+rebuild a cada run de enrich)."""
import sqlite3

import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS auction_houses (
  house_domain TEXT PRIMARY KEY,
  name TEXT,
  city TEXT,
  uf TEXT,
  e_opinion_rating REAL,
  payment_terms_json TEXT,
  first_seen TEXT,
  last_seen TEXT
);

CREATE TABLE IF NOT EXISTS auctions (
  house_domain TEXT NOT NULL,
  auction_id TEXT NOT NULL,
  auction_datetime TEXT,
  uf TEXT,
  source_url TEXT,
  scraped_at TEXT,
  PRIMARY KEY (house_domain, auction_id)
);

CREATE TABLE IF NOT EXISTS lots (
  house_domain TEXT NOT NULL,
  lot_id TEXT NOT NULL,
  auction_id TEXT,
  title TEXT,
  uf TEXT,
  auction_datetime TEXT,
  lot_url TEXT,
  thumbnail_url TEXT,
  description TEXT,
  detail_scraped_at TEXT,
  excluded_sensitive INTEGER DEFAULT 0,
  first_seen TEXT,
  PRIMARY KEY (house_domain, lot_id)
);

CREATE TABLE IF NOT EXISTS lot_categories (
  house_domain TEXT NOT NULL,
  lot_id TEXT NOT NULL,
  category TEXT NOT NULL,
  PRIMARY KEY (house_domain, lot_id, category)
);

CREATE TABLE IF NOT EXISTS lot_snapshots (
  house_domain TEXT NOT NULL,
  lot_id TEXT NOT NULL,
  scraped_at TEXT NOT NULL,
  lot_number TEXT,
  opening_bid_brl REAL,
  current_bid_brl REAL,
  hammer_price_brl REAL,
  bid_count INTEGER,
  sold INTEGER,
  status TEXT,        -- andamento | finalizado | pos_pregao
  source TEXT,        -- busca_andamento | catalogo_finalizado
  PRIMARY KEY (house_domain, lot_id, scraped_at)
);

CREATE TABLE IF NOT EXISTS lot_enrichment (
  house_domain TEXT NOT NULL,
  lot_id TEXT NOT NULL,
  item_type_normalized TEXT,
  size_class TEXT,
  designer TEXT,
  attribution_strength TEXT,
  matched_keywords TEXT,
  matched_snippet TEXT,
  material TEXT,
  period_hint TEXT,
  condition_tier TEXT,
  is_pair_or_set INTEGER DEFAULT 0,
  est_resale_low REAL,
  est_resale_base REAL,
  est_resale_high REAL,
  est_total_cost REAL,
  est_gross_profit REAL,
  est_gross_margin_pct REAL,
  max_bid_35pct REAL,
  max_bid_40pct REAL,
  confidence REAL,
  signal TEXT,
  signal_reasons TEXT,
  PRIMARY KEY (house_domain, lot_id)
);

CREATE TABLE IF NOT EXISTS categories_map (
  category TEXT PRIMARY KEY,
  hex_code TEXT,
  item_count INTEGER,
  pages_fetched INTEGER,
  scraped_at TEXT
);

CREATE TABLE IF NOT EXISTS recon_findings (
  url TEXT,
  kind TEXT,
  note TEXT,
  scraped_at TEXT
);
"""


def connect() -> sqlite3.Connection:
    config.DATA_DIR.mkdir(parents=True, exist_ok=True)
    # timeout alto + WAL: vários workers escrevem em paralelo com segurança
    conn = sqlite3.connect(config.DB_PATH, timeout=60)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA busy_timeout=60000")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.executescript(SCHEMA)
    return conn
