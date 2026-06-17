import { API_BASE, PUBLIC_URL } from "./config";
import type { SitePayload } from "./types";

const ADMIN_PANEL_URL = `${PUBLIC_URL.replace(/\/+$/, "")}/dashboard/admin`;

export function resolveAdminUrl(site?: SitePayload | null): string {
  const raw = site?.links?.admin?.trim();
  if (raw) {
    if (raw.endsWith("/dashboard/admin")) return raw;
    return raw.replace(/\/+$/, "") + "/dashboard/admin";
  }
  const relay = site?.links?.relay?.replace(/\/+$/, "");
  if (relay) return `${relay}/dashboard/admin`;
  if (API_BASE) return `${API_BASE.replace(/\/+$/, "")}/dashboard/admin`;
  return ADMIN_PANEL_URL;
}