"use client";

import { memo, useCallback, useMemo } from "react";
import { Group, Panel, Separator } from "react-resizable-panels";
import { Activity, Gamepad2, Layers, Radio } from "lucide-react";
import { useLiveSyncMeta } from "@/lib/queries/hooks";
import { useMetricHistory, historyToSeries } from "@/lib/hooks/useMetricHistory";
import { useMediaQuery } from "@/lib/hooks/useMediaQuery";
import { useScrollResize, useScroll } from "@/lib/scroll/lenis-context";
import { resolveRelayStatus } from "@/lib/status/resolve";
import type { SitePayload } from "@/lib/types";
import { MetricCard } from "@/components/observability/MetricCard";
import { SyncMonitor } from "@/components/observability/SyncMonitor";
import { HealthRing } from "@/components/observability/HealthRing";
import { FreshnessChip } from "@/components/observability/FreshnessChip";
import { StatusPill } from "@/components/observability/StatusPill";
import { TelemetryAlertBanner, TelemetryMetaStrip } from "@/components/observability/TelemetryPanels";
import { TelemetryLineChart } from "@/components/charts/TelemetryLineChart";
import { StatusHeatmap } from "@/components/charts/StatusHeatmap";
import { EventTimeline, GameStatusStream } from "@/components/charts/EventTimeline";
import { ServiceGraph } from "@/components/charts/ServiceGraph";
import { InViewReveal } from "@/components/motion/InViewReveal";
import { Reveal } from "@/components/motion/Reveal";

const PANEL_CLASS = "flex min-h-0 flex-col overflow-hidden";

function MetricsColumn({
  healthPct,
  working,
  total,
  history,
  sync,
  online,
  dataUpdatedAt,
  relayError,
}: {
  healthPct: number;
  working: number;
  total: number;
  history: Record<string, number>[];
  sync?: { enabled?: boolean; autoStatus?: boolean; lastSyncAt?: string; lastError?: string };
  online: boolean;
  dataUpdatedAt?: number;
  relayError?: string | null;
}) {
  return (
    <div className="obs-scroll flex flex-col gap-3 overflow-y-auto overscroll-contain pb-2 pr-1" data-lenis-prevent>
      <div className="obs-panel flex items-center gap-4">
        <HealthRing kind={healthPct >= 80 ? "healthy" : healthPct >= 50 ? "warning" : "error"} value={healthPct} label="Health" />
        <div className="min-w-0">
          <p className="obs-kicker">Fleet health</p>
          <p className="text-sm text-muted">
            {working} of {total} scripts operational
          </p>
        </div>
      </div>
      <MetricCard label="Working scripts" numeric={working} icon={Gamepad2} accent="green" sparkline={historyToSeries(history, "working")} trend="Live from relay" />
      <MetricCard label="Tracked games" numeric={total} icon={Layers} accent="violet" />
      <SyncMonitor sync={sync} dataUpdatedAt={dataUpdatedAt} online={online} relayError={relayError} />
    </div>
  );
}

function ChartBlock({ chartData, hasLiveData }: { chartData: { value: number; label: string }[]; hasLiveData: boolean }) {
  return (
    <InViewReveal className="obs-panel obs-panel-chart flex min-h-0 flex-col overflow-hidden">
      <div className="obs-panel-head shrink-0">
        <div>
          <p className="obs-kicker">Throughput</p>
          <h3 className="obs-title-sm">Working scripts · rolling window</h3>
        </div>
        <Activity className="h-4 w-4 shrink-0 text-cyan-400" strokeWidth={1.75} />
      </div>
      <div className="command-center-chart-body relative mt-2 shrink-0 overflow-hidden">
        {hasLiveData ? (
          <TelemetryLineChart series={chartData} className="h-full w-full" />
        ) : (
          <div className="grid h-full place-items-center px-4 py-6 text-center">
            <p className="max-w-xs text-xs text-muted">Collecting live samples… chart appears after a few poll cycles.</p>
          </div>
        )}
      </div>
    </InViewReveal>
  );
}

