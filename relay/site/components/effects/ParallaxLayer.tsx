"use client";

import { type ReactNode } from "react";
import clsx from "clsx";

interface ParallaxLayerProps {
  children: ReactNode;
  className?: string;
  depth?: 1 | 2 | 3 | 4;
  light?: boolean;
}

export function ParallaxLayer({
  children,
  className = "",
  depth = 1,
  light = false,
}: ParallaxLayerProps) {
  return (
    <div
      className={clsx(
        "will-change-transform",
        `depth-layer-${depth}`,
        light && "parallax-light",
        className
      )}
    >
      {children}
    </div>
  );
}
