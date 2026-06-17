"use client";

import { Globe, Server, Activity, Shield } from "lucide-react";
import { StatusDot } from "./StatusDot";
import { TelemetryCharts } from "./TelemetryCharts";

export function GlobalTopology() {
  return (
    <section className="relative py-24 md:py-32">
      <div className="mx-auto max-w-7xl px-4 md:px-6">
        <div className="section-head">
          <div className="kicker"><Globe className="h-3 w-3" /> Global Runtime Topology</div>
          <h2 className="heading-lg mt-4">Live infrastructure across every region.</h2>
          <p>Telemetry, node health, and runtime status from the relay network.</p>
        </div>

        <div className="mt-14 grid gap-6 lg:grid-cols-[1fr_1.2fr]">
          <div className="glass-premium rounded-xl p-5">
            <div className="flex items-center gap-2 mb-5">
              <Server className="h-4 w-4 text-accent" />
              <h3 className="text-sm font-semibold text-text">Regional Nodes</h3>
            </div>
            <div className="space-y-3">
              {[
                { name: "us-east-1", status: "working", latency: "12ms", nodes: 4 },
                { name: "eu-west-1", status: "working", latency: "24ms", nodes: 3 },
                { name: "ap-southeast-1", status: "stable", latency: "45ms", nodes: 2 },
                { name: "us-west-2", status: "stable", latency: "18ms", nodes: 3 },
              ].map((r) => (
                <div key={r.name} className="flex items-center justify-between rounded-lg bg-white/[0.02] px-3 py-2.5 cursor-light">
                  <div className="flex items-center gap-3">
                    <StatusDot status={r.status} />
                    <span className="text-sm font-mono text-text">{r.name}</span>
                  </div>
                  <div className="flex items-center gap-4 text-xs font-mono text-muted-2">
                    <span>{r.latency}</span>
                    <span>{r.nodes} nodes</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            <div className="glass-premium rounded-xl p-5">
              <div className="flex items-center gap-2 mb-4">
                <Activity className="h-4 w-4 text-violet" />
                <h3 className="text-sm font-semibold text-text">Live Telemetry</h3>
              </div>
              <TelemetryCharts />
            </div>

            <div className="glass-premium rounded-xl p-5">
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-2">
                  <Shield className="h-4 w-4 text-accent" />
                  <h3 className="text-sm font-semibold text-text">Infrastructure Health</h3>
                </div>
                <span className="text-[10px] font-mono text-muted-2 flex items-center gap-1">
                  <StatusDot status="working" /> All nominal
                </span>
              </div>
              <div className="grid grid-cols-3 gap-3">
                {["Relay", "Sync", "Runtime"].map((s) => (
                  <div key={s} className="rounded-lg bg-white/[0.02] p-3 text-center cursor-light">
                    <StatusDot status="working" className="mx-auto" />
                    <p className="mt-2 text-xs font-mono text-muted">{s}</p>
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
