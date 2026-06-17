"use client";

import { useState, useCallback, type FormEvent } from "react";
import { Send, CheckCircle, Copy, ArrowRight, AlertTriangle, Terminal, Loader2 } from "lucide-react";

const issueTypes = [
  "Loader Issue", "Script Failure", "Runtime Issue", "Game Update Breakage",
  "Access Problem", "Bug Report", "Feature Request", "Other",
] as const;

type TicketStatus = "idle" | "validating" | "sending" | "success" | "error";

export function SupportForm() {
  const [status, setStatus] = useState<TicketStatus>("idle");
  const [ticketId, setTicketId] = useState("");
  const [copied, setCopied] = useState(false);
  const [form, setForm] = useState({
    name: "", email: "", discord: "", roblox: "", issueType: "Bug Report",
    script: "", priority: "normal", message: "", attachment: "",
  });

  const update = (field: string, value: string) => setForm((f) => ({ ...f, [field]: value }));

  const submit = useCallback(async (e: FormEvent) => {
    e.preventDefault();
    setStatus("validating");

    if (!form.name.trim() || !form.email.trim() || !form.message.trim()) {
      setStatus("error");
      setTimeout(() => setStatus("idle"), 2000);
      return;
    }

    setStatus("sending");
    await new Promise((r) => setTimeout(r, 1500));

    const id = `ALLERAL-2026-${String(Math.floor(1000 + Math.random() * 9000))}`;
    setTicketId(id);
    setStatus("success");
  }, [form]);

  const copyTicket = () => {
    navigator.clipboard.writeText(ticketId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (status === "success") {
    return (
      <div className="glass-premium rounded-2xl p-8 text-center">
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-full bg-accent/10 mb-5">
          <CheckCircle className="h-8 w-8 text-accent" />
        </div>
        <h3 className="text-xl font-bold text-text mb-2">Ticket Generated</h3>
        <p className="text-muted text-sm mb-5">Your report has been queued for review.</p>
        <div className="glass-deep rounded-xl p-4 mb-5 inline-block">
          <code className="font-mono text-lg text-accent-bright">{ticketId}</code>
        </div>
        <div className="flex justify-center gap-3">
          <button className="btn btn-primary" onClick={copyTicket}>
            {copied ? "Copied!" : <><Copy className="h-4 w-4" /> Copy Ticket</>}
          </button>
          <button className="btn btn-ghost" onClick={() => { setStatus("idle"); setForm({ name: "", email: "", discord: "", roblox: "", issueType: "Bug Report", script: "", priority: "normal", message: "", attachment: "" }); }}>
            Submit Another
          </button>
        </div>
        <p className="mt-4 text-[10px] font-mono text-muted-2">Our team will respond via Discord within 24 hours.</p>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="glass-premium rounded-2xl p-6 md:p-8">
      <div className="flex items-center gap-3 mb-6">
        <Terminal className="h-5 w-5 text-accent" />
        <h3 className="text-lg font-semibold text-text">Support Command Center</h3>
      </div>

      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Name</label>
          <input value={form.name} onChange={(e) => update("name", e.target.value)} className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 placeholder:text-muted-3" placeholder="Your name" />
        </div>
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Email</label>
          <input value={form.email} onChange={(e) => update("email", e.target.value)} type="email" className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 placeholder:text-muted-3" placeholder="you@example.com" />
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Discord Username</label>
          <input value={form.discord} onChange={(e) => update("discord", e.target.value)} className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 placeholder:text-muted-3" placeholder="user#0000" />
        </div>
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Roblox Username</label>
          <input value={form.roblox} onChange={(e) => update("roblox", e.target.value)} className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 placeholder:text-muted-3" placeholder="roblox_user" />
        </div>
      </div>

      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Issue Type</label>
          <select value={form.issueType} onChange={(e) => update("issueType", e.target.value)} className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20">
            {issueTypes.map((t) => <option key={t}>{t}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Script / Game</label>
          <input value={form.script} onChange={(e) => update("script", e.target.value)} className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 placeholder:text-muted-3" placeholder="e.g. Kick A Lucky Block" />
        </div>
      </div>

      <div className="mb-4">
        <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Priority</label>
        <div className="flex gap-2">
          {["low", "normal", "high", "critical"].map((p) => (
            <button key={p} type="button" onClick={() => update("priority", p)}
              className={`px-3 py-1.5 rounded-lg text-xs font-mono capitalize transition ${
                form.priority === p ? "bg-accent/20 text-accent-bright border border-accent/30" : "bg-white/[0.03] text-muted-2 border border-white/10 hover:border-white/20"
              }`}
            >{p}</button>
          ))}
        </div>
      </div>

      <div className="mb-4">
        <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Message</label>
        <textarea value={form.message} onChange={(e) => update("message", e.target.value)} rows={4} className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 placeholder:text-muted-3 resize-none" placeholder="Describe the issue in detail..." />
      </div>

      <div className="mb-6">
        <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Attachment (optional)</label>
        <div className="rounded-lg border border-dashed border-white/10 bg-white/[0.015] px-4 py-6 text-center cursor-light">
          <p className="text-xs text-muted-2">Drop a file or click to attach</p>
          <p className="text-[10px] text-muted-3 mt-1">Logs, screenshots, etc.</p>
        </div>
      </div>

      {status === "error" && (
        <div className="mb-4 flex items-center gap-2 rounded-lg bg-red/10 border border-red/20 px-4 py-3">
          <AlertTriangle className="h-4 w-4 text-red shrink-0" />
          <p className="text-xs text-red/90">Please fill in all required fields (Name, Email, Message).</p>
        </div>
      )}

      <button type="submit" className="btn btn-primary w-full" disabled={status === "sending"}>
        {status === "sending" ? <><Loader2 className="h-4 w-4 animate-spin" /> Submitting...</> : <><Send className="h-4 w-4" /> Submit Ticket <ArrowRight className="h-4 w-4" /></>}
      </button>

      <p className="mt-4 text-[10px] font-mono text-muted-3 text-center">Responses are handled through our Discord support channel.</p>
    </form>
  );
}
