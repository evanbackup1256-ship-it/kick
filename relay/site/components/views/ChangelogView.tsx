"use client";

import { motion } from "motion/react";
import type { SitePayload } from "@/lib/types";
import { spring, stagger } from "@/lib/motion/config";
import { Panel } from "@/components/ui/Panel";

export function ChangelogView({ site }: { site: SitePayload }) {
  const entries = site.changelog || [];

  return (
    <div className="mx-auto max-w-3xl space-y-3">
      {entries.map((entry, i) => (
        <motion.div key={`${entry.date}-${entry.title}`} initial={{ opacity: 0, y: 14 }} animate={{ opacity: 1, y: 0 }} transition={{ ...spring.soft, delay: Math.min(i * stagger.fast, 0.4) }}>
          <Panel padding="md" hover>
            <h3 className="font-semibold">{entry.title}</h3>
            <p className="mb-3 text-xs text-muted-2">{entry.date}</p>
            <ul className="list-disc space-y-1 pl-5 text-sm text-muted">
              {(entry.items || []).map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </Panel>
        </motion.div>
      ))}
    </div>
  );
}
