"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useSpring } from "motion/react";
import { spring } from "@/lib/motion/config";

export function AnimatedNumber({ value, className }: { value: number; className?: string }) {
  const motionValue = useSpring(value, spring.soft);
  const [display, setDisplay] = useState(value);

  useEffect(() => {
    motionValue.set(value);
    const unsub = motionValue.on("change", (v) => setDisplay(Math.round(v)));
    return () => unsub();
  }, [value, motionValue]);

  return <span className={className}>{display.toLocaleString()}</span>;
}

export function StatusPulse({ online, label }: { online: boolean; label: string }) {
  return (
    <span className={`inline-flex items-center gap-2 text-xs font-medium ${online ? "text-green-400" : "text-red-400"}`}>
      <motion.span
        className={`h-2 w-2 rounded-full ${online ? "bg-green-400" : "bg-red-400"}`}
        animate={online ? { scale: [1, 1.25, 1], opacity: [1, 0.7, 1] } : { opacity: 0.8 }}
        transition={{ duration: 2.2, repeat: Infinity, ease: "easeInOut" }}
      />
      {label}
    </span>
  );
}

export function TelemetryChart({ points, className }: { points: number[]; className?: string }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !points.length) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let raf = 0;
    let t = 0;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);

    const draw = () => {
      t += 0.016;
      const w = canvas.clientWidth * dpr;
      const h = canvas.clientHeight * dpr;
      canvas.width = w;
      canvas.height = h;
      ctx.clearRect(0, 0, w, h);

      const pad = 16 * dpr;
      const max = Math.max(...points, 1);
      const step = (w - pad * 2) / Math.max(points.length - 1, 1);

      ctx.strokeStyle = "rgba(99,102,241,0.25)";
      ctx.lineWidth = 1 * dpr;
      for (let i = 0; i < 4; i += 1) {
        const y = pad + ((h - pad * 2) * i) / 3;
        ctx.beginPath();
        ctx.moveTo(pad, y);
        ctx.lineTo(w - pad, y);
        ctx.stroke();
      }

      const grad = ctx.createLinearGradient(0, 0, w, 0);
      grad.addColorStop(0, "rgba(34,211,238,0.9)");
      grad.addColorStop(1, "rgba(99,102,241,0.9)");

      ctx.beginPath();
      points.forEach((p, i) => {
        const x = pad + i * step;
        const y = h - pad - (p / max) * (h - pad * 2);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      });
      ctx.strokeStyle = grad;
      ctx.lineWidth = 2 * dpr;
      ctx.stroke();

      ctx.lineTo(w - pad, h - pad);
      ctx.lineTo(pad, h - pad);
      ctx.closePath();
      const fill = ctx.createLinearGradient(0, pad, 0, h);
      fill.addColorStop(0, "rgba(99,102,241,0.22)");
      fill.addColorStop(1, "rgba(99,102,241,0)");
      ctx.fillStyle = fill;
      ctx.fill();

      const pulse = (Math.sin(t * 2) + 1) / 2;
      const lastX = pad + (points.length - 1) * step;
      const lastY = h - pad - (points[points.length - 1] / max) * (h - pad * 2);
      ctx.beginPath();
      ctx.arc(lastX, lastY, (4 + pulse * 2) * dpr, 0, Math.PI * 2);
      ctx.fillStyle = "rgba(34,211,238,0.95)";
      ctx.fill();

      raf = requestAnimationFrame(draw);
    };

    draw();
    return () => cancelAnimationFrame(raf);
  }, [points]);

  return <canvas ref={canvasRef} className={className} aria-hidden />;
}
