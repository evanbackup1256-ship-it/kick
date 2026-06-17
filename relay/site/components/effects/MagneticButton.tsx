"use client";

import { useRef, type ReactNode, type MouseEvent } from "react";

export function MagneticButton({ children, onClick, className = "", href }: {
  children: ReactNode; onClick?: () => void; className?: string; href?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);

  const onMove = (e: MouseEvent) => {
    const el = ref.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;
    el.style.transform = `translate(${x * 0.25}px, ${y * 0.25}px)`;
  };

  const onLeave = () => {
    if (ref.current) ref.current.style.transform = "";
  };

  const cls = `inline-block will-change-transform ${className}`;

  if (href) {
    return (
      <div ref={ref} className={cls} style={{ transition: "transform 0.15s cubic-bezier(0.34, 1.56, 0.64, 1)" }}
        onMouseMove={onMove} onMouseLeave={onLeave}>
        <a href={href} target="_blank" rel="noreferrer" className={className}>{children}</a>
      </div>
    );
  }

  return (
    <div ref={ref} className={cls} style={{ transition: "transform 0.15s cubic-bezier(0.34, 1.56, 0.64, 1)" }}
      onMouseMove={onMove} onMouseLeave={onLeave}>
      <button onClick={onClick} className={className} type="button">{children}</button>
    </div>
  );
}
