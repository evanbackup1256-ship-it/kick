"use client";

import clsx from "clsx";
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useMemo, useState } from "react";
import { fetchThumbnails } from "@/lib/api";
import { spring } from "@/lib/motion/config";
import type { GameEntry, SitePayload } from "@/lib/types";
import { Badge } from "@/components/ui/Form";
import { Input } from "@/components/ui/Form";
import { Button } from "@/components/ui/Button";
import { Panel } from "@/components/ui/Panel";

const STATUSES = ["all", "working", "testing", "maintenance", "broken"] as const;

export function GamesView({ site }: { site: SitePayload }) {
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
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        {STATUSES.map((s) => (
          <Button key={s} size="sm" variant={filter === s ? "primary" : "ghost"} onClick={() => setFilter(s)} className="capitalize">
            {s}
          </Button>
        ))}
      </div>
      <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search games…" />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {filtered.map((game, i) => {
          const status = (game.status || "working").toLowerCase();
          const placeId = game.placeIds?.[0] ? String(game.placeIds[0]) : null;
          const thumb = placeId ? thumbs[placeId] : null;
          return (
            <motion.div key={game.id} initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ ...spring.soft, delay: Math.min(i * 0.04, 0.3) }}>
              <Panel hover padding="none" className="overflow-hidden text-left" glow={false}>
                <button type="button" className="block w-full text-left" onClick={() => setModal({ id: game.id, game })}>
                  <div className="relative h-36 overflow-hidden">
                    {thumb ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={thumb} alt="" className="absolute inset-0 h-full w-full object-cover transition duration-700 hover:scale-105" />
                    ) : (
                      <div className="absolute inset-0 bg-gradient-to-br from-accent/20 to-bg-2" />
                    )}
                    <div className="absolute inset-0 bg-gradient-to-t from-bg-2 to-transparent" />
                  </div>
                  <div className="p-4">
                    <div className="mb-2 flex items-center gap-2">
                      <h3 className="font-semibold">{game.name || game.id}</h3>
                      <StatusBadge status={status} />
                    </div>
                    <p className="line-clamp-2 text-sm text-muted">{game.description || game.message || "No description."}</p>
                  </div>
                </button>
              </Panel>
            </motion.div>
          );
        })}
      </div>

      <AnimatePresence>
        {modal ? (
          <motion.div className="fixed inset-0 z-[120] grid place-items-center p-4" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <button type="button" aria-label="Close" className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => setModal(null)} />
            <motion.div initial={{ scale: 0.96, y: 12 }} animate={{ scale: 1, y: 0 }} exit={{ scale: 0.96, y: 12 }} transition={spring.snappy} className="glass-raised relative max-h-[90vh] w-full max-w-md overflow-auto rounded-2xl">
              <button type="button" onClick={() => setModal(null)} className="absolute right-3 top-3 z-10 grid h-8 w-8 place-items-center rounded-full bg-black/50">
                ×
              </button>
              <div className="p-6">
                <h3 className="text-xl font-semibold">{modal.game.name || modal.id}</h3>
                <p className="mt-3 text-sm text-muted">{modal.game.description || modal.game.message}</p>
                {modal.game.robloxUrl ? (
                  <a href={modal.game.robloxUrl} target="_blank" rel="noopener noreferrer" className="mt-4 inline-flex">
                    <Button variant="primary">Open on Roblox</Button>
                  </a>
                ) : null}
              </div>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const tone = status === "working" ? "green" : status === "broken" ? "red" : status === "testing" ? "cyan" : "yellow";
  return (
    <Badge tone={tone as "green"} className="capitalize">
      {status}
    </Badge>
  );
}
