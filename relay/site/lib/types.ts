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

interface ChangelogEntry {
  date?: string;
  title?: string;
  items?: string[];
}

interface SiteLinks {
  website?: string;
  mirror?: string;
  github?: string;
  loaderRaw?: string;
  relay?: string;
  [key: string]: string | undefined;
}

interface CreditMember {
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

interface CreditTeam {
  id?: string;
  title?: string;
  members?: CreditMember[];
}

interface CreditsData {
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
  version?: number;
  updatedAt?: string;
  brand?: string;
  tagline?: string;
  announcement?: string;
  loaderVersion?: string;
  coreVersion?: string;
  uiLibrary?: string;
  uiVersion?: string;
  sydePatch?: number;
  maclibVersion?: number;
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

export interface HubStatusPayload {
  ok?: boolean;
  at?: string;
  versions?: Record<string, string | number | undefined>;
  release?: {
    commit?: string;
    branch?: string;
    updatedAt?: string;
    scriptsUpdatedAt?: string;
  };
  sync?: {
    enabled?: boolean;
    autoStatus?: boolean;
    lastSyncAt?: string;
    lastError?: string;
  };
  games?: {
    total?: number;
    working?: number;
    items?: { id: string; name?: string; status?: string; version?: string; message?: string }[];
  };
  relay?: { online?: boolean; autoSync?: boolean };
  changelog?: { date?: string; title?: string; items?: string[] }[];
}

/** @deprecated Use HubStatusPayload — kept for legacy imports */
type LiveStatusPayload = HubStatusPayload;

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
