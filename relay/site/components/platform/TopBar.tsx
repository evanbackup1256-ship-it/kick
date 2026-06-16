"use client";

import { Menu, RefreshCw, Search, Shield } from "lucide-react";
import { resolveAdminUrl } from "@/lib/links";
import { resolveRelayStatus, formatFreshness } from "@/lib/status/resolve";
import { usePlatformStore, VIEW_META, type WorkspacePreset } from "@/lib/store/platform";
import type { SitePayload } from "@/lib/types";
import { useSecondsSince } from "@/lib/hooks/useSecondsSince";
import { FreshnessChip } from "@/components/observability/FreshnessChip";
import { StatusPill } from "@/components/observability/StatusPill";
import { Select } from "@/components/ui/Form";
import { Button, Kbd } from "@/components/ui/Button";

const WORKSPACE_OPTIONS: { value: WorkspacePreset; label: string }[] = [
  { value: "default", label: "Default" },
  { value: "compact", label: "Compact" },
  { value: "wide", label: "Wide" },
];

export function TopBar({
  site,
  online,
  workspace,
  dataUpdatedAt,
  siteUpdatedAt,
  siteFetching,
  onRefreshSite,
}: {
  site: SitePayload;
  online?: boolean;
  workspace: string;
  dataUpdatedAt?: number;
  siteUpdatedAt?: number;
  siteFetching?: boolean;
  onRefreshSite?: () => void;
}) {
  const setOpen = usePlatformStore((s) => s.setCommandOpen);
  const setMobileNavOpen = usePlatformStore((s) => s.setMobileNavOpen);
  const activeView = usePlatformStore((s) => s.activeView);
  const setWorkspace = usePlatformStore((s) => s.setWorkspace);
  const preset = (WORKSPACE_OPTIONS.some((o) => o.value === workspace) ? workspace : "default") as WorkspacePreset;
  const relayKind = resolveRelayStatus(online);
  const meta = VIEW_META[activeView];
  const siteAge = useSecondsSince(siteUpdatedAt ?? null, 1000);
  const adminUrl = resolveAdminUrl(site);

  return (
    <header className="topbar-shell z-20 flex h-14 shrink-0 items-center justify-between gap-2 px-3 md:h-[3.85rem] md:px-5">
      <div className="flex min-w-0 items-center gap-2">
        <Button variant="ghost" size="sm" className="md:hidden" onClick={() => setMobileNavOpen(true)} aria-label="Open navigation">
          <Menu className="h-4 w-4" />
        </Button>
        <div className="min-w-0 overflow-hidden">
          <p className="obs-kicker !text-[10px] hidden sm:block">{preset} workspace</p>
          <h1 className="truncate text-sm font-semibold tracking-tight md:text-base">{meta.label}</h1>
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-1.5 md:gap-2.5">
        <span
          className="hidden items-center gap-1.5 rounded-full border border-border/80 bg-bg-1/60 px-2 py-1 font-mono text-[10px] text-muted lg:inline-flex"
          title={site.updatedAt || site.siteUpdatedAt ? `Site config: ${site.updatedAt || site.siteUpdatedAt}` : undefined}
        >
          {siteFetching ? "Syncing…" : formatFreshness(siteAge)}
        </span>
        <FreshnessChip dataUpdatedAt={dataUpdatedAt} live={online !== false} className="hidden sm:inline-flex" />
        <StatusPill kind={relayKind} size="sm" className="hidden md:inline-flex" />
        <Button variant="ghost" size="sm" className="hidden px-2 lg:inline-flex" onClick={onRefreshSite}>
          <RefreshCw className={`h-3.5 w-3.5 ${siteFetching ? "animate-spin" : ""}`} />
        </Button>
        <a
          href={adminUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="motion-pop hidden items-center justify-center rounded-lg border border-transparent px-2 py-1.5 text-muted hover:bg-white/[0.04] hover:text-text md:inline-flex"
          aria-label="Open admin site"
        >
          <Shield className="h-3.5 w-3.5 text-accent" />
        </a>
        <div className="hidden w-36 sm:block md:w-40">
          <Select name="workspace" options={WORKSPACE_OPTIONS} value={preset} onChange={(v) => setWorkspace(v as WorkspacePreset)} />
        </div>
        <Button variant="ghost" size="sm" onClick={() => setOpen(true)} className="gap-1.5 px-2 md:gap-2 md:px-3">
          <Search className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">Search</span>
          <span className="hidden md:inline">
            <Kbd>⌘K</Kbd>
          </span>
        </Button>
      </div>
    </header>
  );
}
