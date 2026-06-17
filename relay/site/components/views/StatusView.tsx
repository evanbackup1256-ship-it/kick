"use client";

import { MissionControl } from "@/components/dashboard/MissionControl";
import type { SitePayload } from "@/lib/types";

import { ViewTransition } from "@/components/effects/ViewTransition";

export function StatusView({ site }: { site: SitePayload }) {
  return (
    <ViewTransition id="status">
    <div className="min-h-0">
      <MissionControl site={site} />
    </div>
    </ViewTransition>
  );
}
