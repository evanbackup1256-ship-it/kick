"use client";

import { type ReactNode, useEffect, useRef, useState } from "react";

interface ViewTransitionProps {
  children: ReactNode;
  id: string;
  className?: string;
}

export function ViewTransition({ children, id, className = "" }: ViewTransitionProps) {
  const [visible, setVisible] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const timeout = setTimeout(() => setVisible(true), 30);
    return () => clearTimeout(timeout);
  }, [id]);

  useEffect(() => {
    setVisible(false);
    const timeout = setTimeout(() => setVisible(true), 30);
    return () => clearTimeout(timeout);
  }, [id]);

  return (
    <div
      ref={ref}
      key={id}
      className={`${className} ${visible ? "layout-morph-enter" : "layout-morph-exit"}`}
    >
      {children}
    </div>
  );
}
