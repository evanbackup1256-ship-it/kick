import type { GameEntry, SitePayload } from "@/lib/types";

export function gameRobloxUrl(game: GameEntry): string | null {
  if (game.robloxUrl) return game.robloxUrl;
  const placeId = game.placeIds?.[0];
  if (!placeId) return null;
  return `https://www.roblox.com/games/${placeId}`;
}

export function recentlyUpdatedGameIds(site: SitePayload): Set<string> {
  const ids = new Set<string>();
  const games = site.games || {};
  for (const entry of (site.changelog || []).slice(0, 5)) {
    for (const item of entry.items || []) {
      const lower = item.toLowerCase();
      for (const [id, game] of Object.entries(games)) {
        const name = (game.name || "").toLowerCase();
        const slug = id.replace(/_/g, " ").toLowerCase();
        if (lower.includes(id) || lower.includes(slug) || (name && lower.includes(name))) {
          ids.add(id);
        }
      }
    }
  }
  return ids;
}

export function statusRank(status: string): number {
  const order: Record<string, number> = {
    working: 0,
    testing: 1,
    maintenance: 2,
    broken: 3,
    detected: 4,
  };
  return order[status.toLowerCase()] ?? 5;
}

export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

export function loaderWithGameComment(loadstring: string, gameId: string, gameName?: string): string {
  const label = gameName || gameId;
  return `-- Alleral · ${label}\n${loadstring}`;
}
