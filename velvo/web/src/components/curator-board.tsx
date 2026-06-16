"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

import type { Candidate, Decision } from "@/lib/types";
import { brl, endsLabel } from "@/lib/format";

const BUFFER_KEY = "velvo.pending-decisions";

type Pending = { candidate_id: string; decision: Decision; note: string | null; decided_by: string | null };

// amortecedor offline: se o post falhar (internet caiu), guarda no navegador
// e tenta de novo. nunca é a fonte da verdade — só um buffer.
function readBuffer(): Pending[] {
  try { return JSON.parse(localStorage.getItem(BUFFER_KEY) || "[]"); } catch { return []; }
}
function writeBuffer(items: Pending[]) {
  try { localStorage.setItem(BUFFER_KEY, JSON.stringify(items)); } catch { /* ignore */ }
}

async function postDecision(p: Pending): Promise<boolean> {
  try {
    const res = await fetch("/api/curator/decisions", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(p),
    });
    return res.ok;
  } catch {
    return false;
  }
}

export default function CuratorBoard({
  initialFeed,
  batchId,
  demo = false,
}: {
  initialFeed: Candidate[];
  batchId: string | null;
  demo?: boolean;
}) {
  const [feed] = useState<Candidate[]>(initialFeed);
  const [i, setI] = useState(0);
  const [note, setNote] = useState("");
  const [saving, setSaving] = useState(false);
  const [decidedBy, setDecidedBy] = useState<string>("");

  // lembra o nome de quem está decidindo (opcional), só no navegador
  useEffect(() => {
    setDecidedBy(localStorage.getItem("velvo.decided_by") || "");
  }, []);

  // tenta drenar o buffer offline ao abrir
  useEffect(() => {
    (async () => {
      const pend = readBuffer();
      if (!pend.length) return;
      const left: Pending[] = [];
      for (const p of pend) {
        const ok = await postDecision(p);
        if (!ok) left.push(p);
      }
      writeBuffer(left);
    })();
  }, []);

  const current = feed[i];
  const remaining = feed.length - i;

  const decide = useCallback(
    async (decision: Decision) => {
      if (!current || saving) return;
      setSaving(true);
      const who = decidedBy.trim() || null;
      if (who) localStorage.setItem("velvo.decided_by", who);
      const p: Pending = {
        candidate_id: current.candidate_id,
        decision,
        note: note.trim() || null,
        decided_by: who,
      };
      const ok = await postDecision(p);
      if (!ok) {
        const buf = readBuffer();
        buf.push(p);
        writeBuffer(buf);
      }
      setNote("");
      setSaving(false);
      setI((n) => n + 1);
    },
    [current, note, saving, decidedBy],
  );

  // atalhos: f / t / p
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.target as HTMLElement)?.tagName === "TEXTAREA") return;
      if (e.key === "f") decide("fica");
      if (e.key === "t") decide("talvez");
      if (e.key === "p") decide("passa");
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [decide]);

  const reasons = useMemo(() => current?.payload?.entry_reasons ?? [], [current]);
  const risks = useMemo(() => current?.payload?.risk_reasons ?? [], [current]);

  if (!feed.length) {
    return (
      <div className="wrap">
        <div className="topbar"><span className="brand">uma.uma · studio</span></div>
        <div className="empty">
          <h1>fila vazia</h1>
          <p>nenhum candidato pendente na rodada {batchId ?? "atual"}.</p>
        </div>
      </div>
    );
  }

  if (!current) {
    return (
      <div className="wrap">
        <div className="topbar"><span className="brand">uma.uma · studio</span></div>
        <div className="empty">
          <h1>fim da fila</h1>
          <p>você passou pelas {feed.length} peças da rodada {batchId}.</p>
          <p>recarregue para conferir se entraram novos lotes.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="wrap">
      <div className="topbar">
        <span className="brand">uma.uma · studio</span>
        <span className="counter">
          {demo && <span className="chip chip--pri" style={{ marginRight: 8 }}>demonstração · dados locais</span>}
          {i + 1} / {feed.length} · faltam {remaining}
        </span>
      </div>

      <div className="card">
        {current.image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img className="photo" src={current.image_url} alt="" loading="eager" />
        ) : (
          <div className="photo photo--empty">sem foto</div>
        )}
        <div className="body">
          <p className="title">{current.title}</p>

          <div className="facts">
            <span><b>{current.price_label || brl(current.price_brl)}</b></span>
            <span>{current.bid_count ?? 0} lances</span>
            <span>{current.source_house}</span>
            <span>{endsLabel(current.auction_ends)}</span>
          </div>

          <div className="chips">
            {current.payload?.approved && (
              <span className="chip chip--pri">★ aprovado{current.payload?.tier ? ` · tier ${current.payload.tier}` : ""}</span>
            )}
            {current.priority && <span className="chip chip--pri">prioridade {current.priority}</span>}
            <span className="chip">score {current.score}</span>
            {current.headroom != null && <span className="chip">folga {brl(current.headroom)}</span>}
            {risks.map((r) => (
              <span key={r} className="chip chip--risk">{r}</span>
            ))}
          </div>

          {reasons.length > 0 && (
            <p className="reasons">
              {reasons.map((r) => (
                <span key={r}> {r}</span>
              ))}
            </p>
          )}

          <textarea
            className="note"
            data-keep-case
            placeholder="nota (opcional)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />

          <div className="actions">
            <button className="btn btn--fica" disabled={saving} onClick={() => decide("fica")}>
              fica
            </button>
            <button className="btn btn--talvez" disabled={saving} onClick={() => decide("talvez")}>
              talvez
            </button>
            <button className="btn btn--passa" disabled={saving} onClick={() => decide("passa")}>
              passa
            </button>
          </div>

          {current.source_url && (
            <a className="lotlink" data-keep-case href={current.source_url} target="_blank" rel="noreferrer">
              ver lote na casa
            </a>
          )}
        </div>
      </div>

      <div className="foot">
        <span>atalhos: f fica · t talvez · p passa</span>
        <span>rodada {current.batch_id}</span>
      </div>
    </div>
  );
}
