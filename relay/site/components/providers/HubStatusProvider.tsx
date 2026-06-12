"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { fetchLiveStatus } from "@/lib/api";
import type { HubStatusPayload } from "@/lib/types";

type HubStatusContextValue = {
  data: HubStatusPayload | null;
  error: string | null;
  loading: boolean;
  refresh: () => Promise<void>;
  secondsAgo: number | null;
};

const HubStatusContext = createContext<HubStatusContextValue | null>(null);

export function HubStatusProvider({ children, intervalMs = 20000 }: { children: ReactNode; intervalMs?: number }) {
  const [data, setData] = useState<HubStatusPayload | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [updatedAt, setUpdatedAt] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [clock, setClock] = useState(0);

  const refresh = useCallback(async () => {
    try {
      const next = await fetchLiveStatus();
      setData(next);
      setError(null);
      setUpdatedAt(Date.now());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not reach relay");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void refresh();
    const poll = setInterval(refresh, intervalMs);
    return () => clearInterval(poll);
  }, [refresh, intervalMs]);

  useEffect(() => {
    const tick = setInterval(() => setClock((n) => n + 1), 5000);
    return () => clearInterval(tick);
  }, []);

  const secondsAgo = useMemo(() => {
    void clock;
    return updatedAt ? Math.max(0, Math.floor((Date.now() - updatedAt) / 1000)) : null;
  }, [updatedAt, clock]);

  const value = useMemo(
    () => ({ data, error, loading, refresh, secondsAgo }),
    [data, error, loading, refresh, secondsAgo]
  );

  return <HubStatusContext.Provider value={value}>{children}</HubStatusContext.Provider>;
}

export function useHubStatus() {
  const ctx = useContext(HubStatusContext);
  if (!ctx) throw new Error("useHubStatus must be used within HubStatusProvider");
  return ctx;
}
