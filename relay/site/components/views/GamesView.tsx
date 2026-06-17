"use client";

import clsx from "clsx";
import { Check, Copy, ExternalLink, Sparkles } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { toast } from "sonner";
import { fetchThumbnails } from "@/lib/api";
import {
  copyText,
  gameRobloxUrl,
  loaderWithGameComment,
  recentlyUpdatedGameIds,
  statusRank,
} from "@/lib/games/helpers";
import { useLiveSyncMeta } from "@/lib/queries/hooks";
import type { GameEntry, SitePayload } from "@/lib/types";
import { FreshnessChip } from "@/components/observability/FreshnessChip";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveGameStatus } from "@/lib/status/resolve";
import { Input } from "@/components/ui/Form";
import { Button } from "@/components/ui/Button";

const STATUSES = ["all", "working", "testing", "maintenance", "broken"] as const;
const SORTS = ["status", "name", "version"] as const;

export function GamesView({ site }: { site: SitePayload }) {
  const [filter, setFilter] = useState<(typeof STATUSES)[number]>("all");
  const [sort, setSort] = useState<(typeof SORTS)[number]>("status");
  const [query, setQuery] = useState("");
  const [thumbs, setThumbs] = useState<Record<string, string>>({});
  const [modal, setModal] = useState<{ id: string; game: GameEntry } | null>(null);
  const { data: live, dataUpdatedAt } = useLiveSyncMeta("games");

  const recentIds = useMemo(() => recentlyUpdatedGameIds(site), [site]);

  const liveStatus = useMemo(() => {
    const map: Record<string, string> = {};
    live?.games?.items?.forEach((g) => {
      if (g.id) map[g.id] = (g.status || "working").toLowerCase();
    });
    return map;
  }, [live?.games?.items]);

  const games = useMemo(
    () =>
      Object.entries(site.games || {}).map(([id, game]) => ({
        id,
        ...game,
        liveStatus: liveStatus[id] || (game.status || "working").toLowerCase(),
      })),
    [site.games, liveStatus]
  );

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    const list = games.filter((g) => {
      const status = g.liveStatus;
      if (filter !== "all" && status !== filter) return false;
      if (!q) return true;
      return (
        (g.name || g.id).toLowerCase().includes(q) ||
        (g.description || "").toLowerCase().includes(q) ||
        (g.message || "").toLowerCase().includes(q)
      );
    });

    return [...list].sort((a, b) => {
      if (sort === "name") return (a.name || a.id).localeCompare(b.name || b.id);
      if (sort === "version") return (b.version || "").localeCompare(a.version || "");
      return statusRank(a.liveStatus) - statusRank(b.liveStatus);
    });
  }, [games, filter, query, sort]);

  useEffect(() => {
    const placeIds = [...new Set(games.map((g) => g.placeIds?.[0]).filter(Boolean).map(String))];
    fetchThumbnails(placeIds).then(setThumbs).catch(() => {});
  }, [games]);

  const workingCount = games.filter((g) => g.liveStatus === "working").length;

  return (
    <div className="space-y-4">
      <div className="panel flex flex-wrap items-center justify-between gap-3 !py-3">
        <FreshnessChip dataUpdatedAt={dataUpdatedAt} live />
        <p className="text-xs text-muted">
          {filtered.length} games · {workingCount} working · live status
        </p>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        {STATUSES.map((s) => (
          <Button key={s} size="sm" variant={filter === s ? "primary" : "ghost"} onClick={() => setFilter(s)} className="capitalize">
            {s}
          </Button>
        ))}
        <span className="mx-1 hidden h-4 w-px bg-border sm:inline" aria-hidden />
        {SORTS.map((s) => (
          <Button key={s} size="sm" variant={sort === s ? "primary" : "ghost"} onClick={() => setSort(s)} className="capitalize">
            Sort {s}
          </Button>
        ))}
      </div>

      <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search games…" />

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        {filtered.map((game) => {
          const status = game.liveStatus;
          const placeId = game.placeIds?.[0] ? String(game.placeIds[0]) : null;
          const thumb = placeId ? thumbs[placeId] : null;
          const roblox = gameRobloxUrl(game);
          return (
            <GameCard
              key={game.id}
              game={game}
              status={status}
              thumb={thumb}
              recent={recentIds.has(game.id)}
              robloxUrl={roblox}
              onOpen={() => setModal({ id: game.id, game })}
            />
          );
        })}
      </div>

      {modal ? (
        <GameModal
          id={modal.id}
          game={modal.game}
          liveStatus={liveStatus[modal.id] || (modal.game.status || "working").toLowerCase()}
          loadstring={site.loadstring || ""}
          onClose={() => setModal(null)}
        />
      ) : null}
    </div>
  );
}

