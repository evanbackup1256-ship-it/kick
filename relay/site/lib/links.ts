import { API_BASE, PUBLIC_URL } from "./config";
import type { SitePayload } from "./types";

/** Standalone admin site (separate static app on the relay host). */
const ADMIN_PANEL_URL = `${PUBLIC_URL.replace(/\/+$/, "")}/admin.html`;

export function resolveAdminUrl(site?: SitePayload | null): string {
  const raw = site?.links?.admin?.trim();
  if (raw) {
    if (raw.endsWith(".html")) return raw;
    if (raw.endsWith("/admin")) return `${raw}.html`;
    return raw.replace(/\/+$/, "") + "/admin.html";
  }
  const relay = site?.links?.relay?.replace(/\/+$/, "");
  if (relay) return `${relay}/admin.html`;
  if (API_BASE) return `${API_BASE.replace(/\/+$/, "")}/admin.html`;
  return ADMIN_PANEL_URL;
}
