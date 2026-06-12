"use client";

import clsx from "clsx";
import { motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";
import { reveal, spring, stagger } from "@/lib/motion/config";

export function Reveal({
  children,
  className,
  delay = 0,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
}) {
  const reduce = useReducedMotion();
  if (reduce) return <div className={className}>{children}</div>;
  return (
    <motion.div
      initial={reveal.initial}
      animate={reveal.animate}
      transition={{ ...spring.soft, delay }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

export function Stagger({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const reduce = useReducedMotion();
  if (reduce) return <div className={className}>{children}</div>;
  return (
    <motion.div
      initial="hidden"
      animate="visible"
      variants={{
        hidden: {},
        visible: { transition: { staggerChildren: stagger.base, delayChildren: 0.04 } },
      }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

export function StaggerItem({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const reduce = useReducedMotion();
  if (reduce) return <div className={className}>{children}</div>;
  return (
    <motion.div
      variants={{
        hidden: reveal.initial,
        visible: { opacity: 1, y: 0, transition: spring.soft },
      }}
      className={className}
    >
      {children}
    </motion.div>
  );
}

export function PageTransition({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  const reduce = useReducedMotion();
  if (reduce) return <div className={className}>{children}</div>;
  return (
    <motion.div
      initial={reveal.initial}
      animate={reveal.animate}
      exit={reveal.exit}
      transition={spring.panel}
      className={className}
    >
      {children}
    </motion.div>
  );
}
