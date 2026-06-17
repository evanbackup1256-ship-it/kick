"use client";

import { ArrowRight, Check, Copy, ExternalLink, Gamepad2, Radio, Sparkles, Terminal, Zap, AlertTriangle, BookOpen } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { MetricCard } from "@/components/observability/MetricCard";
import { StatusPill } from "@/components/observability/StatusPill";
import { FreshnessChip } from "@/components/observability/FreshnessChip";
import { InViewReveal } from "@/components/motion/InViewReveal";
import { useLiveSyncMeta } from "@/lib/queries/hooks";
import { resolveRelayStatus, resolveSyncStatus } from "@/lib/status/resolve";
import { resolveResourceUrl } from "@/lib/sanitize";
import type { SitePayload } from "@/lib/types";
import { usePlatformStore } from "@/lib/store/platform";
import { GlassPanel } from "@/components/effects/GlassPanel";
import { HolographicHighlight } from "@/components/effects/HolographicHighlight";
import { ViewTransition } from "@/components/effects/ViewTransition";

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
  const { data: live, dataUpdatedAt } = useLiveSyncMeta("overview");
  const games = Object.entries(site.games || {});
  const working =
    live?.games?.working ?? games.filter(([, g]) => (g.status || "working").toLowerCase() === "working").length;
  const total = live?.games?.total ?? games.length;
  const relayKind = resolveRelayStatus(online);
  const syncKind = resolveSyncStatus(live?.sync);
  const brokenGames = games.filter(([, g]) => {
    const s = (g.status || "working").toLowerCase();
    return s === "broken" || s === "maintenance";
  });
  const latestLog = (site.changelog || []).slice(0, 3);

  return (
    <ViewTransition id="overview">
    <div className="bento-grid">
      <InViewReveal className="bento-hero panel relative overflow-hidden p-6 md:p-10">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_20%_0%,rgba(83,252,18,0.12),transparent_45%)]" />
        <div className="relative z-[1] max-w-3xl">
          <div className="mb-5 flex flex-wrap items-center gap-2">
            <StatusPill kind={relayKind} />
            <StatusPill kind={syncKind} size="sm" />
            <FreshnessChip dataUpdatedAt={dataUpdatedAt} live />
          </div>
          <p className="obs-kicker">Alleral · v{site.loaderVersion || live?.versions?.loader || "—"}</p>
          <h2 className="obs-title mt-3 hero-gradient-text hero-shimmer">{site.brand || "Alleral"}</h2>
          <p className="mt-5 max-w-2xl text-base leading-relaxed text-muted md:text-lg">{site.tagline}</p>
          {site.announcement ? (
            <div className="mt-6 rounded-2xl border border-accent/30 bg-accent/10 px-4 py-3 text-sm text-accent-bright">
              {site.announcement}
            </div>
          ) : null}
          <div className="mt-9 flex flex-wrap gap-3">
            <Button variant="primary" onClick={onCopy} className="btn-glow">
              <Copy className="h-4 w-4" /> Copy loader
            </Button>
            <Button onClick={() => setView("games")}>
              <Gamepad2 className="h-4 w-4" /> Games
            </Button>
            <Button variant="ghost" onClick={() => setView("status")}>
              <Radio className="h-4 w-4" /> Status
            </Button>
          </div>
        </div>
      </InViewReveal>

      <InViewReveal className="bento-stat" delay={0.05}>
        <MetricCard label="Working games" numeric={working} suffix={` / ${total}`} accent="green" trend="From relay" />
      </InViewReveal>
      <InViewReveal className="bento-stat" delay={0.1}>
        <MetricCard label="Loader" value={`v${live?.versions?.loader || site.loaderVersion || "—"}`} accent="cyan" trend="Auto-updates from GitHub" />
      </InViewReveal>
      <InViewReveal className="bento-stat" delay={0.15}>
        <MetricCard label="Core" value={`v${live?.versions?.core || site.coreVersion || "—"}`} accent="violet" trend={`MacLib v${site.maclibVersion ?? live?.versions?.sydePatch ?? "—"}`} />
      </InViewReveal>
      <InViewReveal className="bento-stat" delay={0.2}>
        <MetricCard label="UI" value={site.uiLibrary || "MacLib"} accent="yellow" trend={site.uiVersion} />
      </InViewReveal>

      {brokenGames.length ? (
        <InViewReveal className="bento-full panel border-yellow-500/25 bg-yellow-500/[0.06] p-4 md:p-5" delay={0.06}>
          <div className="flex items-start gap-3">
            <AlertTriangle className="mt-0.5 h-5 w-5 shrink-0 text-yellow-400" />
            <div>
              <p className="font-medium text-yellow-200">
                {brokenGames.length} game{brokenGames.length === 1 ? "" : "s"} need attention
              </p>
              <p className="mt-1 text-sm text-muted">
                {brokenGames.map(([id, g]) => g.name || id).join(", ")} — check Games for live status before injecting.
              </p>
              <Button variant="ghost" size="sm" className="mt-3" onClick={() => setView("games")}>
                View games <ArrowRight className="h-3.5 w-3.5" />
              </Button>
            </div>
          </div>
        </InViewReveal>
      ) : null}

      <InViewReveal className="bento-wide panel p-5 md:p-6" delay={0.07}>
        <div className="mb-4 flex items-center gap-2">
          <BookOpen className="h-4 w-4 text-accent" />
          <h3 className="obs-title-sm">Getting started</h3>
        </div>
        <ol className="grid gap-3 sm:grid-cols-3">
          {[
            { step: "1", title: "Copy loader", desc: "Save the bootstrap once in your executor." },
            { step: "2", title: "Join a game", desc: "Pick a Working game from the library." },
            { step: "3", title: "Let it run", desc: "Loader checks GitHub and updates on its own." },
          ].map((item) => (
            <li key={item.step} className="rounded-xl border border-border bg-bg-1/50 px-4 py-3 liquid-hover">
              <p className="font-mono text-xs text-accent">Step {item.step}</p>
              <p className="mt-1 font-medium">{item.title}</p>
              <p className="mt-1 text-sm text-muted">{item.desc}</p>
            </li>
          ))}
        </ol>
      </InViewReveal>

      {latestLog.length ? (
        <InViewReveal className="bento-wide panel p-5 md:p-6" delay={0.09}>
          <div className="mb-4 flex items-center justify-between gap-2">
            <h3 className="obs-title-sm">Recent updates</h3>
            <Button variant="ghost" size="sm" onClick={() => setView("changelog")}>
              All updates <ArrowRight className="h-3.5 w-3.5" />
            </Button>
          </div>
          <div className="space-y-3">
            {latestLog.map((entry) => (
              <div key={`${entry.date}-${entry.title}`} className="rounded-xl border border-border/80 bg-bg-1/40 px-4 py-3 liquid-hover">
                <div className="flex flex-wrap items-center gap-2">
                  <p className="text-sm font-medium">{entry.title}</p>
                  <span className="text-[10px] text-muted-2">{entry.date}</span>
                </div>
                <ul className="mt-2 space-y-1 text-xs text-muted">
                  {(entry.items || []).slice(0, 2).map((item) => (
                    <li key={item} className="line-clamp-1">
                      · {item}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </InViewReveal>
      ) : null}

      <InViewReveal className="bento-wide panel p-5 md:p-6" delay={0.08}>
        <div className="mb-4 flex items-center gap-2">
          <Sparkles className="h-4 w-4 text-accent" />
          <h3 className="obs-title-sm">What you get</h3>
        </div>
        <ul className="grid gap-2 sm:grid-cols-2">
          {(site.features || []).slice(0, 8).map((f) => (
            <li key={f} className="flex items-start gap-2 rounded-xl border border-border/80 bg-bg-1/50 px-3 py-2.5 text-sm text-muted liquid-hover">
              <Check className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
              <span>{f}</span>
            </li>
          ))}
        </ul>
      </InViewReveal>

      <InViewReveal className="bento-wide panel p-5 md:p-6" delay={0.12}>
        <div className="obs-panel-head">
          <div>
            <p className="obs-kicker flex items-center gap-1.5">
              <Terminal className="h-3.5 w-3.5" /> Bootstrap
            </p>
            <h3 className="obs-title-sm mt-1">Save the loadstring once — updates come from GitHub</h3>
          </div>
          <Button size="sm" variant="ghost" onClick={onCopy}>
            Copy
          </Button>
        </div>
        <pre className="loader-block mt-4 max-h-44 overflow-auto p-4 text-muted obs-scroll">{site.loadstring}</pre>
      </InViewReveal>

      <InViewReveal className="bento-full" delay={0.14}>
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="obs-title-sm">Supported games</h3>
          <Button variant="ghost" size="sm" onClick={() => setView("games")}>
            View all <ArrowRight className="h-3.5 w-3.5" />
          </Button>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {games.slice(0, 6).map(([id, game]) => (
            <button
              key={id}
              type="button"
              onClick={() => setView("games")}
              className="panel panel-hover p-4 text-left liquid-hover"
            >
              <div className="flex items-center justify-between gap-2">
                <p className="font-semibold">{game.name || id}</p>
                <Zap className="h-3.5 w-3.5 text-accent" />
              </div>
              <p className="mt-2 line-clamp-2 text-sm text-muted">{game.description}</p>
            </button>
          ))}
        </div>
      </InViewReveal>

      {(site.faq?.length ?? 0) > 0 ? (
        <InViewReveal className="bento-full panel p-5 md:p-6" delay={0.16}>
          <h3 className="obs-title-sm mb-4">FAQ</h3>
          <div className="grid gap-2 md:grid-cols-2">
            {site.faq!.map((item) => (
              <details key={item.q} className="faq-item rounded-xl border border-border bg-bg-1/60 px-4 py-3 liquid-hover">
                <summary className="text-sm font-medium">{item.q}</summary>
                <p className="mt-2 text-sm leading-relaxed text-muted">{item.a}</p>
              </details>
            ))}
          </div>
        </InViewReveal>
      ) : null}

      {(site.resources?.length ?? 0) > 0 ? (
        <InViewReveal className="bento-full grid gap-3 sm:grid-cols-2 lg:grid-cols-3" delay={0.18}>
          {site.resources!.map((r) => {
            const href = resolveResourceUrl(site, r);
            if (!href) return null;
            return (
              <a
                key={r.title}
                href={href}
                target={href.startsWith("http") ? "_blank" : undefined}
                rel={href.startsWith("http") ? "noopener noreferrer" : undefined}
                className="panel panel-hover flex items-start gap-3 p-4 liquid-hover"
              >
                <ExternalLink className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                <div>
                  <p className="text-sm font-medium">{r.title}</p>
                  <p className="mt-1 text-xs text-muted">{r.desc}</p>
                </div>
              </a>
            );
          })}
        </InViewReveal>
      ) : null}
    </div>
    </ViewTransition>
  );
}
