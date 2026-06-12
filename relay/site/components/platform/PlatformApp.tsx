"use client";

import { AnimatePresence } from "motion/react";
import { useCallback, useEffect } from "react";
import dynamic from "next/dynamic";
import { toast } from "sonner";
import { postHubVisit } from "@/lib/api";
import type { SitePayload } from "@/lib/types";
import { usePlatformStore, type PlatformView } from "@/lib/store/platform";
import { useLiveSyncMeta, useSiteQuery } from "@/lib/queries/hooks";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { CommandPalette } from "@/components/platform/CommandPalette";
import { Sidebar } from "@/components/platform/Sidebar";
import { TopBar } from "@/components/platform/TopBar";
import { LiveAlerts } from "@/components/observability/LiveAlerts";
import { QueryProvider } from "@/components/providers/QueryProvider";
import { MainScroll, ScrollContent } from "@/components/providers/MainScroll";
import { PageTransition } from "@/components/motion/Reveal";
import { ScrollProgress } from "@/components/ui/ScrollProgress";
import { OverviewView } from "@/components/views/OverviewView";
import { GamesView } from "@/components/views/GamesView";
import { ToolsView } from "@/components/views/ToolsView";
import { ChangelogView } from "@/components/views/ChangelogView";
import { SupportView } from "@/components/views/SupportView";
import { CreditsView } from "@/components/views/CreditsView";

const StatusView = dynamic(
  () => import("@/components/views/StatusView").then((m) => ({ default: m.StatusView })),
  { loading: () => <ViewSkeleton label="Mission control" /> }
);

function ViewSkeleton({ label }: { label: string }) {
  return (
    <div className="glass-panel rounded-2xl p-8">
      <p className="text-sm text-muted">Loading {label}…</p>
    </div>
  );
}

function PlatformShell({ site, online }: { site: SitePayload; online?: boolean }) {
  const activeView = usePlatformStore((s) => s.activeView);
  const workspace = usePlatformStore((s) => s.workspace);
  const mobileNavOpen = usePlatformStore((s) => s.mobileNavOpen);
  const { data, error, dataUpdatedAt, refresh: refreshLive } = useLiveSyncMeta();

  const copyLoadstring = useCallback(async () => {
    if (!site?.loadstring) return;
    try {
      await navigator.clipboard.writeText(site.loadstring);
      toast.success("Loader copied to clipboard");
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
      <LiveAlerts online={online !== false} errorMessage={error?.message} data={data} />
      <ScrollProgress />
      <div className="noise-overlay" aria-hidden />
      <div className="ambient-orb left-[-10%] top-[-20%] h-[420px] w-[420px] bg-indigo-500/15" aria-hidden />
      <div className="ambient-orb right-[-5%] top-[10%] h-[360px] w-[360px] bg-cyan-400/10" aria-hidden />

      <div className="relative z-10 flex h-[100dvh] min-h-0">
        <Sidebar online={online} />
        <div className="flex min-h-0 min-w-0 flex-1 flex-col">
          <TopBar online={online} workspace={workspace} dataUpdatedAt={dataUpdatedAt} />
          <MainScroll>
            <ScrollContent className={`mx-auto w-full max-w-[1520px] ${mainPad} ${workspace === "wide" ? "max-w-[1680px]" : ""}`}>
              <AnimatePresence mode="wait">
                <PageTransition key={activeView}>
                  {activeView === "overview" ? <OverviewView site={site} online={online} onCopy={() => void copyLoadstring()} /> : null}
                  {activeView === "status" ? <StatusView site={site} /> : null}
                  {activeView === "games" ? <GamesView site={site} /> : null}
                  {activeView === "tools" ? <ToolsView site={site} /> : null}
                  {activeView === "changelog" ? <ChangelogView site={site} /> : null}
                  {activeView === "support" ? <SupportView site={site} /> : null}
                  {activeView === "credits" ? <CreditsView site={site} /> : null}
                </PageTransition>
              </AnimatePresence>
            </ScrollContent>
          </MainScroll>
        </div>
      </div>
      <CommandPalette
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
  const liveQuery = useLiveSyncMeta();

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

  const site = siteQuery.data;
  const online =
    siteQuery.isLoading ? undefined
    : siteQuery.isError ? false
    : liveQuery.error ? false
    : liveQuery.data?.ok !== false;

  if (siteQuery.isLoading || !site) {
    return (
      <div className="grid min-h-screen place-items-center">
        <div className="glass-float rounded-2xl px-8 py-6 text-center">
          <p className="text-sm text-muted">Initializing observability platform…</p>
        </div>
      </div>
    );
  }

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
