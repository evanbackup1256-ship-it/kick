"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import type { SitePayload } from "@/lib/types";
import { SectionHeader } from "@/components/layout/SiteChrome";

export function ChangelogSection({ site }: { site: SitePayload }) {
  const [shown, setShown] = useState(3);
  const entries = site.changelog || [];

  return (
    <section id="changelog" className="scroll-mt-24 border-y border-border bg-white/[0.02] py-24">
      <div className="section-wrap">
        <SectionHeader label="Changelog" title="Ship log" />
        <div className="mx-auto max-w-2xl space-y-4">
          {entries.slice(0, shown).map((entry, i) => (
            <motion.article
              key={`${entry.date}-${entry.title}`}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.05 }}
              className="glass rounded-2xl px-7 py-6"
            >
              <h3 className="font-semibold">{entry.title}</h3>
              <p className="mb-3 text-xs text-muted-2">{entry.date}</p>
              <ul className="list-disc space-y-1 pl-5 text-sm text-muted">
                {(entry.items || []).map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </motion.article>
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
          <motion.li
            key={step.n}
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.08 }}
            className="glass list-none rounded-[28px] p-6"
          >
            <span className="mb-3 inline-flex h-7 w-7 items-center justify-center rounded-full bg-cyan-400/15 text-xs font-semibold text-accent">{step.n}</span>
            <h3 className="mb-2 font-semibold">{step.title}</h3>
            <p className="text-sm text-muted">{step.desc}</p>
          </motion.li>
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
        <div className="mx-auto flex max-w-xl flex-wrap gap-3">
          <code className="glass flex-1 break-all rounded-2xl px-4 py-3 font-mono text-xs text-muted">{primaryUrl}</code>
          <CopyBtn text={primaryUrl} label="Copy Link" />
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

function CopyBtn({ text, label }: { text: string; label: string }) {
  return (
    <button
      type="button"
      onClick={() => void navigator.clipboard.writeText(text)}
      className="rounded-full bg-gradient-to-br from-accent to-violet px-6 py-3 text-sm font-semibold text-[#030508]"
    >
      {label}
    </button>
  );
}
