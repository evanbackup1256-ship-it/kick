"use client";

import clsx from "clsx";
import { useMemo } from "react";
import { resolveGameStatus } from "@/lib/status/resolve";
import { status } from "@/lib/design/tokens";

const KINDS = ["healthy", "syncing", "warning", "error", "idle"] as const;
const SHORT: Record<(typeof KINDS)[number], string> = {
  healthy: "OK",
  syncing: "Sync",
  warning: "Warn",
  error: "Err",
  idle: "Idle",
};

export function StatusHeatmap({
  games,
  className,
}: {
  games: { id: string; name?: string; status?: string }[];
  className?: string;
}) {
  const counts = useMemo(
    () =>
      KINDS.reduce(
        (acc, k) => {
          acc[k] = games.filter((g) => resolveGameStatus(g.status) === k).length;
          return acc;
        },
        {} as Record<(typeof KINDS)[number], number>
      ),
    [games]
  );
  const max = Math.max(1, ...Object.values(counts));

  return (
    <div className={clsx("obs-panel flex h-auto flex-col self-start", className)}>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Status heatmap</p>
          <h3 className="obs-title-sm">Script health distribution</h3>
        </div>
      </div>
      <div className="mt-3 grid min-w-0 grid-cols-5 gap-1">
        {KINDS.map((kind) => {
          const n = counts[kind];
          const intensity = n / max;
          const meta = status[kind];
          return (
            <div
              key={kind}
              title={meta.label}
              className="flex min-w-0 flex-col items-center justify-center rounded-xl border border-border/60 px-1 py-2"
              style={{
                background: `linear-gradient(180deg, ${meta.color}${Math.round(intensity * 40 + 8).toString(16).padStart(2, "0")}, transparent)`,
                boxShadow: n ? `0 0 ${8 + intensity * 16}px ${meta.glow}` : undefined,
              }}
            >
              <p className="font-mono text-base font-semibold leading-none" style={{ color: meta.color }}>
                {n}
              </p>
              <p className="mt-1.5 text-[9px] font-medium uppercase leading-none tracking-wide text-muted-2">{SHORT[kind]}</p>
            </div>
          );
        })}
      </div>
      {games.length > 0 ? (
        <div className="mt-2.5 flex flex-wrap gap-1">
          {games.slice(0, 24).map((g) => {
            const kind = resolveGameStatus(g.status);
            const meta = status[kind];
            return (
              <span
                key={g.id}
                title={`${g.name || g.id}: ${meta.label}`}
                className="h-2 w-2 rounded-sm"
                style={{ background: meta.color }}
              />
            );
          })}
        </div>
      ) : null}
    </div>
  );
}
