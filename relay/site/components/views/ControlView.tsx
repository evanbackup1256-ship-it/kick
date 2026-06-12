"use client";

import { MissionControl } from "@/components/dashboard/MissionControl";
import { Panel } from "@/components/ui/Panel";

export function ControlView() {
  return (
    <div className="space-y-4">
      <Panel padding="md" className="border-accent/20">
        <p className="text-xs uppercase tracking-[0.08em] text-muted-2">Mission Control</p>
        <h2 className="mt-1 text-xl font-semibold tracking-tight">Live telemetry workspace</h2>
        <p className="mt-2 max-w-2xl text-sm text-muted">Resizable panels, live charts, and event timelines — your command center for relay health and sync activity.</p>
      </Panel>
      <MissionControl />
    </div>
  );
}
