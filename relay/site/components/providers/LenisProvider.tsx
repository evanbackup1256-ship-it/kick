"use client";

import clsx from "clsx";
import Lenis from "lenis";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { LenisContext } from "@/lib/scroll/lenis-context";
import "lenis/dist/lenis.css";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

type LenisProviderProps = {
  children: ReactNode;
  id?: string;
  className?: string;
};

export function LenisProvider({ children, id = "main-scroll", className }: LenisProviderProps) {
  const wrapperRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const lenisRef = useRef<Lenis | null>(null);
  const [lenis, setLenis] = useState<Lenis | null>(null);

  useEffect(() => {
    const wrapper = wrapperRef.current;
    const content = contentRef.current;
    if (!wrapper || !content) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const instance = new Lenis({
      wrapper,
      content,
      lerp: reduced ? 1 : 0.085,
      smoothWheel: !reduced,
      syncTouch: false,
      autoRaf: false,
    });

    lenisRef.current = instance;
    setLenis(instance);

    instance.on("scroll", ScrollTrigger.update);

    ScrollTrigger.scrollerProxy(wrapper, {
      scrollTop(value) {
        if (arguments.length && typeof value === "number") {
          instance.scrollTo(value, { immediate: true });
        }
        return instance.scroll;
      },
      getBoundingClientRect() {
        return wrapper.getBoundingClientRect();
      },
      pinType: wrapper.style.transform ? "transform" : "fixed",
    });

    ScrollTrigger.defaults({ scroller: wrapper });

    const raf = (time: number) => {
      instance.raf(time);
      requestAnimationFrame(raf);
    };
    requestAnimationFrame(raf);

    requestAnimationFrame(() => ScrollTrigger.refresh());

    const onResize = () => ScrollTrigger.refresh();
    window.addEventListener("resize", onResize, { passive: true });

    return () => {
      window.removeEventListener("resize", onResize);
      ScrollTrigger.getAll().forEach((trigger) => trigger.kill());
      instance.destroy();
      lenisRef.current = null;
      setLenis(null);
    };
  }, []);

  return (
    <LenisContext.Provider value={lenis}>
      <div
        ref={wrapperRef}
        id={id}
        data-lenis-root
        className={clsx("lenis-root min-h-0 flex-1 overflow-y-auto overflow-x-hidden overscroll-contain", className)}
      >
        <div ref={contentRef} data-lenis-content className="min-h-0 flex flex-col">
          {children}
        </div>
      </div>
    </LenisContext.Provider>
  );
}
