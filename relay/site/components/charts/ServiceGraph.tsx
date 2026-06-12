"use client";

import clsx from "clsx";
import { resolveGameStatus } from "@/lib/status/resolve";
import { status } from "@/lib/design/tokens";

export function ServiceGraph({
  games,
  className,
}: {
  games: { id: string; name?: string; status?: string }[];
  className?: string;
}) {
  const hub = status.online;

  return (
    <div className={clsx("obs-panel flex min-h-0 flex-col", className)}>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Dependency graph</p>
          <h3 className="obs-title-sm">Hub → scripts</h3>
        </div>
      </div>

      <div className="mt-3 min-h-0 flex-1">
        <div
          className="rounded-xl border px-3 py-2.5 text-center"
          style={{
            borderColor: `${hub.color}44`,
            background: `${hub.color}10`,
            boxShadow: `0 0 16px ${hub.glow}`,
          }}
        >
          <p className="text-xs font-semibold text-text">Alleral Relay</p>
          <p className="text-[10px] text-muted">Central hub</p>
        </div>

        <div className="relative mx-auto mt-2 flex w-px flex-1 min-h-[12px] justify-center bg-gradient-to-b from-cyan-400/40 to-transparent" aria-hidden />

        <ul className="mt-2 space-y-1.5">
          {games.map((g) => {
            const kind = resolveGameStatus(g.status);
            const meta = status[kind];
            return (
              <li
                key={g.id}
                className="flex items-center gap-2 rounded-lg border border-border/70 bg-black/20 px-2.5 py-2"
                style={{ borderLeftColor: meta.color, borderLeftWidth: 2 }}
              >
                <span className="h-1.5 w-1.5 shrink-0 rounded-full" style={{ background: meta.color, boxShadow: `0 0 6px ${meta.glow}` }} />
                <span className="min-w-0 flex-1 truncate text-[11px] font-medium text-text">{g.name || g.id}</span>
                <span className="shrink-0 text-[9px] uppercase tracking-wide" style={{ color: meta.color }}>
                  {meta.label}
                </span>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}
