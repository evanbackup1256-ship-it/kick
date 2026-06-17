"use client";

import { MissionControl } from "@/components/dashboard/MissionControl";
import type { SitePayload } from "@/lib/types";

export function StatusView({ site }: { site: SitePayload }) {
  return (
    <div className="min-h-0">
      <MissionControl site={site} />
    </div>
  );
}
