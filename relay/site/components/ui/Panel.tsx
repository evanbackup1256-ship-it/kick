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
      whileHover={hover ? { y: -3, boxShadow: "0 24px 60px rgba(0,0,0,0.45)" } : undefined}
      transition={spring.soft}
      className={clsx("glass-panel rounded-2xl", glow && "accent-glow", pad, className)}
    >
      {children}
    </motion.div>
  );
}

export function CardHeader({ title, desc, action }: { title: string; desc?: string; action?: React.ReactNode }) {
  return (
    <div className="mb-4 flex items-start justify-between gap-3">
      <div>
        <h3 className="text-sm font-semibold tracking-tight text-text">{title}</h3>
        {desc ? <p className="mt-1 text-xs text-muted">{desc}</p> : null}
      </div>
      {action}
    </div>
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
