"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchLiveStatus, fetchSite } from "@/lib/api";
import { SITE_SNAPSHOT } from "@/lib/site-snapshot";
import type { PlatformView } from "@/lib/store/platform";

export const siteQueryKey = ["site"] as const;
export const liveStatusQueryKey = ["live-status"] as const;

const LIVE_VIEWS = new Set<PlatformView>(["overview", "status", "games"]);

function livePollInterval(view?: PlatformView) {
  if (typeof document === "undefined") return 5_000;
  if (document.hidden) return false;
  if (view === "status") return 3_000;
  if (view === "overview") return 4_000;
  return 5_000;
}

export function useSiteQuery() {
  return useQuery({
    queryKey: siteQueryKey,
    queryFn: fetchSite,
    initialData: SITE_SNAPSHOT,
    staleTime: 30_000,
    gcTime: 30 * 60_000,
    refetchInterval: 60_000,
    refetchOnWindowFocus: true,
  });
}

export function useLiveStatusQuery(activeView: PlatformView) {
  const enabled = LIVE_VIEWS.has(activeView);
  return useQuery({
    queryKey: liveStatusQueryKey,
    queryFn: fetchLiveStatus,
    enabled,
    staleTime: 2_000,
    refetchInterval: enabled ? () => livePollInterval(activeView) : false,
    refetchIntervalInBackground: true,
    refetchOnWindowFocus: true,
  });
}

export function useLiveSyncMeta(activeView: PlatformView = "overview") {
  const query = useLiveStatusQuery(activeView);
  return {
    data: query.data,
    error: query.error,
    loading: query.isLoading,
    fetching: query.isFetching,
    dataUpdatedAt: query.dataUpdatedAt,
    refresh: query.refetch,
    online: query.isSuccess && query.data?.ok !== false,
  };
}

export function useWeaoQuery(enabled: boolean) {
  return useQuery({
    queryKey: ["weao"],
    queryFn: async () => {
      const { fetchWeao } = await import("@/lib/api");
      return fetchWeao();
    },
    enabled,
    staleTime: 30_000,
    refetchInterval: enabled ? 45_000 : false,
    refetchOnWindowFocus: false,
  });
}
