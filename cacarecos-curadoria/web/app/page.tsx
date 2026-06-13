"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Candidate, Verdict, decide, fetchFeed } from "@/lib/supabase";

const BRL = (n: number | null) =>
  n == null ? "—" : n.toLocaleString("pt-BR", { style: "currency", currency: "BRL", maximumFractionDigits: 0 });
const PCT = (n: number | null) => (n == null ? "—" : `${Math.round(n * 100)}%`);

function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-block border border-linha px-2 py-0.5 text-[11px] uppercase tracking-wide text-tinta/70">
      {children}
    </span>
  );
}

export default function Page() {
  const [feed, setFeed] = useState<Candidate[]>([]);
  const [i, setI] = useState(0);
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState(true);
  const [done, setDone] = useState(0);
  const [drag, setDrag] = useState(0);
  const startX = useRef<number | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchFeed(50);
      setFeed(data);
      setI(0);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const card = feed[i];

  const act = useCallback(
    async (verdict: Verdict) => {
      if (!card) return;
      const cid = card.candidate_id;
      const n = note;
      setNote("");
      setDrag(0);
      setI((x) => x + 1);
      setDone((d) => d + 1);
      try {
        await decide(cid, verdict, n);
      } catch (e) {
        console.error(e);
      }
      // recarrega quando a pilha esvazia
      if (i + 1 >= feed.length - 1) load();
    },
    [card, note, i, feed.length, load]
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "ArrowLeft") act("pass");
      else if (e.key === "ArrowRight") act("keep");
      else if (e.key === "ArrowUp") act("maybe");
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [act]);

  if (loading)
    return <Centered>Carregando a fila…</Centered>;
  if (!card)
    return (
      <Centered>
        <div className="text-center">
          <p className="text-lg">Fila zerada por aqui ✨</p>
          <p className="mt-2 text-sm text-tinta/60">
            Você revisou tudo. O motor renova a lista sozinho — volte mais tarde.
          </p>
          <button onClick={load} className="mt-6 border border-tinta px-4 py-2 text-sm">
            Recarregar
          </button>
        </div>
      </Centered>
    );

  const deadline = card.auction_datetime?.slice(0, 16).replace("T", " ");
  const rot = drag / 18;
  const opacity = Math.min(1, Math.abs(drag) / 120);

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col px-4 py-6">
      <header className="mb-4 flex items-baseline justify-between">
        <h1 className="text-sm font-bold uppercase tracking-widest">Cacarecos · Curadoria</h1>
        <span className="text-xs text-tinta/50">{done} decididas · {feed.length - i} na fila</span>
      </header>

      <div
        className="relative select-none"
        onPointerDown={(e) => (startX.current = e.clientX)}
        onPointerMove={(e) => {
          if (startX.current != null) setDrag(e.clientX - startX.current);
        }}
        onPointerUp={() => {
          if (drag > 120) act("keep");
          else if (drag < -120) act("pass");
          else setDrag(0);
          startX.current = null;
        }}
      >
        <article
          className="overflow-hidden border border-linha bg-papel shadow-sm"
          style={{ transform: `translateX(${drag}px) rotate(${rot}deg)`, transition: startX.current == null ? "transform .2s" : "none" }}
        >
          <div className="relative aspect-square bg-nevoa">
            {/* imagem é o produto — fundo neutro, sem corte */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={card.thumbnail_url} alt={card.title} className="h-full w-full object-contain" />
            {drag > 40 && <Stamp className="left-4 border-keep text-keep">FICA</Stamp>}
            {drag < -40 && <Stamp className="right-4 border-pass text-pass">PASSA</Stamp>}
          </div>

          <div className="space-y-3 p-4">
            <p className="text-sm leading-snug">{card.title}</p>

            <div className="flex flex-wrap gap-1">
              {card.item_type && <Badge>{card.item_type.replace(/_/g, " ")}</Badge>}
              {card.material && <Badge>{card.material}</Badge>}
              {card.period_hint && <Badge>{card.period_hint}</Badge>}
              {card.designer && <Badge>{card.designer.replace(/_/g, " ")}</Badge>}
              {card.condition_tier && card.condition_tier !== "none" && <Badge>estado: {card.condition_tier}</Badge>}
              {card.uf && <Badge>{card.uf}</Badge>}
            </div>

            <dl className="grid grid-cols-2 gap-x-4 gap-y-1 text-sm">
              <Stat k="Lance atual" v={BRL(card.current_bid_brl)} />
              <Stat k="Revenda est." v={BRL(card.retail_anchor)} />
              <Stat k="Margem" v={PCT(card.est_margin_pct)} strong />
              <Stat k="Lance máx." v={BRL(card.max_bid_brl)} />
              <Stat k="Comp. leilão" v={BRL(card.comp_median)} />
              {card.antonio_fit_visual != null && (
                <Stat k="Fit visual" v={PCT(card.antonio_fit_visual)} />
              )}
            </dl>

            {deadline && <p className="text-xs text-tinta/50">Fecha: {deadline}</p>}
            <a href={card.lot_url} target="_blank" rel="noreferrer" className="block text-xs text-tinta/50 underline">
              ver no leilão ↗
            </a>
          </div>
        </article>
      </div>

      <input
        value={note}
        onChange={(e) => setNote(e.target.value)}
        placeholder="nota / narrativa (opcional)"
        className="mt-4 w-full border border-linha bg-papel px-3 py-2 text-sm outline-none focus:border-tinta"
      />

      <div className="mt-4 grid grid-cols-3 gap-2">
        <ActBtn onClick={() => act("pass")} className="border-pass text-pass">Passa ←</ActBtn>
        <ActBtn onClick={() => act("maybe")} className="border-maybe text-maybe">Talvez ↑</ActBtn>
        <ActBtn onClick={() => act("keep")} className="border-keep text-keep">Fica →</ActBtn>
      </div>
      <p className="mt-3 text-center text-[11px] text-tinta/40">
        arraste o card ou use ← ↑ → no teclado
      </p>
    </main>
  );
}

function Stat({ k, v, strong }: { k: string; v: string; strong?: boolean }) {
  return (
    <div className="flex justify-between border-b border-linha/60 py-0.5">
      <dt className="text-tinta/50">{k}</dt>
      <dd className={strong ? "font-bold" : ""}>{v}</dd>
    </div>
  );
}

function ActBtn({ onClick, className, children }: { onClick: () => void; className: string; children: React.ReactNode }) {
  return (
    <button onClick={onClick} className={`border-2 py-3 text-sm font-bold uppercase tracking-wide ${className}`}>
      {children}
    </button>
  );
}

function Stamp({ children, className }: { children: React.ReactNode; className: string }) {
  return (
    <span className={`absolute top-4 rotate-[-12deg] border-2 px-3 py-1 text-xl font-extrabold ${className}`}>
      {children}
    </span>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return <main className="flex min-h-screen items-center justify-center px-6 text-tinta/70">{children}</main>;
}
