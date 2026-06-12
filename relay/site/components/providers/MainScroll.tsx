"use client";

import clsx from "clsx";
import type { ReactNode } from "react";
import { LenisProvider } from "@/components/providers/LenisProvider";

/** Primary scroll region — Lenis smooth scroll + GSAP ScrollTrigger scroller. */
export function MainScroll({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <LenisProvider id="main-scroll" className={clsx("flex min-h-0 flex-1 flex-col", className)}>
      {children}
    </LenisProvider>
  );
}

export function ScrollContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={clsx("flex min-h-0 flex-1 flex-col", className)}>{children}</div>;
}
