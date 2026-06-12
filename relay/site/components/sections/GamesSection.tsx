"use client";

import clsx from "clsx";
import { AnimatePresence, motion } from "framer-motion";
import { useEffect, useMemo, useState } from "react";
import { fetchThumbnails } from "@/lib/api";
import type { GameEntry, SitePayload } from "@/lib/types";
import { SectionHeader } from "@/components/layout/SiteChrome";

const STATUSES = ["all", "working", "testing", "maintenance", "broken"] as const;

const GRADIENTS = [
  "linear-gradient(135deg, #1a3a5c 0%, #0a1628 50%, #22d3ee33 100%)",
  "linear-gradient(135deg, #2d1f4e 0%, #0f0a1a 50%, #a78bfa33 100%)",
  "linear-gradient(135deg, #1a3d2e 0%, #0a1a12 50%, #34d39933 100%)",
];

function gradientFor(id: string, index: number) {
  let hash = index;
  for (let i = 0; i < id.length; i += 1) hash += id.charCodeAt(i);
  return GRADIENTS[hash % GRADIENTS.length];
}

export function GamesSection({ site }: { site: SitePayload }) {
  const [filter, setFilter] = useState<(typeof STATUSES)[number]>("all");
  const [query, setQuery] = useState("");
  const [thumbs, setThumbs] = useState<Record<string, string>>({});
  const [modal, setModal] = useState<{ id: string; game: GameEntry } | null>(null);

  const games = useMemo(() => Object.entries(site.games || {}).map(([id, game]) => ({ id, ...game })), [site.games]);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return games.filter((g) => {
      const status = (g.status || "working").toLowerCase();
      if (filter !== "all" && status !== filter) return false;
      if (!q) return true;
      return (g.name || g.id).toLowerCase().includes(q) || (g.description || "").toLowerCase().includes(q);
    });
  }, [games, filter, query]);

  useEffect(() => {
    const placeIds = [...new Set(games.map((g) => g.placeIds?.[0]).filter(Boolean).map(String))];
    fetchThumbnails(placeIds).then(setThumbs).catch(() => {});
  }, [games]);

  return (
    <section id="games" className="section-wrap scroll-mt-24 py-24">
      <SectionHeader label="Games" title="Supported scripts" desc="Live status from real inject telemetry." />

      <div className="mb-5 flex flex-wrap gap-2">
        {STATUSES.map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setFilter(s)}
            className={clsx(
              "rounded-full border px-3 py-1.5 text-xs font-medium capitalize transition",
              filter === s ? "border-cyan-400/40 bg-cyan-400/10 text-text" : "border-border text-muted hover:text-text"
            )}
          >
            {s}
          </button>
        ))}
      </div>

      <div className="relative mb-6 max-w-md">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search games…"
          className="w-full rounded-full border border-border bg-bg-card px-4 py-3 text-sm outline-none transition focus:border-cyan-400/45 focus:shadow-[0_0_0_3px_rgba(34,211,238,0.12)]"
        />
      </div>

      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        {filtered.map((game, i) => {
          const status = (game.status || "working").toLowerCase();
          const placeId = game.placeIds?.[0] ? String(game.placeIds[0]) : null;
          const thumb = placeId ? thumbs[placeId] : null;
          return (
            <motion.button
              key={game.id}
              type="button"
              layout
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-5%" }}
              transition={{ delay: Math.min(i * 0.04, 0.3) }}
              whileHover={{ y: -6 }}
              onClick={() => setModal({ id: game.id, game })}
              className="glass overflow-hidden rounded-[28px] text-left transition hover:border-cyan-400/20"
            >
              <div className="relative h-40 overflow-hidden">
                {thumb ? (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={thumb} alt="" className="absolute inset-0 h-full w-full object-cover" />
                ) : (
                  <div className="absolute inset-0" style={{ background: gradientFor(game.id, i) }} />
                )}
                <div className="absolute inset-0 bg-gradient-to-t from-[rgba(12,16,24,1)] to-transparent" />
              </div>
              <div className="p-5">
                <div className="mb-2 flex flex-wrap items-center gap-2">
                  <h3 className="text-lg font-semibold">{game.name || game.id}</h3>
                  <StatusChip status={status} />
                </div>
                <p className="line-clamp-2 text-sm text-muted">{game.description || game.message || "No description."}</p>
              </div>
            </motion.button>
          );
        })}
      </div>

      {!filtered.length ? <p className="mt-8 text-center text-muted">No games match this filter.</p> : null}

      <AnimatePresence>
        {modal ? (
          <GameModal game={modal.game} id={modal.id} onClose={() => setModal(null)} thumb={modal.game.placeIds?.[0] ? thumbs[String(modal.game.placeIds[0])] : null} index={0} />
        ) : null}
      </AnimatePresence>
    </section>
  );
}

function StatusChip({ status }: { status: string }) {
  const colors: Record<string, string> = {
    working: "text-green-400 bg-green-400/10 border-green-400/25",
    testing: "text-cyan-300 bg-cyan-400/10 border-cyan-400/25",
    maintenance: "text-purple-300 bg-purple-400/10 border-purple-400/25",
    broken: "text-red-400 bg-red-400/10 border-red-400/25",
  };
  return (
    <span className={clsx("rounded-full border px-2 py-0.5 text-[0.68rem] font-semibold capitalize", colors[status] || colors.working)}>
      {status}
    </span>
  );
}

function GameModal({
  game,
  id,
  onClose,
  thumb,
  index,
}: {
  game: GameEntry;
  id: string;
  onClose: () => void;
  thumb: string | null | undefined;
  index: number;
}) {
  const status = (game.status || "working").toLowerCase();
  return (
    <motion.div className="fixed inset-0 z-[120] grid place-items-center p-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
      <button type="button" aria-label="Close" className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={onClose} />
      <motion.div
        initial={{ scale: 0.96, y: 16 }}
        animate={{ scale: 1, y: 0 }}
        exit={{ scale: 0.96, y: 16 }}
        className="glass relative max-h-[90vh] w-full max-w-md overflow-auto rounded-[28px]"
      >
        <button type="button" onClick={onClose} className="absolute right-3 top-3 z-10 grid h-8 w-8 place-items-center rounded-full bg-black/50 text-lg backdrop-blur">
          ×
        </button>
        <div className="relative h-40 overflow-hidden">
          {thumb ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={thumb} alt="" className="absolute inset-0 h-full w-full object-cover" />
          ) : (
            <div className="absolute inset-0" style={{ background: gradientFor(id, index) }} />
          )}
        </div>
        <div className="p-6">
          <div className="mb-2 flex items-start justify-between gap-3">
            <h3 className="text-xl font-semibold">{game.name || id}</h3>
            <StatusChip status={status} />
          </div>
          <p className="mb-4 text-sm text-muted">{game.description || game.message}</p>
          {game.robloxUrl ? (
            <a href={game.robloxUrl} target="_blank" rel="noopener noreferrer" className="inline-flex rounded-full bg-gradient-to-br from-accent to-violet px-5 py-2.5 text-sm font-semibold text-[#030508]">
              Open on Roblox
            </a>
          ) : null}
        </div>
      </motion.div>
    </motion.div>
  );
}
