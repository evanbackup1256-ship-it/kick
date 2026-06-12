"use client";

import clsx from "clsx";
import { AlertCircle } from "lucide-react";
import { InViewReveal } from "@/components/motion/InViewReveal";
import { resolveGameStatus, resolveSyncStatus } from "@/lib/status/resolve";
import { status } from "@/lib/design/tokens";

type GameNode = { id: string; name?: string; status?: string; version?: string; message?: string };

export function ServiceGraph({
  games,
  sync,
  className,
}: {
  games: GameNode[];
  sync?: { lastError?: string; enabled?: boolean; autoStatus?: boolean };
  className?: string;
}) {
  const hub = status.online;
  const syncKind = resolveSyncStatus(sync);
  const syncMeta = status[syncKind];
  const broken = games.filter((g) => resolveGameStatus(g.status) !== "healthy");

  return (
    <InViewReveal className={clsx("obs-panel flex min-h-0 flex-col", className)}>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Dependency graph</p>
          <h3 className="obs-title-sm">Hub → scripts · live topology</h3>
        </div>
        <span className="font-mono text-[10px] text-muted-2">
          {games.length - broken.length}/{games.length} healthy
        </span>
      </div>

      <div className="mt-3 min-h-0 flex-1 space-y-2">
        <div
          className="rounded-xl border px-3 py-2.5"
          style={{
            borderColor: `${hub.color}44`,
            background: `${hub.color}10`,
            boxShadow: `0 0 16px ${hub.glow}`,
          }}
        >
          <div className="flex items-start justify-between gap-2">
            <div>
              <p className="text-xs font-semibold text-text">Alleral Relay</p>
              <p className="text-[10px] text-muted">Central hub · status API</p>
            </div>
            <span className="text-[9px] uppercase tracking-wide" style={{ color: syncMeta.color }}>
              Sync {syncMeta.label}
            </span>
          </div>
          {sync?.lastError ? (
            <p className="mt-2 rounded-lg border border-red-400/20 bg-red-400/8 px-2 py-1.5 font-mono text-[10px] leading-relaxed text-red-200/90">
              {sync.lastError.slice(0, 160)}
              {sync.lastError.length > 160 ? "…" : ""}
            </p>
          ) : (
            <p className="mt-2 text-[10px] text-muted-2">
              Auto sync {sync?.enabled ? (sync.autoStatus ? "active" : "enabled") : "off"} · distributing {games.length} scripts
            </p>
          )}
        </div>

        <div className="relative mx-auto flex w-px min-h-[10px] justify-center bg-gradient-to-b from-cyan-400/40 to-transparent" aria-hidden />

        <ul className="space-y-1.5">
          {games.map((g) => {
            const kind = resolveGameStatus(g.status);
            const meta = status[kind];
            const isBroken = kind !== "healthy";
            return (
              <li
                key={g.id}
                className={clsx(
                  "rounded-lg border bg-black/20 px-2.5 py-2",
                  isBroken ? "border-red-400/25" : "border-border/70"
                )}
                style={{ borderLeftColor: meta.color, borderLeftWidth: 2 }}
              >
                <div className="flex items-start gap-2">
                  <span className="mt-1 h-1.5 w-1.5 shrink-0 rounded-full" style={{ background: meta.color, boxShadow: `0 0 6px ${meta.glow}` }} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <p className="truncate text-[11px] font-medium text-text">{g.name || g.id}</p>
                      <span className="shrink-0 text-[9px] uppercase tracking-wide" style={{ color: meta.color }}>
                        {meta.label}
                      </span>
                    </div>
                    <div className="mt-0.5 flex flex-wrap gap-x-2 gap-y-0.5 font-mono text-[10px] text-muted-2">
                      <span>id {g.id}</span>
                      {g.version ? <span>v{g.version}</span> : null}
                      <span>status {g.status || "working"}</span>
                    </div>
                    <p className={clsx("mt-1 text-[10px] leading-relaxed", isBroken ? "text-red-200/90" : "text-muted")}>
                      {isBroken ? (
                        <span className="inline-flex items-start gap-1">
                          <AlertCircle className="mt-0.5 h-3 w-3 shrink-0" />
                          {g.message || "Script marked non-operational by relay auto-status."}
                        </span>
                      ) : (
                        g.message || "Operational — passing health checks"
                      )}
                    </p>
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      </div>
    </InViewReveal>
  );
}
