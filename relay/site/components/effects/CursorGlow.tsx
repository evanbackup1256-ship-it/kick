"use client";

import { useMousePosition } from "@/lib/hooks/useMousePosition";

interface CursorGlowProps {
  className?: string;
}

export function CursorGlow({ className = "" }: CursorGlowProps) {
  useMousePosition();

  return <div className={`cursor-glow ${className}`} aria-hidden />;
}
