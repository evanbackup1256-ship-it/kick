"use client";

import clsx from "clsx";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveGameStatus } from "@/lib/status/resolve";
import { SmoothScroll } from "@/components/ui/SmoothScroll";

export function EventTimeline({
  events,
  className,
}: {
  events: { at?: string; title?: string; detail?: string; kind?: "release" | "sync" | "status" }[];
  className?: string;
}) {
  return (
    <div className={clsx("obs-panel flex h-full min-h-0 flex-col", className)}>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Event timeline</p>
          <h3 className="obs-title-sm">Activity stream</h3>
        </div>
      </div>
      <SmoothScroll className="mt-3 min-h-0 flex-1" flex>
        <div className="space-y-0 pb-1">
          {events.length ? (
            events.map((ev, i) => (
              <div key={`${ev.at}-${i}`} className="relative flex gap-3 pb-4 pl-4 last:pb-0">
                <span className="absolute left-0 top-1.5 h-full w-px bg-gradient-to-b from-cyan-400/50 to-transparent" />
                <span className="absolute left-[-3px] top-1.5 h-2 w-2 rounded-full border border-cyan-400/60 bg-cyan-400/30" />
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <StatusPill kind={ev.kind === "sync" ? "syncing" : ev.kind === "status" ? "warning" : "online"} size="sm" label={ev.kind || "event"} />
                    <time className="font-mono text-[10px] text-muted-2">{ev.at || "—"}</time>
                  </div>
                  <p className="mt-1 text-sm font-medium text-text">{ev.title || "Update"}</p>
                  {ev.detail ? <p className="mt-0.5 text-xs text-muted">{ev.detail}</p> : null}
                </div>
              </div>
            ))
          ) : (
            <p className="text-sm text-muted-2">Waiting for activity…</p>
          )}
        </div>
      </SmoothScroll>
    </div>
  );
}

export function GameStatusStream({
  games,
  className,
}: {
  games: { id: string; name?: string; status?: string; message?: string; version?: string }[];
  className?: string;
}) {
  return (
    <div className={clsx("obs-panel flex h-full min-h-0 flex-col", className)}>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Service map</p>
          <h3 className="obs-title-sm">Script endpoints</h3>
        </div>
      </div>
      <SmoothScroll className="mt-2 min-h-0 flex-1" flex>
        <div className="space-y-1.5 pb-1">
          {games.map((g) => {
            const pillKind = resolveGameStatus(g.status);
            return (
              <div
                key={g.id}
                className="flex items-center justify-between gap-3 rounded-xl border border-border/70 bg-black/20 px-3 py-2.5 transition hover:border-cyan-400/20"
              >
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">{g.name || g.id}</p>
                  <p className="truncate text-[11px] text-muted">{g.message || "Operational"}</p>
                </div>
                <div className="flex shrink-0 items-center gap-2">
                  {g.version ? <span className="font-mono text-[10px] text-muted-2">v{g.version}</span> : null}
                  <StatusPill kind={pillKind} size="sm" pulse={pillKind === "healthy"} />
                </div>
              </div>
            );
          })}
        </div>
      </SmoothScroll>
    </div>
  );
}
