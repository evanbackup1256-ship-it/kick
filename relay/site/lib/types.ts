export interface GameEntry {
  id?: string;
  name?: string;
  status?: string;
  version?: string;
  message?: string;
  description?: string;
  placeIds?: number[];
  robloxUrl?: string;
  uiTabs?: string[];
  scriptFeatures?: { name?: string; category?: string; desc?: string }[];
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
  loaderRaw?: string;
  relay?: string;
  [key: string]: string | undefined;
}

export interface CreditMember {
  id?: string;
  displayName?: string;
  role?: string;
  robloxUsername?: string;
  robloxUserId?: string;
  bio?: string;
  featured?: boolean;
  accent?: string;
  tags?: string[];
  links?: Record<string, string>;
}

export interface CreditTeam {
  id?: string;
  title?: string;
  members?: CreditMember[];
}

export interface CreditsData {
  headline?: string;
  subheadline?: string;
  teams?: CreditTeam[];
  specialThanks?: { name?: string; note?: string }[];
}

export interface ResourceEntry {
  title?: string;
  desc?: string;
  url?: string;
  urlKey?: string;
  icon?: string;
}

export interface SitePayload {
  brand?: string;
  tagline?: string;
  announcement?: string;
  loaderVersion?: string;
  coreVersion?: string;
  uiLibrary?: string;
  uiVersion?: string;
  sydePatch?: number;
  loadstring?: string;
  scriptsUpdatedAt?: string;
  siteUpdatedAt?: string;
  githubCommit?: string;
  features?: string[];
  faq?: FaqItem[];
  changelog?: ChangelogEntry[];
  bugCategories?: string[];
  links?: SiteLinks;
  credits?: CreditsData;
  resources?: ResourceEntry[];
  games?: Record<string, GameEntry>;
}

export interface LiveStatusPayload {
  ok?: boolean;
  online?: boolean;
  autoSync?: boolean;
  updatedAt?: string;
  versions?: Record<string, string>;
  sync?: Record<string, unknown>;
  telemetry?: Record<string, unknown>;
  feed?: { at?: string; kind?: string; message?: string }[];
}

export interface WeaoExploit {
  slug?: string;
  title?: string;
  logo?: string;
  live?: string;
  liveLabel?: string;
  liveDetail?: string;
  updatedDate?: string;
  price?: string;
  detected?: string;
  recommended?: boolean;
}

export interface WeaoPayload {
  ok?: boolean;
  exploits?: WeaoExploit[];
  summary?: Record<string, number>;
  fetchedAt?: string;
  pollIntervalSec?: number;
  warning?: string;
  stale?: boolean;
  recentChanges?: { at?: string; message?: string; severity?: string; slug?: string }[];
}
