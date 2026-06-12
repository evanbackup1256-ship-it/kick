"use client";

import clsx from "clsx";
import { formatFreshness } from "@/lib/status/resolve";
import { useSecondsSince } from "@/lib/hooks/useSecondsSince";

export function FreshnessChip({
  dataUpdatedAt,
  secondsAgo: secondsAgoProp,
  live = false,
  className,
}: {
  dataUpdatedAt?: number | null;
  secondsAgo?: number | null;
  live?: boolean;
  className?: string;
}) {
  const tickSeconds = useSecondsSince(dataUpdatedAt ?? null, 5000);
  const secondsAgo = secondsAgoProp ?? tickSeconds;
  const fresh = secondsAgo != null && secondsAgo < 30;

  return (
    <span
      className={clsx(
        "inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-mono text-[10px] tabular-nums transition-colors duration-700",
        fresh ? "border-cyan-400/25 text-cyan-200/90" : "border-border text-muted",
        className
      )}
      style={{
        background: fresh ? "rgba(34,211,238,0.06)" : "rgba(255,255,255,0.03)",
      }}
    >
      {live && fresh ? <span className="h-1.5 w-1.5 rounded-full bg-cyan-400/80" aria-hidden /> : null}
      {formatFreshness(secondsAgo)}
    </span>
  );
}
