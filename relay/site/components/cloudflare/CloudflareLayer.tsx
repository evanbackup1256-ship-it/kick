"use client";

import { Shield, Globe, Lock, Zap, Filter, Server, CheckCircle } from "lucide-react";
import { StatusDot } from "../effects/StatusDot";

const layers = [
  { icon: Globe, name: "Edge Protection" },
  { icon: Shield, name: "Web Application Firewall" },
  { icon: Zap, name: "DDoS Mitigation" },
  { icon: Lock, name: "Turnstile Verification" },
  { icon: Filter, name: "Bot Filtering" },
  { icon: Server, name: "Cache Layer" },
];

export function CloudflareLayer() {
  return (
    <section className="relative py-24 md:py-32">
      <div className="mx-auto max-w-7xl px-4 md:px-6">
        <div className="section-head">
          <div className="kicker"><Shield className="h-3 w-3" /> Cloudflare Access Layer</div>
          <h2 className="heading-lg mt-4">Every request runs through our security stack.</h2>
          <p>Edge protection, WAF, DDoS mitigation, and intelligent routing.</p>
        </div>

        <div className="mt-14 grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
          <div className="glass-premium rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-6">
              <Shield className="h-5 w-5 text-accent" />
              <h3 className="text-sm font-semibold text-text">Security Stack</h3>
            </div>
            <div className="space-y-2">
              {layers.map((l) => (
                <div key={l.name} className="flex items-center justify-between rounded-xl bg-white/[0.02] px-4 py-3">
                  <div className="flex items-center gap-3">
                    <l.icon className="h-4 w-4 text-accent" />
                    <span className="text-sm text-text">{l.name}</span>
                  </div>
                  <StatusDot status="working" />
                </div>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            <div className="glass-premium rounded-xl p-5">
              <div className="flex items-center gap-2 mb-4">
                <Globe className="h-4 w-4 text-cyan" />
                <h3 className="text-sm font-semibold text-text">Request Flow</h3>
              </div>
              <div className="space-y-3">
                {["Client", "Edge", "WAF", "Origin"].map((step, i, arr) => (
                  <div key={step} className="flex items-center gap-2 rounded-lg bg-white/[0.02] px-3 py-2 text-xs font-mono text-muted">
                    <CheckCircle className="h-3 w-3 text-accent shrink-0" />
                    <span>{step}</span>
                    {i < arr.length - 1 && <span className="text-muted-2 ml-auto">&rarr;</span>}
                  </div>
                ))}
              </div>
            </div>

            <div className="glass-premium rounded-xl p-5">
              <h3 className="text-sm font-semibold text-text mb-3">Threat Summary</h3>
              <div className="grid grid-cols-2 gap-3">
                {[
                  { label: "Blocked", value: "0" },
                  { label: "Challenged", value: "12" },
                  { label: "Rate Limited", value: "3" },
                  { label: "Cached", value: "87%" },
                ].map((s) => (
                  <div key={s.label} className="rounded-lg bg-white/[0.02] p-3 text-center">
                    <p className="text-lg font-bold text-text">{s.value}</p>
                    <p className="text-[10px] font-mono text-muted-2">{s.label}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
