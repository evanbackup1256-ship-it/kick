"use client";

import clsx from "clsx";
import { Menu, Search } from "lucide-react";
import { Button, Kbd } from "@/components/ui/Button";
import { Select } from "@/components/ui/Form";
import { FreshnessChip } from "@/components/observability/FreshnessChip";
import { StatusPill } from "@/components/observability/StatusPill";
import { resolveRelayStatus } from "@/lib/status/resolve";
import { usePlatformStore, VIEW_META, type WorkspacePreset } from "@/lib/store/platform";

const WORKSPACE_OPTIONS: { value: WorkspacePreset; label: string }[] = [
  { value: "default", label: "Default workspace" },
  { value: "compact", label: "Compact density" },
  { value: "wide", label: "Wide analytics" },
];

export function TopBar({
  online,
  workspace,
  dataUpdatedAt,
}: {
  online?: boolean;
  workspace: string;
  dataUpdatedAt?: number;
}) {
  const setOpen = usePlatformStore((s) => s.setCommandOpen);
  const setMobileNavOpen = usePlatformStore((s) => s.setMobileNavOpen);
  const activeView = usePlatformStore((s) => s.activeView);
  const setWorkspace = usePlatformStore((s) => s.setWorkspace);
  const preset = (WORKSPACE_OPTIONS.some((o) => o.value === workspace) ? workspace : "default") as WorkspacePreset;
  const relayKind = resolveRelayStatus(online);

  return (
    <header className="glass-panel z-20 flex h-14 shrink-0 items-center justify-between gap-2 border-b border-border px-3 md:h-[3.75rem] md:px-5">
      <div className="flex min-w-0 items-center gap-2">
        <Button variant="ghost" size="sm" className="md:hidden" onClick={() => setMobileNavOpen(true)} aria-label="Open navigation">
          <Menu className="h-4 w-4" />
        </Button>
        <div className="min-w-0">
          <p className="obs-kicker !text-[10px] hidden sm:block">Workspace · {preset}</p>
          <h1 className="truncate text-sm font-semibold tracking-tight md:text-base">{VIEW_META[activeView].label}</h1>
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-1.5 md:gap-3">
        <FreshnessChip dataUpdatedAt={dataUpdatedAt} live={online !== false} className="hidden sm:inline-flex" />
        <StatusPill kind={relayKind} size="sm" className="hidden md:inline-flex" />
        <div className="hidden w-40 sm:block md:w-44">
          <Select name="workspace" options={WORKSPACE_OPTIONS} value={preset} onChange={(v) => setWorkspace(v as WorkspacePreset)} />
        </div>
        <Button variant="ghost" size="sm" onClick={() => setOpen(true)} className="gap-1.5 px-2 md:gap-2 md:px-3">
          <Search className="h-3.5 w-3.5" />
          <span className="hidden sm:inline">Command</span>
          <span className="hidden md:inline"><Kbd>⌘K</Kbd></span>
        </Button>
      </div>
    </header>
  );
}
