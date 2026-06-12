"use client";

import clsx from "clsx";
import CountUp from "react-countup";
import { motion } from "motion/react";
import { spring } from "@/lib/motion/config";
import type { LucideIcon } from "lucide-react";

export function MetricCard({
  label,
  value,
  numeric,
  suffix,
  icon: Icon,
  accent = "cyan",
  sparkline,
  trend,
  className,
}: {
  label: string;
  value?: React.ReactNode;
  numeric?: number;
  suffix?: string;
  icon?: LucideIcon;
  accent?: "cyan" | "green" | "violet" | "yellow";
  sparkline?: number[];
  trend?: string;
  className?: string;
}) {
  const accents = {
    cyan: "from-cyan-400/20 to-transparent text-cyan-300",
    green: "from-green-400/20 to-transparent text-green-300",
    violet: "from-violet-400/20 to-transparent text-violet-300",
    yellow: "from-yellow-400/20 to-transparent text-yellow-300",
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={spring.soft}
      whileHover={{ y: -2 }}
      className={clsx("obs-metric relative overflow-hidden", className)}
    >
      <div className={clsx("pointer-events-none absolute inset-0 bg-gradient-to-br opacity-80", accents[accent])} />
      <div className="relative z-[1]">
        <div className="flex items-start justify-between gap-2">
          <p className="obs-kicker">{label}</p>
          {Icon ? <Icon className="h-4 w-4 text-muted-2" strokeWidth={1.75} /> : null}
        </div>
        <p className="mt-2 font-mono text-2xl font-semibold tracking-tight text-text">
          {numeric != null ? (
            <CountUp end={numeric} duration={1.2} separator="," preserveValue suffix={suffix} />
          ) : (
            value
          )}
        </p>
        {trend ? <p className="mt-1 text-[11px] text-muted">{trend}</p> : null}
        {sparkline?.length ? (
          <svg viewBox="0 0 120 28" className="mt-3 h-7 w-full opacity-70" preserveAspectRatio="none">
            <polyline
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              className={accents[accent].split(" ").pop()}
              points={sparkline
                .map((v, i) => {
                  const max = Math.max(...sparkline, 1);
                  const x = (i / Math.max(sparkline.length - 1, 1)) * 120;
                  const y = 26 - (v / max) * 24;
                  return `${x},${y}`;
                })
                .join(" ")}
            />
          </svg>
        ) : null}
      </div>
    </motion.div>
  );
}
