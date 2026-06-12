"use client";

import clsx from "clsx";
import { motion, useReducedMotion } from "motion/react";
import { status, type StatusKind } from "@/lib/design/tokens";

export function StatusPill({
  kind,
  label,
  pulse = false,
  size = "md",
  className,
}: {
  kind: StatusKind;
  label?: string;
  pulse?: boolean;
  size?: "sm" | "md";
  className?: string;
}) {
  const reduce = useReducedMotion();
  const meta = status[kind];
  const text = label ?? meta.label;
  const showPulse = !reduce && pulse && kind === "syncing";

  return (
    <span
      className={clsx(
        "inline-flex items-center gap-2 rounded-full border font-medium transition-colors duration-500",
        size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-1 text-[11px]",
        className
      )}
      style={{
        borderColor: `${meta.color}33`,
        background: `linear-gradient(135deg, ${meta.color}14, ${meta.color}06)`,
        boxShadow: `inset 0 1px 0 rgba(255,255,255,0.05)`,
        color: meta.color,
      }}
    >
      <span className="relative flex h-2 w-2 shrink-0">
        {showPulse ? (
          <motion.span
            className="absolute inset-0 rounded-full"
            style={{ background: meta.color }}
            animate={{ opacity: [0.55, 0.2, 0.55] }}
            transition={{ duration: 3.5, repeat: Infinity, ease: "easeInOut" }}
          />
        ) : null}
        <span className="relative h-2 w-2 rounded-full" style={{ background: meta.color, boxShadow: `0 0 6px ${meta.glow}` }} />
      </span>
      {text}
    </span>
  );
}
