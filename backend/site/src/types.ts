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
  loaderRaw?: string;
  relay?: string;
  admin?: string;
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

export interface ExecutorEntry {
  name?: string;
  status?: string;
  note?: string;
}

export interface ResourceEntry {
  title?: string;
  desc?: string;
  url?: string;
  urlKey?: string;
  icon?: string;
}

export interface AvatarRenders {
  body?: string;
  bust?: string;
  headshot?: string;
  profile?: string;
}

export interface CreditRenderMember {
  id?: string;
  robloxUserId?: string;
  robloxUsername?: string;
  displayName?: string;
  role?: string;
  profileUrl?: string;
  renders?: AvatarRenders;
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
  credits?: CreditsData;
  executors?: ExecutorEntry[];
  resources?: ResourceEntry[];
  games?: Record<string, GameEntry>;
}

export interface ApiOk {
  ok: boolean;
  error?: string;
}
