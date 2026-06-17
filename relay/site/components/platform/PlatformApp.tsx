"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  Activity, ArrowRight, BadgeCheck, ChevronRight, Clipboard, Cpu, Gauge,
  GitBranch, Globe, Layers, Lock, Monitor, Network, Rocket, ScrollText,
  Shield, Sparkles, Terminal, Zap, LogIn, Headset, type LucideIcon,
} from "lucide-react";
import { toast } from "sonner";
import { postHubVisit } from "@/lib/api";
import type { GameEntry, SitePayload } from "@/lib/types";
import { useLiveSyncMeta, useSiteQuery } from "@/lib/queries/hooks";
import { formatFreshness, resolveRelayStatus } from "@/lib/status/resolve";
import { useSecondsSince } from "@/lib/hooks/useSecondsSince";
import { useCursorPosition } from "@/lib/hooks/useCursorPosition";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { SITE_SNAPSHOT } from "@/lib/site-snapshot";
import { ParticleField } from "@/components/effects/ParticleField";
import { ScanLines } from "@/components/effects/ScanLines";
import { StatusDot } from "@/components/effects/StatusDot";
import { PipelineVisualizer } from "@/components/effects/PipelineVisualizer";
import { TelemetryCharts } from "@/components/effects/TelemetryCharts";
import { GlobalTopology } from "@/components/effects/GlobalTopology";
import { Hero3D } from "@/components/effects/Hero3D";
import { SupportForm } from "@/components/support/SupportForm";
import { CloudflareLayer } from "@/components/cloudflare/CloudflareLayer";

const navItems = [
  { label: "Signal", href: "#signal" },
  { label: "Topology", href: "#topology" },
  { label: "Games", href: "#games" },
  { label: "Pipeline", href: "#pipeline" },
  { label: "Cloudflare", href: "#cloudflare" },
  { label: "Support", href: "#support" },
  { label: "Access", href: "#access" },
];

const stats = [
  { label: "Loader", value: "8.11.1", detail: "remote pinned" },
  { label: "UI Runtime", value: "Iris", detail: "active layer" },
  { label: "Resources", value: "Onyx", detail: "Fusion + Spring" },
  { label: "Poll Loop", value: "~60s", detail: "release checks" },
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
  if (n.includes("work") || n.includes("online") || n.includes("stable")) return "badge-green";
  if (n.includes("partial") || n.includes("testing")) return "badge-yellow";
  if (n.includes("down") || n.includes("broken")) return "badge-red";
  return "badge-green";
}

function IconBox({ icon: Icon, variant }: { icon: LucideIcon; variant?: string }) {
  const m = variant === "cyan" ? "icon-box-cyan" : variant === "violet" ? "icon-box-violet" : "";
  return (
    <span className={`icon-box ${m}`}>
      <Icon className="h-4 w-4" />
    </span>
  );
}

