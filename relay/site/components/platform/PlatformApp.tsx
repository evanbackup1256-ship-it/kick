"use client";

import { useCallback, useEffect, useState } from "react";
import dynamic from "next/dynamic";
import { toast } from "sonner";
import { postHubVisit } from "@/lib/api";
import type { SitePayload } from "@/lib/types";
import { usePlatformStore, type PlatformView } from "@/lib/store/platform";
import { useLiveSyncMeta, useSiteQuery } from "@/lib/queries/hooks";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { Sidebar } from "@/components/platform/Sidebar";
import { TopBar } from "@/components/platform/TopBar";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { MainScroll, ScrollContent } from "@/components/providers/MainScroll";
import { PageTransition } from "@/components/motion/Reveal";
import { ScrollProgress } from "@/components/ui/ScrollProgress";
import { AmbientBackground } from "@/components/ui/AmbientBackground";
import { SITE_SNAPSHOT } from "@/lib/site-snapshot";

const CommandPalette = dynamic(
  () => import("@/components/platform/CommandPalette").then((m) => ({ default: m.CommandPalette })),
  { ssr: false }
);

const LiveAlerts = dynamic(
  () => import("@/components/observability/LiveAlerts").then((m) => ({ default: m.LiveAlerts })),
  { ssr: false }
);

const OverviewView = dynamic(
  () => import("@/components/views/OverviewView").then((m) => ({ default: m.OverviewView })),
  { loading: () => <ViewSkeleton label="Overview" /> }
);

const StatusView = dynamic(
  () => import("@/components/views/StatusView").then((m) => ({ default: m.StatusView })),
  { loading: () => <ViewSkeleton label="Mission control" /> }
);

const GamesView = dynamic(
  () => import("@/components/views/GamesView").then((m) => ({ default: m.GamesView })),
  { loading: () => <ViewSkeleton label="Games" /> }
);

const ToolsView = dynamic(
  () => import("@/components/views/ToolsView").then((m) => ({ default: m.ToolsView })),
  { loading: () => <ViewSkeleton label="Executors" /> }
);

const ChangelogView = dynamic(
  () => import("@/components/views/ChangelogView").then((m) => ({ default: m.ChangelogView })),
  { loading: () => <ViewSkeleton label="Ship log" /> }
);

const SupportView = dynamic(
  () => import("@/components/views/SupportView").then((m) => ({ default: m.SupportView })),
  { loading: () => <ViewSkeleton label="Support" /> }
);

const CreditsView = dynamic(
  () => import("@/components/views/CreditsView").then((m) => ({ default: m.CreditsView })),
  { loading: () => <ViewSkeleton label="Team" /> }
);

function ViewSkeleton({ label }: { label: string }) {
  return (
    <div className="panel p-8">
      <p className="text-sm text-muted skeleton-pulse">Loading {label}…</p>
    </div>
  );
}

function PlatformShell({ site, online }: { site: SitePayload; online?: boolean }) {
  const activeView = usePlatformStore((s) => s.activeView);
  const workspace = usePlatformStore((s) => s.workspace);
  const mobileNavOpen = usePlatformStore((s) => s.mobileNavOpen);
  const { data, error, dataUpdatedAt, refresh: refreshLive } = useLiveSyncMeta(activeView);

  const copyLoadstring = useCallback(async () => {
    if (!site?.loadstring) return;
    try {
      await navigator.clipboard.writeText(site.loadstring);
      toast.success("Loader copied");
    } catch {
      toast.error("Copy failed");
    }
  }, [site?.loadstring]);

  const mainPad = workspace === "compact" ? "p-3 md:p-4" : workspace === "wide" ? "p-5 md:p-8" : "p-4 md:p-6";

  useEffect(() => {
    document.body.classList.toggle("mobile-drawer-open", mobileNavOpen);
    return () => document.body.classList.remove("mobile-drawer-open");
  }, [mobileNavOpen]);

  return (
    <>
      <AmbientBackground />
      <LiveAlerts online={online !== false} errorMessage={error?.message} data={data} />
      <ScrollProgress />
      <div className="relative z-10 flex h-[100dvh] min-h-0">
        <Sidebar online={online} />
        <div className="flex min-h-0 min-w-0 flex-1 flex-col">
          <TopBar online={online} workspace={workspace} dataUpdatedAt={dataUpdatedAt} />
          <MainScroll>
            <ScrollContent
              className={`mx-auto w-full max-w-[1520px] ${mainPad} ${workspace === "wide" ? "max-w-[1680px]" : ""}`}
            >
              <PageTransition key={activeView}>
                {activeView === "overview" ? (
                  <OverviewView site={site} online={online} onCopy={() => void copyLoadstring()} />
                ) : null}
                {activeView === "status" ? <StatusView site={site} /> : null}
                {activeView === "games" ? <GamesView site={site} /> : null}
                {activeView === "tools" ? <ToolsView site={site} /> : null}
                {activeView === "changelog" ? <ChangelogView site={site} /> : null}
                {activeView === "support" ? <SupportView site={site} /> : null}
                {activeView === "credits" ? <CreditsView site={site} /> : null}
              </PageTransition>
            </ScrollContent>
          </MainScroll>
        </div>
      </div>
      <CommandPalette
        site={site}
        onCopyScript={() => void copyLoadstring()}
        onRefresh={() => {
          void refreshLive();
          toast.message("Refreshing live data");
        }}
      />
    </>
  );
}

function PlatformAppInner() {
  const siteQuery = useSiteQuery();
  const activeView = usePlatformStore((s) => s.activeView);
  const liveQuery = useLiveSyncMeta(activeView);
  const site = siteQuery.data ?? SITE_SNAPSHOT;

  useEffect(() => {
    void postHubVisit();
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      const map: Record<string, PlatformView> = {
        o: "overview",
        l: "status",
        g: "games",
        e: "tools",
        h: "changelog",
        s: "support",
        t: "credits",
      };
      const next = map[e.key.toLowerCase()];
      if (next) usePlatformStore.getState().setView(next);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const online =
    siteQuery.isError ? false : liveQuery.error ? false : liveQuery.data?.ok !== false;

  return (
    <CloudflareGate>
      <PlatformShell site={site} online={online} />
    </CloudflareGate>
  );
}

export function PlatformApp() {
  return (
    <QueryProvider>
      <PlatformAppInner />
    </QueryProvider>
  );
}
