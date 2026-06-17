"use client";

import { Shield, Globe, Lock, Zap, Eye, Filter, Server, ArrowRight, CheckCircle } from "lucide-react";
import { StatusDot } from "../effects/StatusDot";

const securityLayers = [
  { icon: Globe, name: "Edge Protection", status: "active", requests: "12.4k/min" },
  { icon: Shield, name: "WAF", status: "active", requests: "8.2k/min" },
  { icon: Zap, name: "DDoS Protection", status: "active", requests: "0/min" },
  { icon: Lock, name: "Turnstile Verification", status: "active", requests: "340/min" },
  { icon: Filter, name: "Bot Filtering", status: "active", requests: "2.1k/min" },
  { icon: Eye, name: "Request Inspection", status: "active", requests: "100%" },
  { icon: Server, name: "Cache Layer", status: "active", hitRate: "87%" },
];

export function CloudflareLayer() {
  return (
    <section className="relative py-24 md:py-32">
      <div className="mx-auto max-w-7xl px-4 md:px-6">
        <div className="section-head">
          <div className="kicker"><Shield className="h-3 w-3" /> Cloudflare Access Layer</div>
          <h2 className="heading-lg mt-4">Security infrastructure that protects every request.</h2>
          <p>Edge protection, WAF, DDoS mitigation, and intelligent routing across the global network.</p>
        </div>

        <div className="mt-14 grid gap-6 lg:grid-cols-[1.2fr_0.8fr]">
          <div className="glass-premium rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-6">
              <Shield className="h-5 w-5 text-accent" />
              <h3 className="text-sm font-semibold text-text">Security Stack</h3>
            </div>
            <div className="space-y-2">
              {securityLayers.map((layer) => (
                <div key={layer.name} className="flex items-center justify-between rounded-xl bg-white/[0.02] px-4 py-3 cursor-light">
                  <div className="flex items-center gap-3">
                    <layer.icon className="h-4 w-4 text-accent" />
                    <span className="text-sm text-text">{layer.name}</span>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className="text-xs font-mono text-muted-2">{layer.requests || layer.hitRate}</span>
                    <StatusDot status="working" />
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            <div className="glass-deep rounded-xl p-5">
              <div className="flex items-center gap-2 mb-4">
                <Globe className="h-4 w-4 text-cyan" />
                <h3 className="text-sm font-semibold text-text">Request Flow</h3>
              </div>
              <div className="space-y-3">
                {["Client → Edge", "Edge → WAF", "WAF → Origin"].map((flow, i) => (
                  <div key={flow} className="flex items-center gap-2 rounded-lg bg-white/[0.02] px-3 py-2 text-xs font-mono text-muted cursor-light">
                    <CheckCircle className="h-3 w-3 text-accent" />
                    <span>{flow}</span>
                    {i < 2 && <ArrowRight className="h-3 w-3 text-muted-2 ml-auto" />}
                  </div>
                ))}
              </div>
            </div>

            <div className="glass-deep rounded-xl p-5">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-sm font-semibold text-text">Threat Summary</h3>
                <span className="text-[10px] font-mono text-accent">All clear</span>
              </div>
              <div className="grid grid-cols-2 gap-3">
                {[
                  { label: "Blocked", value: "0", color: "text-accent" },
                  { label: "Challenged", value: "12", color: "text-cyan" },
                  { label: "Rate Limited", value: "3", color: "text-violet" },
                  { label: "Cached", value: "87%", color: "text-accent-bright" },
                ].map((s) => (
                  <div key={s.label} className="rounded-lg bg-white/[0.02] p-3 text-center">
                    <p className={`text-lg font-bold ${s.color}`}>{s.value}</p>
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
