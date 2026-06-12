"use client";

import dynamic from "next/dynamic";

export const AmbientScene = dynamic(() => import("./AmbientSceneInner").then((m) => m.AmbientSceneInner), {
  ssr: false,
  loading: () => <div className="pointer-events-none fixed inset-0 z-0" aria-hidden />,
});
