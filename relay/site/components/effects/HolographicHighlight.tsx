"use client";

import { type ReactNode } from "react";
import clsx from "clsx";

interface HolographicHighlightProps {
  children: ReactNode;
  className?: string;
  shimmer?: boolean;
  border?: boolean;
}

export function HolographicHighlight({
  children,
  className = "",
  shimmer = false,
  border = false,
}: HolographicHighlightProps) {
  return (
    <div
      className={clsx(
        shimmer && "holo-shimmer",
        border && "holo-border",
        className
      )}
    >
      {children}
    </div>
  );
}
