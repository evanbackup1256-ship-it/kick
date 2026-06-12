"use client";

import { CommandCenter } from "@/components/dashboard/CommandCenter";
import type { SitePayload } from "@/lib/types";

export function StatusView({ site }: { site: SitePayload }) {
  return (
    <div className="min-h-0">
      <CommandCenter site={site} />
    </div>
  );
}
