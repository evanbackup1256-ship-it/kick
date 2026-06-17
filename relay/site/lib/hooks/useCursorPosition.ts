"use client";

import { useEffect, useRef } from "react";

export function useCursorPosition() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const target = ref.current ?? document.documentElement;
    const onMove = (e: MouseEvent) => {
      target.style.setProperty("--cursor-x", `${e.clientX}px`);
      target.style.setProperty("--cursor-y", `${e.clientY}px`);
    };
    window.addEventListener("mousemove", onMove, { passive: true });
    return () => window.removeEventListener("mousemove", onMove);
  }, []);

  return ref;
}
