"use client";

import clsx from "clsx";
import type { ReactNode } from "react";
import { SmoothScroll } from "@/components/ui/SmoothScroll";

/** Main app scroll — uses OverlayScrollbars smooth scroll module. */
export function MainScroll({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <SmoothScroll id="main-scroll" className={clsx("min-h-0 flex-1", className)} flex>
      {children}
    </SmoothScroll>
  );
}

export function ScrollContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}
