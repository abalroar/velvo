"use client";

import { useMemo, useState } from "react";
import type { Candidate } from "@/lib/types";
import { brl } from "@/lib/format";

type Facets = {
  material: string[];
  size: string[];
  price: string[];
  era: string[];
};

const PRICE_ORDER = ["até R$ 800", "R$ 800 – 1.500", "R$ 1.500 – 2.500", "R$ 2.500 +"];
const SIZE_ORDER = ["pequeno", "médio", "grande"];

type Sort = "curadoria" | "preco-asc" | "preco-desc";

function count<T>(items: Candidate[], pick: (c: Candidate) => T | null | undefined) {
  const m = new Map<string, number>();
  for (const c of items) {
    const v = pick(c);
    if (v == null || v === "") continue;
    const k = String(v);
    m.set(k, (m.get(k) || 0) + 1);
  }
  return m;
}

function ordered(map: Map<string, number>, order?: string[]) {
  const keys = [...map.keys()];
  if (order) keys.sort((a, b) => order.indexOf(a) - order.indexOf(b));
  else keys.sort((a, b) => (map.get(b) || 0) - (map.get(a) || 0));
  return keys;
}

export default function Vitrine({ items }: { items: Candidate[] }) {
  const [sel, setSel] = useState<Facets>({ material: [], size: [], price: [], era: [] });
  const [sort, setSort] = useState<Sort>("curadoria");
  const [railOpen, setRailOpen] = useState(false);

  const matMap = useMemo(() => count(items, (c) => c.payload?.material), [items]);
  const sizeMap = useMemo(() => count(items, (c) => c.payload?.size_label), [items]);
  const priceMap = useMemo(() => count(items, (c) => c.payload?.price_band), [items]);
  const eraMap = useMemo(() => count(items, (c) => c.payload?.era), [items]);

  const toggle = (group: keyof Facets, value: string) =>
    setSel((s) => {
      const has = s[group].includes(value);
      return { ...s, [group]: has ? s[group].filter((v) => v !== value) : [...s[group], value] };
    });

  const clearAll = () => setSel({ material: [], size: [], price: [], era: [] });
  const activeCount = sel.material.length + sel.size.length + sel.price.length + sel.era.length;

  const shown = useMemo(() => {
    let out = items.filter((c) => {
      const p = c.payload || {};
      if (sel.material.length && !sel.material.includes(p.material as string)) return false;
      if (sel.size.length && !sel.size.includes(p.size_label as string)) return false;
      if (sel.price.length && !sel.price.includes(p.price_band as string)) return false;
      if (sel.era.length && !(p.era && sel.era.includes(p.era))) return false;
      return true;
    });
    if (sort === "preco-asc") out = [...out].sort((a, b) => (a.payload?.price_sale || 0) - (b.payload?.price_sale || 0));
    else if (sort === "preco-desc") out = [...out].sort((a, b) => (b.payload?.price_sale || 0) - (a.payload?.price_sale || 0));
    return out;
  }, [items, sel, sort]);

  const Group = ({
    title,
    map,
    group,
    order,
  }: {
    title: string;
    map: Map<string, number>;
    group: keyof Facets;
    order?: string[];
  }) => {
    const keys = ordered(map, order);
    if (!keys.length) return null;
    return (
      <div className="facet-group">
        <span className="label">{title}</span>
        {keys.map((k) => {
          const on = sel[group].includes(k);
          return (
            <button key={k} className={`facet${on ? " on" : ""}`} onClick={() => toggle(group, k)}>
              <span className="dot" />
              <span className="nm">{k}</span>
              <span className="ct">{map.get(k)}</span>
            </button>
          );
        })}
      </div>
    );
  };

  return (
    <div className="catalog">
      <button className="filter-toggle" onClick={() => setRailOpen((v) => !v)}>
        filtros {activeCount ? `· ${activeCount}` : ""}
      </button>

      <aside className={`rail${railOpen ? " open" : ""}`}>
        <Group title="material" map={matMap} group="material" />
        <Group title="tamanho" map={sizeMap} group="size" order={SIZE_ORDER} />
        <Group title="preço" map={priceMap} group="price" order={PRICE_ORDER} />
        <Group title="época" map={eraMap} group="era" />
      </aside>

      <section>
        <div className="toolbar">
          <span className="count">
            <b>{shown.length}</b> peças{activeCount ? " · filtradas" : " na vitrine"}
          </span>
          <select className="sortsel" value={sort} onChange={(e) => setSort(e.target.value as Sort)}>
            <option value="curadoria">ordem da curadoria</option>
            <option value="preco-asc">preço · menor</option>
            <option value="preco-desc">preço · maior</option>
          </select>
          {activeCount > 0 && (
            <div className="active-chips">
              {(["material", "size", "price", "era"] as (keyof Facets)[]).flatMap((g) =>
                sel[g].map((v) => (
                  <button key={g + v} className="fchip" onClick={() => toggle(g, v)}>
                    {v} <span className="x">×</span>
                  </button>
                )),
              )}
              <button className="fclear" onClick={clearAll}>limpar tudo</button>
            </div>
          )}
        </div>

        {shown.length === 0 ? (
          <div className="empty-grid">
            <h3>nada com esse recorte</h3>
            <p>afrouxe um filtro para ver mais peças.</p>
          </div>
        ) : (
          <div className="grid">
            {shown.map((c) => (
              <a
                key={c.candidate_id}
                className="product"
                href={c.source_url || "#"}
                target="_blank"
                rel="noreferrer"
              >
                <div className="product__frame">
                  {c.payload?.approved && <span className="product__star">curadoria</span>}
                  {c.image_url ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={c.image_url} alt="" loading="lazy" />
                  ) : null}
                </div>
                <div className="product__cap">
                  <div className="product__title">{c.title}</div>
                  <div className="product__meta">
                    {c.payload?.material}
                    {c.payload?.size_label && (
                      <>
                        <span className="sep">·</span>
                        {c.payload.size_label}
                      </>
                    )}
                    {c.payload?.uf && (
                      <>
                        <span className="sep">·</span>
                        {c.payload.uf}
                      </>
                    )}
                  </div>
                  <div className="product__price">
                    {brl(c.payload?.price_sale)} <small>preço de vitrine</small>
                  </div>
                </div>
              </a>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