function CommandCenterInner({ site }: { site: SitePayload }) {
  const isMobile = useMediaQuery("(max-width: 767px)");
  const { data, error, dataUpdatedAt, loading } = useLiveSyncMeta();
  const online = !error && data?.ok !== false;
  const relayKind = resolveRelayStatus(online, error ? error.message : null);
  const relayError = error ? error.message : null;

  const games = useMemo(() => {
    if (data?.games?.items?.length) return data.games.items;
    return Object.entries(site.games || {}).map(([id, g]) => ({
      id,
      name: g.name || id,
      status: (g.status || "working").toLowerCase(),
      version: g.version,
      message: g.message,
    }));
  }, [data?.games?.items, site.games]);

  const working = data?.games?.working ?? games.filter((g) => (g.status || "working") === "working").length;
  const total = data?.games?.total ?? games.length;
  const healthPct = total ? Math.round((working / total) * 100) : 100;

  const snapshot = useMemo(() => ({ working, total, health: healthPct }), [working, total, healthPct]);
  const history = useMetricHistory(snapshot, 36, 20000);
  const workingSeries = useMemo(
    () => historyToSeries(history, "working").map((v, i) => ({ value: v, label: `${i}` })),
    [history]
  );
  const hasLiveData = workingSeries.length > 2;

  const timeline = useMemo(() => {
    const items: {
      at?: string;
      title?: string;
      detail?: string;
      kind?: "release" | "sync" | "status" | "error";
      severity?: "info" | "warning" | "error";
    }[] = [];

    if (data?.sync?.lastError) {
      items.push({
        at: data.sync.lastSyncAt ? new Date(data.sync.lastSyncAt).toLocaleTimeString() : "Recent",
        title: "Sync pipeline fault",
        detail: data.sync.lastError,
        kind: "error",
        severity: "error",
      });
    }

    games
      .filter((g) => (g.status || "working") !== "working")
      .forEach((g) => {
        items.push({
          at: "Live",
          title: `${g.name || g.id} degraded`,
          detail: g.message || `Status: ${g.status || "unknown"} · id ${g.id}${g.version ? ` · v${g.version}` : ""}`,
          kind: "error",
          severity: "error",
        });
      });

    if (data?.sync?.lastSyncAt) {
      items.push({
        at: new Date(data.sync.lastSyncAt).toLocaleTimeString(),
        title: "GitHub sync completed",
        kind: "sync",
        detail: `Commit ${data.release?.commit || "—"} · branch ${data.release?.branch || "main"}`,
      });
    }

    (data?.changelog || []).slice(0, 5).forEach((c) => {
      items.push({ at: c.date, title: c.title, detail: c.items?.[0], kind: "release" });
    });

    if (site.announcement) {
      items.push({ at: "Now", title: "Announcement", detail: site.announcement, kind: "status", severity: "warning" });
    }

    return items;
  }, [data, games, site.announcement]);

  const chartData = hasLiveData ? workingSeries : [];
  const scroll = useScroll();
  const onPanelLayout = useCallback(() => {
    scroll?.resize();
  }, [scroll]);

  useScrollResize([isMobile, hasLiveData, games.length]);

  return (
    <div className="command-center flex min-h-0 flex-col">
      <Reveal className="mb-4 flex shrink-0 flex-wrap items-center justify-between gap-3">
        <div>
          <p className="obs-kicker">Observability</p>
          <h2 className="obs-title">Mission control</h2>
        </div>
        <div className="flex flex-wrap items-center gap-2 md:hidden">
          <StatusPill kind={relayKind} />
          <FreshnessChip dataUpdatedAt={dataUpdatedAt} live={!loading} />
        </div>
      </Reveal>

      <TelemetryAlertBanner online={online} errorMessage={relayError} sync={data?.sync} />
      <TelemetryMetaStrip data={data} siteLoader={site.loaderVersion} siteCore={site.coreVersion} />

      {isMobile ? (
        <div className="mt-4 flex flex-col gap-3 pb-4">
          <MetricsColumn
            healthPct={healthPct}
            working={working}
            total={total}
            history={history}
            sync={data?.sync}
            online={online}
            dataUpdatedAt={dataUpdatedAt}
            relayError={relayError}
          />
          <div className="obs-panel obs-panel-chart overflow-hidden">
            <div className="obs-panel-head">
              <div>
                <p className="obs-kicker">Throughput</p>
                <h3 className="obs-title-sm">Working scripts · rolling window</h3>
              </div>
            </div>
            {hasLiveData ? (
              <TelemetryLineChart series={chartData} className="relative mt-2 h-[220px] w-full" />
            ) : (
              <p className="px-4 py-8 text-center text-xs text-muted">Collecting live samples…</p>
            )}
          </div>
          <StatusHeatmap games={games} className="min-h-[220px]" />
          <ServiceGraph games={games} sync={data?.sync} className="min-h-[280px]" />
          <GameStatusStream games={games} className="min-h-[280px]" />
          <EventTimeline events={timeline} className="min-h-[280px]" />
        </div>
      ) : (
        <div className="command-center-grid mt-4 min-h-0 overflow-hidden">
          <Group orientation="horizontal" className="h-full w-full gap-2" onLayoutChanged={onPanelLayout}>
            <Panel defaultSize={20} minSize={18} maxSize={28} className={PANEL_CLASS}>
              <MetricsColumn
                healthPct={healthPct}
                working={working}
                total={total}
                history={history}
                sync={data?.sync}
                online={online}
                dataUpdatedAt={dataUpdatedAt}
                relayError={relayError}
              />
            </Panel>

            <Separator className="obs-separator" />

            <Panel defaultSize={52} minSize={36} className={PANEL_CLASS}>
              <Group orientation="vertical" className="h-full min-h-0 gap-2">
                <Panel defaultSize={38} minSize={28} maxSize={45} className={PANEL_CLASS}>
                  <ChartBlock chartData={chartData} hasLiveData={hasLiveData} />
                </Panel>
                <Separator className="obs-separator horizontal" />
                <Panel defaultSize={62} minSize={40} className={PANEL_CLASS}>
                  <div className="grid h-full min-h-0 grid-cols-1 gap-2 overflow-hidden xl:grid-cols-2">
                    <StatusHeatmap games={games} className="min-h-0 overflow-hidden" />
                    <ServiceGraph games={games} sync={data?.sync} className="min-h-0 overflow-hidden" />
                  </div>
                </Panel>
              </Group>
            </Panel>

            <Separator className="obs-separator" />

            <Panel defaultSize={28} minSize={22} maxSize={36} className={PANEL_CLASS}>
              <Group orientation="vertical" className="h-full min-h-0 gap-2 pl-1">
                <Panel defaultSize={55} minSize={30} className={PANEL_CLASS}>
                  <GameStatusStream games={games} className="h-full min-h-0" />
                </Panel>
                <Separator className="obs-separator horizontal" />
                <Panel defaultSize={45} minSize={25} className={PANEL_CLASS}>
                  <EventTimeline events={timeline} className="h-full min-h-0" />
                </Panel>
              </Group>
            </Panel>
          </Group>
        </div>
      )}

      <div className="mt-3 flex shrink-0 flex-wrap gap-2 font-mono text-[10px] text-muted-2">
        <span className="inline-flex items-center gap-1">
          <Radio className="h-3 w-3" /> loader {data?.versions?.loader || site.loaderVersion || "—"}
        </span>
        <span>core {data?.versions?.core || site.coreVersion || "—"}</span>
        <span>
          {data?.versions?.ui || site.uiLibrary} {data?.versions?.uiVersion || site.uiVersion}
        </span>
        {relayError ? <span className="text-red-300/90">api: {relayError}</span> : null}
      </div>
    </div>
  );
}

export const CommandCenter = memo(CommandCenterInner);
