"use client";

import { useEffect, useState } from "react";

function findMainViewport(): HTMLElement | null {
  const root = document.getElementById("main-scroll");
  if (!root) return null;
  return root.querySelector(".os-viewport") as HTMLElement | null;
}

export function ScrollProgress() {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    let viewport = findMainViewport();
    let pollId = 0;

    const attach = (el: HTMLElement) => {
      const onScroll = () => {
        const max = el.scrollHeight - el.clientHeight;
        setProgress(max > 0 ? el.scrollTop / max : 0);
      };
      onScroll();
      el.addEventListener("scroll", onScroll, { passive: true });
      return () => el.removeEventListener("scroll", onScroll);
    };

    if (viewport) return attach(viewport);

    pollId = window.setInterval(() => {
      viewport = findMainViewport();
      if (viewport) {
        window.clearInterval(pollId);
        attach(viewport);
      }
    }, 120);

    return () => window.clearInterval(pollId);
  }, []);

  return (
    <div
      className="scroll-progress pointer-events-none fixed inset-x-0 top-0 z-[100] h-0.5 origin-left"
      style={{ transform: `scaleX(${progress})` }}
      aria-hidden
    />
  );
}
