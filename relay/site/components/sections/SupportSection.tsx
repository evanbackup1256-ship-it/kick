"use client";

import { motion } from "framer-motion";
import { useState } from "react";
import { API_BASE } from "@/lib/config";
import type { SitePayload } from "@/lib/types";
import { SectionHeader } from "@/components/layout/SiteChrome";

export function SupportSection({ site }: { site: SitePayload }) {
  const [tab, setTab] = useState<"bug" | "feature" | "support">("bug");
  const [error, setError] = useState("");
  const [ok, setOk] = useState(false);

  const submit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError("");
    setOk(false);
    const form = new FormData(e.currentTarget);
    const path = tab === "bug" ? "/api/bug-report" : tab === "feature" ? "/api/feature-request" : "/api/support";
    const payload: Record<string, string> = Object.fromEntries(
      [...form.entries()].map(([k, v]) => [k, String(v)])
    );
    if (tab === "bug") {
      payload.robloxUser = payload.username || "";
      payload.pageUrl = `${location.pathname}${location.hash}`;
      payload.userAgent = navigator.userAgent;
    } else if (tab === "feature") {
      payload.robloxUser = payload.username || "";
      payload.pageUrl = `${location.pathname}${location.hash}`;
      payload.userAgent = navigator.userAgent;
    } else {
      payload.pageUrl = `${location.pathname}${location.hash}`;
      payload.userAgent = navigator.userAgent;
    }
    try {
      const res = await fetch(`${API_BASE}${path}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok || data.ok === false) throw new Error(data.error || "Submit failed");
      setOk(true);
      e.currentTarget.reset();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Submit failed");
    }
  };

  return (
    <section id="support" className="scroll-mt-24 border-y border-border bg-white/[0.02] py-24">
      <div className="section-wrap">
        <SectionHeader label="Contact" title="Reach out" desc="Bug reports and ideas go straight to Discord." />

        <div className="mx-auto mb-6 flex max-w-md flex-wrap justify-center gap-2">
          {(
            [
              ["bug", "Bug Report"],
              ["feature", "Feature"],
              ["support", "Question"],
            ] as const
          ).map(([id, label]) => (
            <button
              key={id}
              type="button"
              onClick={() => setTab(id)}
              className={`rounded-full border px-4 py-2 text-sm transition ${tab === id ? "border-cyan-400/40 bg-cyan-400/10 text-text" : "border-border text-muted"}`}
            >
              {label}
            </button>
          ))}
        </div>

        <motion.form
          key={tab}
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          onSubmit={submit}
          className="glass mx-auto grid max-w-xl gap-4 rounded-[28px] p-8"
        >
          {tab === "bug" ? (
            <>
              <Field name="category" label="Category" select options={site.bugCategories || ["UI", "Script", "Loader", "Other"]} />
              <Field name="severity" label="Severity" select options={["low", "normal", "high", "critical"]} />
              <Field name="game" label="Game" />
              <div className="grid gap-4 sm:grid-cols-2">
                <Field name="username" label="Username" />
                <Field name="executor" label="Executor" />
              </div>
              <Field name="contact" label="Contact (optional)" />
              <Field name="description" label="Description" textarea required />
              <Field name="steps" label="Steps" textarea />
            </>
          ) : null}
          {tab === "feature" ? (
            <>
              <Field name="username" label="Username" />
              <Field name="game" label="Game (optional)" />
              <Field name="contact" label="Contact (optional)" />
              <Field name="idea" label="Your idea" textarea required />
            </>
          ) : null}
          {tab === "support" ? (
            <>
              <Field name="topic" label="Topic" select options={["Loading", "Games", "Executor", "Other"]} />
              <div className="grid gap-4 sm:grid-cols-2">
                <Field name="username" label="Username" />
                <Field name="contact" label="Contact (optional)" />
              </div>
              <Field name="question" label="Question" textarea required />
            </>
          ) : null}
          {error ? <p className="text-sm text-red-400">{error}</p> : null}
          {ok ? <p className="text-sm text-green-400">Sent — thanks!</p> : null}
          <button type="submit" className="rounded-full bg-gradient-to-br from-accent to-violet px-6 py-3 text-sm font-semibold text-[#030508]">
            Submit
          </button>
        </motion.form>
      </div>
    </section>
  );
}

function Field({
  name,
  label,
  textarea,
  required,
  select,
  options,
}: {
  name: string;
  label: string;
  textarea?: boolean;
  required?: boolean;
  select?: boolean;
  options?: string[];
}) {
  const className =
    "w-full rounded-xl border border-border bg-black/30 px-3.5 py-3 text-sm outline-none focus:border-cyan-400/40 focus:shadow-[0_0_0_3px_rgba(34,211,238,0.12)]";
  return (
    <label className="grid gap-2 text-sm text-muted">
      {label}
      {select ? (
        <select name={name} className={className} required={required}>
          {(options || []).map((o) => (
            <option key={o} value={o}>
              {o}
            </option>
          ))}
        </select>
      ) : textarea ? (
        <textarea name={name} className={`${className} min-h-[100px]`} required={required} />
      ) : (
        <input name={name} className={className} required={required} />
      )}
    </label>
  );
}

export function CreditsSection({ site }: { site: SitePayload }) {
  const credits = site.credits;
  if (!credits) return null;
  return (
    <section id="credits" className="section-wrap scroll-mt-24 py-24">
      <SectionHeader label="Credits" title={credits.headline || "Creator"} desc={credits.subheadline} />
      <div className="grid gap-6">
        {(credits.teams || []).map((team) => (
          <div key={team.id || team.title}>
            <h3 className="mb-4 text-lg font-semibold">{team.title}</h3>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {(team.members || []).map((member) => (
                <motion.article
                  key={member.id || member.displayName}
                  whileHover={{ y: -4 }}
                  className="glass rounded-[28px] p-6"
                  style={member.accent ? { boxShadow: `0 0 0 1px ${member.accent}33 inset` } : undefined}
                >
                  <strong className="block text-lg">{member.displayName}</strong>
                  <span className="text-sm text-accent">{member.role}</span>
                  {member.bio ? <p className="mt-3 text-sm text-muted">{member.bio}</p> : null}
                </motion.article>
              ))}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
