"use client";

import clsx from "clsx";
import { motion } from "motion/react";
import { spring } from "@/lib/motion/config";

export function Panel({
  children,
  className,
  glow = false,
  hover = false,
  padding = "md",
  style,
}: {
  children: React.ReactNode;
  className?: string;
  glow?: boolean;
  hover?: boolean;
  padding?: "none" | "sm" | "md" | "lg";
  style?: React.CSSProperties;
}) {
  const pad = { none: "", sm: "p-4", md: "p-5", lg: "p-6" }[padding];
  return (
    <motion.div
      style={style}
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={spring.soft}
      whileHover={hover ? { y: -2 } : undefined}
      className={clsx("glass-panel rounded-2xl transition-shadow duration-500", glow && "accent-glow", pad, className)}
    >
      {children}
    </motion.div>
  );
}

export function MetricTile({
  label,
  value,
  trend,
  accent,
}: {
  label: string;
  value: React.ReactNode;
  trend?: string;
  accent?: "green" | "cyan" | "violet" | "yellow" | "red";
}) {
  const colors = {
    green: "text-green-400",
    cyan: "text-cyan-300",
    violet: "text-violet-300",
    yellow: "text-yellow-300",
    red: "text-red-400",
  };
  return (
    <Panel padding="sm" className="min-w-0">
      <p className="text-[0.68rem] uppercase tracking-[0.08em] text-muted-2">{label}</p>
      <p className={clsx("mt-1 truncate text-xl font-semibold tracking-tight", accent && colors[accent])}>{value}</p>
      {trend ? <p className="mt-1 text-xs text-muted">{trend}</p> : null}
    </Panel>
  );
}
