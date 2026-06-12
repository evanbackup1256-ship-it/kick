"use client";

import type Lenis from "lenis";
import { createContext, useContext } from "react";

export const LenisContext = createContext<Lenis | null>(null);

export function useLenis() {
  return useContext(LenisContext);
}
