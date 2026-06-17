"use client";

import { useEffect, useRef, useState } from "react";
import { Activity, Cpu, Radio, Zap } from "lucide-react";

function MiniSparkline({ color = "#00f0c8", height = 40 }: { color?: string; height?: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const c = canvas.current;
    if (!c) return;
    const ctx = c.getContext("2d");
    if (!ctx) return;
    let points: number[] = Array.from({ length: 40 }, () => Math.random() * height);
    let anim = true;

    const draw = () => {
      if (!ctx || !c) return;
      c.width = c.clientWidth;
      c.height = c.clientHeight;
      ctx.clearRect(0, 0, c.width, c.height);

      points.push(Math.random() * height);
      if (points.length > 60) points.shift();

      ctx.beginPath();
      ctx.moveTo(0, c.height - points[0]);
      for (let i = 1; i < points.length; i++) {
        ctx.lineTo((i / points.length) * c.width, c.height - points[i]);
      }
      ctx.strokeStyle = color;
      ctx.lineWidth = 1.5;
      ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0, c.height - points[0]);
      for (let i = 1; i < points.length; i++) {
        ctx.lineTo((i / points.length) * c.width, c.height - points[i]);
      }
      ctx.lineTo(c.width, c.height);
      ctx.lineTo(0, c.height);
      ctx.closePath();
      ctx.fillStyle = color + "15";
      ctx.fill();

      if (anim) requestAnimationFrame(draw);
    };
    draw();
    return () => { anim = false; };
  }, [color, height]);

  return <canvas ref={canvas} className="w-full h-full" />;
}

const metrics = [
  { icon: Radio, label: "Runtime Latency", value: "24ms", color: "#00f0c8", trend: "stable" },
  { icon: Activity, label: "Signal Throughput", value: "1.2k/s", color: "#00d4ff", trend: "increasing" },
  { icon: Cpu, label: "Active Nodes", value: "12", color: "#7c3aed", trend: "online" },
  { icon: Zap, label: "Request Volume", value: "4.8k", color: "#00f0c8", trend: "normal" },
];

export function TelemetryCharts() {
  return (
    <div className="grid gap-3 md:grid-cols-2">
      {metrics.map((m) => (
        <div key={m.label} className="glass-deep rounded-xl p-4 cursor-light">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <m.icon className="h-4 w-4" style={{ color: m.color }} />
              <span className="text-xs font-mono text-muted-2 uppercase tracking-wider">{m.label}</span>
            </div>
            <span className="text-xs font-mono text-muted-2">{m.trend}</span>
          </div>
          <div className="flex items-end justify-between">
            <span className="text-2xl font-bold text-text">{m.value}</span>
            <span className="text-[10px] font-mono text-muted-2">live</span>
          </div>
          <div className="mt-2 h-10">
            <MiniSparkline color={m.color} />
          </div>
        </div>
      ))}
    </div>
  );
}
