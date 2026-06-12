"use client";

import { AnimatePresence, motion } from "motion/react";
import { useCallback, useEffect, useState } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { toast } from "sonner";
import { fetchSite, postHubVisit } from "@/lib/api";
import type { SitePayload } from "@/lib/types";
import { usePlatformStore, type PlatformView } from "@/lib/store/platform";
import { useHubStatus } from "@/lib/hooks/useHubStatus";
import { reveal, spring } from "@/lib/motion/config";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { CommandPalette } from "@/components/platform/CommandPalette";
import { Sidebar } from "@/components/platform/Sidebar";
import { TopBar } from "@/components/platform/TopBar";
import { OverviewView } from "@/components/views/OverviewView";
import { StatusView } from "@/components/views/StatusView";
import { GamesView } from "@/components/views/GamesView";
import { ToolsView } from "@/components/views/ToolsView";
import { ChangelogView } from "@/components/views/ChangelogView";
import { SupportView } from "@/components/views/SupportView";
import { CreditsView } from "@/components/views/CreditsView";
import { HubStatusProvider } from "@/components/providers/HubStatusProvider";
import { LenisProvider, ScrollContent } from "@/components/providers/LenisProvider";

gsap.registerPlugin(ScrollTrigger);

function PlatformShell({ site, online }: { site: SitePayload; online?: boolean }) {
  const activeView = usePlatformStore((s) => s.activeView);
  const workspace = usePlatformStore((s) => s.workspace);
  const { secondsAgo, refresh: refreshLive } = useHubStatus();

  const copyLoadstring = async () => {
    if (!site?.loadstring) return;
    try {
      await navigator.clipboard.writeText(site.loadstring);
      toast.success("Loader copied to clipboard");
    } catch {
      toast.error("Copy failed");
    }
  };

  const mainPad = workspace === "compact" ? "p-3 md:p-4" : workspace === "wide" ? "p-5 md:p-8" : "p-4 md:p-6";

  return (
    <>
      <div className="noise-overlay" aria-hidden />
      <div className="ambient-orb left-[-10%] top-[-20%] h-[420px] w-[420px] bg-indigo-500/15" aria-hidden />
      <div className="ambient-orb right-[-5%] top-[10%] h-[360px] w-[360px] bg-cyan-400/10" aria-hidden />

      <div className="relative z-10 flex h-screen min-h-0">
        <Sidebar online={online} />
        <div className="flex min-h-0 min-w-0 flex-1 flex-col">
          <TopBar online={online} workspace={workspace} secondsAgo={secondsAgo} />
          <LenisProvider>
            <ScrollContent className={`mx-auto w-full max-w-[1520px] ${mainPad} ${workspace === "wide" ? "max-w-[1680px]" : ""}`}>
              <AnimatePresence mode="wait">
                <motion.div
                  key={activeView}
                  initial={reveal.initial}
                  animate={reveal.animate}
                  exit={reveal.exit}
                  transition={spring.panel}
                >
                  {activeView === "overview" ? <OverviewView site={site} online={online} onCopy={() => void copyLoadstring()} /> : null}
                  {activeView === "status" ? <StatusView site={site} /> : null}
                  {activeView === "games" ? <GamesView site={site} /> : null}
                  {activeView === "tools" ? <ToolsView site={site} /> : null}
                  {activeView === "changelog" ? <ChangelogView site={site} /> : null}
                  {activeView === "support" ? <SupportView site={site} /> : null}
                  {activeView === "credits" ? <CreditsView site={site} /> : null}
                </motion.div>
              </AnimatePresence>
            </ScrollContent>
          </LenisProvider>
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

export function PlatformApp() {
  const [site, setSite] = useState<SitePayload | null>(null);
  const [online, setOnline] = useState<boolean | undefined>();

  const load = useCallback(async () => {
    try {
      const data = await fetchSite();
      setSite(data);
      setOnline(true);
    } catch {
      setOnline(false);
    }
  }, []);

  useEffect(() => {
    void load();
    void postHubVisit();
    const t = setInterval(load, 30000);
    return () => clearInterval(t);
  }, [load]);

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

  if (!site) {
    return (
      <div className="grid min-h-screen place-items-center">
        <motion.div initial={{ opacity: 0, scale: 0.98 }} animate={{ opacity: 1, scale: 1 }} transition={spring.soft} className="glass-float rounded-2xl px-8 py-6 text-center">
          <p className="text-sm text-muted">Initializing observability platform…</p>
        </motion.div>
      </div>
    );
  }

  return (
    <HubStatusProvider intervalMs={20000}>
      <CloudflareGate>
        <PlatformShell site={site} online={online} />
      </CloudflareGate>
    </HubStatusProvider>
  );
}
