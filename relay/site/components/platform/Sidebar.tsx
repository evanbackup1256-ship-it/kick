"use client";

import clsx from "clsx";
import { motion } from "motion/react";
import { spring } from "@/lib/motion/config";
import { usePlatformStore, VIEW_META, type PlatformView } from "@/lib/store/platform";

const ICONS: Record<PlatformView, string> = {
  overview: "◆",
  control: "◎",
  games: "▦",
  tools: "⚡",
  changelog: "↗",
  support: "✉",
  credits: "★",
};

export function Sidebar({ online }: { online?: boolean }) {
  const collapsed = usePlatformStore((s) => s.sidebarCollapsed);
  const activeView = usePlatformStore((s) => s.activeView);
  const setView = usePlatformStore((s) => s.setView);
  const toggle = usePlatformStore((s) => s.toggleSidebar);

  return (
    <motion.aside
      animate={{ width: collapsed ? 72 : 248 }}
      transition={spring.panel}
      className="glass-panel relative z-20 flex h-full shrink-0 flex-col border-r border-border"
    >
      <div className="flex items-center gap-3 border-b border-border px-4 py-4">
        <div className="grid h-9 w-9 shrink-0 place-items-center rounded-xl border border-accent/30 bg-gradient-to-br from-accent/25 to-cyan-400/10 text-sm font-bold text-text accent-glow">
          A
        </div>
        {!collapsed ? (
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold">Alleral</p>
            <p className="truncate text-[11px] text-muted">Telemetry Platform</p>
          </div>
        ) : null}
      </div>

      <nav className="flex-1 space-y-1 p-2">
        {(Object.keys(VIEW_META) as PlatformView[]).map((view) => {
          const active = activeView === view;
          return (
            <button
              key={view}
              type="button"
              onClick={() => setView(view)}
              className={clsx(
                "group relative flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm transition",
                active ? "bg-white/[0.06] text-text" : "text-muted hover:bg-white/[0.03] hover:text-text"
              )}
            >
              {active ? (
                <motion.span
                  layoutId="nav-active"
                  className="absolute inset-0 rounded-xl border border-accent/25 bg-gradient-to-r from-accent/10 to-transparent"
                  transition={spring.panel}
                />
              ) : null}
              <span className="relative z-[1] w-5 text-center text-xs opacity-80">{ICONS[view]}</span>
              {!collapsed ? <span className="relative z-[1] truncate">{VIEW_META[view].label}</span> : null}
            </button>
          );
        })}
      </nav>

      <div className="border-t border-border p-3">
        {!collapsed ? (
          <p className="mb-2 px-1 text-[10px] uppercase tracking-wider text-muted-2">Relay</p>
        ) : null}
        <div className={clsx("flex items-center gap-2 rounded-xl border border-border bg-black/20 px-3 py-2", collapsed && "justify-center px-2")}>
          <span className={clsx("h-2 w-2 rounded-full", online ? "bg-green-400 shadow-[0_0_10px_rgba(52,211,153,0.7)]" : "bg-muted-2")} />
          {!collapsed ? <span className="text-xs text-muted">{online ? "Online" : "Offline"}</span> : null}
        </div>
        <button type="button" onClick={toggle} className="mt-2 w-full rounded-lg px-2 py-1.5 text-xs text-muted hover:bg-white/[0.04] hover:text-text">
          {collapsed ? "→" : "← Collapse"}
        </button>
      </div>
    </motion.aside>
  );
}
