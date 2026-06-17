"use client";

import { type ReactNode } from "react";
import clsx from "clsx";

interface AnimatedGradientProps {
  children: ReactNode;
  className?: string;
  accent?: boolean;
  fast?: boolean;
}

export function AnimatedGradient({
  children,
  className = "",
  accent = false,
  fast = false,
}: AnimatedGradientProps) {
  return (
    <div
      className={clsx(
        accent ? "gradient-animate-accent" : "gradient-animate",
        fast && "gradient-animate-fast",
        className
      )}
    >
      {children}
    </div>
  );
}
