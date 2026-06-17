"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Activity,
  ArrowRight,
  BadgeCheck,
  ChevronRight,
  Clipboard,
  Cpu,
  Gauge,
  GitBranch,
  Globe,
  Layers,
  Lock,
  Monitor,
  Network,
  Rocket,
  ScrollText,
  Shield,
  Sparkles,
  Terminal,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { toast } from "sonner";
import { postHubVisit } from "@/lib/api";
import type { GameEntry, SitePayload } from "@/lib/types";
import { useLiveSyncMeta, useSiteQuery } from "@/lib/queries/hooks";
import { formatFreshness, resolveRelayStatus } from "@/lib/status/resolve";
import { useSecondsSince } from "@/lib/hooks/useSecondsSince";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { SITE_SNAPSHOT } from "@/lib/site-snapshot";

const navItems = [
  { label: "Signal", href: "#signal" },
  { label: "Games", href: "#games" },
  { label: "Pipeline", href: "#pipeline" },
  { label: "Access", href: "#access" },
];

const operatorStats = [
  { label: "Loader", value: "8.11.1", detail: "remote pinned" },
  { label: "Runtime UI", value: "Iris", detail: "active layer" },
  { label: "Resource kit", value: "Onyx", detail: "Fusion + Spring" },
  { label: "Update loop", value: "~60s", detail: "release checks" },
];

const qualityMarks = [
  "Iris-only visible UI",
  "Onyx resources retained",
  "Fusion stack available",
  "Spring motion available",
  "GitHub release pinning",
  "Live site snapshot",
];

const pipelineSteps = [
  { icon: Globe, number: "01", title: "Fetch", body: "The loader requests the current release manifest and keeps a local fallback when remote data is unavailable." },
  { icon: Lock, number: "02", title: "Verify", body: "Expected versions include Iris 5.7.0-iris, core 2.9.10, and the pinned commit." },
  { icon: Layers, number: "03", title: "Compose", body: "Iris owns the visual runtime, while Onyx supplies resources and the Fusion/Spring capability stack behind it." },
  { icon: Zap, number: "04", title: "Launch", body: "The game script starts only after access, security, telemetry, UI source, and workspace prep have resolved." },
];

function getGameEntries(site: SitePayload): GameEntry[] {
  return Object.values(site.games || {}).filter(Boolean).slice(0, 6);
}

function statusClass(status?: string) {
  const n = String(status || "").toLowerCase();
  if (n.includes("work") || n.includes("online") || n.includes("stable")) return "status-badge-working";
  if (n.includes("partial") || n.includes("testing")) return "status-badge-partial";
  if (n.includes("down") || n.includes("broken")) return "status-badge-down";
  return "status-badge-working";
}

function MiniButton({ children, href, onClick, variant = "primary" }: { children: React.ReactNode; href?: string; onClick?: () => void; variant?: "primary" | "quiet" }) {
  const cls = variant === "primary"
    ? "site-button site-button-primary"
    : "site-button border-white/8 bg-white/[0.03] text-muted hover:border-cyan/30 hover:bg-cyan/8 hover:text-text";
  if (href) {
    return <a className={cls} href={href} target={href.startsWith("http") ? "_blank" : undefined} rel="noreferrer">{children}</a>;
  }
  return <button className={cls} onClick={onClick} type="button">{children}</button>;
}

function StatPill({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="site-stat">
      <p className="font-mono text-[10px] uppercase tracking-wider text-muted">{label}</p>
      <div className="mt-2 flex items-end justify-between gap-2">
        <strong className="text-xl font-semibold text-text">{value}</strong>
        <span className="pb-[3px] font-mono text-[10px] text-muted-2">{detail}</span>
      </div>
    </div>
  );
}

function IconBox({ icon: Icon, variant }: { icon: LucideIcon; variant?: "default" | "cyan" | "violet" | "pink" | "orange" }) {
  const v = variant || "default";
  const cls = v === "cyan" ? "site-icon-box-cyan" : v === "violet" ? "site-icon-box-violet" : v === "pink" ? "site-icon-box-pink" : v === "orange" ? "site-icon-box-orange" : "site-icon-box";
  return (
    <span className={cls}>
      <Icon className="h-4 w-4" />
    </span>
  );
}

function SignalCard({ icon: Icon, title, value, detail }: { icon: LucideIcon; title: string; value: string; detail: string }) {
  return (
    <div className="site-card site-card-lift p-5 fade-in-up">
      <div className="flex items-center justify-between gap-3">
        <IconBox icon={Icon} variant="cyan" />
        <Activity className="h-4 w-4 text-accent" />
      </div>
      <p className="mt-6 text-sm font-medium text-muted">{title}</p>
      <strong className="mt-2 block text-2xl font-bold tracking-tight text-text">{value}</strong>
      <p className="mt-3 text-sm leading-6 text-muted">{detail}</p>
    </div>
  );
}

