"use client";

import clsx from "clsx";
import { ChevronDown } from "lucide-react";
import { useState } from "react";
import { StatusPill } from "./StatusPill";
import { FreshnessChip } from "./FreshnessChip";
import { formatDisplayValue, resolveSyncStatus } from "@/lib/status/resolve";
import { Stagger, StaggerItem } from "@/components/motion/Reveal";

export function SyncMonitor({
  sync,
  dataUpdatedAt,
  online,
}: {
  sync?: { enabled?: boolean; autoStatus?: boolean; lastSyncAt?: string; lastError?: string };
  dataUpdatedAt?: number;
  online?: boolean;
}) {
  const [expanded, setExpanded] = useState(false);
  const syncKind = resolveSyncStatus(sync);
  const rows = [
    {
      label: "Auto Sync",
      kind: syncKind,
      value: syncKind === "healthy" ? "Healthy" : syncKind === "syncing" ? "Syncing" : syncKind === "error" ? "Fault" : "Idle",
      pulse: syncKind === "syncing",
    },
    {
      label: "Relay",
      kind: online === false ? ("offline" as const) : ("online" as const),
      value: online === false ? "Unreachable" : "Online",
      pulse: online !== false,
    },
    { label: "Last Sync", kind: "idle" as const, value: formatDisplayValue(sync?.lastSyncAt ? new Date(sync.lastSyncAt).toLocaleTimeString() : null), pulse: false },
    { label: "Last Error", kind: sync?.lastError ? ("error" as const) : ("healthy" as const), value: sync?.lastError ? "Detected" : "None", pulse: false },
  ] as const;

  return (
    <div className="obs-panel overflow-hidden">
      <div className="obs-panel-head">
        <div>
          <p className="obs-kicker">Sync Monitor</p>
          <h3 className="obs-title-sm">Live pipeline health</h3>
        </div>
        <FreshnessChip dataUpdatedAt={dataUpdatedAt} live />
      </div>

      <Stagger className="mt-4 space-y-2">
        {rows.map((row) => (
          <StaggerItem key={row.label}>
            <div className="flex items-center justify-between gap-3 rounded-xl border border-border/80 bg-black/25 px-3 py-2.5 transition-colors duration-300 hover:border-white/10">
              <span className="text-xs text-muted">{row.label}</span>
              <div className="flex items-center gap-2">
                <span className="text-xs font-medium text-text">{row.value}</span>
                <StatusPill kind={row.kind} size="sm" pulse={row.pulse} />
              </div>
            </div>
          </StaggerItem>
        ))}
      </Stagger>

      {sync?.lastError ? (
        <>
          <button
            type="button"
            onClick={() => setExpanded((v) => !v)}
            className="mt-3 flex w-full items-center justify-between rounded-xl border border-red-400/25 bg-red-400/8 px-3 py-2 text-left text-xs text-red-200 transition-colors duration-300 hover:bg-red-400/12"
          >
            <span>View error details</span>
            <ChevronDown className={clsx("h-4 w-4 transition-transform duration-300", expanded && "rotate-180")} />
          </button>
          {expanded ? (
            <pre className="error-reveal mt-2 overflow-hidden rounded-xl border border-red-400/20 bg-black/40 p-3 font-mono text-[11px] text-red-100/90">
              {sync.lastError}
            </pre>
          ) : null}
        </>
      ) : null}
    </div>
  );
}
