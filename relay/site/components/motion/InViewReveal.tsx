"use client";

import clsx from "clsx";
import { motion, useReducedMotion } from "motion/react";
import type { ReactNode } from "react";
import { useInView } from "react-intersection-observer";
import { reveal, spring } from "@/lib/motion/config";

export function InViewReveal({
  children,
  className,
  delay = 0,
  once = true,
  amount = 0.15,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
  once?: boolean;
  amount?: number;
}) {
  const reduce = useReducedMotion();
  const { ref, inView } = useInView({ triggerOnce: once, threshold: amount, rootMargin: "0px 0px -8% 0px" });

  if (reduce) {
    return (
      <div ref={ref} className={className}>
        {children}
      </div>
    );
  }

  return (
    <motion.div
      ref={ref}
      initial={reveal.initial}
      animate={inView ? reveal.animate : reveal.initial}
      transition={{ ...spring.soft, delay }}
      className={clsx(className)}
    >
      {children}
    </motion.div>
  );
}
