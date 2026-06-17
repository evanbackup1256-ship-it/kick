"use client";

import { useEffect, useRef } from "react";
import { Activity, Cpu, Radio, Zap } from "lucide-react";

function Sparkline({ color = "#00f0c8" }: { color?: string }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const points = useRef<number[]>([]);

  useEffect(() => {
    const c = canvas.current;
    if (!c) return;
    const ctx = c.getContext("2d");
    if (!ctx) return;

    let running = true;
    const init = Array.from({ length: 30 }, () => Math.random() * 30 + 5);
    points.current = init;

    const draw = () => {
      if (!running) return;
      if (!ctx || !c) return;
      c.width = c.clientWidth;
      c.height = c.clientHeight;
      ctx.clearRect(0, 0, c.width, c.height);

      points.current.push(Math.random() * 30 + 5);
      if (points.current.length > 50) points.current.shift();

      const p = points.current;
      const w = c.width;
      const h = c.height;

      ctx.beginPath();
      ctx.moveTo(0, h - p[0]);
      for (let i = 1; i < p.length; i++) {
        ctx.lineTo((i / p.length) * w, h - p[i]);
      }
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0, h - p[0]);
      for (let i = 1; i < p.length; i++) {
        ctx.lineTo((i / p.length) * w, h - p[i]);
      }
      ctx.lineTo(w, h);
      ctx.lineTo(0, h);
      ctx.closePath();
      ctx.fillStyle = color + "12";
      ctx.fill();

      requestAnimationFrame(draw);
    };
    draw();
    return () => { running = false; };
  }, [color]);

  return <canvas ref={canvas} className="w-full h-full" />;
}

const metrics = [
  { icon: Radio, label: "Runtime Latency", value: "24ms", color: "#00f0c8" },
  { icon: Activity, label: "Signal Throughput", value: "1.2k/s", color: "#00d4ff" },
  { icon: Cpu, label: "Active Nodes", value: "12", color: "#7c3aed" },
  { icon: Zap, label: "Request Volume", value: "4.8k", color: "#00f0c8" },
];

export function TelemetryCharts() {
  return (
    <div className="grid gap-3 md:grid-cols-2">
      {metrics.map((m) => (
        <div key={m.label} className="glass-premium rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <m.icon className="h-4 w-4" style={{ color: m.color }} />
            <span className="text-xs font-mono text-muted-2 uppercase tracking-wider">{m.label}</span>
          </div>
          <div className="flex items-end justify-between">
            <span className="text-2xl font-bold text-text">{m.value}</span>
            <span className="text-[10px] font-mono text-muted-2">live</span>
          </div>
          <div className="mt-2 h-10">
            <Sparkline color={m.color} />
          </div>
        </div>
      ))}
    </div>
  );
}
