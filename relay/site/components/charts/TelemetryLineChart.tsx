"use client";

import { memo, useMemo, useState, useCallback } from "react";
import { Group } from "@visx/group";
import { LinePath, AreaClosed } from "@visx/shape";
import { scaleLinear } from "@visx/scale";
import { AxisBottom, AxisLeft } from "@visx/axis";
import { GridRows } from "@visx/grid";
import { curveMonotoneX } from "@visx/curve";
import { LinearGradient } from "@visx/gradient";
import { ParentSize } from "@visx/responsive";
import { Activity } from "lucide-react";
import { chart as chartTokens } from "@/lib/design/tokens";
import { ChartTooltip } from "./ChartTooltip";

type Point = { x: number; y: number; label?: string };

function InnerChart({
  width,
  height,
  data,
  secondary,
  color = chartTokens.linePrimary,
  areaColor = chartTokens.areaPrimary,
}: {
  width: number;
  height: number;
  data: Point[];
  secondary?: Point[];
  color?: string;
  areaColor?: string;
}) {
  const margin = { top: 16, right: 16, bottom: 28, left: 40 };
  const innerW = Math.max(10, width - margin.left - margin.right);
  const innerH = Math.max(10, height - margin.top - margin.bottom);
  const [hover, setHover] = useState<{ idx: number; px: number; py: number } | null>(null);

  const xScale = useMemo(
    () =>
      scaleLinear<number>({
        domain: [0, Math.max(data.length - 1, 1)],
        range: [0, innerW],
      }),
    [data.length, innerW]
  );

  const maxY = useMemo(() => Math.max(1, ...data.map((d) => d.y), ...(secondary?.map((d) => d.y) || [])), [data, secondary]);

  const yScale = useMemo(
    () =>
      scaleLinear<number>({
        domain: [0, maxY * 1.1],
        range: [innerH, 0],
        nice: true,
      }),
    [innerH, maxY]
  );

  const onMove = useCallback(
    (e: React.MouseEvent<SVGRectElement>) => {
      const rect = e.currentTarget.getBoundingClientRect();
      const x = e.clientX - rect.left - margin.left;
      const idx = Math.round(xScale.invert(Math.max(0, Math.min(innerW, x))));
      const clamped = Math.max(0, Math.min(data.length - 1, idx));
      setHover({ idx: clamped, px: xScale(clamped) + margin.left, py: margin.top });
    },
    [data.length, innerW, margin.left, margin.top, xScale]
  );

  const active = hover ? data[hover.idx] : null;

  return (
    <div className="relative h-full w-full">
      <svg width={width} height={height}>
        <LinearGradient id="area-grad" from={color} to={color} fromOpacity={0.35} toOpacity={0} />
        <Group left={margin.left} top={margin.top}>
          <GridRows scale={yScale} width={innerW} stroke={chartTokens.grid} numTicks={4} />
          <AreaClosed
            data={data}
            x={(d, i) => xScale(i)}
            y={(d) => yScale(d.y)}
            yScale={yScale}
            curve={curveMonotoneX}
            fill="url(#area-grad)"
          />
          {secondary ? (
            <LinePath
              data={secondary}
              x={(d, i) => xScale(i)}
              y={(d) => yScale(d.y)}
              curve={curveMonotoneX}
              stroke={chartTokens.lineSecondary}
              strokeWidth={2}
              strokeOpacity={0.85}
            />
          ) : null}
          <LinePath
            data={data}
            x={(d, i) => xScale(i)}
            y={(d) => yScale(d.y)}
            curve={curveMonotoneX}
            stroke={color}
            strokeWidth={2.5}
            style={{ filter: hover ? `drop-shadow(0 0 8px ${chartTokens.pointGlow})` : undefined }}
          />
          {hover ? (
            <>
              <line x1={xScale(hover.idx)} x2={xScale(hover.idx)} y1={0} y2={innerH} stroke={chartTokens.crosshair} strokeDasharray="4 4" />
              <circle cx={xScale(hover.idx)} cy={yScale(data[hover.idx]?.y ?? 0)} r={6} fill={color} />
              <circle cx={xScale(hover.idx)} cy={yScale(data[hover.idx]?.y ?? 0)} r={12} fill={color} opacity={0.15} />
            </>
          ) : null}
          <AxisLeft scale={yScale} numTicks={4} stroke={chartTokens.axis} tickStroke="transparent" tickLabelProps={() => ({ fill: "#64748b", fontSize: 10, fontFamily: "var(--font-mono)" })} />
          <AxisBottom
            top={innerH}
            scale={xScale}
            numTicks={Math.min(6, data.length)}
            stroke={chartTokens.axis}
            tickStroke="transparent"
            tickFormat={(v) => data[Number(v)]?.label?.slice(0, 5) || String(v)}
            tickLabelProps={() => ({ fill: "#64748b", fontSize: 10, fontFamily: "var(--font-mono)" })}
          />
          <rect x={0} y={0} width={innerW} height={innerH} fill="transparent" onMouseMove={onMove} onMouseLeave={() => setHover(null)} />
        </Group>
      </svg>
      <ChartTooltip
        open={!!active && hover != null}
        x={hover?.px ?? 0}
        y={hover?.py ?? 0}
        title={active?.label || "Sample"}
        icon={Activity}
        rows={[
          { label: "Value", value: String(active?.y ?? 0), accent: "text-cyan-300" },
          { label: "Index", value: String((hover?.idx ?? 0) + 1) },
        ]}
      />
    </div>
  );
}

export const TelemetryLineChart = memo(function TelemetryLineChart({
  series,
  secondary,
  className,
}: {
  series: { value: number; label?: string }[];
  secondary?: { value: number; label?: string }[];
  className?: string;
}) {
  const data = series.map((s, i) => ({ x: i, y: s.value, label: s.label }));
  const sec = secondary?.map((s, i) => ({ x: i, y: s.value, label: s.label }));

  return (
    <div className={className}>
      <ParentSize className="h-full w-full" debounceTime={10}>
        {({ width, height }) => (width > 0 && height > 0 ? <InnerChart width={width} height={height} data={data} secondary={sec} /> : null)}
      </ParentSize>
    </div>
  );
});
