// formatadores em caixa baixa, sem tom de marketing.

export function endsLabel(iso: string | null): string {
  if (!iso) return "encerramento não informado";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "encerramento não informado";
  const now = Date.now();
  const diff = d.getTime() - now;
  const dia = d.toLocaleDateString("pt-br", { day: "2-digit", month: "2-digit" });
  const hora = d.toLocaleTimeString("pt-br", { hour: "2-digit", minute: "2-digit" });
  if (diff < 0) return `encerrado em ${dia}`;
  const dias = Math.floor(diff / 86400000);
  if (dias === 0) return `encerra hoje, ${hora}`;
  if (dias === 1) return `encerra amanhã, ${hora}`;
  return `encerra em ${dias} dias · ${dia} ${hora}`;
}

export function brl(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `r$ ${Math.round(n).toLocaleString("pt-br")}`;
}
