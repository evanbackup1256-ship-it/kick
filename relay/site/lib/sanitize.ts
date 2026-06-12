import type { FaqItem, ResourceEntry, SitePayload } from "./types";

const BAN_KEYWORDS = /\bban(?:s|ned|ning| evasion| api| list| system| check| issue)?\b/i;

export function isBanRelatedText(text: string): boolean {
  return BAN_KEYWORDS.test(text);
}

export function sanitizePublicSite(site: SitePayload): SitePayload {
  return {
    ...site,
    features: (site.features || []).filter((f) => !isBanRelatedText(f)),
    faq: (site.faq || [])
      .filter((item) => !isBanRelatedText(item.q || ""))
      .map((item) => {
        if (/ban message|blocked on the server/i.test(item.a || "")) {
          return {
            ...item,
            a: "Usually it's the wrong game, a weak executor, or the game is marked Broken/Maintenance.",
          };
        }
        return isBanRelatedText(item.a || "") ? null : item;
      })
      .filter((item): item is FaqItem => item !== null),
    resources: (site.resources || []).filter((r: ResourceEntry) => {
      const blob = `${r.title || ""} ${r.desc || ""} ${r.url || ""}`;
      if (isBanRelatedText(blob)) return false;
      if (r.urlKey === "admin") return false;
      if ((r.url || "").includes("ban")) return false;
      return true;
    }),
    credits: site.credits
      ? {
          ...site.credits,
          subheadline: (site.credits.subheadline || "").replace(/,?\s*bans?,?/gi, ""),
          teams: (site.credits.teams || []).map((team) => ({
            ...team,
            members: (team.members || []).map((m) => ({
              ...m,
              bio: (m.bio || "").replace(/ban system,?\s*/gi, "").replace(/,\s*and everything/i, " and everything"),
            })),
          })),
        }
      : site.credits,
  };
}

export function resolveResourceUrl(site: SitePayload, item: ResourceEntry): string | null {
  if (item.urlKey && site.links?.[item.urlKey]) return site.links[item.urlKey]!;
  if (item.url?.startsWith("http")) return item.url;
  if (item.url?.startsWith("/")) return item.url;
  if (item.url?.startsWith("#")) return item.url;
  return item.url || null;
}
