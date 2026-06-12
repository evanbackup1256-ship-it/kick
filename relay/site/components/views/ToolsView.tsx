"use client";

import clsx from "clsx";
import { useEffect, useMemo, useState } from "react";
import { fetchWeao } from "@/lib/api";
import { resolveResourceUrl } from "@/lib/sanitize";
import type { SitePayload, WeaoExploit } from "@/lib/types";
import { Button } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Form";
import { Input } from "@/components/ui/Form";
import { AnimatedNumber } from "@/components/ui/DataViz";
import { MetricTile, Panel } from "@/components/ui/Panel";

const FILTERS = ["all", "working", "not_working", "recommended", "detected", "outdated", "free"] as const;

export function ToolsView({ site }: { site: SitePayload }) {
  const [data, setData] = useState<Awaited<ReturnType<typeof fetchWeao>> | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("all");
  const [query, setQuery] = useState("");

  const load = async () => {
    try {
      setData(await fetchWeao());
    } catch {
      setData(null);
    }
  };

  useEffect(() => {
    void load();
    const t = setInterval(load, (data?.pollIntervalSec || 35) * 1000);
    return () => clearInterval(t);
  }, [data?.pollIntervalSec]);

  const list = useMemo(() => {
    const exploits = data?.exploits || [];
    const q = query.trim().toLowerCase();
    return exploits.filter((ex) => {
      if (filter === "recommended" && !ex.recommended) return false;
      if (filter === "free" && (ex.price || "").toLowerCase() !== "free") return false;
      if (filter !== "all" && filter !== "recommended" && filter !== "free" && (ex.live || "") !== filter) return false;
      if (q && !(ex.title || "").toLowerCase().includes(q)) return false;
      return true;
    });
  }, [data?.exploits, filter, query]);

  const summary = data?.summary || {};

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
        <MetricTile label="Tracked" value={<AnimatedNumber value={summary.total || 0} />} />
        <MetricTile label="Working" value={<AnimatedNumber value={summary.working || 0} />} accent="green" />
        <MetricTile label="Not working" value={<AnimatedNumber value={summary.notWorking || 0} />} accent="red" />
        <MetricTile label="Detected" value={<AnimatedNumber value={summary.detected || 0} />} accent="yellow" />
        <MetricTile label="Recommended" value={<AnimatedNumber value={summary.recommended || 0} />} accent="violet" />
      </div>

      <Panel padding="md">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 className="text-lg font-semibold">WEAO executor intel</h3>
            <p className="text-sm text-muted">Live status from WEAO API</p>
          </div>
          <Button size="sm" onClick={() => void load()}>
            Refresh
          </Button>
        </div>
        <div className="mb-3 flex flex-wrap gap-2">
          {FILTERS.map((f) => (
            <Button key={f} size="sm" variant={filter === f ? "primary" : "ghost"} onClick={() => setFilter(f)} className="capitalize">
              {f.replace("_", " ")}
            </Button>
          ))}
        </div>
        <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search executors…" className="mb-4 max-w-sm" />
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          {list.length ? list.map((ex) => <ExecutorCard key={ex.slug || ex.title} ex={ex} />) : <p className="text-sm text-muted">{data ? "No matches." : "Loading WEAO…"}</p>}
        </div>
      </Panel>

      <Panel padding="md">
        <h3 className="mb-4 text-lg font-semibold">Resources</h3>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {(site.resources || []).map((item) => {
            const url = resolveResourceUrl(site, item);
            if (!url) return null;
            const external = url.startsWith("http") || url.startsWith("/api");
            return (
              <a
                key={item.title}
                href={url}
                {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}
                className="rounded-xl border border-border bg-white/[0.02] px-4 py-3 transition hover:-translate-y-0.5 hover:border-accent/30 hover:bg-accent/5"
              >
                <strong className="text-sm">{item.title}</strong>
                <p className="mt-1 text-xs text-muted">{item.desc}</p>
              </a>
            );
          })}
        </div>
      </Panel>
    </div>
  );
}

function ExecutorCard({ ex }: { ex: WeaoExploit }) {
  const live = ex.live || "working";
  const tone = live === "working" ? "green" : live === "not_working" ? "red" : live === "detected" ? "yellow" : "neutral";
  return (
    <article className="rounded-xl border border-border bg-white/[0.02] p-4 transition hover:border-accent/20">
      <div className="mb-2 flex items-center gap-3">
        {ex.logo ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={ex.logo} alt="" width={40} height={40} className="rounded-lg" />
        ) : (
          <span className="grid h-10 w-10 place-items-center rounded-lg bg-white/5 text-sm font-bold">{(ex.title || "?")[0]}</span>
        )}
        <div>
          <strong className="block text-sm">{ex.title}</strong>
          <Badge tone={tone as "green"} className="mt-1 capitalize">
            {ex.liveLabel || live.replace("_", " ")}
          </Badge>
        </div>
      </div>
      {ex.liveDetail ? <p className="text-xs text-muted">{ex.liveDetail}</p> : null}
    </article>
  );
}
