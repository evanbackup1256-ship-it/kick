"use client";

import { AnimatePresence, motion } from "motion/react";
import { useCallback, useEffect, useState } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { fetchSite, postHubVisit } from "@/lib/api";
import type { SitePayload } from "@/lib/types";
import { usePlatformStore, type PlatformView } from "@/lib/store/platform";
import { reveal, spring } from "@/lib/motion/config";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { AmbientScene } from "@/components/platform/AmbientScene";
import { CommandPalette } from "@/components/platform/CommandPalette";
import { Sidebar } from "@/components/platform/Sidebar";
import { TopBar } from "@/components/platform/TopBar";
import { OverviewView } from "@/components/views/OverviewView";
import { ControlView } from "@/components/views/ControlView";
import { GamesView } from "@/components/views/GamesView";
import { ToolsView } from "@/components/views/ToolsView";
import { ChangelogView } from "@/components/views/ChangelogView";
import { SupportView } from "@/components/views/SupportView";
import { CreditsView } from "@/components/views/CreditsView";
import { LenisProvider } from "@/components/providers/LenisProvider";

gsap.registerPlugin(ScrollTrigger);

export function PlatformApp() {
  const [site, setSite] = useState<SitePayload | null>(null);
  const [online, setOnline] = useState<boolean | undefined>();
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null);
  const activeView = usePlatformStore((s) => s.activeView);
  const workspace = usePlatformStore((s) => s.workspace);

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
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 2800);
    return () => clearTimeout(t);
  }, [toast]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      const tag = (e.target as HTMLElement | null)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      const map: Record<string, PlatformView> = {
        o: "overview",
        m: "control",
        g: "games",
        e: "tools",
        l: "changelog",
        s: "support",
        t: "credits",
      };
      const next = map[e.key.toLowerCase()];
      if (next) usePlatformStore.getState().setView(next);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const flash = (text: string, error = false) => setToast({ text, error });

  const copyLoadstring = async () => {
    if (!site?.loadstring) return;
    try {
      await navigator.clipboard.writeText(site.loadstring);
      flash("Script copied");
    } catch {
      flash("Copy failed", true);
    }
  };

  if (!site) {
    return (
      <div className="grid min-h-screen place-items-center">
        <motion.div initial={{ opacity: 0, scale: 0.98 }} animate={{ opacity: 1, scale: 1 }} transition={spring.soft} className="glass-panel rounded-2xl px-8 py-6 text-center">
          <p className="text-sm text-muted">Initializing Alleral platform…</p>
        </motion.div>
      </div>
    );
  }

  return (
    <LenisProvider>
      <CloudflareGate>
        <AmbientScene />
        <div className="relative z-10 flex min-h-screen">
          <Sidebar online={online} />
          <div className="flex min-w-0 flex-1 flex-col">
            <TopBar online={online} workspace={workspace} />
            <main className="flex-1 overflow-y-auto p-4 md:p-6">
              <AnimatePresence mode="wait">
                <motion.div
                  key={activeView}
                  initial={reveal.initial}
                  animate={reveal.animate}
                  exit={reveal.exit}
                  transition={spring.panel}
                  className="mx-auto w-full max-w-[1400px]"
                >
                  {activeView === "overview" ? <OverviewView site={site} online={online} onCopy={() => void copyLoadstring()} /> : null}
                  {activeView === "control" ? <ControlView /> : null}
                  {activeView === "games" ? <GamesView site={site} /> : null}
                  {activeView === "tools" ? <ToolsView site={site} /> : null}
                  {activeView === "changelog" ? <ChangelogView site={site} /> : null}
                  {activeView === "support" ? <SupportView site={site} /> : null}
                  {activeView === "credits" ? <CreditsView site={site} /> : null}
                </motion.div>
              </AnimatePresence>
            </main>
          </div>
        </div>
        <CommandPalette onCopyScript={() => void copyLoadstring()} />
        <AnimatePresence>
          {toast ? (
            <motion.div
              initial={{ opacity: 0, y: 12, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 8, scale: 0.98 }}
              transition={spring.snappy}
              className={`fixed bottom-6 left-1/2 z-[150] -translate-x-1/2 rounded-full border px-5 py-3 text-sm shadow-xl backdrop-blur-xl ${
                toast.error ? "border-red-400/40 text-red-300" : "border-border bg-surface text-text"
              }`}
            >
              {toast.text}
            </motion.div>
          ) : null}
        </AnimatePresence>
      </CloudflareGate>
    </LenisProvider>
  );
}