function CodePreview({ loadstring }: { loadstring?: string }) {
  const display = loadstring || 'loadstring(game:HttpGet("https://raw.githubusercontent.com/.../loader.luau"))()';
  return (
    <div className="site-terminal">
      <div className="flex items-center justify-between border-b border-white/8 px-4 py-3">
        <div className="flex items-center gap-2">
          <span className="h-2.5 w-2.5 rounded-full bg-red" />
          <span className="h-2.5 w-2.5 rounded-full bg-yellow" />
          <span className="h-2.5 w-2.5 rounded-full bg-accent" />
        </div>
        <span className="font-mono text-[10px] uppercase tracking-wider text-muted-2">Alleral loader</span>
      </div>
      <pre className="overflow-hidden whitespace-pre-wrap px-4 py-4 font-mono text-xs leading-6 text-cyan md:text-sm">
        <span className="text-muted-2">-- one pinned entrypoint</span>
        {"\n"}
        {display}
      </pre>
      <div className="grid grid-cols-3 border-t border-white/8 text-center text-[10px] uppercase tracking-wider text-muted-2">
        <span className="px-3 py-3">request</span>
        <span className="border-x border-white/8 px-3 py-3">verify</span>
        <span className="px-3 py-3">launch</span>
      </div>
    </div>
  );
}

function GameTile({ game, index }: { game: GameEntry; index: number }) {
  const features = (game.scriptFeatures || []).slice(0, 3);
  return (
    <article className={`site-card site-card-lift p-5 fade-in-up fade-in-delay-${Math.min(index + 1, 5)}`}>
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="font-mono text-[10px] uppercase tracking-wider text-muted-2">{game.version || "live script"}</p>
          <h3 className="mt-2 text-lg font-semibold text-text">{game.name || game.id || "Supported game"}</h3>
        </div>
        <span className={`status-badge ${statusClass(game.status)}`}>{game.status || "tracked"}</span>
      </div>
      <p className="mt-4 min-h-12 text-sm leading-6 text-muted">
        {game.description || game.message || "Auto-selected by place ID with live release metadata and script health checks."}
      </p>
      <div className="mt-5 flex flex-wrap gap-2">
        {(features.length ? features : [{ name: "Auto load" }, { name: "Config aware" }, { name: "Live pin" }]).map((f) => (
          <span key={f.name} className="feature-chip">{f.name}</span>
        ))}
      </div>
    </article>
  );
}

