"use client";

import { motion } from "motion/react";
import { ArrowRight, Copy, Radio, Shield } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { MetricCard } from "@/components/observability/MetricCard";
import { StatusPill } from "@/components/observability/StatusPill";
import { FreshnessChip } from "@/components/observability/FreshnessChip";
import { HealthRing } from "@/components/observability/HealthRing";
import { useHubStatus } from "@/lib/hooks/useHubStatus";
import { resolveRelayStatus, resolveSyncStatus } from "@/lib/status/resolve";
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
  const { data: live, secondsAgo } = useHubStatus();
  const games = Object.values(site.games || {});
  const working = live?.games?.working ?? games.filter((g) => (g.status || "working").toLowerCase() === "working").length;
  const total = live?.games?.total ?? games.length;
  const health = total ? Math.round((working / total) * 100) : 100;
  const relayKind = resolveRelayStatus(online);
  const syncKind = resolveSyncStatus(live?.sync);

  return (
    <div className="grid-workspace">
      <motion.div className="col-span-12 xl:col-span-8" initial={reveal.initial} animate={reveal.animate} transition={spring.soft}>
        <div className="obs-panel relative overflow-hidden p-6 md:p-8">
          <div className="pointer-events-none absolute -right-20 -top-20 h-72 w-72 rounded-full bg-cyan-400/15 blur-3xl" />
          <div className="pointer-events-none absolute -bottom-16 left-1/3 h-48 w-48 rounded-full bg-indigo-500/15 blur-3xl" />
          <div className="relative z-[1]">
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <StatusPill kind={relayKind} pulse={online !== false} />
              <StatusPill kind={syncKind} size="sm" />
              <FreshnessChip secondsAgo={secondsAgo} live />
            </div>
            <p className="obs-kicker">Alleral observability</p>
            <h2 className="obs-title mt-2">{(site.brand || "Alleral").toUpperCase()}</h2>
            <p className="mt-3 max-w-2xl text-sm leading-relaxed text-muted md:text-base">{site.tagline}</p>
            {site.announcement ? (
              <div className="mt-5 rounded-2xl border border-cyan-400/25 bg-cyan-400/8 px-4 py-3 text-sm text-cyan-100 backdrop-blur-sm">{site.announcement}</div>
            ) : null}
            <div className="mt-8 flex flex-wrap gap-2">
              <Button variant="primary" magnetic onClick={onCopy}>
                <Copy className="h-4 w-4" /> Copy loader
              </Button>
              <Button magnetic onClick={() => setView("status")}>
                <Radio className="h-4 w-4" /> Mission control
              </Button>
              <Button variant="ghost" onClick={() => setView("games")}>
                Browse scripts <ArrowRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      </motion.div>

      <motion.div className="col-span-12 grid gap-3 sm:grid-cols-2 xl:col-span-4 xl:grid-cols-1" initial={reveal.initial} animate={reveal.animate} transition={{ ...spring.soft, delay: stagger.base }}>
        <div className="obs-panel flex items-center gap-4">
          <HealthRing kind={health >= 80 ? "healthy" : "warning"} value={health} label="Fleet" />
          <div>
            <p className="obs-kicker">Script fleet</p>
            <p className="text-2xl font-semibold">{working}<span className="text-muted">/{total}</span></p>
            <p className="text-xs text-muted">Operational endpoints</p>
          </div>
        </div>
        <MetricCard label="Loader version" value={`v${live?.versions?.loader || site.loaderVersion || "—"}`} icon={Shield} accent="cyan" />
        <MetricCard label="Core runtime" value={`v${live?.versions?.core || site.coreVersion || "—"}`} accent="violet" trend={`${site.uiLibrary || "Syde"} ${site.uiVersion || ""}`} />
      </motion.div>

      <motion.div className="col-span-12" initial={reveal.initial} animate={reveal.animate} transition={{ ...spring.soft, delay: stagger.base * 2 }}>
        <div className="obs-panel">
          <div className="obs-panel-head">
            <div>
              <p className="obs-kicker">Bootstrap</p>
              <h3 className="obs-title-sm">Loader script · auto-synced</h3>
            </div>
            <Button size="sm" variant="ghost" onClick={onCopy}>
              Copy
            </Button>
          </div>
          <pre className="mt-4 max-h-44 overflow-auto rounded-xl border border-border bg-black/40 p-4 font-mono text-xs leading-relaxed text-muted obs-scroll">
            {site.loadstring || "Loading…"}
          </pre>
        </div>
      </motion.div>
    </div>
  );
}
