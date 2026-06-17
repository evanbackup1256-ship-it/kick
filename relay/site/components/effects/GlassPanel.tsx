"use client";

import { type ReactNode } from "react";
import clsx from "clsx";

interface GlassPanelProps {
  children: ReactNode;
  className?: string;
  hover?: boolean;
  glow?: boolean;
  distortion?: boolean;
  holo?: boolean;
  morph?: boolean;
  depth?: 1 | 2 | 3 | 4;
  as?: "div" | "section" | "article";
  style?: React.CSSProperties;
}

export function GlassPanel({
  children,
  className = "",
  hover = false,
  glow = false,
  distortion = false,
  holo = false,
  morph = false,
  depth,
  as: Tag = "div",
  style,
}: GlassPanelProps) {
  return (
    <Tag
      className={clsx(
        "panel relative",
        hover && "panel-hover",
        distortion && "glass-distortion",
        holo && "holo-border",
        morph && "panel-morph",
        depth && `depth-float-${depth}`,
        className
      )}
      style={style}
    >
      {glow && <div className="pointer-events-none absolute inset-0 rounded-[inherit] bg-[radial-gradient(circle_at_50%_0%,rgba(0,240,200,0.06),transparent_70%)]" />}
      <div className="relative z-[1]">{children}</div>
    </Tag>
  );
}
