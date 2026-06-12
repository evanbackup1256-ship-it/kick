"use client";

import clsx from "clsx";
import { motion, useMotionValue, useSpring } from "motion/react";
import { useRef, type ReactNode } from "react";
import { spring } from "@/lib/motion/config";

type Variant = "primary" | "secondary" | "ghost" | "danger";

const variants: Record<Variant, string> = {
  primary:
    "bg-gradient-to-b from-accent-bright to-accent text-white shadow-[0_0_24px_rgba(99,102,241,0.35)] border border-white/10",
  secondary: "glass-panel text-text hover:border-border-strong",
  ghost: "border border-transparent text-muted hover:text-text hover:bg-white/[0.04]",
  danger: "border border-red-400/30 bg-red-400/10 text-red-300",
};

type ButtonProps = {
  children: ReactNode;
  className?: string;
  variant?: Variant;
  magnetic?: boolean;
  size?: "sm" | "md" | "lg";
  type?: "button" | "submit" | "reset";
  disabled?: boolean;
  onClick?: () => void;
};

export function Button({
  children,
  className,
  variant = "secondary",
  magnetic = false,
  size = "md",
  type = "button",
  disabled,
  onClick,
}: ButtonProps) {
  const ref = useRef<HTMLButtonElement>(null);
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const sx = useSpring(x, spring.magnetic);
  const sy = useSpring(y, spring.magnetic);

  const sizes = { sm: "px-3 py-1.5 text-xs rounded-lg", md: "px-4 py-2 text-sm rounded-xl", lg: "px-5 py-2.5 text-sm rounded-xl" };

  const body = (
    <motion.button
      ref={ref}
      type={type}
      disabled={disabled}
      onClick={onClick}
      style={magnetic ? { x: sx, y: sy } : undefined}
      whileHover={{ scale: 1.02 }}
      whileTap={{ scale: 0.98 }}
      transition={spring.snappy}
      className={clsx(
        "inline-flex items-center justify-center gap-2 font-medium transition-colors disabled:opacity-50",
        variants[variant],
        sizes[size],
        className
      )}
    >
      {children}
    </motion.button>
  );

  if (!magnetic) return body;

  return (
    <span
      className="inline-flex"
      onMouseMove={(e) => {
        const el = ref.current;
        if (!el) return;
        const r = el.getBoundingClientRect();
        x.set((e.clientX - r.left - r.width / 2) * 0.14);
        y.set((e.clientY - r.top - r.height / 2) * 0.18);
      }}
      onMouseLeave={() => {
        x.set(0);
        y.set(0);
      }}
    >
      {body}
    </span>
  );
}

export function IconButton({
  children,
  className,
  label,
  onClick,
}: {
  children: ReactNode;
  className?: string;
  label: string;
  onClick?: () => void;
}) {
  return (
    <Button variant="ghost" size="sm" aria-label={label} className={clsx("!px-2.5", className)} onClick={onClick}>
      {children}
    </Button>
  );
}

export function Kbd({ children }: { children: ReactNode }) {
  return (
    <kbd className="rounded-md border border-border bg-bg-2 px-1.5 py-0.5 font-mono text-[10px] text-muted">{children}</kbd>
  );
}
