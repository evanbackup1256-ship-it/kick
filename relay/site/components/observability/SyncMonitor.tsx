"use client";

import clsx from "clsx";
import { ChevronDown } from "lucide-react";
import { useState } from "react";
import { motion, AnimatePresence } from "motion/react";
import { StatusPill } from "./StatusPill";
import { FreshnessChip } from "./FreshnessChip";
import { formatDisplayValue, resolveSyncStatus } from "@/lib/status/resolve";
import { spring } from "@/lib/motion/config";

export function SyncMonitor({
  sync,
  dataUpdatedAt,
  online,
  relayError,
}: {
  sync?: { enabled?: boolean; autoStatus?: boolean; lastSyncAt?: string; lastError?: string };
  dataUpdatedAt?: number;
  online?: boolean;
  relayError?: string | null;
}) {
  const [expanded, setExpanded] = useState(Boolean(sync?.lastError));
  const syncKind = resolveSyncStatus(sync);
  const rows = [
    {
      label: "Auto Sync",
      kind: syncKind,
      value: syncKind === "healthy" ? "Healthy" : syncKind === "syncing" ? "Syncing" : syncKind === "error" ? "Fault" : "Idle",
      pulse: syncKind === "syncing",
      detail: sync?.enabled ? (sync.autoStatus ? "Polling GitHub for script updates" : "Enabled but idle") : "Disabled in relay config",
    },
    {
      label: "Relay",
      kind: online === false ? ("offline" as const) : ("online" as const),
      value: online === false ? "Unreachable" : "Online",
      pulse: false,
      detail: relayError || (online === false ? "Status API did not respond" : "Accepting live status requests"),
    },
    {
      label: "Last Sync",
      kind: "idle" as const,
      value: formatDisplayValue(sync?.lastSyncAt ? new Date(sync.lastSyncAt).toLocaleString() : null),
      pulse: false,
      detail: sync?.lastSyncAt ? `Completed ${new Date(sync.lastSyncAt).toLocaleString()}` : "No successful sync recorded yet",
    },
    {
      label: "Last Error",
      kind: sync?.lastError ? ("error" as const) : ("healthy" as const),
      value: sync?.lastError ? "Fault detected" : "None",
      pulse: false,
      detail: sync?.lastError || "Pipeline clean — no sync errors in relay memory",
    },
  ] as const;

  return (
    <div className="obs-panel overflow-hidden">
      <div className="obs-panel-head">
        <div>
          <p className="obs-kicker">Sync Monitor</p>
          <h3 className="obs-title-sm">Pipeline diagnostics</h3>
        </div>
        <FreshnessChip dataUpdatedAt={dataUpdatedAt} live />
      </div>

      <div className="mt-4 space-y-2">
        {rows.map((row) => (
          <div
            key={row.label}
            className="rounded-xl border border-border/80 bg-black/25 px-3 py-2.5 transition-colors duration-300 hover:border-white/10"
          >
            <div className="flex items-center justify-between gap-3">
              <span className="text-xs text-muted">{row.label}</span>
              <div className="flex items-center gap-2">
                <span className="text-xs font-medium text-text">{row.value}</span>
                <StatusPill kind={row.kind} size="sm" pulse={row.pulse} />
              </div>
            </div>
            <p className="mt-1.5 text-[11px] leading-relaxed text-muted-2">{row.detail}</p>
          </div>
        ))}
      </div>

      <AnimatePresence initial={false}>
        {sync?.lastError ? (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={spring.soft}
            className="overflow-hidden"
          >
            <button
              type="button"
              onClick={() => setExpanded((v) => !v)}
              className="mt-3 flex w-full items-center justify-between rounded-xl border border-red-400/25 bg-red-400/8 px-3 py-2 text-left text-xs text-red-200 transition-colors duration-300 hover:bg-red-400/12"
            >
              <span>Full error payload</span>
              <ChevronDown className={clsx("h-4 w-4 transition-transform duration-300", expanded && "rotate-180")} />
            </button>
            {expanded ? (
              <pre className="error-reveal mt-2 max-h-40 overflow-auto rounded-xl border border-red-400/20 bg-black/40 p-3 font-mono text-[11px] leading-relaxed text-red-100/90 whitespace-pre-wrap">
                {sync.lastError}
              </pre>
            ) : null}
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}
