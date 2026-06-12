"use client";

import clsx from "clsx";
import { motion } from "motion/react";
import { formatFreshness } from "@/lib/status/resolve";
import { spring } from "@/lib/motion/config";

export function FreshnessChip({
  secondsAgo,
  live = false,
  className,
}: {
  secondsAgo: number | null;
  live?: boolean;
  className?: string;
}) {
  const fresh = secondsAgo != null && secondsAgo < 20;
  return (
    <motion.span
      transition={spring.status}
      className={clsx(
        "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-mono text-[10px]",
        fresh ? "border-cyan-400/30 text-cyan-200" : "border-border text-muted",
        className
      )}
      style={{
        background: fresh ? "rgba(34,211,238,0.08)" : "rgba(255,255,255,0.03)",
        boxShadow: fresh ? "0 0 16px rgba(34,211,238,0.15)" : undefined,
      }}
    >
      {live && fresh ? (
        <motion.span
          className="h-1.5 w-1.5 rounded-full bg-cyan-400"
          animate={{ opacity: [1, 0.4, 1] }}
          transition={{ duration: 1.5, repeat: Infinity }}
        />
      ) : null}
      {formatFreshness(secondsAgo)}
    </motion.span>
  );
}
