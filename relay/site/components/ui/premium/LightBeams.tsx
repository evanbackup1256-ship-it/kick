"use client";

import clsx from "clsx";
import { useReducedMotion } from "@/lib/useReducedMotion";

/** Aceternity-style subtle vertical light beams */
export function LightBeams({ className }: { className?: string }) {
  const reduced = useReducedMotion();
  if (reduced) return null;

  const beams = [
    { left: "18%", delay: "0s", dur: "6s" },
    { left: "42%", delay: "-2s", dur: "7.5s" },
    { left: "68%", delay: "-4s", dur: "5.5s" },
    { left: "86%", delay: "-1s", dur: "8s" },
  ];

  return (
    <div aria-hidden className={clsx("pointer-events-none absolute inset-0 overflow-hidden", className)}>
      {beams.map((b) => (
        <div
          key={b.left}
          className="absolute top-[-10%] h-[120%] w-px bg-gradient-to-b from-transparent via-cyan-400/35 to-transparent opacity-0 animate-beam"
          style={{ left: b.left, animationDuration: b.dur, animationDelay: b.delay }}
        />
      ))}
    </div>
  );
}
