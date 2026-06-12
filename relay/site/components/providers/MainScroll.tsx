"use client";

import clsx from "clsx";
import type { ReactNode } from "react";

/** Native main scroll — avoids Lenis fighting nested panel scrollers. */
export function MainScroll({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={clsx("min-h-0 flex-1 overflow-y-auto overscroll-y-contain", className)} id="main-scroll">
      {children}
    </div>
  );
}

export function ScrollContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}
