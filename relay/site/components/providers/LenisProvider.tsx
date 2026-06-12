"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import Lenis from "lenis";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { LenisContext } from "@/lib/lenis-context";

gsap.registerPlugin(ScrollTrigger);

export function LenisProvider({ children }: { children: ReactNode }) {
  const wrapperRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const [lenis, setLenis] = useState<Lenis | null>(null);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const wrapper = wrapperRef.current;
    const content = contentRef.current;
    if (!wrapper || !content) return;

    const instance = new Lenis({
      wrapper,
      content,
      duration: 1.05,
      easing: (t) => Math.min(1, 1.001 - 2 ** (-10 * t)),
      smoothWheel: true,
      wheelMultiplier: 0.9,
      touchMultiplier: 1.1,
    });
    setLenis(instance);

    instance.on("scroll", ScrollTrigger.update);
    const tick = (time: number) => instance.raf(time * 1000);
    gsap.ticker.add(tick);
    gsap.ticker.lagSmoothing(0);

    const onGatePassed = () => {
      instance.resize();
      ScrollTrigger.refresh();
    };
    window.addEventListener("alleral:gate-passed", onGatePassed);

    return () => {
      window.removeEventListener("alleral:gate-passed", onGatePassed);
      gsap.ticker.remove(tick);
      instance.destroy();
      setLenis(null);
    };
  }, []);

  return (
    <LenisContext.Provider value={lenis}>
      <div ref={wrapperRef} className="min-h-0 flex-1 overflow-hidden" data-lenis-root>
        <div ref={contentRef}>{children}</div>
      </div>
    </LenisContext.Provider>
  );
}

export function ScrollContent({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={className}>{children}</div>;
}
