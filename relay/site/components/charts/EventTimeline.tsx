"use client";

import clsx from "clsx";
import { useVirtualizer } from "@tanstack/react-virtual";
import { memo, useRef } from "react";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveGameStatus } from "@/lib/status/resolve";

type TimelineEvent = { at?: string; title?: string; detail?: string; kind?: "release" | "sync" | "status" };
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
    <div ref={parentRef} className={clsx("min-h-0 flex-1 overflow-y-auto overscroll-contain", className)}>
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

export const EventTimeline = memo(function EventTimeline({
  events,
  className,
}: {
  events: TimelineEvent[];
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
      <VirtualList
        items={events}
        estimateSize={88}
        className="mt-3"
        empty="Waiting for activity…"
        renderRow={(ev, i) => (
          <div className="relative flex gap-3 pb-4 pl-4">
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
        )}
      />
    </div>
  );
});

export const GameStatusStream = memo(function GameStatusStream({
  games,
  className,
}: {
  games: GameRow[];
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
      <VirtualList
        items={games}
        estimateSize={64}
        className="mt-2"
        empty="No scripts tracked yet."
        renderRow={(g) => {
          const pillKind = resolveGameStatus(g.status);
          return (
            <div className="mb-1.5 flex items-center justify-between gap-3 rounded-xl border border-border/70 bg-black/20 px-3 py-2.5 transition hover:border-cyan-400/20">
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
        }}
      />
    </div>
  );
});
