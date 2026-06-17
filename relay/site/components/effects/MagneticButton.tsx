"use client";

import { useRef, type ReactNode, type MouseEvent } from "react";

interface MagneticButtonProps {
  children: ReactNode;
  onClick?: () => void;
  className?: string;
  as?: "button" | "a" | "div";
  href?: string;
  strength?: number;
}

export function MagneticButton({ children, onClick, className = "", as = "button", href, strength = 0.3 }: MagneticButtonProps) {
  const ref = useRef<HTMLDivElement>(null);

  const onMove = (e: MouseEvent) => {
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;
    el.style.transform = `translate(${x * strength}px, ${y * strength}px)`;
  };

  const onLeave = () => {
    const el = ref.current;
    if (!el) return;
    el.style.transform = "";
  };

  const Tag = as;

  return (
    <div
      ref={ref}
      className="inline-block will-change-transform"
      style={{ transition: "transform 0.15s cubic-bezier(0.34, 1.56, 0.64, 1)" }}
      onMouseMove={onMove}
      onMouseLeave={onLeave}
    >
      <Tag {...(as === "a" ? { href, target: "_blank", rel: "noreferrer" } : {})} onClick={onClick} className={className} type={as === "button" ? "button" : undefined}>
        {children}
      </Tag>
    </div>
  );
}
