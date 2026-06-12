"use client";

import clsx from "clsx";
import { OverlayScrollbarsComponent } from "overlayscrollbars-react";
import "overlayscrollbars/overlayscrollbars.css";
import type { ReactNode } from "react";

type SmoothScrollProps = {
  children: ReactNode;
  className?: string;
  flex?: boolean;
};

export function SmoothScroll({ children, className, flex }: SmoothScrollProps) {
  return (
    <OverlayScrollbarsComponent
      className={clsx(flex && "flex min-h-0 flex-1 flex-col", className)}
      options={{
        scrollbars: { autoHide: "scroll", autoHideDelay: 400, theme: "os-theme-alleral" },
        overflow: { x: "hidden" },
      }}
      defer
    >
      <div data-scroll-lock className={clsx(flex && "flex min-h-0 flex-1 flex-col")}>
        {children}
      </div>
    </OverlayScrollbarsComponent>
  );
}
