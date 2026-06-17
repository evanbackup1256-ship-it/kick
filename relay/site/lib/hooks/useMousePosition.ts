"use client";

import { useEffect, useRef, type RefObject } from "react";

export interface MousePosition {
  x: number;
  y: number;
  px: string;
  py: string;
  ratioX: number;
  ratioY: number;
}

export function useMousePosition(
  ref?: RefObject<HTMLElement | null>
) {
  const pos = useRef<MousePosition>({ x: 0, y: 0, px: "50%", py: "50%", ratioX: 0.5, ratioY: 0.5 });

  useEffect(() => {
    const target = ref?.current ?? document.documentElement;

    const onMove = (e: MouseEvent) => {
      let x = e.clientX;
      let y = e.clientY;
      let rx = 0.5;
      let ry = 0.5;

      if (ref?.current) {
        const rect = ref.current.getBoundingClientRect();
        x = e.clientX - rect.left;
        y = e.clientY - rect.top;
        rx = rect.width > 0 ? x / rect.width : 0.5;
        ry = rect.height > 0 ? y / rect.height : 0.5;
      } else {
        rx = window.innerWidth > 0 ? x / window.innerWidth : 0.5;
        ry = window.innerHeight > 0 ? y / window.innerHeight : 0.5;
      }

      pos.current = {
        x,
        y,
        px: `${x}px`,
        py: `${y}px`,
        ratioX: rx,
        ratioY: ry,
      };

      target.style.setProperty("--cursor-x", `${x}px`);
      target.style.setProperty("--cursor-y", `${y}px`);
      target.style.setProperty("--mouse-x", `${x}px`);
      target.style.setProperty("--mouse-y", `${y}px`);
      target.style.setProperty("--mouse-x-ratio", `${rx}`);
      target.style.setProperty("--mouse-y-ratio", `${ry}`);
    };

    window.addEventListener("mousemove", onMove, { passive: true });
    return () => window.removeEventListener("mousemove", onMove);
  }, [ref]);

  return pos;
}
