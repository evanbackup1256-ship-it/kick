"use client";

import { QueryClient } from "@tanstack/react-query";

function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 8_000,
        gcTime: 300_000,
        refetchOnWindowFocus: true,
        refetchOnReconnect: true,
        retry: 1,
        structuralSharing: true,
      },
    },
  });
}

let client: QueryClient | null = null;

export function getQueryClient() {
  if (!client) client = createQueryClient();
  return client;
}
