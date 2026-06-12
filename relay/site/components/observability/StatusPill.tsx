"use client";

import clsx from "clsx";
import { motion } from "motion/react";
import { status, type StatusKind } from "@/lib/design/tokens";
import { spring } from "@/lib/motion/config";

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
  const meta = status[kind];
  const text = label ?? meta.label;

  return (
    <motion.span
      transition={spring.status}
      className={clsx(
        "inline-flex items-center gap-2 rounded-full border font-medium",
        size === "sm" ? "px-2 py-0.5 text-[10px]" : "px-2.5 py-1 text-[11px]",
        className
      )}
      style={{
        borderColor: `${meta.color}44`,
        background: `linear-gradient(135deg, ${meta.color}18, ${meta.color}08)`,
        boxShadow: `0 0 20px ${meta.glow}, inset 0 1px 0 rgba(255,255,255,0.06)`,
        color: meta.color,
      }}
    >
      <span className="relative flex h-2 w-2">
        {pulse ? (
          <motion.span
            className="absolute inset-0 rounded-full"
            style={{ background: meta.color }}
            animate={{ scale: [1, 1.8, 1], opacity: [0.9, 0.2, 0.9] }}
            transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
          />
        ) : null}
        <span className="relative h-2 w-2 rounded-full" style={{ background: meta.color, boxShadow: `0 0 8px ${meta.glow}` }} />
      </span>
      {text}
    </motion.span>
  );
}
