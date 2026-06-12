"use client";

import clsx from "clsx";
import {
  Activity,
  ChevronLeft,
  ChevronRight,
  Gamepad2,
  History,
  LayoutDashboard,
  LifeBuoy,
  Sparkles,
  Users,
  Wrench,
  X,
} from "lucide-react";
import { usePlatformStore, VIEW_META, type PlatformView } from "@/lib/store/platform";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveRelayStatus } from "@/lib/status/resolve";

const ICONS: Record<PlatformView, typeof LayoutDashboard> = {
  overview: LayoutDashboard,
  status: Activity,
  games: Gamepad2,
  tools: Wrench,
  changelog: History,
  support: LifeBuoy,
  credits: Users,
};

function SidebarNav({ online, collapsed }: { online?: boolean; collapsed: boolean }) {
  const activeView = usePlatformStore((s) => s.activeView);
  const setView = usePlatformStore((s) => s.setView);
  const relayKind = resolveRelayStatus(online);

  return (
    <>
      <div className="flex items-center gap-3 border-b border-border px-4 py-4">
        <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl border border-cyan-400/25 bg-gradient-to-br from-indigo-500/30 via-cyan-400/10 to-violet-500/20 shadow-[0_0_24px_rgba(34,211,238,0.15)]">
          <Sparkles className="h-4 w-4 text-cyan-200" strokeWidth={2} />
        </div>
        {!collapsed ? (
          <div className="min-w-0">
            <p className="truncate text-sm font-semibold tracking-tight">Alleral</p>
            <p className="truncate text-[11px] text-muted">Observability Platform</p>
          </div>
        ) : null}
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto p-2">
        {(Object.keys(VIEW_META) as PlatformView[]).map((view) => {
          const active = activeView === view;
          const Icon = ICONS[view];
          return (
            <button
              key={view}
              type="button"
              onClick={() => setView(view)}
              className={clsx(
                "nav-rail-item group",
                active && "nav-rail-item-active border border-cyan-400/20 bg-cyan-400/8",
                !active && "text-muted hover:bg-white/[0.03] hover:text-text"
              )}
            >
              <Icon className="relative z-[1] h-4 w-4 shrink-0 opacity-85" strokeWidth={1.75} />
              {!collapsed ? <span className="relative z-[1] truncate">{VIEW_META[view].label}</span> : null}
              {!collapsed && active ? (
                <kbd className="relative z-[1] ml-auto rounded border border-border bg-black/30 px-1.5 py-0.5 font-mono text-[9px] text-muted-2">
                  {VIEW_META[view].shortcut}
                </kbd>
              ) : null}
            </button>
          );
        })}
      </nav>

      <div className="border-t border-border p-3">
        {!collapsed ? <p className="mb-2 px-1 text-[10px] uppercase tracking-wider text-muted-2">Relay status</p> : null}
        <div className={clsx("flex items-center gap-2 rounded-xl border border-border bg-black/25 px-3 py-2.5", collapsed && "justify-center px-2")}>
          {!collapsed ? <StatusPill kind={relayKind} size="sm" pulse={online !== false} /> : <span className={clsx("h-2 w-2 rounded-full", online !== false ? "bg-green-400 shadow-[0_0_10px_rgba(52,211,153,0.7)]" : "bg-red-400")} />}
        </div>
      </div>
    </>
  );
}

export function Sidebar({ online }: { online?: boolean }) {
  const collapsed = usePlatformStore((s) => s.sidebarCollapsed);
  const mobileNavOpen = usePlatformStore((s) => s.mobileNavOpen);
  const setMobileNavOpen = usePlatformStore((s) => s.setMobileNavOpen);
  const toggle = usePlatformStore((s) => s.toggleSidebar);

  return (
    <>
      <aside
        className={clsx(
          "glass-raised relative z-30 hidden h-full shrink-0 flex-col border-r border-border transition-[width] duration-300 md:flex",
          collapsed ? "w-[76px]" : "w-[260px]"
        )}
      >
        <SidebarNav online={online} collapsed={collapsed} />
        <button type="button" onClick={toggle} className="mx-3 mb-3 flex items-center justify-center gap-1 rounded-lg px-2 py-1.5 text-xs text-muted hover:bg-white/[0.04] hover:text-text">
          {collapsed ? <ChevronRight className="h-4 w-4" /> : <ChevronLeft className="h-4 w-4" />}
          {!collapsed ? "Collapse" : null}
        </button>
      </aside>

      {mobileNavOpen ? (
        <button type="button" className="fixed inset-0 z-40 bg-black/60 md:hidden" aria-label="Close navigation" onClick={() => setMobileNavOpen(false)} />
      ) : null}

      <aside
        className={clsx(
          "glass-raised fixed inset-y-0 left-0 z-50 flex w-[min(280px,88vw)] flex-col border-r border-border transition-transform duration-300 md:hidden",
          mobileNavOpen ? "translate-x-0" : "-translate-x-full"
        )}
        aria-hidden={!mobileNavOpen}
      >
        <div className="flex items-center justify-end border-b border-border px-3 py-2">
          <button type="button" onClick={() => setMobileNavOpen(false)} className="rounded-lg p-2 text-muted hover:bg-white/[0.04] hover:text-text" aria-label="Close menu">
            <X className="h-4 w-4" />
          </button>
        </div>
        <SidebarNav online={online} collapsed={false} />
      </aside>
    </>
  );
}
