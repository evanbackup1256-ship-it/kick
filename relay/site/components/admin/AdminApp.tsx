"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  Activity,
  ArrowLeft,
  BarChart3,
  ClipboardCheck,
  EyeOff,
  KeyRound,
  Lock,
  LogOut,
  Radio,
  RefreshCw,
  Shield,
  Sparkles,
  Zap,
} from "lucide-react";
import { toast } from "sonner";
import { apiUrl } from "@/lib/config";
import { useLiveSyncMeta, useSiteQuery } from "@/lib/queries/hooks";
import { SITE_SNAPSHOT } from "@/lib/site-snapshot";
import { MissionControl } from "@/components/dashboard/MissionControl";
import { QueryProvider } from "@/components/providers/QueryProvider";

type Summary = Record<string, number | string | undefined>;
type FeedItem = {
  at?: string;
  event?: string;
  kind?: string;
  placeId?: string | number;
  jobId?: string;
  executor?: string;
  game?: string;
  message?: string;
  details?: string;
};
type SeriesMap = Record<string, { label?: string; at?: string; value?: number; count?: number }[] | number[]>;

const TOKEN_KEY = "alleral_admin_token";
const TOKEN_EXP_KEY = "alleral_admin_token_exp";

function readToken() {
  if (typeof window === "undefined") return "";
  const token = sessionStorage.getItem(TOKEN_KEY) || localStorage.getItem(TOKEN_KEY) || "";
  const exp = sessionStorage.getItem(TOKEN_EXP_KEY) || localStorage.getItem(TOKEN_EXP_KEY) || "";
  if (exp && Date.parse(exp) < Date.now()) {
    sessionStorage.removeItem(TOKEN_KEY); sessionStorage.removeItem(TOKEN_EXP_KEY);
    localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(TOKEN_EXP_KEY);
    return "";
  }
  return token;
}

function adminHeaders(token: string): HeadersInit {
  return { "Content-Type": "application/json", "X-Admin-Token": token };
}

async function fetchAdmin<T>(path: string, token: string): Promise<T> {
  const res = await fetch(apiUrl(path), { headers: adminHeaders(token), cache: "no-store" });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.ok === false) throw new Error(String(data.error || `Request failed (${res.status})`));
  return data as T;
}

function StatCard({ label, value, detail }: { label: string; value: React.ReactNode; detail?: string }) {
  return (
    <div className="admin-glass admin-lift p-4">
      <p className="font-mono text-[10px] uppercase tracking-wider text-muted">{label}</p>
      <div className="mt-3 text-3xl font-bold tracking-tight text-text">{value}</div>
      {detail ? <p className="mt-2 text-xs leading-5 text-muted">{detail}</p> : null}
    </div>
  );
}

function MiniSeries({ data, label }: { data: number[]; label: string }) {
  const max = Math.max(1, ...data);
  return (
    <div className="admin-glass p-4">
      <div className="flex items-center justify-between gap-3">
        <p className="font-mono text-[10px] uppercase tracking-wider text-muted">{label}</p>
        <BarChart3 className="h-4 w-4 text-cyan" />
      </div>
      <div className="mt-5 flex h-28 items-end gap-1.5">
        {(data.length ? data : [0, 0, 0, 0, 0, 0, 0, 0]).slice(-28).map((value, index) => (
          <span
            key={`${label}-${index}`}
            className="min-w-1 flex-1 rounded-t bg-gradient-to-t from-accent/30 to-cyan/90 shadow-[0_0_18px_rgba(0,212,255,0.16)]"
            style={{ height: `${Math.max(8, (value / max) * 100)}%` }}
            title={`${value}`}
          />
        ))}
      </div>
    </div>
  );
}

function normalizeSeries(series?: SeriesMap): { key: string; values: number[] }[] {
  if (!series) return [];
  return Object.entries(series).map(([key, raw]) => ({
    key,
    values: Array.isArray(raw) ? raw.map((item) => (typeof item === "number" ? item : Number(item.value ?? item.count ?? 0))) : [],
  }));
}

