"use client";

import type LocomotiveScroll from "locomotive-scroll";
import { createContext, useContext, useEffect } from "react";

export const ScrollContext = createContext<LocomotiveScroll | null>(null);

export function useScroll() {
  return useContext(ScrollContext);
}

/** Lenis instance exposed by Locomotive Scroll (scroll progress, programmatic scroll). */
export function useLenis() {
  return useContext(ScrollContext)?.lenisInstance ?? null;
}

/** Trigger Locomotive resize after layout-affecting changes (e.g. Mission Control mount). */
export function useScrollResize(deps: readonly unknown[] = []) {
  const scroll = useScroll();

  useEffect(() => {
    if (!scroll) return;
    const raf = requestAnimationFrame(() => scroll.resize());
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- caller supplies layout triggers
  }, [scroll, ...deps]);
}
