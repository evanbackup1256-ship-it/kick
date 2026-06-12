"use client";

import clsx from "clsx";
import { useReducedMotion } from "@/lib/useReducedMotion";

type MovingBorderProps = {
  children: React.ReactNode;
  className?: string;
  containerClassName?: string;
  rounded?: string;
  duration?: number;
};

export function MovingBorder({
  children,
  className,
  containerClassName,
  rounded = "rounded-full",
  duration = 5,
}: MovingBorderProps) {
  const reduced = useReducedMotion();

  if (reduced) {
    return <div className={clsx("border border-cyan-400/30", rounded, className)}>{children}</div>;
  }

  return (
    <div className={clsx("relative p-px", rounded, containerClassName)}>
      <div
        className={clsx("absolute inset-0 overflow-hidden", rounded)}
        style={{ animation: `spin-border ${duration}s linear infinite` }}
      >
        <div className="absolute inset-[-200%] bg-[conic-gradient(from_0deg,transparent_0_300deg,rgba(34,211,238,0.9)_330deg,rgba(167,139,250,0.8)_360deg)] opacity-70" />
      </div>
      <div className={clsx("relative bg-transparent", rounded, className)}>{children}</div>
    </div>
  );
}