function GameModal({
  id,
  game,
  liveStatus,
  loadstring,
  onClose,
}: {
  id: string;
  game: GameEntry;
  liveStatus: string;
  loadstring: string;
  onClose: () => void;
}) {
  const roblox = gameRobloxUrl(game);
  const features = game.scriptFeatures || [];
  const tabs = game.uiTabs || [];
  const byCategory = useMemo(() => {
    const map = new Map<string, typeof features>();
    for (const f of features) {
      const cat = f.category || "General";
      if (!map.has(cat)) map.set(cat, []);
      map.get(cat)!.push(f);
    }
    return [...map.entries()];
  }, [features]);

  const copyLoader = async () => {
    if (!loadstring) return;
    const ok = await copyText(loaderWithGameComment(loadstring, id, game.name || id));
    toast[ok ? "success" : "error"](ok ? "Loader copied" : "Copy failed");
  };

  return (
    <div className="fixed inset-0 z-[120] grid place-items-center p-4">
      <button type="button" aria-label="Close" className="absolute inset-0 bg-black/70" onClick={onClose} />
      <div className="panel-raised view-enter relative max-h-[90vh] w-full max-w-lg overflow-auto">
        <button type="button" onClick={onClose} className="absolute right-3 top-3 z-10 grid h-8 w-8 place-items-center rounded-full bg-bg-1">
          ×
        </button>
        <div className="p-6">
          <div className="mb-3 flex flex-wrap items-center gap-2">
            <h3 className="text-xl font-semibold">{game.name || id}</h3>
            <StatusBadge status={liveStatus} />
            {game.version ? (
              <span className="rounded-full border border-border bg-bg-1 px-2 py-0.5 font-mono text-[10px] text-muted">v{game.version}</span>
            ) : null}
          </div>
          <p className="text-sm text-muted">{game.description || game.message || "No description."}</p>
          {game.message && game.description ? <p className="mt-2 text-xs text-muted-2">{game.message}</p> : null}

          {tabs.length ? (
            <div className="mt-4 flex flex-wrap gap-1.5">
              {tabs.map((tab) => (
                <span key={tab} className="rounded-lg border border-border bg-bg-1 px-2 py-1 text-[11px] text-muted">
                  {tab}
                </span>
              ))}
            </div>
          ) : null}

          {byCategory.length ? (
            <div className="mt-5 space-y-3">
              <p className="obs-kicker">Script features</p>
              {byCategory.map(([cat, items]) => (
                <div key={cat}>
                  <p className="mb-2 text-xs font-medium text-muted-2">{cat}</p>
                  <ul className="space-y-2">
                    {items.map((f) => (
                      <li key={f.name} className="flex items-start gap-2 rounded-xl border border-border/80 bg-bg-1/50 px-3 py-2 text-sm">
                        <Check className="mt-0.5 h-3.5 w-3.5 shrink-0 text-accent" />
                        <div>
                          <p className="font-medium">{f.name}</p>
                          {f.desc ? <p className="mt-0.5 text-xs text-muted">{f.desc}</p> : null}
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
            </div>
          ) : null}

          <div className="mt-6 flex flex-wrap gap-2">
            {roblox ? (
              <a href={roblox} target="_blank" rel="noopener noreferrer" className="inline-flex">
                <Button variant="primary">
                  <ExternalLink className="h-4 w-4" /> Open on Roblox
                </Button>
              </a>
            ) : null}
            {loadstring ? (
              <Button variant="ghost" onClick={() => void copyLoader()}>
                <Copy className="h-4 w-4" /> Copy loader
              </Button>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  );
}

function GameCard({
  game,
  status,
  thumb,
  recent,
  robloxUrl,
  onOpen,
}: {
  game: GameEntry & { id: string; liveStatus: string };
  status: string;
  thumb: string | null;
  recent: boolean;
  robloxUrl: string | null;
  onOpen: () => void;
}) {
  const cardRef = useRef<HTMLDivElement>(null);
  const thumbRef = useRef<HTMLDivElement>(null);

  const resetTilt = useCallback(() => {
    const card = cardRef.current;
    const layer = thumbRef.current;
    if (card) card.style.transform = "";
    if (layer) layer.style.transform = "";
  }, []);

  const onMove = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    const card = cardRef.current;
    const layer = thumbRef.current;
    if (!card || !layer) return;
    const rect = card.getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width - 0.5;
    const y = (e.clientY - rect.top) / rect.height - 0.5;
    card.style.transform = `rotateY(${x * 10}deg) rotateX(${-y * 8}deg)`;
    layer.style.transform = `translateZ(28px) scale(1.04) rotateY(${x * -4}deg) rotateX(${y * 3}deg)`;
  }, []);

  return (
    <div className="game-card-3d">
      <div
        ref={cardRef}
        className="game-card-3d-inner panel panel-hover overflow-hidden p-0"
        onMouseMove={onMove}
        onMouseLeave={resetTilt}
      >
        <button type="button" className="block w-full text-left" onClick={onOpen}>
          <div className="game-card-3d-scene relative h-40 overflow-hidden bg-bg-2">
            <div ref={thumbRef} className={clsx("game-card-3d-thumb absolute inset-0", thumb && "game-card-3d-thumb-float")}>
              {thumb ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={thumb} alt="" className="absolute inset-0 h-full w-full object-cover" loading="lazy" />
              ) : (
                <div className="absolute inset-0 bg-gradient-to-br from-accent/20 via-bg-2 to-bg-1" />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-bg-2 via-bg-2/20 to-transparent" />
              <div className="game-card-3d-shine absolute inset-0" />
            </div>
            {thumb ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img
                src={thumb}
                alt=""
                aria-hidden
                className="game-card-3d-reflection pointer-events-none absolute inset-x-3 bottom-[-34px] h-24 w-[calc(100%-1.5rem)] object-cover"
              />
            ) : null}
            {recent ? (
              <span className="absolute left-2 top-2 inline-flex items-center gap-1 rounded-full border border-accent/30 bg-bg-0/80 px-2 py-0.5 text-[10px] font-medium text-accent backdrop-blur">
                <Sparkles className="h-3 w-3" /> Updated
              </span>
            ) : null}
          </div>
          <div className="relative z-[1] p-4">
            <div className="mb-2 flex items-center gap-2">
              <h3 className="font-semibold">{game.name || game.id}</h3>
              <StatusBadge status={status} />
              {game.version ? <span className="font-mono text-[10px] text-muted-2">v{game.version}</span> : null}
            </div>
            <p className="line-clamp-2 text-sm text-muted">{game.description || game.message || "No description."}</p>
          </div>
        </button>
        {robloxUrl ? (
          <div className="border-t border-border px-4 py-2">
            <a
              href={robloxUrl}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
              className="inline-flex items-center gap-1.5 text-xs text-accent hover:text-accent-bright"
            >
              <ExternalLink className="h-3 w-3" /> Play on Roblox
            </a>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function StatusBadge({ status }: { status: string }) {
  const kind = resolveGameStatus(status);
  return <StatusPill kind={kind} size="sm" className="capitalize" label={status} />;
}
