"use client";

import { type ReactNode } from "react";
import clsx from "clsx";

interface MeshBackgroundProps {
  children?: ReactNode;
  className?: string;
  as?: "div" | "section";
}

export function MeshBackground({
  children,
  className = "",
  as: Tag = "div",
}: MeshBackgroundProps) {
  return (
    <Tag className={clsx("mesh-bg", className)}>
      {children}
    </Tag>
  );
}
