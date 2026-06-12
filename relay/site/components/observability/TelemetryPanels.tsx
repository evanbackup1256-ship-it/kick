"use client";

import clsx from "clsx";
import { AlertTriangle, Radio, WifiOff } from "lucide-react";
import { InViewReveal } from "@/components/motion/InViewReveal";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveRelayStatus, resolveSyncStatus } from "@/lib/status/resolve";
import type { HubStatusPayload } from "@/lib/types";

export function TelemetryAlertBanner({
  online,
  errorMessage,
  sync,
  className,
}: {
  online: boolean;
  errorMessage?: string | null;
  sync?: HubStatusPayload["sync"];
  className?: string;
}) {
  const relayKind = resolveRelayStatus(online, errorMessage);
  const syncKind = resolveSyncStatus(sync);
  const syncError = sync?.lastError?.trim();
  const show = !online || !!errorMessage || syncKind === "error" || !!syncError;

  if (!show) return null;

  return (
    <InViewReveal className={clsx("mb-4", className)}>
      <div
        className={clsx(
          "rounded-2xl border px-4 py-3",
          !online || errorMessage ? "border-red-400/30 bg-red-400/8" : "border-amber-400/25 bg-amber-400/8"
        )}
      >
        <div className="flex flex-wrap items-start gap-3">
          {!online || errorMessage ? (
            <WifiOff className="mt-0.5 h-4 w-4 shrink-0 text-red-300" />
          ) : (
            <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-300" />
          )}
          <div className="min-w-0 flex-1 space-y-2">
            <div className="flex flex-wrap items-center gap-2">
              <p className="text-sm font-semibold text-text">
                {!online ? "Relay unreachable" : syncError ? "Sync pipeline fault" : "Telemetry degraded"}
              </p>
              <StatusPill kind={relayKind} size="sm" />
              {syncKind === "error" ? <StatusPill kind="error" size="sm" label="Sync fault" /> : null}
            </div>
            {errorMessage ? (
              <p className="font-mono text-xs leading-relaxed text-red-100/90">{errorMessage}</p>
            ) : null}
            {syncError ? (
              <pre className="overflow-x-auto rounded-xl border border-red-400/20 bg-black/40 p-3 font-mono text-[11px] leading-relaxed text-red-100/90 whitespace-pre-wrap">
                {syncError}
              </pre>
            ) : null}
            {!errorMessage && !syncError ? (
              <p className="text-xs text-muted">Live polling returned partial data. Metrics may be stale until the relay recovers.</p>
            ) : null}
          </div>
        </div>
      </div>
    </InViewReveal>
  );
}

export function TelemetryMetaStrip({
  data,
  siteLoader,
  siteCore,
}: {
  data?: HubStatusPayload | null;
  siteLoader?: string;
  siteCore?: string;
}) {
  const rows = [
    { label: "Relay", value: data?.relay?.online === false ? "Offline" : "Online", icon: Radio },
    { label: "Auto sync", value: data?.sync?.enabled ? (data.sync.autoStatus ? "Active" : "Enabled") : "Disabled" },
    { label: "Commit", value: data?.release?.commit || "—" },
    { label: "Branch", value: data?.release?.branch || "main" },
    { label: "Loader", value: data?.versions?.loader || siteLoader || "—" },
    { label: "Core", value: data?.versions?.core || siteCore || "—" },
    { label: "Last sync", value: data?.sync?.lastSyncAt ? new Date(data.sync.lastSyncAt).toLocaleString() : "—" },
    { label: "Snapshot", value: data?.at ? new Date(data.at).toLocaleTimeString() : "—" },
  ];

  return (
    <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-4">
      {rows.map((row) => (
        <div key={row.label} className="rounded-xl border border-border/70 bg-black/20 px-3 py-2">
          <p className="text-[10px] uppercase tracking-wide text-muted-2">{row.label}</p>
          <p className="mt-0.5 truncate font-mono text-[11px] text-text">{row.value}</p>
        </div>
      ))}
    </div>
  );
}
