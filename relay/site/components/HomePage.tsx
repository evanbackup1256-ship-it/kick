"use client";

import { useCallback, useEffect, useState } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { fetchSite, postHubVisit } from "@/lib/api";
import { PUBLIC_URL, MIRROR_URL } from "@/lib/config";
import type { SitePayload } from "@/lib/types";
import { ConstellationCanvas } from "@/components/effects/ConstellationCanvas";
import { ScrollProgress } from "@/components/effects/ScrollProgress";
import { CloudflareGate } from "@/components/gate/CloudflareGate";
import { AmbientLayer, Footer, Nav } from "@/components/layout/SiteChrome";
import { ChangelogSection, QuickStartSection, ShareSection } from "@/components/sections/MiscSections";
import { CreditsSection, SupportSection } from "@/components/sections/SupportSection";
import { GamesSection } from "@/components/sections/GamesSection";
import { HeroSection } from "@/components/sections/HeroSection";
import { LiveSection } from "@/components/sections/LiveSection";
import { ToolsSection } from "@/components/sections/ToolsSection";

gsap.registerPlugin(ScrollTrigger);

export function HomePage() {
  const [site, setSite] = useState<SitePayload | null>(null);
  const [online, setOnline] = useState<boolean | undefined>();
  const [toast, setToast] = useState<{ text: string; error?: boolean } | null>(null);

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
    if (!site) return;
    const id = requestAnimationFrame(() => ScrollTrigger.refresh());
    return () => cancelAnimationFrame(id);
  }, [site]);

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

  const navigate = (hash: string) => {
    location.hash = hash;
    document.querySelector(hash)?.scrollIntoView({ behavior: "smooth" });
  };

  if (!site) {
    return (
      <div className="grid min-h-screen place-items-center">
        <p className="text-muted">Loading Alleral…</p>
      </div>
    );
  }

  return (
    <CloudflareGate>
      <ScrollProgress />
      <ConstellationCanvas />
      <AmbientLayer />
      <Nav online={online} />
      <main>
        <HeroSection site={site} onCopy={() => void copyLoadstring()} onNavigate={navigate} />
        <LiveSection />
        <QuickStartSection />
        <GamesSection site={site} />
        <ToolsSection site={site} />
        <ChangelogSection site={site} />
        <SupportSection site={site} />
        <CreditsSection site={site} />
        <ShareSection primaryUrl={PUBLIC_URL} mirrorUrl={MIRROR_URL} />
      </main>
      <Footer />
      {toast ? (
        <div
          className={`fixed bottom-6 left-1/2 z-[150] -translate-x-1/2 rounded-full border px-5 py-3 text-sm shadow-xl backdrop-blur-xl ${
            toast.error ? "border-red-400/40 text-red-300" : "border-border bg-[rgba(8,12,18,0.92)] text-text"
          }`}
        >
          {toast.text}
        </div>
      ) : null}
    </CloudflareGate>
  );
}
