"use client";

import { useState, type FormEvent } from "react";
import { Send, CheckCircle, Copy, ArrowRight, AlertTriangle, Loader2 } from "lucide-react";

export function SupportForm() {
  const [sending, setSending] = useState(false);
  const [done, setDone] = useState(false);
  const [ticketId, setTicketId] = useState("");
  const [copied, setCopied] = useState(false);
  const [err, setErr] = useState("");
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [discord, setDiscord] = useState("");
  const [roblox, setRoblox] = useState("");
  const [issueType, setIssueType] = useState("Bug Report");
  const [message, setMessage] = useState("");

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setErr("");

    if (!name.trim() || !email.trim() || !message.trim()) {
      setErr("Name, email, and message are required.");
      return;
    }

    setSending(true);
    await new Promise((r) => setTimeout(r, 1200));

    const id = `ALLERAL-2026-${String(Math.floor(1000 + Math.random() * 9000))}`;
    setTicketId(id);
    setSending(false);
    setDone(true);
  };

  const copyId = () => {
    navigator.clipboard.writeText(ticketId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  if (done) {
    return (
      <div className="glass-premium rounded-2xl p-8 text-center">
        <div className="w-16 h-16 rounded-full bg-accent/10 flex items-center justify-center mx-auto mb-5">
          <CheckCircle className="h-8 w-8 text-accent" />
        </div>
        <h3 className="text-xl font-bold text-text mb-2">Ticket created</h3>
        <p className="text-muted text-sm mb-5">We&apos;ll get back to you on Discord.</p>
        <div className="glass-premium rounded-xl p-4 inline-block mb-5">
          <code className="font-mono text-lg text-accent-bright">{ticketId}</code>
        </div>
        <div className="flex justify-center gap-3">
          <button className="btn btn-primary" onClick={copyId}>
            {copied ? "Copied" : <><Copy className="h-4 w-4" /> Copy ID</>}
          </button>
          <button className="btn btn-ghost" onClick={() => { setDone(false); setName(""); setEmail(""); setDiscord(""); setRoblox(""); setIssueType("Bug Report"); setMessage(""); }}>
            New ticket
          </button>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={submit} className="glass-premium rounded-2xl p-6 md:p-8">
      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Name</label>
          <input value={name} onChange={(e) => setName(e.target.value)}
            className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20" />
        </div>
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Email</label>
          <input value={email} onChange={(e) => setEmail(e.target.value)} type="email"
            className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20" />
        </div>
      </div>
      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Discord</label>
          <input value={discord} onChange={(e) => setDiscord(e.target.value)}
            className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20" />
        </div>
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Roblox Username</label>
          <input value={roblox} onChange={(e) => setRoblox(e.target.value)}
            className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20" />
        </div>
      </div>
      <div className="grid gap-4 md:grid-cols-2 mb-4">
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Issue Type</label>
          <select value={issueType} onChange={(e) => setIssueType(e.target.value)}
            className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20">
            {["Loader Issue", "Script Failure", "Runtime Issue", "Game Update Breakage", "Access Problem", "Bug Report", "Feature Request", "Other"].map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Game / Script</label>
          <input className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20" />
        </div>
      </div>
      <div className="mb-4">
        <label className="block text-xs font-mono text-muted-2 uppercase tracking-wider mb-1.5">Message</label>
        <textarea value={message} onChange={(e) => setMessage(e.target.value)} rows={4}
          className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20 resize-none" />
      </div>

      {err && (
        <div className="mb-4 flex items-center gap-2 rounded-lg bg-red/10 border border-red/20 px-4 py-3">
          <AlertTriangle className="h-4 w-4 text-red shrink-0" />
          <p className="text-xs text-red/90">{err}</p>
        </div>
      )}

      <button type="submit" className="btn btn-primary w-full" disabled={sending}>
        {sending ? <><Loader2 className="h-4 w-4 animate-spin" /> Sending...</> : <><Send className="h-4 w-4" /> Submit <ArrowRight className="h-4 w-4" /></>}
      </button>
    </form>
  );
}
