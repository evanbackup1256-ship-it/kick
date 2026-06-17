"use client";

import { Globe, Lock, Layers, Zap, CheckCircle, ArrowRight } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { StatusDot } from "./StatusDot";

const steps = [
  { icon: Globe, title: "Fetch", desc: "Loader requests the release manifest from the global relay.", color: "#00f0c8" },
  { icon: Lock, title: "Verify", desc: "Versions, commit hashes, and runtime integrity are validated.", color: "#00d4ff" },
  { icon: Layers, title: "Compose", desc: "Iris runtime, Onyx resources, and the capability stack are assembled.", color: "#7c3aed" },
  { icon: Zap, title: "Launch", desc: "Access, security, and telemetry modules resolve before injection.", color: "#00f0c8" },
];

export function PipelineVisualizer() {
  return (
    <div className="relative">
      {steps.map((step, i) => (
        <div key={step.title} className="relative pl-12 pb-10 last:pb-0">
          <div className="absolute left-[11px] top-0 bottom-0 w-[2px] bg-gradient-to-b from-accent/40 via-cyan/30 to-violet/20 last:hidden" style={i === steps.length - 1 ? { display: "none" } : {}} />
          <div className="absolute left-0 top-1 w-[24px] h-[24px] rounded-full border-2 flex items-center justify-center" style={{ borderColor: step.color, background: "rgba(3,5,10,0.9)" }}>
            <step.icon className="h-3 w-3" style={{ color: step.color }} />
          </div>
          <div className="glass-deep rounded-xl p-4 cursor-light">
            <div className="flex items-center gap-2 mb-2">
              <h3 className="text-sm font-semibold text-text">{step.title}</h3>
              <StatusDot status="working" />
            </div>
            <p className="text-sm text-muted leading-relaxed">{step.desc}</p>
            <div className="mt-3 flex items-center gap-2 text-[10px] font-mono text-muted-2">
              <CheckCircle className="h-3 w-3 text-accent" />
              <span>Runtime verified</span>
              <ArrowRight className="h-3 w-3 mx-1" />
              <span className="text-accent-bright">Ready</span>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
