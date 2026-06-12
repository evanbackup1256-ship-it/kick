"use client";

import { useEffect, useState } from "react";
import { fetchLiveStatus } from "@/lib/api";
import type { LiveStatusPayload } from "@/lib/types";
import { SectionHeader } from "@/components/layout/SiteChrome";
import { BlurFadeIn, SpotlightCard } from "@/components/ui/premium";

export function LiveSection() {
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
            return merged.filter((item) => {
              const key = `${item.at}-${item.message}`;
              if (seen.has(key)) return false;
              seen.add(key);
              return true;
            }).slice(0, 40);
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

  return (
    <section id="live" className="section-wrap scroll-mt-24 py-24">
      <SectionHeader
        label="Live tracker"
        title="Real-time pulse"
        desc="Versions, GitHub sync, inject health, and changelog — streaming every 15 seconds."
      />

      <BlurFadeIn>
      <SpotlightCard spotlight="rgba(34,211,238,0.1)">
        <div className="p-6">
        <div className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <span className={`inline-flex items-center gap-2 text-sm ${online ? "text-green-400" : "text-red-400"}`}>
            <span className={`h-1.5 w-1.5 rounded-full ${online ? "bg-green-400" : "bg-red-400"}`} />
            {online ? (data?.autoSync ? "Live · auto-sync active" : "Relay online · sync idle") : "Offline"}
          </span>
          <span className="text-xs text-muted-2">{data?.updatedAt || "—"}</span>
        </div>

        <div className="mb-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {Object.entries(versions).map(([k, v]) => (
            <div key={k} className="rounded-xl border border-border bg-white/[0.02] px-4 py-3">
              <span className="block text-[0.68rem] uppercase tracking-wider text-muted-2">{k}</span>
              <strong className="text-sm">{v}</strong>
            </div>
          ))}
        </div>

        <div className="grid gap-4 lg:grid-cols-2">
          <Panel title="Sync & release">
            <KeyValue data={data?.sync} />
          </Panel>
          <Panel title="24h inject health">
            <KeyValue data={data?.telemetry} />
          </Panel>
        </div>

        <div className="mt-4 rounded-xl border border-border bg-white/[0.02] p-4">
          <div className="mb-3 flex items-center justify-between">
            <h3 className="text-sm font-semibold">Update feed</h3>
            <button type="button" className="text-xs text-muted hover:text-text" onClick={() => setFeed([])}>
              Clear
            </button>
          </div>
          <div className="max-h-64 space-y-2 overflow-y-auto">
            {feed?.length ? (
              feed.map((item, i) => (
                <article key={`${item.at}-${i}`} className="rounded-lg border border-border px-3 py-2 text-sm">
                  <time className="block text-[0.68rem] text-muted-2">{item.at}</time>
                  <p className="text-muted">{item.message}</p>
                </article>
              ))
            ) : (
              <p className="text-sm text-muted-2">{error ? "Could not reach live endpoint." : "Waiting for first sync…"}</p>
            )}
          </div>
        </div>
        </div>
      </SpotlightCard>
      </BlurFadeIn>
    </section>
  );
}

function Panel({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-border bg-white/[0.02] p-4">
      <h3 className="mb-3 text-sm font-semibold">{title}</h3>
      {children}
    </div>
  );
}

function KeyValue({ data }: { data?: Record<string, unknown> }) {
  if (!data || !Object.keys(data).length) return <p className="text-sm text-muted-2">—</p>;
  return (
    <dl className="space-y-2 text-sm">
      {Object.entries(data).map(([k, v]) => (
        <div key={k} className="flex justify-between gap-3 border-b border-border/60 pb-2 last:border-0">
          <dt className="text-muted">{k}</dt>
          <dd className="font-medium">{String(v)}</dd>
        </div>
      ))}
    </dl>
  );
}
