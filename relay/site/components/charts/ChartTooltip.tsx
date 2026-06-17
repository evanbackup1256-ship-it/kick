"use client";

import type { LucideIcon } from "lucide-react";

type TooltipRow = {
  label: string;
  value: string | number;
  accent?: string;
};

export function ChartTooltip({
  open,
  x,
  y,
  label,
  value,
  title,
  icon: Icon,
  rows,
  visible,
}: {
  open?: boolean;
  x: number;
  y: number;
  label?: string;
  value?: string | number;
  title?: string;
  icon?: LucideIcon;
  rows?: TooltipRow[];
  visible?: boolean;
}) {
  const isVisible = open ?? visible;
  if (!isVisible) return null;
  const displayRows = rows ?? (value !== undefined ? [{ label: label || "Value", value }] : []);

  return (
    <div
      className="chart-tooltip pointer-events-none absolute z-10 min-w-32 rounded-md border border-white/10 bg-slate-950/95 px-3 py-2 font-mono text-[10px] shadow-xl shadow-black/30"
      style={{ left: x, top: y, transform: "translate(-50%, -120%)" }}
    >
      {title || Icon ? (
        <div className="mb-1 flex items-center gap-1.5 text-slate-200">
          {Icon ? <Icon className="h-3 w-3 text-cyan-300" /> : null}
          {title ? <p className="font-semibold">{title}</p> : null}
        </div>
      ) : label ? (
        <p className="text-muted-2">{label}</p>
      ) : null}
      <div className="space-y-0.5">
        {displayRows.map((row) => (
          <div key={row.label} className="flex items-center justify-between gap-4">
            <span className="text-slate-500">{row.label}</span>
            <span className={row.accent ?? "text-slate-100"}>{row.value}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
