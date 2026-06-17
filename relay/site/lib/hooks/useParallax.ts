"use client";

import { useEffect, useRef } from "react";

export function useParallax(depth = 0.03) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const onMove = (e: MouseEvent) => {
      const rx = (e.clientX / window.innerWidth - 0.5) * 2;
      const ry = (e.clientY / window.innerHeight - 0.5) * 2;
      el.style.setProperty("--parallax-x", `${50 + rx * 20}%`);
      el.style.setProperty("--parallax-y", `${50 + ry * 20}%`);
      el.style.transform = `translate(${rx * depth * 100}px, ${ry * depth * 100}px)`;
    };

    window.addEventListener("mousemove", onMove, { passive: true });
    return () => window.removeEventListener("mousemove", onMove);
  }, [depth]);

  return ref;
}
