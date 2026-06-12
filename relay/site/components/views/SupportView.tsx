"use client";

import { motion } from "motion/react";
import { useEffect, useMemo, useState } from "react";
import { API_BASE } from "@/lib/config";
import type { SitePayload } from "@/lib/types";
import { spring } from "@/lib/motion/config";
import { Button } from "@/components/ui/Button";
import { Input, Select, Textarea } from "@/components/ui/Form";
import { Panel } from "@/components/ui/Panel";
import { FormTurnstile } from "@/components/turnstile/FormTurnstile";

export function SupportView({ site }: { site: SitePayload }) {
  const [tab, setTab] = useState<"bug" | "feature" | "support">("bug");
  const [error, setError] = useState("");
  const [ok, setOk] = useState(false);
  const [turnstileToken, setTurnstileToken] = useState("");
  const [captchaRequired, setCaptchaRequired] = useState(false);

  useEffect(() => {
    fetch(`${API_BASE}/api/gate/config`, { cache: "no-store" })
      .then((res) => res.json())
      .then((data) => setCaptchaRequired(Boolean(data.serverVerify && data.siteKey)))
      .catch(() => setCaptchaRequired(false));
  }, []);

  const gameOptions = useMemo(
    () => [
      { value: "", label: "Select a game" },
      ...Object.values(site.games || {}).map((g) => ({ value: g.name || g.id || "", label: g.name || g.id || "Unknown" })),
    ],
    [site.games]
  );

  const submit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setError("");
    setOk(false);
    if (captchaRequired && !turnstileToken) {
      setError("Complete the captcha first.");
      return;
    }
    const form = new FormData(e.currentTarget);
    const path = tab === "bug" ? "/api/bug-report" : tab === "feature" ? "/api/feature-request" : "/api/support";
    const payload: Record<string, string> = Object.fromEntries([...form.entries()].map(([k, v]) => [k, String(v)]));
    payload.pageUrl = `${location.pathname}${location.hash}`;
    payload.userAgent = navigator.userAgent;
    if (tab !== "support") payload.robloxUser = payload.username || "";
    if (turnstileToken) payload.turnstileToken = turnstileToken;
    try {
      const res = await fetch(`${API_BASE}${path}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
      const data = await res.json();
      if (!res.ok || data.ok === false) throw new Error(data.error || "Submit failed");
      setOk(true);
      setTurnstileToken("");
      e.currentTarget.reset();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Submit failed");
    }
  };

  return (
    <div className="mx-auto max-w-xl space-y-4">
      <div className="flex flex-wrap gap-2">
        {(
          [
            ["bug", "Bug Report"],
            ["feature", "Feature"],
            ["support", "Question"],
          ] as const
        ).map(([id, label]) => (
          <Button key={id} size="sm" variant={tab === id ? "primary" : "ghost"} onClick={() => { setTab(id); setError(""); setOk(false); }}>
            {label}
          </Button>
        ))}
      </div>

      <Panel padding="lg">
        <motion.form key={tab} onSubmit={submit} className="grid gap-4" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={spring.soft}>
          {tab === "bug" ? (
            <>
              <Field label="Category"><Select name="category" options={site.bugCategories || ["UI", "Script", "Loader", "Other"]} required /></Field>
              <Field label="Severity"><Select name="severity" options={["low", "normal", "high", "critical"]} defaultValue="normal" required /></Field>
              <Field label="Game"><Select name="game" options={gameOptions} /></Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Username"><Input name="username" required /></Field>
                <Field label="Executor"><Input name="executor" /></Field>
              </div>
              <Field label="Contact (optional)"><Input name="contact" /></Field>
              <Field label="Description"><Textarea name="description" required /></Field>
              <Field label="Steps"><Textarea name="steps" /></Field>
            </>
          ) : null}
          {tab === "feature" ? (
            <>
              <Field label="Username"><Input name="username" /></Field>
              <Field label="Game (optional)"><Input name="game" /></Field>
              <Field label="Contact (optional)"><Input name="contact" /></Field>
              <Field label="Your idea"><Textarea name="idea" required /></Field>
            </>
          ) : null}
          {tab === "support" ? (
            <>
              <Field label="Topic"><Select name="topic" options={["Loading", "Games", "Executor", "Other"]} defaultValue="Loading" required /></Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Username"><Input name="username" required /></Field>
                <Field label="Contact (optional)"><Input name="contact" /></Field>
              </div>
              <Field label="Question"><Textarea name="question" required /></Field>
            </>
          ) : null}
          {error ? <p className="text-sm text-red-400">{error}</p> : null}
          {ok ? <p className="text-sm text-green-400">Sent — thanks!</p> : null}
          {captchaRequired ? <FormTurnstile formId={tab} onToken={setTurnstileToken} /> : null}
          <Button type="submit" variant="primary" magnetic>
            Submit
          </Button>
        </motion.form>
      </Panel>
    </div>
  );
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="grid gap-2 text-sm text-muted">
      {label}
      {children}
    </label>
  );
}