function CodePreview({ loadstring }: { loadstring?: string }) {
  const display = loadstring || 'loadstring(game:HttpGet("https://raw.githubusercontent.com/.../loader.luau"))()';
  return (
    <div className="terminal">
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

function AlleralLanding({ site, online, siteUpdatedAt, siteFetching, onRefreshSite }: { site: SitePayload; online?: boolean; siteUpdatedAt?: number; siteFetching?: boolean; onRefreshSite?: () => void }) {
  const live = useLiveSyncMeta("overview");
  const siteAge = useSecondsSince(siteUpdatedAt ?? null, 1000);
  const games = useMemo(() => getGameEntries(site), [site]);
  const relayKind = resolveRelayStatus(online);
  const latestChange = site.changelog?.[0];
  const [menuOpen, setMenuOpen] = useState(false);
  const [adminPass, setAdminPass] = useState("");
  const [adminAuthed, setAdminAuthed] = useState(false);
  const [showAdminModal, setShowAdminModal] = useState(false);

  useEffect(() => {
    if (typeof window !== "undefined") {
      const stored = sessionStorage.getItem("alleral_admin_auth");
      if (stored === "true") setAdminAuthed(true);
    }
  }, []);

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

  const handleAdminLogin = useCallback(() => {
    if (adminPass === "583716465") {
      sessionStorage.setItem("alleral_admin_auth", "true");
      setAdminAuthed(true);
      setShowAdminModal(false);
      setAdminPass("");
      toast.success("Admin authenticated");
    } else {
      toast.error("Invalid password");
    }
  }, [adminPass]);

  const openAdmin = useCallback(() => {
    if (adminAuthed) {
      window.open(site.links?.admin || site.links?.relay + "/admin.html", "_blank");
    } else {
      setShowAdminModal(true);
    }
  }, [adminAuthed, site.links]);

  return (
    <main className="min-h-dvh overflow-hidden bg-bg-0 text-text">
      <div className="site-shell">
        <div className="mesh-grid" />
        <div className="orb orb-a" />
        <div className="orb orb-b" />
        <div className="orb orb-c" />

        {/* ── Nav ── */}
        <header className="fixed inset-x-0 top-0 z-50 border-b border-white/6 bg-bg-0/80 backdrop-blur-2xl">
          <nav className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 md:px-6">
            <a href="#top" className="flex items-center gap-3">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-accent/30 bg-accent/8 text-accent">
                <Sparkles className="h-4 w-4" />
              </span>
              <span className="hidden sm:block">
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
                onClick={refreshAll}
              >
                {siteFetching ? "Syncing" : formatFreshness(siteAge)}
              </button>
              <button className="btn btn-primary" onClick={copyLoadstring}>
                <Clipboard className="h-4 w-4" /> Copy
              </button>
              <button className="rounded-lg border border-white/8 bg-white/[0.03] px-2.5 py-2 text-muted hover:text-text transition md:inline-flex hidden" onClick={openAdmin} title="Admin">
                <Shield className="h-4 w-4" />
              </button>
              <button className="md:hidden p-2 text-muted hover:text-text" onClick={() => setMenuOpen(!menuOpen)}>
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

        <ScanLines />
        <ParticleField count={15} />

        {/* ── Hero ── */}
        <section id="top" className="relative mx-auto min-h-[90dvh] max-w-7xl items-center gap-12 px-4 pb-24 pt-28 md:grid-cols-[1.1fr_0.9fr] md:px-6 md:pt-36" style={{ display: "grid" }}>
          <Hero3D />
          <div>
            <div className="kicker">
              <Sparkles className="h-3 w-3" />
              {relayKind === "online" ? "Relay live" : "Relay monitored"} · {site.uiLibrary || "Iris"} active
            </div>
            <h1 className="heading-xl mt-8">
              Scripts that <span className="gradient-text gradient-text-shimmer">stay fresh</span> without a second loadstring.
            </h1>
            <p className="mt-6 max-w-2xl text-lg leading-8 text-muted md:text-xl">
              {site.tagline || "One loader, live game routing, automatic release pins, and an Iris UI powered by Onyx resources, Fusion, and Spring."}
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <button className="btn btn-primary" onClick={copyLoadstring}>
                <Rocket className="h-4 w-4" />
                Copy loader
                <ChevronRight className="h-4 w-4" />
              </button>
              <a className="btn btn-outline" href={site.links?.github || site.links?.loaderRaw || "#pipeline"} target="_blank" rel="noreferrer">
                <GitBranch className="h-4 w-4" />
                View source
                <ArrowRight className="h-4 w-4" />
              </a>
            </div>
            <div className="mt-10 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {stats.map((s) => (
                <div key={s.label} className="stat-box fade-in-up">
                  <p className="font-mono text-[10px] uppercase tracking-wider text-muted">{s.label}</p>
                  <div className="mt-2 flex items-end justify-between gap-2">
                    <strong className="text-xl font-semibold text-text">{s.value}</strong>
                    <span className="pb-[3px] font-mono text-[10px] text-muted-2">{s.detail}</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div>
            <div className="card p-5 float fade-in-up fade-in-d2">
              <div className="flex items-center justify-between mb-4">
                <p className="font-mono text-[10px] uppercase tracking-wider text-muted-2">runtime profile</p>
                <span className="badge badge-green">stable</span>
              </div>
              <div className="grid grid-cols-2 gap-3">
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
                {["Iris-only visible UI", "Onyx resources retained", "Fusion stack available", "Spring motion available"].map((m) => (
                  <div key={m} className="flex items-center gap-3 rounded-lg bg-bg-0/50 px-3 py-2">
                    <BadgeCheck className="h-4 w-4 shrink-0 text-accent" />
                    <span className="text-sm text-muted">{m}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="mt-4">
              <CodePreview loadstring={site.loadstring} />
            </div>
          </div>
        </section>

        {/* ── Signal ── */}
        <section id="signal" className="relative mx-auto max-w-7xl px-4 py-24 md:px-6">
          <div className="section-head">
            <div className="kicker"><Activity className="h-3 w-3" /> Live signal</div>
            <h2 className="heading-lg mt-4">A command center without the dead weight.</h2>
            <p>The website leads with the operational facts people actually need: what is live, what changed, what UI is active, and where the loader points.</p>
          </div>
          <div className="mt-14 grid gap-4 md:grid-cols-4">
            {[
              { icon: Activity, title: "Relay", value: relayKind, detail: live.error?.message || "Status from live sync endpoint." },
              { icon: Gauge, title: "Freshness", value: formatFreshness(siteAge), detail: "Site snapshot baked into the static build." },
              { icon: Cpu, title: "Core", value: site.coreVersion || "2.9.10", detail: `Loader ${site.loaderVersion || "8.11.1"} with release polling.` },
              { icon: Shield, title: "Guardrails", value: "public", detail: "Access and security modules load before the game script." },
            ].map((s) => (
              <div key={s.title} className="card card-hover p-5 fade-in-up">
                <div className="flex items-center justify-between gap-3">
                  <IconBox icon={s.icon} variant="cyan" />
                  <Activity className="h-4 w-4 text-accent" />
                </div>
                <p className="mt-6 text-sm font-medium text-muted">{s.title}</p>
                <strong className="mt-2 block text-2xl font-bold tracking-tight text-text">{s.value}</strong>
                <p className="mt-3 text-sm leading-6 text-muted">{s.detail}</p>
              </div>
            ))}
          </div>
        </section>

        <GlobalTopology />

        {/* ── Games ── */}
        <section id="games" className="border-y border-white/6 bg-white/[0.015] px-4 py-24 md:px-6">
          <div className="mx-auto max-w-7xl">
            <div className="grid gap-8 md:grid-cols-[0.85fr_1.15fr] md:items-end">
              <div>
                <p className="font-mono text-[10px] uppercase tracking-wider text-accent-bright">Game routing</p>
                <h2 className="heading-lg mt-4">Scripts that know where they landed.</h2>
              </div>
              <p className="text-base leading-7 text-muted">
                Place IDs, release metadata, and script features are surfaced as a clean launch matrix instead of buried in a generic dashboard.
              </p>
            </div>
            <div className="mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {(games.length ? games : [{ name: "Auto-selected experience", status: "tracked" }]).map((game, i) => {
                const features = (game.scriptFeatures || []).slice(0, 3);
                return (
                  <article key={game.id || game.name || i} className="card card-hover p-5 fade-in-up" style={{ animationDelay: `${i * 0.05}s` }}>
                    <div className="flex items-start justify-between gap-4">
                      <div>
                        <p className="font-mono text-[10px] uppercase tracking-wider text-muted-2">{game.version || "live script"}</p>
                        <h3 className="mt-2 text-lg font-semibold text-text">{game.name || game.id || "Supported game"}</h3>
                      </div>
                      <span className={`badge ${statusClass(game.status)}`}>{game.status || "tracked"}</span>
                    </div>
                    <p className="mt-4 min-h-12 text-sm leading-6 text-muted">
                      {game.description || game.message || "Auto-selected by place ID with live release metadata and script health checks."}
                    </p>
                    <div className="mt-5 flex flex-wrap gap-2">
                      {(features.length ? features : [{ name: "Auto load" }, { name: "Config aware" }, { name: "Live pin" }]).map((f) => (
                        <span key={f.name} className="chip">{f.name}</span>
                      ))}
                    </div>
                  </article>
                );
              })}
            </div>
          </div>
        </section>

        {/* ── Pipeline ── */}
        <section id="pipeline" className="relative mx-auto max-w-7xl px-4 py-24 md:px-6">
          <div className="section-head">
            <div className="kicker"><GitBranch className="h-3 w-3" /> Deployment Pipeline</div>
            <h2 className="heading-lg mt-4">Every release flows through a verified runtime path.</h2>
            <p>Fetch, verify, compose, and launch — each stage is validated before the next begins.</p>
          </div>
          <div className="mt-14 grid gap-10 lg:grid-cols-[0.95fr_1.05fr]">
            <div className="glass-premium rounded-xl p-5 md:p-6 fade-in-up">
              <CodePreview loadstring={site.loadstring} />
            </div>
            <div className="fade-in-up fade-in-d2">
              <PipelineVisualizer />
            </div>
          </div>
        </section>

        <CloudflareLayer />

        {/* ── Support ── */}
        <section id="support" className="relative mx-auto max-w-5xl px-4 py-24 md:px-6">
          <div className="section-head">
            <div className="kicker"><Terminal className="h-3 w-3" /> Support</div>
            <h2 className="heading-lg mt-4">Report issues directly to the command center.</h2>
            <p>Submit a ticket and our operations team will respond within 24 hours through Discord.</p>
          </div>
          <div className="mt-10">
            <SupportForm />
          </div>
        </section>

        {/* ── Access ── */}
        <section id="access" className="px-4 pb-32 md:px-6">
          <div className="mx-auto grid max-w-7xl gap-4 lg:grid-cols-[1.1fr_0.9fr]">
            <div className="card card-gradient overflow-hidden p-6 md:p-8 fade-in-up">
              <div className="kicker"><ScrollText className="h-3 w-3" /> What changed</div>
              <h2 className="heading-lg mt-6">{latestChange?.title || "Built for fast fixes and clear releases."}</h2>
              <div className="mt-8 grid gap-3 md:grid-cols-2">
                {(latestChange?.items || [
                  "Iris-only visible UI", "Onyx resources retained",
                  "Fusion stack available", "Spring motion available",
                  "GitHub release pinning", "Live site snapshot",
                ]).slice(0, 6).map((item: string) => (
                  <div key={item} className="flex gap-3 rounded-lg border border-white/6 bg-bg-2/60 p-3">
                    <BadgeCheck className="mt-0.5 h-4 w-4 shrink-0 text-accent" />
                    <span className="text-sm leading-6 text-muted">{item}</span>
                  </div>
                ))}
              </div>
            </div>
            <div className="card flex flex-col justify-between p-6 md:p-8 fade-in-up fade-in-d2">
              <div>
                <IconBox icon={Terminal} variant="cyan" />
                <h3 className="mt-6 text-2xl font-bold">Launch with one command.</h3>
                <p className="mt-3 text-sm leading-7 text-muted">
                  Copy the live loader, inject once, and let the release system choose the right game module and UI stack.
                </p>
              </div>
              <div className="mt-6 flex flex-col gap-3">
                <button className="btn btn-primary" onClick={copyLoadstring}>
                  <Clipboard className="h-4 w-4" />
                  Copy loadstring
                </button>
                <a className="btn btn-ghost" href={site.links?.mirror || site.links?.website || "#top"} target="_blank" rel="noreferrer">
                  <Network className="h-4 w-4" />
                  Open mirror
                </a>
              </div>
            </div>
          </div>
        </section>

        {/* ── Footer ── */}
        <footer className="border-t border-white/6 px-4 py-8 md:px-6">
          <div className="mx-auto flex max-w-7xl items-center justify-between">
            <p className="text-xs text-muted-2">Alleral · {site.loaderVersion || "8.11.1"}</p>
            <button className="text-xs text-muted-2 hover:text-muted transition" onClick={openAdmin}>
              <Shield className="inline h-3 w-3 mr-1" />Admin
            </button>
          </div>
        </footer>
      </div>

      {/* ── Admin Login Modal ── */}
      {showAdminModal ? (
        <div className="fixed inset-0 z-[200] grid place-items-center p-4">
          <button className="absolute inset-0 bg-black/60" onClick={() => setShowAdminModal(false)} />
          <div className="card relative z-10 w-full max-w-sm p-6" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center gap-3 mb-5">
              <Shield className="h-5 w-5 text-accent" />
              <h3 className="text-lg font-semibold">Admin access</h3>
            </div>
            <input
              type="password"
              value={adminPass}
              onChange={(e) => setAdminPass(e.target.value)}
              onKeyDown={(e) => { if (e.key === "Enter") handleAdminLogin(); }}
              placeholder="Enter admin password"
              className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20"
              autoFocus
            />
            <div className="mt-4 flex gap-2">
              <button className="btn btn-primary flex-1" onClick={handleAdminLogin}>
                <LogIn className="h-4 w-4" /> Sign in
              </button>
              <button className="btn btn-ghost flex-1" onClick={() => setShowAdminModal(false)}>
                Cancel
              </button>
            </div>
          </div>
        </div>
      ) : null}
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
