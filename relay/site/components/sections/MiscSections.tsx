"use client";

import { useState } from "react";
import type { SitePayload } from "@/lib/types";
import { SectionHeader } from "@/components/layout/SiteChrome";
import { BlurFadeIn, GlowButton, SpotlightCard } from "@/components/ui/premium";

export function ChangelogSection({ site }: { site: SitePayload }) {
  const [shown, setShown] = useState(3);
  const entries = site.changelog || [];

  return (
    <section id="changelog" className="scroll-mt-24 border-y border-border bg-white/[0.02] py-24">
      <div className="section-wrap">
        <SectionHeader label="Changelog" title="Ship log" />
        <div className="mx-auto max-w-2xl space-y-4">
          {entries.slice(0, shown).map((entry, i) => (
            <div key={`${entry.date}-${entry.title}`}>
            <BlurFadeIn delay={i * 0.05}>
              <SpotlightCard spotlight="rgba(167,139,250,0.08)">
                <div className="px-7 py-6">
                  <h3 className="font-semibold">{entry.title}</h3>
                  <p className="mb-3 text-xs text-muted-2">{entry.date}</p>
                  <ul className="list-disc space-y-1 pl-5 text-sm text-muted">
                    {(entry.items || []).map((item) => (
                      <li key={item}>{item}</li>
                    ))}
                  </ul>
                </div>
              </SpotlightCard>
            </BlurFadeIn>
            </div>
          ))}
        </div>
        {shown < entries.length ? (
          <div className="mt-8 text-center">
            <button type="button" onClick={() => setShown((n) => n + 3)} className="rounded-full border border-border px-6 py-3 text-sm hover:bg-white/[0.04]">
              Load more
            </button>
          </div>
        ) : null}
      </div>
    </section>
  );
}

export function QuickStartSection() {
  const steps = [
    { n: "01", title: "Copy the loader", desc: "Use the script above — it auto-updates from GitHub on every inject." },
    { n: "02", title: "Execute in Roblox", desc: "Paste into your executor and run. Check WEAO status in Tools if unsure." },
    { n: "03", title: "Pick a game", desc: "Green status means working. Join and the hub menu loads automatically." },
  ];

  return (
    <section id="getting-started" className="section-wrap scroll-mt-24 py-24">
      <SectionHeader label="Quick start" title="Three steps in" desc="Copy, inject, play — the loader handles the rest." />
      <ol className="grid gap-4 md:grid-cols-3">
        {steps.map((step, i) => (
          <li key={step.n} className="list-none">
            <BlurFadeIn delay={i * 0.08}>
              <SpotlightCard spotlight="rgba(34,211,238,0.09)">
                <div className="p-6">
                  <span className="mb-3 inline-flex h-7 w-7 items-center justify-center rounded-full bg-cyan-400/15 text-xs font-semibold text-accent">{step.n}</span>
                  <h3 className="mb-2 font-semibold">{step.title}</h3>
                  <p className="text-sm text-muted">{step.desc}</p>
                </div>
              </SpotlightCard>
            </BlurFadeIn>
          </li>
        ))}
      </ol>
    </section>
  );
}

export function ShareSection({ primaryUrl, mirrorUrl }: { primaryUrl: string; mirrorUrl: string }) {
  return (
    <section id="access" className="scroll-mt-24 border-t border-border bg-white/[0.02] py-24">
      <div className="section-wrap">
        <SectionHeader label="Share" title="Spread the hub" />
        <div className="mx-auto flex max-w-xl flex-wrap items-stretch gap-3">
          <SpotlightCard className="flex-1" spotlight="rgba(34,211,238,0.08)">
            <code className="block break-all px-4 py-3 font-mono text-xs text-muted">{primaryUrl}</code>
          </SpotlightCard>
          <GlowButton onClick={() => void navigator.clipboard.writeText(primaryUrl)}>Copy Link</GlowButton>
        </div>
        <p className="mt-4 text-center text-sm text-muted-2">
          Mirror:{" "}
          <a href={mirrorUrl} target="_blank" rel="noopener noreferrer" className="text-accent hover:text-cyan-300">
            {mirrorUrl}
          </a>
        </p>
      </div>
    </section>
  );
}
