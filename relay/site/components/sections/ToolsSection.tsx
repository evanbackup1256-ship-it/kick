"use client";

import clsx from "clsx";
import { motion } from "framer-motion";
import { useEffect, useMemo, useState } from "react";
import { fetchWeao } from "@/lib/api";
import { resolveResourceUrl } from "@/lib/sanitize";
import type { SitePayload, WeaoExploit } from "@/lib/types";
import { SectionHeader } from "@/components/layout/SiteChrome";

const FILTERS = ["all", "working", "not_working", "recommended", "detected", "outdated", "free"] as const;

export function ToolsSection({ site }: { site: SitePayload }) {
  const [data, setData] = useState<Awaited<ReturnType<typeof fetchWeao>> | null>(null);
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>("all");
  const [query, setQuery] = useState("");
  const [live, setLive] = useState(false);

  useEffect(() => {
    const el = document.getElementById("tools");
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        const visible = entries.some((e) => e.isIntersecting);
        setLive(visible);
        if (visible) void load(true);
      },
      { threshold: 0.15 }
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  const load = async (force = false) => {
    try {
      const next = await fetchWeao();
      setData(next);
    } catch {
      if (force) setData(null);
    }
  };

  useEffect(() => {
    if (!live) return;
    const t = setInterval(() => void load(), (data?.pollIntervalSec || 35) * 1000);
    return () => clearInterval(t);
  }, [live, data?.pollIntervalSec]);

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
    <section id="tools" className="scroll-mt-24 border-y border-border bg-white/[0.02] py-24">
      <div className="section-wrap">
        <SectionHeader label="Toolbox" title="Executor intel" desc="Live WEAO data and dev resources. Press Ctrl+K for commands." />

        <div className="mb-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-5">
          {[
            ["Tracked", summary.total || 0],
            ["Working", summary.working || 0],
            ["Not working", summary.notWorking || 0],
            ["Detected", summary.detected || 0],
            ["Best", summary.recommended || 0],
          ].map(([label, value]) => (
            <div key={label as string} className="glass rounded-2xl px-4 py-3">
              <span className="block text-[0.68rem] uppercase tracking-wider text-muted-2">{label as string}</span>
              <strong className="text-lg">{value as number}</strong>
            </div>
          ))}
        </div>

        <div className="glass mb-4 rounded-[28px] p-6">
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <div>
              <h3 className="text-lg font-semibold">All executors</h3>
              <p className="text-sm text-muted">Live from WEAO — refreshes when visible.</p>
            </div>
            <div className="flex items-center gap-2">
              <span className={clsx("rounded-full border px-3 py-1 text-xs font-medium", live ? "border-green-400/30 text-green-400" : "border-border text-muted")}>
                {live ? "Live · WEAO" : "WEAO"}
              </span>
              <button type="button" onClick={() => void load(true)} className="rounded-full border border-border px-4 py-2 text-xs font-medium hover:bg-white/[0.04]">
                Refresh
              </button>
            </div>
          </div>

          <div className="mb-3 flex flex-wrap gap-2">
            {FILTERS.map((f) => (
              <button
                key={f}
                type="button"
                onClick={() => setFilter(f)}
                className={clsx(
                  "rounded-full border px-3 py-1 text-xs capitalize transition",
                  filter === f ? "border-cyan-400/40 bg-cyan-400/10 text-text" : "border-border text-muted"
                )}
              >
                {f.replace("_", " ")}
              </button>
            ))}
          </div>

          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search Volt, Wave…"
            className="mb-4 w-full max-w-sm rounded-full border border-border bg-black/30 px-4 py-2.5 text-sm outline-none focus:border-cyan-400/40"
          />

          <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {list.length ? (
              list.map((ex) => <ExecutorCard key={ex.slug || ex.title} ex={ex} />)
            ) : (
              <p className="text-sm text-muted md:col-span-2 xl:col-span-3">
                {data ? "No executors match your search." : "Loading live executor data from WEAO…"}
              </p>
            )}
          </div>
        </div>

        <div className="glass rounded-[28px] p-6">
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
                  className="flex flex-col gap-1 rounded-xl border border-border bg-white/[0.02] px-4 py-3 transition hover:-translate-y-0.5 hover:border-cyan-400/35 hover:bg-cyan-400/5"
                >
                  <strong className="text-sm">{item.title}</strong>
                  <span className="text-xs text-muted-2">{item.desc}</span>
                </a>
              );
            })}
          </div>
        </div>
      </div>
    </section>
  );
}

function ExecutorCard({ ex }: { ex: WeaoExploit }) {
  const live = ex.live || "working";
  const colors: Record<string, string> = {
    working: "text-green-400",
    not_working: "text-red-400",
    detected: "text-yellow-400",
  };
  return (
    <article className="rounded-2xl border border-border bg-white/[0.02] p-4 transition hover:border-cyan-400/20">
      <div className="mb-3 flex items-center gap-3">
        {ex.logo ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={ex.logo} alt="" width={44} height={44} className="rounded-xl" />
        ) : (
          <span className="grid h-11 w-11 place-items-center rounded-xl bg-white/5 text-lg font-bold">{(ex.title || "?")[0]}</span>
        )}
        <div>
          <strong className="block text-sm">{ex.title}</strong>
          <span className={clsx("text-xs capitalize", colors[live] || "text-muted")}>{ex.liveLabel || live.replace("_", " ")}</span>
        </div>
      </div>
      {ex.liveDetail ? <p className="text-xs text-muted">{ex.liveDetail}</p> : null}
    </article>
  );
}
