"use client";

import { useEffect, useRef } from "react";

interface Particle {
  el: HTMLDivElement;
  x: number;
  y: number;
  speed: number;
  size: number;
  drift: number;
}

export function ParticleField({ count = 20 }: { count?: number }) {
  const container = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const c = container.current;
    if (!c) return;
    const particles: Particle[] = [];

    for (let i = 0; i < count; i++) {
      const el = document.createElement("div");
      el.className = "telemetry-particle";
      const size = 1 + Math.random() * 2;
      el.style.width = `${size}px`;
      el.style.height = `${size}px`;
      el.style.left = `${Math.random() * 100}%`;
      el.style.animationDelay = `${Math.random() * 8}s`;
      el.style.animationDuration = `${6 + Math.random() * 8}s`;
      el.style.opacity = "0.3";
      c.appendChild(el);
      particles.push({
        el,
        x: Math.random() * 100,
        y: Math.random() * 100,
        speed: 0.2 + Math.random() * 0.5,
        size,
        drift: (Math.random() - 0.5) * 0.3,
      });
    }

    return () => {
      particles.forEach((p) => p.el.remove());
    };
  }, [count]);

  return <div ref={container} className="fixed inset-0 z-[1] pointer-events-none overflow-hidden" />;
}
