"use client";

import clsx from "clsx";
import type { ReactNode } from "react";

export function Reveal({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={clsx("view-enter", className)}>{children}</div>;
}

export function Stagger({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}

export function StaggerItem({ children, className, index = 0 }: { children: ReactNode; className?: string; index?: number }) {
  const delay = Math.min(index + 1, 6);
  return <div className={clsx("view-enter", `stagger-${delay}`, className)}>{children}</div>;
}

export function PageTransition({ children }: { children: ReactNode }) {
  return <div className="view-enter fade-rise">{children}</div>;
}

function InViewReveal({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={clsx("view-enter fade-rise", className)}>{children}</div>;
}
