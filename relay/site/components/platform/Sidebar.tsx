"use client";

import clsx from "clsx";
import {
  Activity,
  Bug,
  ChevronLeft,
  ChevronRight,
  Gamepad2,
  History,
  LayoutDashboard,
  LifeBuoy,
  Shield,
  Users,
  Wrench,
  X,
  Zap,
} from "lucide-react";
import { resolveAdminUrl } from "@/lib/links";
import { usePlatformStore, VIEW_META, type PlatformView } from "@/lib/store/platform";
import type { SitePayload } from "@/lib/types";
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

function SidebarNav({
  online,
  collapsed,
  site,
}: {
  online?: boolean;
  collapsed: boolean;
  site: SitePayload;
}) {
  const activeView = usePlatformStore((s) => s.activeView);
  const setView = usePlatformStore((s) => s.setView);
  const relayKind = resolveRelayStatus(online);
  const adminUrl = resolveAdminUrl(site);

  return (
    <>
      <div className="sidebar-brand flex items-center gap-3 border-b border-border/80 px-4 py-4">
        <div className="brand-mark grid h-11 w-11 shrink-0 place-items-center rounded-2xl">
          <Zap className="h-5 w-5 text-accent-bright" strokeWidth={2.25} />
        </div>
        {!collapsed ? (
          <div className="min-w-0">
            <p className="truncate text-[15px] font-bold tracking-tight">Alleral</p>
            <p className="truncate text-[11px] text-muted">Script hub · v{site.loaderVersion || "—"}</p>
          </div>
        ) : null}
      </div>

      <nav className="flex-1 space-y-1 overflow-y-auto p-2.5 obs-scroll">
        {(Object.keys(VIEW_META) as PlatformView[]).map((view) => {
          const active = activeView === view;
          const Icon = ICONS[view];
          return (
            <button
              key={view}
              type="button"
              onClick={() => setView(view)}
              className={clsx(
                "nav-rail-item",
                active && "nav-rail-item-active",
                !active && "text-muted hover:bg-white/[0.04] hover:text-text"
              )}
            >
              <Icon className="h-4 w-4 shrink-0 opacity-85" strokeWidth={1.75} />
              {!collapsed ? <span className="truncate">{VIEW_META[view].label}</span> : null}
              {!collapsed && active ? (
                <kbd className="ml-auto rounded border border-border bg-bg-2 px-1.5 py-0.5 font-mono text-[9px] text-muted-2">
                  {VIEW_META[view].shortcut}
                </kbd>
              ) : null}
            </button>
          );
        })}
      </nav>

      <div className="space-y-2 border-t border-border/80 p-3">
        {!collapsed ? <p className="px-1 text-[10px] uppercase tracking-wider text-muted-2">Quick actions</p> : null}
        <div className={clsx("grid gap-1.5", collapsed && "grid-cols-1")}>
          <button
            type="button"
            onClick={() => setView("support")}
            className="sidebar-action"
            title="Report a bug"
          >
            <Bug className="h-3.5 w-3.5" />
            {!collapsed ? <span>Report bug</span> : null}
          </button>
          <a
            href={adminUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="sidebar-action sidebar-action-accent"
          >
            <Shield className="h-3.5 w-3.5" />
            {!collapsed ? <span>Admin site</span> : null}
          </a>
        </div>
        <div className={clsx("flex items-center gap-2 rounded-xl border border-border bg-bg-1/80 px-3 py-2.5", collapsed && "justify-center px-2")}>
          {!collapsed ? <StatusPill kind={relayKind} size="sm" /> : <span className={clsx("h-2 w-2 rounded-full", online !== false ? "bg-green" : "bg-red")} />}
        </div>
      </div>
    </>
  );
}

export function Sidebar({ online, site }: { online?: boolean; site: SitePayload }) {
  const collapsed = usePlatformStore((s) => s.sidebarCollapsed);
  const mobileNavOpen = usePlatformStore((s) => s.mobileNavOpen);
  const setMobileNavOpen = usePlatformStore((s) => s.setMobileNavOpen);
  const toggle = usePlatformStore((s) => s.toggleSidebar);

  return (
    <>
      <aside
        className={clsx(
          "sidebar-shell relative z-30 hidden h-full shrink-0 flex-col md:flex",
          collapsed ? "w-[76px]" : "w-[268px]"
        )}
      >
        <SidebarNav online={online} collapsed={collapsed} site={site} />
        <button
          type="button"
          onClick={toggle}
          className="mx-3 mb-3 flex items-center justify-center gap-1 rounded-lg px-2 py-1.5 text-xs text-muted hover:bg-white/[0.04] hover:text-text"
        >
          {collapsed ? <ChevronRight className="h-4 w-4" /> : <ChevronLeft className="h-4 w-4" />}
          {!collapsed ? "Collapse" : null}
        </button>
      </aside>

      {mobileNavOpen ? (
        <button
          type="button"
          className="fixed inset-0 z-40 bg-black/70 backdrop-blur-sm md:hidden"
          aria-label="Close navigation"
          onClick={() => setMobileNavOpen(false)}
        />
      ) : null}

      <aside
        className={clsx(
          "sidebar-shell fixed inset-y-0 left-0 z-50 flex w-[min(288px,90vw)] flex-col border-r border-border transition-transform duration-200 md:hidden",
          mobileNavOpen ? "translate-x-0" : "-translate-x-full"
        )}
        aria-hidden={!mobileNavOpen}
      >
        <div className="flex items-center justify-end border-b border-border px-3 py-2">
          <button
            type="button"
            onClick={() => setMobileNavOpen(false)}
            className="rounded-lg p-2 text-muted hover:bg-white/[0.04] hover:text-text"
            aria-label="Close menu"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
        <SidebarNav online={online} collapsed={false} site={site} />
      </aside>
    </>
  );
}
