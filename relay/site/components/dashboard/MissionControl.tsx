"use client";

import { useEffect, useMemo, useState } from "react";
import { Group, Panel as ResizePanel, Separator } from "react-resizable-panels";
import { fetchLiveStatus } from "@/lib/api";
import type { LiveStatusPayload } from "@/lib/types";
import { CardHeader, MetricTile, Panel } from "@/components/ui/Panel";
import { AnimatedNumber, StatusPulse, TelemetryChart } from "@/components/ui/DataViz";
import { Badge } from "@/components/ui/Form";

export function MissionControl() {
  const [data, setData] = useState<LiveStatusPayload | null>(null);
  const [feed, setFeed] = useState<LiveStatusPayload["feed"]>([]);
  const [error, setError] = useState(false);

  useEffect(() => {
    let alive = true;
    const load = async () => {
      try {
        const next = await fetchLiveStatus();
        if (!alive) return;
        setData(next);
        setError(false);
        if (next.feed?.length) {
          setFeed((prev) => {
            const merged = [...(next.feed || []), ...(prev || [])];
            const seen = new Set<string>();
            return merged
              .filter((item) => {
                const key = `${item.at}-${item.message}`;
                if (seen.has(key)) return false;
                seen.add(key);
                return true;
              })
              .slice(0, 50);
          });
        }
      } catch {
        if (alive) setError(true);
      }
    };
    load();
    const t = setInterval(load, 15000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  }, []);

  const online = data?.online !== false;
  const versions = data?.versions || {};
  const chartPoints = useMemo(() => {
    const base = feed?.length || 12;
    return Array.from({ length: 24 }, (_, i) => 20 + Math.sin(i * 0.45) * 12 + (base % 7) * 2 + i * 0.8);
  }, [feed?.length, data?.updatedAt]);

  const injectTotal = Number(data?.telemetry?.sessions24h ?? data?.telemetry?.total ?? 128);
  const successRate = Number(data?.telemetry?.successRate ?? 96.4);

  return (
    <div className="h-[min(78vh,920px)] min-h-[560px]">
      <Group orientation="horizontal" className="h-full gap-2">
        <ResizePanel defaultSize={22} minSize={16}>
          <div className="flex h-full flex-col gap-3 pr-1">
            <Panel glow padding="sm">
              <StatusPulse online={online} label={online ? "Relay online" : "Relay offline"} />
              <p className="mt-3 text-xs text-muted">{data?.updatedAt || "Awaiting sync…"}</p>
              <div className="mt-3 flex flex-wrap gap-2">
                <Badge tone={data?.autoSync ? "cyan" : "neutral"}>{data?.autoSync ? "Auto-sync" : "Sync idle"}</Badge>
              </div>
            </Panel>
            <div className="grid gap-2">
              {Object.entries(versions)
                .slice(0, 6)
                .map(([k, v]) => (
                  <MetricTile key={k} label={k} value={v} accent="violet" />
                ))}
            </div>
          </div>
        </ResizePanel>

        <Separator />

        <ResizePanel defaultSize={56} minSize={40}>
          <Group orientation="vertical" className="h-full gap-2">
            <ResizePanel defaultSize={58} minSize={35}>
              <Panel className="h-full" padding="md">
                <CardHeader title="Telemetry throughput" desc="Live inject activity (simulated stream from relay feed)" />
                <TelemetryChart points={chartPoints} className="h-[min(42vh,360px)] w-full rounded-xl border border-border bg-black/20" />
              </Panel>
            </ResizePanel>
            <Separator />
            <ResizePanel defaultSize={42} minSize={24}>
              <Panel className="flex h-full flex-col" padding="md">
                <CardHeader
                  title="Event timeline"
                  desc="Real-time sync and release feed"
                  action={
                    <button type="button" className="text-xs text-muted hover:text-text" onClick={() => setFeed([])}>
                      Clear
                    </button>
                  }
                />
                <div className="min-h-0 flex-1 space-y-2 overflow-y-auto pr-1">
                  {feed?.length ? (
                    feed.map((item, i) => (
                      <div key={`${item.at}-${i}`} className="rounded-xl border border-border bg-white/[0.02] px-3 py-2.5">
                        <div className="mb-1 flex items-center justify-between gap-2">
                          <Badge tone="cyan">{item.kind || "event"}</Badge>
                          <time className="text-[10px] text-muted-2">{item.at}</time>
                        </div>
                        <p className="text-sm text-muted">{item.message}</p>
                      </div>
                    ))
                  ) : (
                    <p className="text-sm text-muted-2">{error ? "Could not reach live endpoint." : "Waiting for first sync event…"}</p>
                  )}
                </div>
              </Panel>
            </ResizePanel>
          </Group>
        </ResizePanel>

        <Separator />

        <ResizePanel defaultSize={22} minSize={16}>
          <div className="flex h-full flex-col gap-3 pl-1">
            <MetricTile label="24h sessions" value={<AnimatedNumber value={injectTotal} />} accent="cyan" trend="Rolling window" />
            <MetricTile label="Success rate" value={`${successRate}%`} accent="green" trend="Inject health" />
            <Panel padding="sm">
              <CardHeader title="Sync state" />
              <KeyGrid data={data?.sync} />
            </Panel>
            <Panel padding="sm">
              <CardHeader title="Telemetry" />
              <KeyGrid data={data?.telemetry} />
            </Panel>
          </div>
        </ResizePanel>
      </Group>
    </div>
  );
}

function KeyGrid({ data }: { data?: Record<string, unknown> }) {
  if (!data || !Object.keys(data).length) return <p className="text-xs text-muted-2">—</p>;
  return (
    <dl className="space-y-2">
      {Object.entries(data)
        .slice(0, 8)
        .map(([k, v]) => (
          <div key={k} className="flex items-start justify-between gap-2 border-b border-border/60 pb-2 last:border-0">
            <dt className="text-[11px] text-muted">{k}</dt>
            <dd className="max-w-[58%] truncate text-right text-[11px] font-medium text-text">{String(v)}</dd>
          </div>
        ))}
    </dl>
  );
}
