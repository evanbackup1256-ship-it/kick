"use client";

import clsx from "clsx";
import { useEffect, useRef } from "react";
import { useReducedMotion } from "@/lib/useReducedMotion";

/** ShaderGradient-inspired animated mesh — lightweight canvas, hero backdrop only */
export function ShaderMesh({ className }: { className?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const reduced = useReducedMotion();

  useEffect(() => {
    if (reduced) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let w = 0;
    let h = 0;
    let dpr = 1;
    let t = 0;
    let raf = 0;

    const resize = () => {
      const parent = canvas.parentElement;
      if (!parent) return;
      dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      w = Math.floor(parent.clientWidth * dpr);
      h = Math.floor(parent.clientHeight * dpr);
      canvas.width = w;
      canvas.height = h;
      canvas.style.width = `${parent.clientWidth}px`;
      canvas.style.height = `${parent.clientHeight}px`;
    };

    const blobs = [
      { hx: 190, hy: 280, sx: 0.0009, sy: 0.0011, px: 0.25, py: 0.35, r: 0.42 },
      { hx: 265, hy: 220, sx: 0.0012, sy: 0.0008, px: 0.72, py: 0.28, r: 0.36 },
      { hx: 320, hy: 300, sx: 0.0007, sy: 0.0013, px: 0.5, py: 0.62, r: 0.32 },
    ];

    const frame = () => {
      t += 1;
      ctx.clearRect(0, 0, w, h);

      for (const b of blobs) {
        const ox = Math.sin(t * b.sx) * 0.07;
        const oy = Math.cos(t * b.sy) * 0.06;
        const px = (b.px + ox) * w;
        const py = (b.py + oy) * h;
        const rad = b.r * Math.min(w, h);
        const g = ctx.createRadialGradient(px, py, 0, px, py, rad);
        g.addColorStop(0, `hsla(${b.hx}, 90%, 58%, 0.22)`);
        g.addColorStop(0.45, `hsla(${b.hy}, 75%, 48%, 0.06)`);
        g.addColorStop(1, "transparent");
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, w, h);
      }

      raf = requestAnimationFrame(frame);
    };

    resize();
    window.addEventListener("resize", resize, { passive: true });
    raf = requestAnimationFrame(frame);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
    };
  }, [reduced]);

  if (reduced) return null;

  return (
    <canvas
      ref={canvasRef}
      aria-hidden
      className={clsx("pointer-events-none absolute inset-0 h-full w-full mix-blend-screen", className)}
    />
  );
}
