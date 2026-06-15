/** Same-origin in production; override with NEXT_PUBLIC_ALLERAL_API for split-host deploys. */
export const API_BASE = (process.env.NEXT_PUBLIC_ALLERAL_API || "").replace(/\/$/, "");

export const PUBLIC_URL =
  process.env.NEXT_PUBLIC_PUBLIC_URL || "https://alleral-telemetry-production.up.railway.app/";

export const MIRROR_URL =
  process.env.NEXT_PUBLIC_MIRROR_URL || "https://evanbackup1256-ship-it.github.io/kick/";

export const BASE_PATH = process.env.NEXT_PUBLIC_BASE_PATH || "";

export const TURNSTILE_SITE_KEY = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY || "";

export function apiUrl(path: string): string {
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `${API_BASE}${normalized}`;
}
