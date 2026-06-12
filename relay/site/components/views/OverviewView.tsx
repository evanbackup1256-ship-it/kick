"use client";

import { motion } from "motion/react";
import { Button } from "@/components/ui/Button";
import { AnimatedNumber, StatusPulse } from "@/components/ui/DataViz";
import { Badge } from "@/components/ui/Form";
import { CardHeader, MetricTile, Panel } from "@/components/ui/Panel";
import { reveal, spring, stagger } from "@/lib/motion/config";
import type { SitePayload } from "@/lib/types";
import { usePlatformStore } from "@/lib/store/platform";

export function OverviewView({
  site,
  online,
  onCopy,
}: {
  site: SitePayload;
  online?: boolean;
  onCopy: () => void;
}) {
  const setView = usePlatformStore((s) => s.setView);
  const games = Object.values(site.games || {});
  const working = games.filter((g) => (g.status || "working").toLowerCase() === "working").length;

  return (
    <div className="grid-workspace">
      <motion.div className="col-span-12 lg:col-span-7" initial={reveal.initial} animate={reveal.animate} transition={{ ...spring.soft, delay: 0 }}>
        <Panel glow padding="lg" className="relative overflow-hidden">
          <div className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full bg-accent/20 blur-3xl" />
          <p className="label-gradient mb-2 text-xs font-semibold uppercase tracking-[0.12em]">Alleral Platform</p>
          <h2 className="text-gradient text-[clamp(2rem,4vw,3.2rem)] font-bold tracking-tight">{(site.brand || "Alleral").toUpperCase()}</h2>
          <p className="mt-3 max-w-xl text-muted">{site.tagline}</p>
          {site.announcement ? (
            <div className="mt-4 rounded-xl border border-cyan-400/25 bg-cyan-400/10 px-4 py-3 text-sm text-cyan-200">{site.announcement}</div>
          ) : null}
          <div className="mt-6 flex flex-wrap gap-2">
            <Button variant="primary" magnetic onClick={onCopy}>
              Copy loader
            </Button>
            <Button magnetic onClick={() => setView("control")}>
              Open mission control
            </Button>
            <Button variant="ghost" onClick={() => setView("games")}>
              Browse games
            </Button>
          </div>
        </Panel>
      </motion.div>

      <motion.div className="col-span-12 grid gap-3 sm:grid-cols-2 lg:col-span-5 lg:grid-cols-1" initial={reveal.initial} animate={reveal.animate} transition={{ ...spring.soft, delay: stagger.base }}>
        <MetricTile label="Games tracked" value={<AnimatedNumber value={games.length} />} accent="cyan" />
        <MetricTile label="Working scripts" value={<AnimatedNumber value={working} />} accent="green" />
        <Panel padding="md">
          <StatusPulse online={!!online} label={online ? "Relay connected" : "Relay unreachable"} />
          <p className="mt-3 font-mono text-xs text-muted">loader v{site.loaderVersion || "—"} · core {site.coreVersion || "—"}</p>
          <Badge tone="violet" className="mt-3">
            {site.uiLibrary || "Syde"} {site.uiVersion || ""}
          </Badge>
        </Panel>
      </motion.div>

      <motion.div className="col-span-12" initial={reveal.initial} animate={reveal.animate} transition={{ ...spring.soft, delay: stagger.base * 2 }}>
        <Panel padding="md">
          <CardHeader title="Loader script" desc="Auto-synced from GitHub on every inject" />
          <pre className="max-h-40 overflow-auto rounded-xl border border-border bg-black/30 p-4 font-mono text-xs leading-relaxed text-muted">
            {site.loadstring || "Loading…"}
          </pre>
        </Panel>
      </motion.div>
    </div>
  );
}
