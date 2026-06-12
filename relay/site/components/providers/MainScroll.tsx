"use client";

import clsx from "clsx";
import { useEffect, type ReactNode } from "react";
import { LenisProvider } from "@/components/providers/LenisProvider";
import { useScroll } from "@/lib/scroll/lenis-context";
import { usePlatformStore } from "@/lib/store/platform";

/** Re-measure scroll when platform view or workspace layout changes. */
function ScrollViewSync() {
  const scroll = useScroll();
  const activeView = usePlatformStore((s) => s.activeView);
  const workspace = usePlatformStore((s) => s.workspace);

  useEffect(() => {
    if (!scroll) return;
    const raf = requestAnimationFrame(() => scroll.resize());
    return () => cancelAnimationFrame(raf);
  }, [scroll, activeView, workspace]);

  return null;
}

/** Primary scroll region — Locomotive Scroll smooth scroll. */
export function MainScroll({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <LenisProvider id="main-scroll" className={clsx("flex min-h-0 flex-1 flex-col", className)}>
      <ScrollViewSync />
      {children}
    </LenisProvider>
  );
}

export function ScrollContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={clsx("flex w-full flex-col", className)}>{children}</div>;
}