function AdminLogin({ onLogin }: { onLogin: (token: string) => void }) {
  const [key, setKey] = useState("");
  const [remember, setRemember] = useState(true);
  const [busy, setBusy] = useState(false);

  const login = useCallback(async () => {
    if (!key.trim()) { toast.error("Enter ADMIN_API_KEY"); return; }
    setBusy(true);
    try {
      const res = await fetch(apiUrl("/api/admin/login"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: key.trim(), remember }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || data.ok === false || !data.token) throw new Error(String(data.error || "Login failed"));
      const storage = remember ? localStorage : sessionStorage;
      storage.setItem(TOKEN_KEY, data.token);
      if (data.expiresAt) storage.setItem(TOKEN_EXP_KEY, data.expiresAt);
      onLogin(data.token);
      toast.success("Admin session active");
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Admin login failed");
    } finally { setBusy(false); }
  }, [key, onLogin, remember]);

  return (
    <div className="grid min-h-dvh place-items-center bg-bg-0 px-4 py-16 text-text">
      <div className="ambient-orb ambient-orb-a" />
      <div className="ambient-orb ambient-orb-b" />
      <div className="admin-login-card relative z-10 w-full max-w-xl p-6 md:p-8">
        <div className="flex items-center justify-between">
          <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-accent/25 bg-accent/8 text-accent">
            <Lock className="h-4 w-4" />
          </span>
          <a href="/" className="inline-flex items-center gap-2 text-sm text-muted hover:text-text">
            <ArrowLeft className="h-4 w-4" />
            Public site
          </a>
        </div>
        <p className="mt-8 inline-flex items-center gap-2 font-mono text-[10px] uppercase tracking-wider text-accent-bright">
          <EyeOff className="h-3 w-3" /> Owner access
        </p>
        <h1 className="mt-4 text-4xl font-bold tracking-tight md:text-5xl">Private telemetry deck.</h1>
        <p className="mt-4 text-sm leading-7 text-muted">
          Telemetry, recent injects, failure feed, and admin status stay behind the backend admin token. Players only see the public landing page.
        </p>
        <label className="mt-8 block">
          <span className="mb-2 block text-xs font-medium text-muted">ADMIN_API_KEY</span>
          <input
            className="admin-input"
            value={key}
            onChange={(e) => setKey(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") void login(); }}
            type="password"
            autoComplete="current-password"
            placeholder="Paste your Railway admin key"
          />
        </label>
        <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
          <label className="inline-flex items-center gap-2 text-sm text-muted">
            <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} className="accent-accent" />
            Remember this browser
          </label>
          <button className="site-button site-button-primary" type="button" onClick={() => void login()} disabled={busy}>
            <KeyRound className="h-4 w-4" />
            {busy ? "Signing in" : "Unlock admin"}
          </button>
        </div>
      </div>
    </div>
  );
}

function AdminDeck({ token, onLogout }: { token: string; onLogout: () => void }) {
  const siteQuery = useSiteQuery();
  const site = siteQuery.data ?? SITE_SNAPSHOT;
  const live = useLiveSyncMeta("status");
  const [summary, setSummary] = useState<Summary>({});
  const [feed, setFeed] = useState<FeedItem[]>([]);
  const [series, setSeries] = useState<SeriesMap>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const seriesRows = useMemo(() => normalizeSeries(series), [series]);

  const refresh = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const [summaryData, recentData, seriesData] = await Promise.all([
        fetchAdmin<{ summary?: Summary }>("/api/admin/telemetry/summary?hours=48", token),
        fetchAdmin<{ items?: FeedItem[] }>("/api/admin/telemetry/recent?limit=60", token),
        fetchAdmin<{ series?: SeriesMap }>("/api/admin/telemetry/timeseries?hours=48&bucket=1", token),
      ]);
      setSummary(summaryData.summary || {});
      setFeed(recentData.items || []);
      setSeries(seriesData.series || {});
    } catch (err) {
      const message = err instanceof Error ? err.message : "Telemetry unavailable";
      setError(message);
      if (message === "unauthorized") onLogout();
    } finally { setLoading(false); }
  }, [onLogout, token]);

  useEffect(() => {
    void refresh();
    const id = window.setInterval(() => void refresh(), 15_000);
    return () => window.clearInterval(id);
  }, [refresh]);

  return (
    <main className="min-h-dvh bg-bg-0 text-text">
      <div className="ambient-orb ambient-orb-a" />
      <div className="ambient-orb ambient-orb-b" />
      <div className="relative z-10 mx-auto max-w-7xl px-4 py-6 md:px-6">
        <header className="admin-shell-head">
          <div>
            <p className="inline-flex items-center gap-2 font-mono text-[10px] uppercase tracking-wider text-accent-bright">
              <EyeOff className="h-3 w-3" /> Admin only
            </p>
            <h1 className="mt-3 text-4xl font-bold tracking-tight md:text-6xl">Telemetry command center</h1>
          </div>
          <div className="flex flex-wrap gap-2">
            <button className="site-button border-white/8 bg-white/[0.03] text-text hover:border-accent/30" type="button" onClick={() => void refresh()}>
              <RefreshCw className={`h-4 w-4 ${loading ? "animate-spin" : ""}`} />
              Refresh
            </button>
            <button className="site-button border-red/18 bg-red/8 text-red hover:bg-red/15" type="button" onClick={onLogout}>
              <LogOut className="h-4 w-4" />
              Sign out
            </button>
          </div>
        </header>

        {error ? (
          <div className="admin-glass mt-5 border-red/25 bg-red/8 p-4 font-mono text-sm text-red">{error}</div>
        ) : null}

        <section className="mt-6 grid gap-3 md:grid-cols-5">
          <StatCard label="48h injects ok" value={summary.inject_loaded ?? summary.inject_ok ?? "-"} detail="Successful loader completions" />
          <StatCard label="48h inject fail" value={summary.inject_failed ?? "-"} detail="Failures caught by telemetry" />
          <StatCard label="48h errors" value={summary.errors ?? summary.feed_errors ?? "-"} detail="Runtime exceptions and warnings" />
          <StatCard label="Game updates" value={summary.place_updated ?? "-"} detail="Place status changes" />
          <StatCard label="Live relay" value={live.online ? "online" : "watch"} detail="Public status remains player-safe" />
        </section>

        <section className="mt-6 grid gap-4 xl:grid-cols-[0.9fr_1.1fr]">
          <div className="admin-glass admin-panel-scroll p-4">
            <div className="mb-4 flex items-center justify-between">
              <div>
                <p className="font-mono text-[10px] uppercase tracking-wider text-accent-bright">Private feed</p>
                <h2 className="mt-2 text-2xl font-bold">Recent telemetry</h2>
              </div>
              <Radio className="h-5 w-5 text-accent" />
            </div>
            <div className="space-y-2">
              {(feed.length ? feed : [{ event: "Waiting", message: "No recent admin telemetry returned yet." }]).map((item, index) => (
                <article key={`${item.at || "feed"}-${index}`} className="admin-feed-item">
                  <div className="flex items-center justify-between gap-3">
                    <strong className="text-sm">{item.event || item.kind || "telemetry"}</strong>
                    <time className="font-mono text-[10px] text-muted-2">{item.at ? new Date(item.at).toLocaleTimeString() : "live"}</time>
                  </div>
                  <p className="mt-2 text-sm leading-6 text-muted">{item.message || item.game || item.executor || "Telemetry event received."}</p>
                  <div className="mt-2 flex flex-wrap gap-2 font-mono text-[10px] text-muted-2">
                    {item.placeId ? <span>place {item.placeId}</span> : null}
                    {item.executor ? <span>{item.executor}</span> : null}
                    {item.jobId ? <span>job {String(item.jobId).slice(0, 8)}</span> : null}
                  </div>
                  {item.details ? <pre className="mt-2 whitespace-pre-wrap rounded border border-white/8 bg-black/30 p-2 text-[11px] text-red/85">{item.details}</pre> : null}
                </article>
              ))}
            </div>
          </div>

          <div className="grid gap-4">
            <div className="grid gap-4 md:grid-cols-2">
              {(seriesRows.length ? seriesRows : [{ key: "inject_loaded", values: [0, 1, 2, 3, 2, 5, 4, 6] }]).slice(0, 4).map((row) => (
                <MiniSeries key={row.key} label={row.key.replace(/_/g, " ")} data={row.values} />
              ))}
            </div>
            <div className="admin-glass p-4">
              <div className="mb-4 flex items-center justify-between">
                <div>
                  <p className="font-mono text-[10px] uppercase tracking-wider text-accent-bright">Live health</p>
                  <h2 className="mt-2 text-2xl font-bold">Operational status</h2>
                </div>
                <Shield className="h-5 w-5 text-accent" />
              </div>
              <MissionControl site={site} />
            </div>
          </div>
        </section>

        <section className="mt-6 grid gap-3 md:grid-cols-3">
          <div className="admin-glass p-4">
            <Sparkles className="h-5 w-5 text-violet" />
            <h3 className="mt-4 font-semibold">Animated surface</h3>
            <p className="mt-2 text-sm leading-6 text-muted">Layered glass, live bars, hover lift, scanlines, and refresh motion.</p>
          </div>
          <div className="admin-glass p-4">
            <ClipboardCheck className="h-5 w-5 text-cyan" />
            <h3 className="mt-4 font-semibold">Private by API</h3>
            <p className="mt-2 text-sm leading-6 text-muted">Telemetry calls require the backend admin token before any feed data renders.</p>
          </div>
          <div className="admin-glass p-4">
            <Zap className="h-5 w-5 text-accent" />
            <h3 className="mt-4 font-semibold">Fast polling</h3>
            <p className="mt-2 text-sm leading-6 text-muted">Admin telemetry refreshes every 15 seconds while the page is open.</p>
          </div>
        </section>
      </div>
    </main>
  );
}

function AdminAppInner() {
  const [token, setToken] = useState("");

  useEffect(() => { setToken(readToken()); }, []);

  const logout = useCallback(() => {
    const active = readToken();
    if (active) { void fetch(apiUrl("/api/admin/logout"), { method: "POST", headers: adminHeaders(active) }).catch(() => {}); }
    sessionStorage.removeItem(TOKEN_KEY); sessionStorage.removeItem(TOKEN_EXP_KEY);
    localStorage.removeItem(TOKEN_KEY); localStorage.removeItem(TOKEN_EXP_KEY);
    setToken("");
    toast.message("Signed out");
  }, []);

  return token ? <AdminDeck token={token} onLogout={logout} /> : <AdminLogin onLogin={setToken} />;
}

export function AdminApp() {
  return (
    <QueryProvider>
      <AdminAppInner />
    </QueryProvider>
  );
}