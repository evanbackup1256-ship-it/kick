"use client";

import { useCallback, useRef, useState } from "react";

interface DragState {
  x: number;
  y: number;
  dragging: boolean;
}

export function useInertiaDrag(initialX = 0, initialY = 0, friction = 0.92) {
  const [state, setState] = useState<DragState>({ x: initialX, y: initialY, dragging: false });
  const pos = useRef({ x: initialX, y: initialY });
  const velocity = useRef({ x: 0, y: 0 });
  const last = useRef({ x: initialX, y: initialY, t: 0 });
  const raf = useRef(0);

  const onPointerDown = useCallback((e: React.PointerEvent) => {
    const el = e.currentTarget as HTMLElement;
    el.setPointerCapture(e.pointerId);
    velocity.current = { x: 0, y: 0 };
    last.current = { x: e.clientX, y: e.clientY, t: performance.now() };
    setState((s) => ({ ...s, dragging: true }));
  }, []);

  const onPointerMove = useCallback((e: React.PointerEvent) => {
    if (!state.dragging) return;
    const dx = e.clientX - last.current.x;
    const dy = e.clientY - last.current.y;
    const dt = performance.now() - last.current.t;

    pos.current.x += dx;
    pos.current.y += dy;

    if (dt > 0) {
      velocity.current = { x: dx / dt * 16, y: dy / dt * 16 };
    }

    last.current = { x: e.clientX, y: e.clientY, t: performance.now() };
    setState((s) => ({ ...s, x: pos.current.x, y: pos.current.y }));
  }, [state.dragging]);

  const onPointerUp = useCallback((e: React.PointerEvent) => {
    const el = e.currentTarget as HTMLElement;
    el.releasePointerCapture(e.pointerId);
    setState((s) => ({ ...s, dragging: false }));

    const step = () => {
      velocity.current.x *= friction;
      velocity.current.y *= friction;
      pos.current.x += velocity.current.x;
      pos.current.y += velocity.current.y;
      setState((s) => ({ x: pos.current.x, y: pos.current.y, dragging: false }));

      if (Math.abs(velocity.current.x) > 0.1 || Math.abs(velocity.current.y) > 0.1) {
        raf.current = requestAnimationFrame(step);
      }
    };
    raf.current = requestAnimationFrame(step);
  }, [friction]);

  return {
    x: state.x,
    y: state.y,
    dragging: state.dragging,
    handlers: {
      onPointerDown,
      onPointerMove,
      onPointerUp,
    },
  };
}
