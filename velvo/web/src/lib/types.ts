export type Decision = "fica" | "talvez" | "passa";

export type CandidatePayload = {
  item_type?: string | null;
  macro_category?: string | null;
  designer?: string | null;
  attribution_strength?: string | null;
  condition_tier?: string | null;
  size_class?: string | null;
  uf?: string | null;
  house_name?: string | null;
  est_resale_base?: number | null;
  est_total_cost?: number | null;
  est_gross_profit?: number | null;
  est_gross_margin_pct?: number | null;
  max_bid_40pct?: number | null;
  confidence?: number | null;
  signal?: string | null;
  signal_reasons?: string | null;
  entry_reasons?: string[];
  risk_reasons?: string[];
  approved?: boolean | null;
  tier?: string | null;
};

export type Candidate = {
  candidate_id: string;
  product_slug: string;
  batch_id: string;
  title: string;
  price_brl: number | null;
  price_label: string | null;
  source_house: string | null;
  source_url: string | null;
  image_url: string | null;
  auction_ends: string | null;
  score: number | null;
  priority: string | null;
  risk: string | null;
  headroom: number | null;
  bid_count: number | null;
  status: string;
  payload: CandidatePayload;
  refreshed_at: string;
};
