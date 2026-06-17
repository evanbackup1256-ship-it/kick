"use client";

import { useCallback, useEffect, useMemo } from "react";
import {
  Activity,
  ArrowUpRight,
  BadgeCheck,
  Boxes,
  Check,
  ChevronRight,
  CircleDot,
  Clipboard,
  Code2,
  Cpu,
  Gauge,
  GitBranch,
  Globe2,
  Layers3,
  LockKeyhole,
  MonitorCheck,
  Radio,
  Rocket,
  ShieldCheck,
  Sparkles,
  TerminalSquare,
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

function getGameEntries(site: SitePayload): GameEntry[] {
  return Object.values(site.games || {}).filter(Boolean).slice(0, 6);
}

function statusTone(status?: string) {
  const normalized = String(status || "").toLowerCase();
  if (normalized.includes("work") || normalized.includes("online") || normalized.includes("stable")) return "text-accent";
  if (normalized.includes("partial") || normalized.includes("testing")) return "text-yellow";
  if (normalized.includes("down") || normalized.includes("broken")) return "text-red";
  return "text-cyan";
}

function MiniButton({
  children,
  href,
  onClick,
  variant = "primary",
}: {
  children: React.ReactNode;
  href?: string;
  onClick?: () => void;
  variant?: "primary" | "quiet";
}) {
  const className =
    variant === "primary"
      ? "site-button site-button-primary"
      : "site-button border-white/10 bg-white/[0.035] text-text hover:border-cyan/35 hover:bg-cyan/10";

  if (href) {
    return (
      <a className={className} href={href} target={href.startsWith("http") ? "_blank" : undefined} rel="noreferrer">
        {children}
      </a>
    );
  }

  return (
    <button className={className} onClick={onClick} type="button">
      {children}
    </button>
  );
}

function StatPill({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="site-stat">
      <p className="text-[10px] uppercase text-muted">{label}</p>
      <div className="mt-2 flex items-end justify-between gap-2">
        <strong className="text-xl font-semibold text-text">{value}</strong>
        <span className="pb-1 font-mono text-[10px] text-muted">{detail}</span>
      </div>
    </div>
  );
}

function SectionTitle({
  kicker,
  title,
  body,
}: {
  kicker: string;
  title: string;
  body: string;
}) {
  return (
    <div className="mx-auto max-w-3xl text-center">
      <p className="site-kicker justify-center">{kicker}</p>
      <h2 className="mt-4 text-3xl font-semibold tracking-tight text-text md:text-5xl">{title}</h2>
      <p className="mt-4 text-base leading-7 text-muted md:text-lg">{body}</p>
    </div>
  );
}

function SignalCard({
  icon: Icon,
  title,
  value,
  detail,
}: {
  icon: LucideIcon;
  title: string;
  value: string;
  detail: string;
}) {
  return (
    <div className="site-panel site-panel-lift p-5">
      <div className="flex items-center justify-between gap-3">
        <span className="site-icon">
          <Icon className="h-4 w-4" />
        </span>
        <Radio className="h-4 w-4 text-accent" />
      </div>
      <p className="mt-6 text-sm text-muted">{title}</p>
      <strong className="mt-2 block text-2xl font-semibold text-text">{value}</strong>
      <p className="mt-3 text-sm leading-6 text-muted">{detail}</p>
    </div>
  );
}

function CodePreview({ loadstring }: { loadstring?: string }) {
  const display = loadstring || 'loadstring(game:HttpGet("https://raw.githubusercontent.com/.../loader.luau"))()';

  return (
    <div className="site-terminal">
      <div className="flex items-center justify-between border-b border-white/10 px-4 py-3">
        <div className="flex items-center gap-2">
          <span className="h-2.5 w-2.5 rounded-full bg-red" />
          <span className="h-2.5 w-2.5 rounded-full bg-yellow" />
          <span className="h-2.5 w-2.5 rounded-full bg-accent" />
        </div>
        <span className="font-mono text-[10px] uppercase text-muted">Alleral loader</span>
      </div>
      <pre className="overflow-hidden whitespace-pre-wrap px-4 py-4 font-mono text-xs leading-6 text-cyan md:text-sm">
        <span className="text-muted">-- one pinned entrypoint</span>
        {"\n"}
        {display}
      </pre>
      <div className="grid grid-cols-3 border-t border-white/10 text-center text-[10px] uppercase text-muted">
        <span className="px-3 py-3">request</span>
        <span className="border-x border-white/10 px-3 py-3">verify</span>
        <span className="px-3 py-3">launch</span>
      </div>
    </div>
  );
}

function GameTile({ game }: { game: GameEntry }) {
  const features = (game.scriptFeatures || []).slice(0, 3);

  return (
    <article className="site-panel site-panel-lift p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="font-mono text-[10px] uppercase text-muted">{game.version || "live script"}</p>
          <h3 className="mt-2 text-lg font-semibold text-text">{game.name || game.id || "Supported game"}</h3>
        </div>
        <span className={`rounded-full border border-white/10 bg-white/[0.04] px-2.5 py-1 text-[11px] ${statusTone(game.status)}`}>
          {game.status || "tracked"}
        </span>
      </div>
      <p className="mt-4 min-h-12 text-sm leading-6 text-muted">
        {game.description || game.message || "Auto-selected by place ID with live release metadata and script health checks."}
      </p>
      <div className="mt-5 flex flex-wrap gap-2">
        {(features.length ? features : [{ name: "Auto load" }, { name: "Config aware" }, { name: "Live pin" }]).map((feature) => (
          <span key={feature.name} className="rounded-full border border-white/10 bg-bg-2/70 px-2.5 py-1 text-[11px] text-muted">
            {feature.name}
          </span>
        ))}
      </div>
    </article>
  );
}

function PipelineStep({
  number,
  title,
  body,
  icon: Icon,
}: {
  number: string;
  title: string;
  body: string;
  icon: LucideIcon;
}) {
  return (
    <div className="relative grid gap-4 border-l border-white/10 pl-6 md:grid-cols-[11rem_1fr] md:gap-8">
      <div className="absolute -left-3 top-0 flex h-6 w-6 items-center justify-center rounded-full border border-accent/40 bg-bg-0 text-[10px] text-accent">
        {number}
      </div>
      <div className="flex items-center gap-3">
        <span className="site-icon">
          <Icon className="h-4 w-4" />
        </span>
        <h3 className="text-lg font-semibold text-text">{title}</h3>
      </div>
      <p className="text-sm leading-7 text-muted">{body}</p>
    </div>
  );
}

function AlleralLanding({ site, online, siteUpdatedAt, siteFetching, onRefreshSite }: { site: SitePayload; online?: boolean; siteUpdatedAt?: number; siteFetching?: boolean; onRefreshSite?: () => void }) {
  const live = useLiveSyncMeta("overview");
  const siteAge = useSecondsSince(siteUpdatedAt ?? null, 1000);
  const games = useMemo(() => getGameEntries(site), [site]);
  const relayKind = resolveRelayStatus(online);
  const latestChange = site.changelog?.[0];

  const copyLoadstring = useCallback(async () => {
    if (!site.loadstring) {
      toast.error("Loader unavailable");
      return;
    }
    try {
      await navigator.clipboard.writeText(site.loadstring);
      toast.success("Loader copied");
    } catch {
      toast.error("Copy failed");
    }
  }, [site.loadstring]);

  const refreshAll = useCallback(() => {
    onRefreshSite?.();
    void live.refresh();
    toast.message("Refreshing live signal");
  }, [live, onRefreshSite]);

  return (
    <main className="min-h-dvh overflow-hidden bg-bg-0 text-text">
      <div className="site-backdrop" />
      <header className="fixed inset-x-0 top-0 z-50 border-b border-white/10 bg-bg-0/75 backdrop-blur-xl">
        <nav className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 md:px-6">
          <a href="#top" className="flex items-center gap-3">
            <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-accent/35 bg-accent/10 text-accent">
              <Sparkles className="h-4 w-4" />
            </span>
            <span>
              <strong className="block text-sm font-semibold leading-none">{site.brand || "Alleral"}</strong>
              <span className="font-mono text-[10px] uppercase text-muted">Iris runtime</span>
            </span>
          </a>
          <div className="hidden items-center gap-6 md:flex">
            {navItems.map((item) => (
              <a key={item.href} href={item.href} className="text-sm text-muted transition hover:text-text">
                {item.label}
              </a>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <button
              className="hidden rounded-lg border border-white/10 bg-white/[0.035] px-3 py-2 text-xs text-muted transition hover:border-accent/35 hover:text-text md:inline-flex"
              type="button"
              onClick={refreshAll}
            >
              {siteFetching ? "Syncing" : formatFreshness(siteAge)}
            </button>
            <MiniButton onClick={copyLoadstring}>
              <Clipboard className="h-4 w-4" />
              Copy
            </MiniButton>
          </div>
        </nav>
      </header>

      <section id="top" className="relative mx-auto grid min-h-[92dvh] max-w-7xl items-center gap-10 px-4 pb-20 pt-28 md:grid-cols-[1.05fr_0.95fr] md:px-6 md:pt-32">
        <div className="relative z-10">
          <p className="site-kicker">
            <CircleDot className="h-3.5 w-3.5 text-accent" />
            {relayKind === "online" ? "Relay live" : "Relay monitored"} · {site.uiLibrary || "Iris"} active
          </p>
          <h1 className="mt-6 max-w-4xl text-5xl font-semibold leading-[0.95] tracking-tight text-text md:text-7xl">
            Roblox scripts with a release system that feels alive.
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
              <ArrowUpRight className="h-4 w-4" />
            </MiniButton>
          </div>
          <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            {operatorStats.map((stat) => (
              <StatPill key={stat.label} {...stat} />
            ))}
          </div>
        </div>

        <div className="relative z-10">
          <div className="site-hero-visual">
            <div className="site-orbit site-orbit-a" />
            <div className="site-orbit site-orbit-b" />
            <div className="site-console-card">
              <div className="flex items-center justify-between">
                <p className="font-mono text-[10px] uppercase text-muted">runtime profile</p>
                <span className="rounded-full border border-accent/25 bg-accent/10 px-2 py-1 text-[10px] text-accent">stable</span>
              </div>
              <div className="mt-6 grid grid-cols-2 gap-3">
                <div className="rounded-lg border border-white/10 bg-white/[0.04] p-4">
                  <MonitorCheck className="h-5 w-5 text-cyan" />
                  <p className="mt-4 text-2xl font-semibold">{site.uiLibrary || "Iris"}</p>
                  <p className="text-xs text-muted">visible UI</p>
                </div>
                <div className="rounded-lg border border-white/10 bg-white/[0.04] p-4">
                  <Layers3 className="h-5 w-5 text-violet" />
                  <p className="mt-4 text-2xl font-semibold">Onyx</p>
                  <p className="text-xs text-muted">resources</p>
                </div>
              </div>
              <div className="mt-4 space-y-3">
                {qualityMarks.slice(0, 4).map((mark) => (
                  <div key={mark} className="flex items-center gap-3 rounded-lg bg-bg-0/55 px-3 py-2">
                    <Check className="h-4 w-4 text-accent" />
                    <span className="text-sm text-muted">{mark}</span>
                  </div>
                ))}
              </div>
            </div>
            <CodePreview loadstring={site.loadstring} />
          </div>
        </div>
      </section>

      <section id="signal" className="relative mx-auto max-w-7xl px-4 py-20 md:px-6">
        <SectionTitle
          kicker="Live signal"
          title="A command center without the dead weight."
          body="The website now leads with the operational facts people actually need: what is live, what changed, what UI is active, and where the loader points."
        />
        <div className="mt-12 grid gap-4 md:grid-cols-4">
          <SignalCard icon={Activity} title="Relay" value={relayKind} detail={live.error?.message || "Status comes from the live sync endpoint."} />
          <SignalCard icon={Gauge} title="Freshness" value={formatFreshness(siteAge)} detail="Site configuration snapshot baked into the static build." />
          <SignalCard icon={Cpu} title="Core" value={site.coreVersion || "2.9.10"} detail={`Loader ${site.loaderVersion || "8.11.1"} with release polling enabled.`} />
          <SignalCard icon={ShieldCheck} title="Guardrails" value="public" detail="Access and security modules load before the game script is selected." />
        </div>
      </section>

      <section id="games" className="relative border-y border-white/10 bg-white/[0.025] px-4 py-20 md:px-6">
        <div className="mx-auto max-w-7xl">
          <div className="grid gap-8 md:grid-cols-[0.85fr_1.15fr] md:items-end">
            <div>
              <p className="site-kicker">Game routing</p>
              <h2 className="mt-4 text-3xl font-semibold tracking-tight md:text-5xl">Scripts that know where they landed.</h2>
            </div>
            <p className="text-base leading-7 text-muted">
              Place IDs, release metadata, and script features are surfaced as a clean launch matrix instead of buried in a generic dashboard.
            </p>
          </div>
          <div className="mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {(games.length ? games : [{ name: "Auto-selected experience", status: "tracked" }]).map((game, index) => (
              <GameTile key={game.id || game.name || index} game={game} />
            ))}
          </div>
        </div>
      </section>

      <section id="pipeline" className="relative mx-auto max-w-7xl px-4 py-20 md:px-6">
        <SectionTitle
          kicker="Release pipeline"
          title="Pin, bake, publish, repeat."
          body="The public site mirrors how the loader works: it makes the release path visible, legible, and trustworthy."
        />
        <div className="mt-14 grid gap-10 lg:grid-cols-[0.95fr_1.05fr]">
          <div className="site-panel p-5 md:p-6">
            <CodePreview loadstring={site.loadstring} />
          </div>
          <div className="space-y-8">
            <PipelineStep icon={Globe2} number="01" title="Fetch" body="The loader requests the current release manifest and keeps a local fallback when remote data is unavailable." />
            <PipelineStep icon={LockKeyhole} number="02" title="Verify" body={`Expected versions include ${site.uiLibrary || "Iris"} ${site.uiVersion || "5.7.0-iris"}, core ${site.coreVersion || "2.9.10"}, and the pinned commit.`} />
            <PipelineStep icon={Boxes} number="03" title="Compose" body="Iris owns the visual runtime, while Onyx supplies resources and the Fusion/Spring capability stack behind it." />
            <PipelineStep icon={Zap} number="04" title="Launch" body="The game script starts only after access, security, telemetry, UI source, and workspace prep have resolved." />
          </div>
        </div>
      </section>

      <section id="access" className="relative px-4 pb-24 md:px-6">
        <div className="mx-auto grid max-w-7xl gap-4 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="site-panel overflow-hidden p-6 md:p-8">
            <p className="site-kicker">What changed</p>
            <h2 className="mt-4 text-3xl font-semibold tracking-tight md:text-5xl">
              {latestChange?.title || "Built for fast fixes and clear releases."}
            </h2>
            <div className="mt-8 grid gap-3 md:grid-cols-2">
              {(latestChange?.items || qualityMarks).slice(0, 6).map((item) => (
                <div key={item} className="flex gap-3 rounded-lg border border-white/10 bg-bg-2/70 p-3">
                  <BadgeCheck className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                  <span className="text-sm leading-6 text-muted">{item}</span>
                </div>
              ))}
            </div>
          </div>
          <div className="site-panel p-6 md:p-8">
            <TerminalSquare className="h-8 w-8 text-cyan" />
            <h3 className="mt-6 text-2xl font-semibold">Launch with one command.</h3>
            <p className="mt-3 text-sm leading-7 text-muted">
              Copy the live loader, inject once, and let the release system choose the right game module and UI stack.
            </p>
            <div className="mt-6 flex flex-col gap-3">
              <MiniButton onClick={copyLoadstring}>
                <Clipboard className="h-4 w-4" />
                Copy loadstring
              </MiniButton>
              <MiniButton href={site.links?.mirror || site.links?.website || "#top"} variant="quiet">
                <Code2 className="h-4 w-4" />
                Open mirror
              </MiniButton>
            </div>
          </div>
        </div>
      </section>
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
