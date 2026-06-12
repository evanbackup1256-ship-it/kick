"use client";

import clsx from "clsx";
import { motion } from "framer-motion";
import { useRef } from "react";
import { gsap } from "gsap";
import type { SitePayload } from "@/lib/types";
import { HeroOrbit } from "@/components/effects/HeroOrbit";
import { GlowButton, LightBeams, ShaderMesh, SpotlightCard } from "@/components/ui/premium";

function SplitBrand({ text }: { text: string }) {
  return (
    <span className="inline-block">
      {[...text].map((char, i) => (
        <motion.span
          key={`${char}-${i}`}
          initial={{ opacity: 0, y: 24, rotateX: 40, filter: "blur(4px)" }}
          animate={{ opacity: 1, y: 0, rotateX: 0, filter: "blur(0px)" }}
          transition={{ delay: 0.04 * i, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="inline-block bg-gradient-to-b from-white to-white/75 bg-clip-text text-transparent"
        >
          {char}
        </motion.span>
      ))}
    </span>
  );
}

function MagneticButton({
  children,
  className,
  onClick,
}: {
  children: React.ReactNode;
  className?: string;
  onClick?: () => void;
}) {
  const ref = useRef<HTMLButtonElement>(null);

  return (
    <button
      ref={ref}
      type="button"
      onClick={onClick}
      onMouseMove={(e) => {
        const el = ref.current;
        if (!el) return;
        const rect = el.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        gsap.to(el, { x: x * 0.12, y: y * 0.18, duration: 0.3, ease: "power2.out" });
      }}
      onMouseLeave={() => {
        const el = ref.current;
        if (el) gsap.to(el, { x: 0, y: 0, duration: 0.4, ease: "power2.out" });
      }}
      className={className}
    >
      {children}
    </button>
  );
}

export function HeroSection({
  site,
  onCopy,
  onNavigate,
}: {
  site: SitePayload;
  onCopy: () => void;
  onNavigate: (hash: string) => void;
}) {
  const games = Object.values(site.games || {});
  const working = games.filter((g) => (g.status || "working").toLowerCase() === "working").length;

  const brand = (site.brand || "Alleral").toUpperCase();
  const metaBits = [
    site.coreVersion ? `core ${site.coreVersion}` : "",
    site.uiLibrary ? `${site.uiLibrary}${site.uiVersion ? ` ${site.uiVersion}` : ""}` : "",
    site.sydePatch ? `patch v${site.sydePatch}` : "",
  ].filter(Boolean);

  return (
    <section id="home" className="relative scroll-mt-24 pb-20 pt-[130px] min-h-[min(92vh,920px)] overflow-hidden">
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <ShaderMesh className="opacity-50" />
        <LightBeams className="opacity-60" />
      </div>

      <div className="section-wrap relative z-10 grid items-center gap-12 lg:grid-cols-2">
        <div className="text-left">
          {site.announcement ? (
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              className="mb-5 rounded-xl border border-cyan-400/30 bg-cyan-400/10 px-4 py-3 text-sm text-cyan-300"
            >
              {site.announcement}
            </motion.div>
          ) : null}

          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.1 }}
            className="shimmer-text mb-3 text-xs font-medium uppercase tracking-[0.12em]"
          >
            Roblox script hub · auto-synced
          </motion.p>

          <h1 className="text-[clamp(2.8rem,7vw,4.8rem)] font-extrabold leading-none tracking-[-0.05em]">
            <SplitBrand text={brand} />
          </h1>

          <motion.p initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="mt-4 max-w-md text-lg text-muted">
            {site.tagline}
          </motion.p>

          <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.28 }} className="mt-6 flex flex-wrap gap-2">
            {[
              ["Copy Script", onCopy],
              ["Browse Games", () => onNavigate("#games")],
              ["Live Tracker", () => onNavigate("#live")],
              ["Executors", () => onNavigate("#tools")],
              ["Support", () => onNavigate("#support")],
            ].map(([label, action]) => (
              <MagneticButton
                key={label as string}
                onClick={action as () => void}
                className="rounded-full border border-border bg-white/[0.03] px-3.5 py-2 text-xs font-medium text-muted transition hover:border-cyan-400/35 hover:bg-cyan-400/10 hover:text-text"
              >
                {label as string}
              </MagneticButton>
            ))}
          </motion.div>

          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.35 }}>
            <SpotlightCard className="mt-6" spotlight="rgba(34,211,238,0.16)">
              <div className="flex items-center justify-between border-b border-border bg-white/[0.02] px-5 py-3.5">
                <span className="inline-flex items-center gap-2 font-mono text-xs text-muted">
                  <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-green-400 shadow-[0_0_10px_rgba(52,211,153,0.7)]" />
                  loader.luau
                </span>
                <span className="text-xs text-muted-2">
                  v{site.loaderVersion || "—"}
                  {metaBits.length ? ` · ${metaBits.join(" · ")}` : ""}
                </span>
              </div>
              <pre className="max-h-[120px] overflow-y-auto whitespace-pre-wrap break-all px-5 py-5 font-mono text-xs leading-relaxed text-[#b8c4d4]">
                {site.loadstring || "Loading…"}
              </pre>
              <div className="flex flex-wrap gap-2.5 px-5 pb-5">
                <GlowButton onClick={onCopy}>Copy Script</GlowButton>
                <MagneticButton
                  onClick={() => onNavigate("#games")}
                  className="rounded-full border border-border-strong px-6 py-3 text-sm font-medium text-text hover:bg-white/[0.04]"
                >
                  View Games
                </MagneticButton>
              </div>
            </SpotlightCard>
          </motion.div>

          <motion.div initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.42 }}>
            <SpotlightCard className="mt-6" spotlight="rgba(167,139,250,0.12)">
              <div className="flex flex-wrap items-center gap-6 px-6 py-4">
                <Stat value={games.length} label="Games" />
                <Divider />
                <Stat value={working} label="Working" />
                <Divider />
                <Stat text={site.scriptsUpdatedAt || "—"} label="Last sync" />
                <Divider />
                <Stat text="Live" label="Relay" accent />
              </div>
            </SpotlightCard>
          </motion.div>
        </div>

        <motion.div initial={{ opacity: 0, scale: 0.96 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: 0.2, duration: 0.9 }}>
          <HeroOrbit loaderVersion={site.loaderVersion} sydePatch={site.sydePatch} />
        </motion.div>
      </div>
    </section>
  );
}

function Stat({ value, text, label, accent }: { value?: number; text?: string; label: string; accent?: boolean }) {
  return (
    <div className="flex flex-col gap-0.5">
      <strong className={clsx("text-lg font-bold tracking-tight", accent && "bg-gradient-to-r from-accent to-violet bg-clip-text text-transparent")}>
        {value !== undefined ? value : text}
      </strong>
      <span className="text-[0.68rem] uppercase tracking-[0.08em] text-muted-2">{label}</span>
    </div>
  );
}

function Divider() {
  return <div className="hidden h-8 w-px bg-border sm:block" />;
}
