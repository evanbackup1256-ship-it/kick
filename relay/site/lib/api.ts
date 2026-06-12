import { API_BASE } from "./config";
import { sanitizePublicSite } from "./sanitize";
import type { LiveStatusPayload, SitePayload, WeaoPayload } from "./types";

async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
    cache: "no-store",
  });
  const data = (await res.json().catch(() => ({}))) as T & { ok?: boolean; error?: string };
  if (!res.ok || (data as { ok?: boolean }).ok === false) {
    throw new Error(String((data as { error?: string }).error || `Request failed (${res.status})`));
  }
  return data;
}

export async function fetchSite(): Promise<SitePayload> {
  const data = await fetchJson<SitePayload & { ok?: boolean }>("/api/site");
  return sanitizePublicSite(data);
}

export async function fetchLiveStatus(): Promise<LiveStatusPayload> {
  return fetchJson<LiveStatusPayload>("/api/live/status");
}

export async function fetchWeao(): Promise<WeaoPayload> {
  return fetchJson<WeaoPayload>("/api/weao/exploits");
}

export async function fetchThumbnails(placeIds: string[]): Promise<Record<string, string>> {
  if (!placeIds.length) return {};
  const q = encodeURIComponent(placeIds.join(","));
  const data = await fetchJson<{ thumbnails?: Record<string, string> }>(`/api/games/thumbnails?placeIds=${q}`);
  return data.thumbnails || {};
}

export async function postHubVisit(source = "load"): Promise<void> {
  if (typeof window === "undefined") return;
  try {
    await fetch(`${API_BASE}/api/hub/visit`, {
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

export async function submitForm(path: string, body: Record<string, unknown>): Promise<void> {
  await fetchJson(path, { method: "POST", body: JSON.stringify(body) });
}
