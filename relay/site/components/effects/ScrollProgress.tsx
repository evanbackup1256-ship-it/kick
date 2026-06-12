"use client";

import { useEffect, useRef } from "react";
import { useLenis } from "@/lib/lenis-context";

export function ScrollProgress() {
  const ref = useRef<HTMLDivElement>(null);
  const lenis = useLenis();

  useEffect(() => {
    const bar = ref.current;
    if (!bar || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const update = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      const scrollY = lenis?.scroll ?? window.scrollY;
      const p = max > 0 ? scrollY / max : 0;
      bar.style.transform = `scaleX(${Math.min(1, Math.max(0, p))})`;
    };

    if (lenis) {
      lenis.on("scroll", update);
      update();
      return () => lenis.off("scroll", update);
    }

    window.addEventListener("scroll", update, { passive: true });
    update();
    return () => window.removeEventListener("scroll", update);
  }, [lenis]);

  return (
    <div
      ref={ref}
      aria-hidden
      className="fixed top-0 left-0 right-0 z-[200] h-0.5 origin-left scale-x-0 bg-gradient-to-r from-accent via-violet to-accent shadow-[0_0_16px_rgba(34,211,238,0.55)]"
    />
  );
}
