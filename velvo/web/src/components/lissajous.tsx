"use client";

import { useEffect, useRef } from "react";

// curva de lissajous: x = sin(a·t + φ), y = sin(b·t). a fase φ avança devagar
// no tempo e a figura se redesenha continuamente. canvas retina-correto, com
// uma segunda passada em acento para profundidade e um ponto que percorre a
// curva. respeita prefers-reduced-motion (desenha um quadro estático).
export default function Lissajous({ a = 3, b = 4 }: { a?: number; b?: number }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let raf = 0;
    let w = 0;
    let h = 0;
    const reduce =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    const resize = () => {
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      w = canvas.clientWidth || 1;
      h = canvas.clientHeight || 1;
      canvas.width = Math.round(w * dpr);
      canvas.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);

    const N = 1500;
    const draw = (time: number) => {
      ctx.clearRect(0, 0, w, h);
      const cx = w / 2;
      const cy = h / 2;
      const R = Math.min(w, h) * 0.37;
      const phase = time * 0.00022;

      // duas passadas: a linha principal (tinta) e um eco em acento.
      const passes: [number, number, string][] = [
        [phase, 1.2, `rgba(27,24,19,0.82)`],
        [phase + 0.10, 1.0, `rgba(90,81,64,0.16)`],
      ];
      for (const [ph, lw, color] of passes) {
        ctx.beginPath();
        for (let i = 0; i <= N; i++) {
          const t = (i / N) * Math.PI * 2;
          const x = cx + R * Math.sin(a * t + ph);
          const y = cy + R * Math.sin(b * t);
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        }
        ctx.strokeStyle = color;
        ctx.lineWidth = lw;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();
      }

      // ponto que percorre a curva
      const td = (time * 0.0009) % (Math.PI * 2);
      const dx = cx + R * Math.sin(a * td + phase);
      const dy = cy + R * Math.sin(b * td);
      ctx.beginPath();
      ctx.arc(dx, dy, 3.2, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(27,24,19,0.95)";
      ctx.fill();

      if (!reduce) raf = requestAnimationFrame(draw);
    };

    if (reduce) draw(9000);
    else raf = requestAnimationFrame(draw);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
  }, [a, b]);

  return <canvas ref={ref} className="lissajous" aria-hidden="true" />;
}
