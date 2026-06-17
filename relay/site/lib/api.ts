import { apiUrl } from "./config";
import { sanitizePublicSite } from "./sanitize";
import type { HubStatusPayload, SitePayload, WeaoPayload } from "./types";

const GET_CACHE: RequestInit = { cache: "no-store" };

async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(apiUrl(path), {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });
  const data = (await res.json().catch(() => ({}))) as T & { ok?: boolean; error?: string };
  if (!res.ok || (data as { ok?: boolean }).ok === false) {
    throw new Error(String((data as { error?: string }).error || `Request failed (${res.status})`));
  }
  return data;
}

export async function fetchSite(): Promise<SitePayload> {
  const data = await fetchJson<SitePayload & { ok?: boolean }>("/api/site", GET_CACHE);
  return sanitizePublicSite(data);
}

export async function fetchLiveStatus(): Promise<HubStatusPayload> {
  return fetchJson<HubStatusPayload>("/api/live/status", { cache: "no-store" });
}

export async function fetchWeao(): Promise<WeaoPayload> {
  return fetchJson<WeaoPayload>("/api/weao/exploits", { cache: "no-store" });
}

export async function fetchThumbnails(placeIds: string[]): Promise<Record<string, string>> {
  if (!placeIds.length) return {};
  const q = encodeURIComponent(placeIds.join(","));
  const data = await fetchJson<{ thumbnails?: Record<string, string> }>(
    `/api/games/thumbnails?placeIds=${q}`,
    GET_CACHE
  );
  return data.thumbnails || {};
}

export async function postHubVisit(source = "load"): Promise<void> {
  if (typeof window === "undefined") return;
  try {
    await fetch(apiUrl("/api/hub/visit"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        path: `${location.pathname}${location.hash}`,
        referrer: document.referrer || "",
        userAgent: navigator.userAgent,
        host: location.host,
        source,
      }),
      keepalive: true,
    });
  } catch {
    /* ignore */
  }
}

async function submitForm(path: string, body: Record<string, unknown>): Promise<void> {
  await fetchJson(path, { method: "POST", body: JSON.stringify(body), cache: "no-store" });
}
