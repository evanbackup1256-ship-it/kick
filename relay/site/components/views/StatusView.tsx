"use client";

import { CommandCenter } from "@/components/dashboard/CommandCenter";
import type { SitePayload } from "@/lib/types";

export function StatusView({ site }: { site: SitePayload }) {
  return (
    <div className="min-h-0 md:max-h-[calc(100dvh-3.75rem-3rem)] md:overflow-hidden">
      <CommandCenter site={site} />
    </div>
  );
}