function AlleralLanding({ site, online, siteUpdatedAt, siteFetching, onRefreshSite }: { site: SitePayload; online?: boolean; siteUpdatedAt?: number; siteFetching?: boolean; onRefreshSite?: () => void }) {
  const live = useLiveSyncMeta("overview");
  const siteAge = useSecondsSince(siteUpdatedAt ?? null, 1000);
  const games = useMemo(() => getGameEntries(site), [site]);
  const relayKind = resolveRelayStatus(online);
  const latestChange = site.changelog?.[0];
  const [menuOpen, setMenuOpen] = useState(false);

  const copyLoadstring = useCallback(async () => {
    if (!site.loadstring) { toast.error("Loader unavailable"); return; }
    try {
      await navigator.clipboard.writeText(site.loadstring);
      toast.success("Loader copied");
    } catch { toast.error("Copy failed"); }
  }, [site.loadstring]);

  const refreshAll = useCallback(() => {
    onRefreshSite?.();
    void live.refresh();
    toast.message("Refreshing live signal");
  }, [live, onRefreshSite]);

  return (
    <main className="min-h-dvh overflow-hidden bg-bg-0 text-text">
      <div className="hub-shell">
        <div className="ambient-grid" />
        <div className="ambient-orb ambient-orb-a" />
        <div className="ambient-orb ambient-orb-b" />
        <div className="ambient-orb ambient-orb-c" />

        <header className="fixed inset-x-0 top-0 z-50 border-b border-white/6 bg-bg-0/80 backdrop-blur-2xl">
          <nav className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 md:px-6">
            <a href="#top" className="flex items-center gap-3">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-accent/30 bg-accent/8 text-accent">
                <Sparkles className="h-4 w-4" />
              </span>
              <span>
                <strong className="block text-sm font-semibold leading-none">{site.brand || "Alleral"}</strong>
                <span className="font-mono text-[10px] uppercase tracking-wider text-muted-2">Iris runtime</span>
              </span>
            </a>
            <div className="hidden items-center gap-8 md:flex">
              {navItems.map((item) => (
                <a key={item.href} href={item.href} className="nav-link">{item.label}</a>
              ))}
            </div>
            <div className="flex items-center gap-2">
              <button
                className="hidden rounded-lg border border-white/8 bg-white/[0.03] px-3 py-2 text-xs text-muted transition hover:border-accent/30 hover:text-text md:inline-flex"
                type="button"
                onClick={refreshAll}
              >
                {siteFetching ? "Syncing" : formatFreshness(siteAge)}
              </button>
              <MiniButton onClick={copyLoadstring}>
                <Clipboard className="h-4 w-4" />
                Copy
              </MiniButton>
              <button className="md:hidden p-2 text-muted hover:text-text" onClick={() => setMenuOpen(!menuOpen)} type="button">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 5h14M3 10h14M3 15h14"/></svg>
              </button>
            </div>
          </nav>
          {menuOpen && (
            <div className="border-t border-white/6 bg-bg-0/95 backdrop-blur-2xl md:hidden">
              <div className="flex flex-col gap-2 px-4 py-4">
                {navItems.map((item) => (
                  <a key={item.href} href={item.href} className="py-2 text-sm text-muted hover:text-text" onClick={() => setMenuOpen(false)}>{item.label}</a>
                ))}
              </div>
            </div>
          )}
        </header>

        <section id="top" className="relative mx-auto grid min-h-[90dvh] max-w-7xl items-center gap-12 px-4 pb-24 pt-28 md:grid-cols-[1.05fr_0.95fr] md:px-6 md:pt-36">
          <div className="relative z-10">
            <div className="pill-kicker">
              <Sparkles className="h-3 w-3" />
              {relayKind === "online" ? "Relay live" : "Relay monitored"} &middot; {site.uiLibrary || "Iris"} active
            </div>
            <h1 className="mt-8 max-w-4xl text-5xl font-bold leading-[0.95] tracking-tight md:text-7xl">
              Roblox scripts with a <span className="hero-gradient-text">release system</span> that feels alive.
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-muted md:text-xl">
              {site.tagline || "One loader, live game routing, automatic release pins, and an Iris UI powered by Onyx resources, Fusion, and Spring."}
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <MiniButton onClick={copyLoadstring}>
                <Rocket className="h-4 w-4" />
                Copy loader
                <ChevronRight className="h-4 w-4" />
              </MiniButton>
              <MiniButton href={site.links?.github || site.links?.loaderRaw || "#pipeline"} variant="quiet">
                <GitBranch className="h-4 w-4" />
                View source
                <ArrowRight className="h-4 w-4" />
              </MiniButton>
            </div>
            <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {operatorStats.map((stat) => (
                <StatPill key={stat.label} {...stat} />
              ))}
            </div>
          </div>

          <div className="relative z-10">
            <div className="site-card p-6 float-anim">
              <div className="flex items-center justify-between">
                <p className="font-mono text-[10px] uppercase tracking-wider text-muted-2">runtime profile</p>
                <span className="status-badge status-badge-working">stable</span>
              </div>
              <div className="mt-6 grid grid-cols-2 gap-3">
                <div className="rounded-lg border border-white/6 bg-white/[0.03] p-4">
                  <Monitor className="h-5 w-5 text-cyan" />
                  <p className="mt-4 text-2xl font-bold">{site.uiLibrary || "Iris"}</p>
                  <p className="text-xs text-muted">visible UI</p>
                </div>
                <div className="rounded-lg border border-white/6 bg-white/[0.03] p-4">
                  <Layers className="h-5 w-5 text-violet" />
                  <p className="mt-4 text-2xl font-bold">Onyx</p>
                  <p className="text-xs text-muted">resources</p>
                </div>
              </div>
              <div className="mt-4 space-y-2">
                {qualityMarks.slice(0, 4).map((mark) => (
                  <div key={mark} className="flex items-center gap-3 rounded-lg bg-bg-0/50 px-3 py-2">
                    <BadgeCheck className="h-4 w-4 shrink-0 text-accent" />
                    <span className="text-sm text-muted">{mark}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="mt-4">
              <CodePreview loadstring={site.loadstring} />
            </div>
          </div>
        </section>

        <section id="signal" className="relative mx-auto max-w-7xl px-4 py-24 md:px-6">
          <div className="section-header">
            <div className="kicker"><Activity className="h-3 w-3" /> Live signal</div>
            <h2>A command center without the dead weight.</h2>
            <p>The website now leads with the operational facts people actually need: what is live, what changed, what UI is active, and where the loader points.</p>
          </div>
          <div className="mt-14 grid gap-4 md:grid-cols-4">
            <SignalCard icon={Activity} title="Relay" value={relayKind} detail={live.error?.message || "Status comes from the live sync endpoint."} />
            <SignalCard icon={Gauge} title="Freshness" value={formatFreshness(siteAge)} detail="Site configuration snapshot baked into the static build." />
            <SignalCard icon={Cpu} title="Core" value={site.coreVersion || "2.9.10"} detail={`Loader ${site.loaderVersion || "8.11.1"} with release polling enabled.`} />
            <SignalCard icon={Shield} title="Guardrails" value="public" detail="Access and security modules load before the game script is selected." />
          </div>
        </section>

        <section id="games" className="relative border-y border-white/6 bg-white/[0.015] px-4 py-24 md:px-6">
          <div className="mx-auto max-w-7xl">
            <div className="grid gap-8 md:grid-cols-[0.85fr_1.15fr] md:items-end">
              <div>
                <p className="font-mono text-[10px] uppercase tracking-wider text-accent-bright">Game routing</p>
                <h2 className="mt-4 text-3xl font-bold tracking-tight md:text-5xl">Scripts that know where they landed.</h2>
              </div>
              <p className="text-base leading-7 text-muted">
                Place IDs, release metadata, and script features are surfaced as a clean launch matrix instead of buried in a generic dashboard.
              </p>
            </div>
            <div className="mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {(games.length ? games : [{ name: "Auto-selected experience", status: "tracked" }]).map((game, index) => (
                <GameTile key={game.id || game.name || index} game={game} index={index} />
              ))}
            </div>
          </div>
        </section>

        <section id="pipeline" className="relative mx-auto max-w-7xl px-4 py-24 md:px-6">
          <div className="section-header">
            <div className="kicker"><GitBranch className="h-3 w-3" /> Release pipeline</div>
            <h2>Pin, bake, publish, repeat.</h2>
            <p>The public site mirrors how the loader works: it makes the release path visible, legible, and trustworthy.</p>
          </div>
          <div className="mt-14 grid gap-10 lg:grid-cols-[0.95fr_1.05fr]">
            <div className="site-card p-5 md:p-6">
              <CodePreview loadstring={site.loadstring} />
            </div>
            <div className="space-y-10">
              {pipelineSteps.map((step) => (
                <div key={step.number} className="pipeline-step">
                  <div className="pipeline-step-number">{step.number}</div>
                  <div className="flex items-center gap-3">
                    <IconBox icon={step.icon} variant="cyan" />
                    <h3 className="text-lg font-semibold text-text">{step.title}</h3>
                  </div>
                  <p className="text-sm leading-7 text-muted">{step.body}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section id="access" className="relative px-4 pb-32 md:px-6">
          <div className="mx-auto grid max-w-7xl gap-4 lg:grid-cols-[1.1fr_0.9fr]">
            <div className="site-card overflow-hidden p-6 md:p-8">
              <div className="pill-kicker"><ScrollText className="h-3 w-3" /> What changed</div>
              <h2 className="mt-6 text-3xl font-bold tracking-tight md:text-5xl">
                {latestChange?.title || "Built for fast fixes and clear releases."}
              </h2>
              <div className="mt-8 grid gap-3 md:grid-cols-2">
                {(latestChange?.items || qualityMarks).slice(0, 6).map((item) => (
                  <div key={item} className="flex gap-3 rounded-lg border border-white/6 bg-bg-2/60 p-3">
                    <BadgeCheck className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                    <span className="text-sm leading-6 text-muted">{item}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="site-card p-6 md:p-8 flex flex-col justify-between">
              <div>
                <IconBox icon={Terminal} variant="cyan" />
                <h3 className="mt-6 text-2xl font-bold">Launch with one command.</h3>
                <p className="mt-3 text-sm leading-7 text-muted">
                  Copy the live loader, inject once, and let the release system choose the right game module and UI stack.
                </p>
              </div>
              <div className="mt-6 flex flex-col gap-3">
                <MiniButton onClick={copyLoadstring}>
                  <Clipboard className="h-4 w-4" />
                  Copy loadstring
                </MiniButton>
                <MiniButton href={site.links?.mirror || site.links?.website || "#top"} variant="quiet">
                  <Network className="h-4 w-4" />
                  Open mirror
                </MiniButton>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>
  );
}

function PlatformAppInner() {
  const siteQuery = useSiteQuery();
  const site = siteQuery.data ?? SITE_SNAPSHOT;
  const liveQuery = useLiveSyncMeta("overview");

  useEffect(() => {
    void postHubVisit("website-rewrite");
  }, []);

  const online = siteQuery.isError ? false : liveQuery.error ? false : liveQuery.data?.ok !== false;

  return (
    <CloudflareGate>
      <AlleralLanding
        site={site}
        online={online}
        siteUpdatedAt={siteQuery.dataUpdatedAt}
        siteFetching={siteQuery.isFetching}
        onRefreshSite={() => void siteQuery.refetch()}
      />
    </CloudflareGate>
  );
}

export function PlatformApp() {
  return (
    <QueryProvider>
      <PlatformAppInner />
    </QueryProvider>
  );
}