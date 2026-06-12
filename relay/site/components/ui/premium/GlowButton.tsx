"use client";

import clsx from "clsx";
import { useRef } from "react";
import { gsap } from "gsap";
import { MovingBorder } from "./MovingBorder";

type GlowButtonProps = {
  children: React.ReactNode;
  className?: string;
  variant?: "primary" | "ghost";
  onClick?: () => void;
  type?: "button" | "submit";
};

export function GlowButton({ children, className, variant = "primary", onClick, type = "button" }: GlowButtonProps) {
  const ref = useRef<HTMLButtonElement>(null);

  const inner = (
    <button
      ref={ref}
      type={type}
      onClick={onClick}
      onMouseMove={(e) => {
        const el = ref.current;
        if (!el || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
        const rect = el.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        gsap.to(el, { x: x * 0.1, y: y * 0.14, duration: 0.3, ease: "power2.out" });
      }}
      onMouseLeave={() => {
        const el = ref.current;
        if (el) gsap.to(el, { x: 0, y: 0, duration: 0.4, ease: "power2.out" });
      }}
      className={clsx(
        "relative w-full px-6 py-3 text-sm font-semibold transition",
        variant === "primary"
          ? "bg-gradient-to-br from-accent to-violet text-[#030508] shadow-[0_8px_32px_rgba(34,211,238,0.2)]"
          : "border border-border-strong bg-transparent text-text hover:bg-white/[0.04]",
        className
      )}
    >
      {children}
    </button>
  );

  if (variant === "primary") {
    return <MovingBorder rounded="rounded-full">{inner}</MovingBorder>;
  }

  return inner;
}
