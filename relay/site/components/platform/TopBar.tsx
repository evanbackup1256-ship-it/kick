"use client";

import { Button, Kbd } from "@/components/ui/Button";
import { Badge } from "@/components/ui/Form";
import { usePlatformStore, VIEW_META } from "@/lib/store/platform";

export function TopBar({ online, workspace }: { online?: boolean; workspace: string }) {
  const setOpen = usePlatformStore((s) => s.setCommandOpen);
  const activeView = usePlatformStore((s) => s.activeView);
  const setWorkspace = usePlatformStore((s) => s.setWorkspace);

  return (
    <header className="glass-panel z-10 flex h-14 shrink-0 items-center justify-between border-b border-border px-4">
      <div className="min-w-0">
        <p className="text-[11px] uppercase tracking-[0.08em] text-muted-2">Workspace / {workspace}</p>
        <h1 className="truncate text-sm font-semibold">{VIEW_META[activeView].label}</h1>
      </div>

      <div className="flex items-center gap-2">
        <Badge tone={online ? "green" : "red"}>{online ? "Live" : "Degraded"}</Badge>
        <select
          aria-label="Workspace preset"
          value={workspace}
          onChange={(e) => setWorkspace(e.target.value as "default" | "telemetry" | "ops")}
          className="hidden rounded-lg border border-border bg-bg-2 px-2 py-1 text-xs text-muted md:block"
        >
          <option value="default">Default</option>
          <option value="telemetry">Telemetry</option>
          <option value="ops">Ops</option>
        </select>
        <Button variant="ghost" size="sm" onClick={() => setOpen(true)} className="gap-2">
          <span className="hidden sm:inline">Command</span>
          <Kbd>⌘K</Kbd>
        </Button>
      </div>
    </header>
  );
}
