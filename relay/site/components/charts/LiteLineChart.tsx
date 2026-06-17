"use client";

import clsx from "clsx";
import { memo, useEffect, useRef, useState } from "react";

type Point = { value: number; label?: string };

function ChartInner({ width, height, data }: { width: number; height: number; data: Point[] }) {
  const [hover, setHover] = useState<number | null>(null);
  const pad = { t: 12, r: 8, b: 24, l: 32 };
  const innerW = Math.max(10, width - pad.l - pad.r);
  const innerH = Math.max(10, height - pad.t - pad.b);
  const maxY = Math.max(1, ...data.map((d) => d.value));

  const points = data.map((d, i) => {
    const x = pad.l + (i / Math.max(data.length - 1, 1)) * innerW;
    const y = pad.t + innerH - (d.value / maxY) * innerH;
    return { x, y, ...d, i };
  });

  const line = points.map((p) => `${p.x},${p.y}`).join(" ");
  const area = `${pad.l},${pad.t + innerH} ${line} ${pad.l + innerW},${pad.t + innerH}`;

  return (
    <div className="relative h-full w-full">
      <svg width={width} height={height} className="overflow-visible">
        {[0, 0.25, 0.5, 0.75, 1].map((t) => (
          <line
            key={t}
            x1={pad.l}
            x2={pad.l + innerW}
            y1={pad.t + innerH * (1 - t)}
            y2={pad.t + innerH * (1 - t)}
            stroke="rgba(255,255,255,0.06)"
            strokeWidth={1}
          />
        ))}
        <polygon points={area} fill="url(#chart-fill)" opacity={0.35} />
        <polyline points={line} fill="none" stroke="#34d399" strokeWidth={2} strokeLinejoin="round" />
        {points.map((p) => (
          <circle key={p.i} cx={p.x} cy={p.y} r={hover === p.i ? 4 : 2} fill="#34d399" opacity={hover === null || hover === p.i ? 1 : 0.35} />
        ))}
        <defs>
          <linearGradient id="chart-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#34d399" stopOpacity={0.4} />
            <stop offset="100%" stopColor="#34d399" stopOpacity={0} />
          </linearGradient>
        </defs>
        <rect
          x={pad.l}
          y={pad.t}
          width={innerW}
          height={innerH}
          fill="transparent"
          onMouseMove={(e) => {
            const rect = e.currentTarget.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const idx = Math.round((x / innerW) * Math.max(data.length - 1, 0));
            setHover(Math.max(0, Math.min(data.length - 1, idx)));
          }}
          onMouseLeave={() => setHover(null)}
        />
      </svg>
      {hover != null && points[hover] ? (
        <div
          className="pointer-events-none absolute rounded-lg border border-border bg-bg-2 px-2 py-1 text-[10px] font-mono text-text shadow-lg"
          style={{ left: points[hover].x, top: points[hover].y - 28, transform: "translateX(-50%)" }}
        >
          {points[hover].value} working
        </div>
      ) : null}
    </div>
  );
}

const LiteLineChart = memo(function LiteLineChart({
  series,
  className,
}: {
  series: Point[];
  className?: string;
}) {
  const rootRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ w: 0, h: 0 });

  useEffect(() => {
    const el = rootRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => {
      const { width, height } = entry.contentRect;
      setSize({ w: width, h: height });
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  return (
    <div ref={rootRef} className={clsx("relative h-full min-h-[140px] w-full", className)}>
      {size.w > 0 && size.h > 0 ? <ChartInner width={size.w} height={size.h} data={series} /> : null}
    </div>
  );
});

export const TelemetryLineChart = LiteLineChart;
