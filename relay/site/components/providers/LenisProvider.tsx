"use client";

import clsx from "clsx";
import LocomotiveScroll from "locomotive-scroll";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { ScrollContext } from "@/lib/scroll/lenis-context";
import "locomotive-scroll/locomotive-scroll.css";

type ScrollProviderProps = {
  children: ReactNode;
  id?: string;
  className?: string;
};

function scheduleResize(instance: LocomotiveScroll) {
  requestAnimationFrame(() => instance.resize());
}

/** Primary scroll region — Locomotive Scroll (Lenis-backed smooth scroll + in-view triggers). */
export function LenisProvider({ children, id = "main-scroll", className }: ScrollProviderProps) {
  const wrapperRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const scrollRef = useRef<LocomotiveScroll | null>(null);
  const [scroll, setScroll] = useState<LocomotiveScroll | null>(null);

  useEffect(() => {
    const wrapper = wrapperRef.current;
    const content = contentRef.current;
    if (!wrapper || !content) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const instance = new LocomotiveScroll({
      lenisOptions: {
        wrapper,
        content,
        lerp: reduced ? 1 : 0.085,
        smoothWheel: !reduced,
        syncTouch: false,
      },
      autoStart: true,
    });

    scrollRef.current = instance;
    setScroll(instance);
    scheduleResize(instance);

    let resizeRaf = 0;
    const onWindowResize = () => {
      cancelAnimationFrame(resizeRaf);
      resizeRaf = requestAnimationFrame(() => instance.resize());
    };

    const resizeObserver = new ResizeObserver(() => scheduleResize(instance));
    resizeObserver.observe(content);
    resizeObserver.observe(wrapper);

    window.addEventListener("resize", onWindowResize, { passive: true });

    return () => {
      cancelAnimationFrame(resizeRaf);
      window.removeEventListener("resize", onWindowResize);
      resizeObserver.disconnect();
      instance.destroy();
      scrollRef.current = null;
      setScroll(null);
    };
  }, []);

  return (
    <ScrollContext.Provider value={scroll}>
      <div
        ref={wrapperRef}
        id={id}
        data-scroll-root
        className={clsx("scroll-root min-h-0 flex-1 overflow-x-hidden overflow-y-auto overscroll-contain", className)}
      >
        <div ref={contentRef} data-scroll-content className="flex flex-col">
          {children}
        </div>
      </div>
    </ScrollContext.Provider>
  );
}
