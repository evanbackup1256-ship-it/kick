"use client";

import { Command } from "cmdk";
import { useEffect, useMemo, useState } from "react";
import { usePlatformStore, VIEW_META, type PlatformView } from "@/lib/store/platform";
import type { SitePayload } from "@/lib/types";

export function CommandPalette({
  site,
  onCopyScript,
  onRefresh,
}: {
  site: SitePayload;
  onCopyScript?: () => void;
  onRefresh?: () => void;
}) {
  const open = usePlatformStore((s) => s.commandOpen);
  const setOpen = usePlatformStore((s) => s.setCommandOpen);
  const setView = usePlatformStore((s) => s.setView);
  const [search, setSearch] = useState("");

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(!open);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, setOpen]);

  useEffect(() => {
    if (!open) setSearch("");
  }, [open]);

  const go = (view: PlatformView) => {
    setView(view);
    setOpen(false);
  };

  const views = Object.keys(VIEW_META) as PlatformView[];
  const games = useMemo(() => Object.entries(site.games || {}), [site.games]);
  const q = search.trim().toLowerCase();
  const gameMatches = useMemo(() => {
    if (!q) return games.slice(0, 6);
    return games.filter(([id, g]) => {
      const name = (g.name || id).toLowerCase();
      return name.includes(q) || id.includes(q) || (g.description || "").toLowerCase().includes(q);
    }).slice(0, 8);
  }, [games, q]);

  if (!open) return null;

  return (
    <>
      <button
        type="button"
        aria-label="Close command palette"
        className="fixed inset-0 z-[300] bg-black/70"
        onClick={() => setOpen(false)}
      />
      <div className="view-enter fixed left-1/2 top-[18%] z-[301] w-[min(640px,calc(100vw-24px))] -translate-x-1/2">
        <Command className="panel-raised overflow-hidden" label="Command palette" shouldFilter={false}>
          <div className="border-b border-border px-4 py-3">
            <Command.Input
              value={search}
              onValueChange={setSearch}
              placeholder="Search views, games, actions…"
              className="w-full bg-transparent text-sm outline-none placeholder:text-muted"
            />
          </div>
          <Command.List className="max-h-[360px] overflow-y-auto overscroll-contain p-2 obs-scroll">
            <Command.Empty className="px-3 py-6 text-center text-sm text-muted">No results.</Command.Empty>
            <Command.Group heading="Navigate" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
              {views
                .filter((view) => !q || VIEW_META[view].label.toLowerCase().includes(q))
                .map((view) => (
                  <Command.Item
                    key={view}
                    onSelect={() => go(view)}
                    className="flex w-full cursor-pointer items-center justify-between rounded-xl px-3 py-2.5 text-left text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
                  >
                    <span>{VIEW_META[view].label}</span>
                    <kbd className="font-mono text-[10px] text-muted-2">⌘{VIEW_META[view].shortcut}</kbd>
                  </Command.Item>
                ))}
            </Command.Group>
            {gameMatches.length ? (
              <Command.Group heading="Games" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
                {gameMatches.map(([id, game]) => (
                  <Command.Item
                    key={id}
                    onSelect={() => go("games")}
                    className="flex w-full cursor-pointer items-center justify-between gap-2 rounded-xl px-3 py-2.5 text-left text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
                  >
                    <span>{game.name || id}</span>
                    <span className="shrink-0 font-mono text-[10px] capitalize text-muted-2">{game.status || "working"}</span>
                  </Command.Item>
                ))}
              </Command.Group>
            ) : null}
            <Command.Group heading="Actions" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
              <Command.Item
                onSelect={() => {
                  onCopyScript?.();
                  setOpen(false);
                }}
                className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
              >
                Copy loader script
              </Command.Item>
              <Command.Item
                onSelect={() => {
                  onRefresh?.();
                  setOpen(false);
                }}
                className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
              >
                Refresh live data
              </Command.Item>
              <Command.Item
                onSelect={() => go("support")}
                className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
              >
                Report a bug
              </Command.Item>
              <Command.Item
                onSelect={() => go("tools")}
                className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
              >
                Check executor status
              </Command.Item>
              <Command.Item
                onSelect={() => {
                  const adminUrl = site.links?.admin || site.links?.relay?.replace(/\/$/, "") + "/admin" || "/admin";
                  window.open(adminUrl, "_blank", "noopener,noreferrer");
                  setOpen(false);
                }}
                className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
              >
                Open admin panel
              </Command.Item>
            </Command.Group>
          </Command.List>
        </Command>
      </div>
    </>
  );
}
