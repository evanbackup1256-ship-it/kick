"use client";

import clsx from "clsx";
import { motion, useMotionTemplate, useMotionValue } from "framer-motion";
import { useReducedMotion } from "@/lib/useReducedMotion";

type SpotlightCardProps = {
  children: React.ReactNode;
  className?: string;
  innerClassName?: string;
  spotlight?: string;
  as?: "div" | "button" | "article";
  onClick?: () => void;
  type?: "button";
  style?: React.CSSProperties;
};

export function SpotlightCard({
  children,
  className,
  innerClassName,
  spotlight = "rgba(34, 211, 238, 0.14)",
  as = "div",
  onClick,
  type,
  style,
}: SpotlightCardProps) {
  const reduced = useReducedMotion();
  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);
  const background = useMotionTemplate`radial-gradient(420px circle at ${mouseX}px ${mouseY}px, ${spotlight}, transparent 70%)`;

  const handleMove = (e: React.MouseEvent<HTMLElement>) => {
    if (reduced) return;
    const rect = e.currentTarget.getBoundingClientRect();
    mouseX.set(e.clientX - rect.left);
    mouseY.set(e.clientY - rect.top);
  };

  const Tag = as;
  const props = {
    onMouseMove: handleMove,
    onClick,
    className: clsx(
      "group relative overflow-hidden rounded-[28px] border border-border bg-[rgba(10,14,22,0.62)] backdrop-blur-2xl",
      "shadow-[inset_0_1px_0_rgba(255,255,255,0.04),0_24px_80px_rgba(0,0,0,0.45)]",
      "transition-[border-color,transform] duration-500 hover:border-cyan-400/20",
      className
    ),
    ...(as === "button" ? { type: type || "button" } : {}),
    style,
  };

  return (
    <Tag {...props}>
      {!reduced ? (
        <motion.div
          aria-hidden
          className="pointer-events-none absolute inset-0 z-0 opacity-0 transition-opacity duration-500 group-hover:opacity-100"
          style={{ background }}
        />
      ) : (
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 z-0 bg-[radial-gradient(ellipse_at_top,rgba(34,211,238,0.08),transparent_55%)]"
        />
      )}
      <div className={clsx("relative z-[1]", innerClassName)}>{children}</div>
    </Tag>
  );
}
