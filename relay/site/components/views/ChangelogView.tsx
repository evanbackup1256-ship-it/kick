"use client";



import { Calendar, Sparkles } from "lucide-react";

import { useMemo, useState } from "react";

import type { SitePayload } from "@/lib/types";

import { Input } from "@/components/ui/Form";



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

    <div className="mx-auto max-w-3xl space-y-6">

      <div className="changelog-hero panel relative overflow-hidden p-6 md:p-8">

        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_80%_0%,rgba(0,232,255,0.12),transparent_50%)]" />

        <div className="relative z-[1]">

          <p className="obs-kicker flex items-center gap-2">

            <Sparkles className="h-3.5 w-3.5" /> Release notes

          </p>

          <h2 className="obs-title mt-2 text-2xl md:text-3xl">Updates</h2>

          <p className="mt-2 max-w-xl text-sm text-muted">

            Pulled live from the relay — refreshes with site config every 30 seconds.

          </p>

        </div>

      </div>



      <Input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search updates…" className="changelog-search" />



      {filtered.length === 0 ? <p className="text-sm text-muted">No matching entries.</p> : null}



      <ol className="changelog-timeline space-y-0">

        {filtered.map((entry, index) => (

          <li key={`${entry.date}-${entry.title}`} className="changelog-entry">

            <div className="changelog-marker" aria-hidden>

              <span className={index === 0 && !query ? "changelog-dot-live" : "changelog-dot"} />

            </div>

            <article className={`changelog-card ${index === 0 && !query ? "changelog-card-latest" : ""}`}>

              <header className="mb-3 flex flex-wrap items-center gap-2">

                <h3 className="text-base font-semibold tracking-tight md:text-lg">{entry.title}</h3>

                {index === 0 && !query ? (

                  <span className="rounded-full border border-accent/40 bg-accent/12 px-2.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-accent-bright">

                    Latest

                  </span>

                ) : null}

              </header>

              <p className="mb-4 flex items-center gap-1.5 text-xs text-muted-2">

                <Calendar className="h-3.5 w-3.5" />

                {entry.date}

              </p>

              <ul className="space-y-2">

                {(entry.items || []).map((item) => (

                  <li key={item} className="changelog-item text-sm leading-relaxed text-muted">

                    {item}

                  </li>

                ))}

              </ul>

            </article>

          </li>

        ))}

      </ol>

    </div>

  );

}

