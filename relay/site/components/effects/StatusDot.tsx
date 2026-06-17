"use client";

import clsx from "clsx";

interface StatusDotProps {
  status?: string;
  className?: string;
}

export function StatusDot({ status = "working", className }: StatusDotProps) {
  const n = status.toLowerCase();
  const kind =
    n.includes("work") || n.includes("online") || n.includes("stable")
      ? "status-dot-working"
      : n.includes("partial") || n.includes("testing")
        ? "status-dot-stable"
        : "status-dot-broken";

  return <span className={clsx("status-dot", kind, className)} />;
}
