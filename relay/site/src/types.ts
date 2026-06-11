export interface GameEntry {
  id?: string;
  name?: string;
  status?: string;
  version?: string;
  message?: string;
  description?: string;
  placeIds?: number[];
  robloxUrl?: string;
}

export interface FaqItem {
  q?: string;
  a?: string;
}

export interface ChangelogEntry {
  date?: string;
  title?: string;
  items?: string[];
}

export interface SiteLinks {
  website?: string;
  mirror?: string;
  github?: string;
}

export interface SitePayload {
  brand?: string;
  tagline?: string;
  announcement?: string;
  loaderVersion?: string;
  loadstring?: string;
  scriptsUpdatedAt?: string;
  siteUpdatedAt?: string;
  githubCommit?: string;
  features?: string[];
  faq?: FaqItem[];
  changelog?: ChangelogEntry[];
  bugCategories?: string[];
  links?: SiteLinks;
  games?: Record<string, GameEntry>;
}

export interface ApiOk {
  ok: boolean;
  error?: string;
}
