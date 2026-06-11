-- Alleral management schema for Supabase (audit + hub telemetry mirror)
-- Applied via: npx supabase db push   OR   Supabase SQL editor

create extension if not exists "pgcrypto";

-- ── Audit log (admin actions, sync events, bans) ──
create table if not exists public.alleral_audit (
  id bigint generated always as identity primary key,
  event text not null check (char_length(event) <= 120),
  actor text not null default 'system' check (char_length(actor) <= 120),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists alleral_audit_created_at_idx on public.alleral_audit (created_at desc);
create index if not exists alleral_audit_event_idx on public.alleral_audit (event);
create index if not exists alleral_audit_actor_idx on public.alleral_audit (actor);

-- ── Hub visit / support event mirror (optional future sync) ──
create table if not exists public.alleral_hub_events (
  id bigint generated always as identity primary key,
  kind text not null check (char_length(kind) <= 64),
  source text not null default 'hub',
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists alleral_hub_events_kind_idx on public.alleral_hub_events (kind);
create index if not exists alleral_hub_events_created_at_idx on public.alleral_hub_events (created_at desc);

-- ── Games snapshot after auto-sync ──
create table if not exists public.alleral_games_snapshots (
  id bigint generated always as identity primary key,
  commit_sha text,
  total_games integer not null default 0,
  games jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists alleral_games_snapshots_created_at_idx on public.alleral_games_snapshots (created_at desc);

-- ── Row level security: deny public; service_role bypasses RLS ──
alter table public.alleral_audit enable row level security;
alter table public.alleral_hub_events enable row level security;
alter table public.alleral_games_snapshots enable row level security;

-- No policies for anon/authenticated = no client access without service key

comment on table public.alleral_audit is 'Alleral admin audit trail mirrored from Railway relay';
comment on table public.alleral_hub_events is 'Hub telemetry mirror (visits, reports)';
comment on table public.alleral_games_snapshots is 'Supported games list snapshots after GitHub sync';
