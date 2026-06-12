"use client";

import clsx from "clsx";
import { useVirtualizer } from "@tanstack/react-virtual";
import { memo, useRef } from "react";
import { InViewReveal } from "@/components/motion/InViewReveal";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveGameStatus } from "@/lib/status/resolve";

type TimelineEvent = {
  at?: string;
  title?: string;
  detail?: string;
  kind?: "release" | "sync" | "status" | "error";
  severity?: "info" | "warning" | "error";
};

type GameRow = { id: string; name?: string; status?: string; message?: string; version?: string };

function VirtualList<T>({
  items,
  estimateSize,
  className,
  empty,
  renderRow,
}: {
  items: T[];
  estimateSize: number;
  className?: string;
  empty: React.ReactNode;
  renderRow: (item: T, index: number) => React.ReactNode;
}) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => estimateSize,
    overscan: 6,
  });

  if (!items.length) {
    return <div className={clsx("text-sm text-muted-2", className)}>{empty}</div>;
  }

  return (
    <div ref={parentRef} className={clsx("obs-scroll min-h-0 flex-1 overflow-y-auto overscroll-contain", className)} data-lenis-prevent>
      <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
        {virtualizer.getVirtualItems().map((row) => (
          <div
            key={row.key}
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              transform: `translateY(${row.start}px)`,
            }}
          >
            {renderRow(items[row.index], row.index)}
          </div>
        ))}
      </div>
    </div>
  );
}

function eventKind(ev: TimelineEvent) {
  if (ev.kind === "error" || ev.severity === "error") return "error" as const;
  if (ev.kind === "sync") return "syncing" as const;
  if (ev.kind === "status" || ev.severity === "warning") return "warning" as const;
  return "online" as const;
}

export const EventTimeline = memo(function EventTimeline({
  events,
  className,
  embedded,
}: {
  events: TimelineEvent[];
  className?: string;
  embedded?: boolean;
}) {
  const body = (
    <>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Event timeline</p>
          <h3 className="obs-title-sm">Activity & fault stream</h3>
        </div>
      </div>
      <VirtualList
        items={events}
        estimateSize={96}
        className="mt-3"
        empty="Waiting for activity…"
        renderRow={(ev) => (
          <div
            className={clsx(
              "relative flex gap-3 pb-4 pl-4",
              ev.severity === "error" && "rounded-xl border border-red-400/15 bg-red-400/5 pr-2"
            )}
          >
            <span
              className={clsx(
                "absolute left-0 top-1.5 h-full w-px bg-gradient-to-b to-transparent",
                ev.severity === "error" ? "from-red-400/60" : "from-cyan-400/50"
              )}
            />
            <span
              className={clsx(
                "absolute left-[-3px] top-1.5 h-2 w-2 rounded-full border",
                ev.severity === "error" ? "border-red-400/60 bg-red-400/30" : "border-cyan-400/60 bg-cyan-400/30"
              )}
            />
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <StatusPill kind={eventKind(ev)} size="sm" label={ev.kind || "event"} />
                <time className="font-mono text-[10px] text-muted-2">{ev.at || "—"}</time>
              </div>
              <p className="mt-1 text-sm font-medium text-text">{ev.title || "Update"}</p>
              {ev.detail ? (
                <p className={clsx("mt-0.5 text-xs leading-relaxed", ev.severity === "error" ? "font-mono text-red-200/90" : "text-muted")}>
                  {ev.detail}
                </p>
              ) : null}
            </div>
          </div>
        )}
      />
    </>
  );

  if (embedded) {
    return <div className={clsx("obs-panel flex h-full min-h-0 flex-col", className)}>{body}</div>;
  }

  return <InViewReveal className={clsx("obs-panel flex h-full min-h-0 flex-col", className)}>{body}</InViewReveal>;
});

export const GameStatusStream = memo(function GameStatusStream({
  games,
  className,
  embedded,
}: {
  games: GameRow[];
  className?: string;
  embedded?: boolean;
}) {
  const body = (
    <>
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Service map</p>
          <h3 className="obs-title-sm">Script endpoints · diagnostics</h3>
        </div>
      </div>
      <VirtualList
        items={games}
        estimateSize={78}
        className="mt-2"
        empty="No scripts tracked yet."
        renderRow={(g) => {
          const pillKind = resolveGameStatus(g.status);
          const broken = pillKind !== "healthy";
          return (
            <div
              className={clsx(
                "mb-1.5 rounded-xl border px-3 py-2.5 transition hover:border-cyan-400/20",
                broken ? "border-red-400/25 bg-red-400/5" : "border-border/70 bg-black/20"
              )}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <p className="truncate text-sm font-medium">{g.name || g.id}</p>
                  <p className="mt-0.5 font-mono text-[10px] text-muted-2">
                    {g.id}
                    {g.version ? ` · v${g.version}` : ""}
                  </p>
                  <p className={clsx("mt-1 text-[11px] leading-relaxed", broken ? "text-red-200/90" : "text-muted")}>
                    {g.message || (broken ? "Non-operational — check relay auto-status logs" : "Operational")}
                  </p>
                </div>
                <StatusPill kind={pillKind} size="sm" />
              </div>
            </div>
          );
        }}
      />
    </>
  );

  if (embedded) {
    return <div className={clsx("obs-panel flex h-full min-h-0 flex-col", className)}>{body}</div>;
  }

  return <InViewReveal className={clsx("obs-panel flex h-full min-h-0 flex-col", className)}>{body}</InViewReveal>;
});
