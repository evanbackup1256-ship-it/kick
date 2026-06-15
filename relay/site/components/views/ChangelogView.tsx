"use client";

import { useMemo, useState } from "react";
import type { SitePayload } from "@/lib/types";
import { Input } from "@/components/ui/Form";
import { Panel } from "@/components/ui/Panel";

export function ChangelogView({ site }: { site: SitePayload }) {
  const [query, setQuery] = useState("");
  const entries = site.changelog || [];

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return entries;
    return entries.filter(
      (e) =>
        (e.title || "").toLowerCase().includes(q) ||
        (e.date || "").includes(q) ||
        (e.items || []).some((item) => item.toLowerCase().includes(q))
    );
  }, [entries, query]);

  return (
    <div className="mx-auto max-w-3xl space-y-4">
      <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search ship log…" />
      {filtered.length === 0 ? <p className="text-sm text-muted">No matching entries.</p> : null}
      {filtered.map((entry, index) => (
        <Panel
          key={`${entry.date}-${entry.title}`}
          padding="md"
          hover
          className={index === 0 && !query ? "border-accent/25 bg-accent/[0.04]" : undefined}
        >
          <div className="mb-3 flex flex-wrap items-center gap-2">
            <h3 className="font-semibold">{entry.title}</h3>
            {index === 0 && !query ? (
              <span className="rounded-full border border-accent/30 bg-accent/10 px-2 py-0.5 text-[10px] font-medium text-accent">Latest</span>
            ) : null}
          </div>
          <p className="mb-3 text-xs text-muted-2">{entry.date}</p>
          <ul className="list-disc space-y-1 pl-5 text-sm text-muted">
            {(entry.items || []).map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </Panel>
      ))}
    </div>
  );
}
