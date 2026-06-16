"use client";

import { Command } from "cmdk";
import { Bug, RefreshCw, Shield, Terminal, Wrench } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { resolveAdminUrl } from "@/lib/links";
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
    return games
      .filter(([id, g]) => {
        const name = (g.name || id).toLowerCase();
        return name.includes(q) || id.includes(q) || (g.description || "").toLowerCase().includes(q);
      })
      .slice(0, 8);
  }, [games, q]);

  const adminUrl = resolveAdminUrl(site);

  if (!open) return null;

  return (
    <>
      <button
        type="button"
        aria-label="Close command palette"
        className="cmdk-backdrop fixed inset-0 z-[300]"
        onClick={() => setOpen(false)}
      />
      <div className="view-enter fixed left-1/2 top-[14%] z-[301] w-[min(680px,calc(100vw-24px))] -translate-x-1/2">
        <Command className="cmdk-shell overflow-hidden" label="Command palette" shouldFilter={false}>
          <div className="cmdk-input-wrap border-b border-border/80 px-4 py-3.5">
            <Command.Input
              value={search}
              onValueChange={setSearch}
              placeholder="Search views, games, actions…"
              className="w-full bg-transparent text-base outline-none placeholder:text-muted-2"
            />
          </div>
          <Command.List className="max-h-[min(420px,55vh)] overflow-y-auto overscroll-contain p-2 obs-scroll">
            <Command.Empty className="px-3 py-8 text-center text-sm text-muted">No results.</Command.Empty>
            <Command.Group heading="Navigate" className="cmdk-group">
              {views
                .filter((view) => !q || VIEW_META[view].label.toLowerCase().includes(q))
                .map((view) => (
                  <Command.Item key={view} onSelect={() => go(view)} className="cmdk-item">
                    <span>{VIEW_META[view].label}</span>
                    <kbd className="font-mono text-[10px] text-muted-2">⌘{VIEW_META[view].shortcut}</kbd>
                  </Command.Item>
                ))}
            </Command.Group>
            {gameMatches.length ? (
              <Command.Group heading="Games" className="cmdk-group">
                {gameMatches.map(([id, game]) => (
                  <Command.Item key={id} onSelect={() => go("games")} className="cmdk-item">
                    <span>{game.name || id}</span>
                    <span className="shrink-0 font-mono text-[10px] capitalize text-muted-2">{game.status || "working"}</span>
                  </Command.Item>
                ))}
              </Command.Group>
            ) : null}
            <Command.Group heading="Actions" className="cmdk-group">
              <Command.Item
                onSelect={() => {
                  onCopyScript?.();
                  setOpen(false);
                }}
                className="cmdk-item"
              >
                <Terminal className="h-4 w-4 opacity-70" />
                Copy loader script
              </Command.Item>
              <Command.Item
                onSelect={() => {
                  onRefresh?.();
                  setOpen(false);
                }}
                className="cmdk-item"
              >
                <RefreshCw className="h-4 w-4 opacity-70" />
                Refresh live data
              </Command.Item>
              <Command.Item onSelect={() => go("support")} className="cmdk-item">
                <Bug className="h-4 w-4 opacity-70" />
                Report a bug
              </Command.Item>
              <Command.Item onSelect={() => go("tools")} className="cmdk-item">
                <Wrench className="h-4 w-4 opacity-70" />
                Check executor status
              </Command.Item>
              <Command.Item asChild value="admin-panel">
                <a
                  href={adminUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="cmdk-item cmdk-item-accent"
                  onClick={() => setOpen(false)}
                >
                  <Shield className="h-4 w-4 text-accent" />
                  Open admin site
                </a>
              </Command.Item>
            </Command.Group>
          </Command.List>
        </Command>
      </div>
    </>
  );
}
