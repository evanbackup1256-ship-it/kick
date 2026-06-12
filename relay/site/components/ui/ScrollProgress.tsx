"use client";

import { useEffect, useState } from "react";
import { useLenis } from "@/lib/scroll/lenis-context";

function findScrollRoot(): HTMLElement | null {
  return document.querySelector("[data-lenis-root]") as HTMLElement | null;
}

export function ScrollProgress() {
  const lenis = useLenis();
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    let detach: (() => void) | undefined;
    let pollId = 0;

    const attachNative = (el: HTMLElement) => {
      const onScroll = () => {
        const max = el.scrollHeight - el.clientHeight;
        setProgress(max > 0 ? el.scrollTop / max : 0);
      };
      onScroll();
      el.addEventListener("scroll", onScroll, { passive: true });
      return () => el.removeEventListener("scroll", onScroll);
    };

    if (lenis) {
      const onScroll = ({ scroll, limit }: { scroll: number; limit: number }) => {
        setProgress(limit > 0 ? scroll / limit : 0);
      };
      const unsubscribe = lenis.on("scroll", onScroll);
      onScroll({ scroll: lenis.scroll, limit: lenis.limit });
      return unsubscribe;
    }

    const root = findScrollRoot();
    if (root) {
      detach = attachNative(root);
      return () => detach?.();
    }

    pollId = window.setInterval(() => {
      const found = findScrollRoot();
      if (found) {
        window.clearInterval(pollId);
        detach = attachNative(found);
      }
    }, 120);

    return () => {
      window.clearInterval(pollId);
      detach?.();
    };
  }, [lenis]);

  return (
    <div
      className="scroll-progress pointer-events-none fixed inset-x-0 top-0 z-[100] h-0.5 origin-left"
      style={{ transform: `scaleX(${progress})` }}
      aria-hidden
    />
  );
}
