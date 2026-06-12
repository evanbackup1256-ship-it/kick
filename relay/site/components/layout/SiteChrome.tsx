"use client";

import clsx from "clsx";
import { motion } from "framer-motion";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { BlurFadeIn } from "@/components/ui/premium";

const LINKS = [
  { href: "#home", id: "home", label: "Home" },
  { href: "#live", id: "live", label: "Live" },
  { href: "#games", id: "games", label: "Games" },
  { href: "#tools", id: "tools", label: "Tools" },
  { href: "#changelog", id: "changelog", label: "Updates" },
  { href: "#support", id: "support", label: "Support" },
];

export function Nav({ online }: { online?: boolean }) {
  const [active, setActive] = useState("home");
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const indicatorRef = useRef<HTMLSpanElement>(null);
  const navRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20);
    const onHash = () => setActive(location.hash.replace("#", "") || "home");
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("hashchange", onHash);
    onHash();
    onScroll();
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("hashchange", onHash);
    };
  }, []);

  useEffect(() => {
    const nav = navRef.current;
    const indicator = indicatorRef.current;
    if (!nav || !indicator) return;
    const link = nav.querySelector<HTMLAnchorElement>(`a[data-section="${active}"]`);
    if (!link) return;
    const navRect = nav.getBoundingClientRect();
    const rect = link.getBoundingClientRect();
    indicator.style.width = `${rect.width}px`;
    indicator.style.transform = `translateX(${rect.left - navRect.left}px)`;
  }, [active, open]);

  return (
    <header
      className={clsx(
        "fixed inset-x-0 top-0 z-[100] border-b border-transparent px-0 py-3.5 transition-all duration-500",
        scrolled && "border-border bg-[rgba(3,5,8,0.82)] py-2.5 shadow-[0_16px_48px_rgba(0,0,0,0.35)] backdrop-blur-xl"
      )}
    >
      <div className="section-wrap flex items-center gap-5">
        <Link href="#home" className="inline-flex shrink-0 items-center gap-2.5 font-semibold text-text">
          <span className="grid h-[34px] w-[34px] place-items-center rounded-[10px] border border-cyan-400/35 bg-gradient-to-br from-cyan-400/20 to-violet-400/20 text-sm font-bold shadow-[0_0_24px_rgba(34,211,238,0.15)]">
            A
          </span>
          Alleral
        </Link>

        <nav
          ref={navRef}
          className={clsx(
            "relative ml-auto hidden items-center gap-0.5 rounded-full border border-border bg-white/[0.03] p-1 md:flex",
            open && "!flex absolute left-4 right-4 top-[calc(100%+8px)] flex-col rounded-2xl bg-[rgba(8,12,18,0.96)] p-2"
          )}
        >
          <span
            ref={indicatorRef}
            aria-hidden
            className="pointer-events-none absolute top-1 hidden h-[calc(100%-8px)] rounded-full border border-cyan-400/25 bg-gradient-to-br from-cyan-400/15 to-violet-400/10 shadow-[0_4px_20px_rgba(34,211,238,0.12)] transition-all duration-500 md:block"
          />
          {LINKS.map((link) => (
            <Link
              key={link.id}
              href={link.href}
              data-section={link.id}
              onClick={() => {
                setActive(link.id);
                setOpen(false);
              }}
              className={clsx(
                "relative z-[1] rounded-full px-3.5 py-2 text-sm font-medium transition-colors",
                active === link.id ? "text-text" : "text-muted hover:text-text"
              )}
            >
              {link.label}
            </Link>
          ))}
        </nav>

        <div className="ml-3 flex items-center gap-2.5">
          <span
            className={clsx(
              "hidden items-center gap-1.5 rounded-full border px-3 py-1.5 text-xs font-medium md:inline-flex",
              online ? "border-green-400/25 text-green-400" : "border-border text-muted-2"
            )}
          >
            <span className={clsx("h-1.5 w-1.5 rounded-full", online ? "bg-green-400 shadow-[0_0_10px_rgba(52,211,153,0.65)]" : "bg-muted-2")} />
            {online ? "Online" : "Checking"}
          </span>
          <button
            type="button"
            aria-label="Menu"
            className="flex h-[38px] w-[38px] flex-col items-center justify-center gap-1 rounded-[10px] border border-border bg-white/[0.04] md:hidden"
            onClick={() => setOpen((v) => !v)}
          >
            <span className="block h-[1.5px] w-4 bg-text" />
            <span className="block h-[1.5px] w-4 bg-text" />
          </button>
        </div>
      </div>
    </header>
  );
}

export function Footer() {
  return (
    <footer className="relative border-t border-border py-10">
      <div className="section-wrap flex flex-wrap items-center justify-between gap-4">
        <p className="text-sm text-muted-2">© {new Date().getFullYear()} Alleral</p>
        <div className="flex flex-wrap gap-5 text-sm text-muted">
          <Link href="#home" className="hover:text-text">
            Hub
          </Link>
          <Link href="#credits" className="hover:text-text">
            Creator
          </Link>
          <Link href="#tools" className="hover:text-text">
            Tools
          </Link>
          <a href="https://github.com/evanbackup1256-ship-it/kick" target="_blank" rel="noopener noreferrer" className="hover:text-text">
            GitHub
          </a>
        </div>
      </div>
    </footer>
  );
}

export function AmbientLayer() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <motion.div
        className="absolute -left-[12%] -top-[8%] h-[520px] w-[520px] rounded-full blur-[80px]"
        style={{ background: "radial-gradient(circle, rgba(34,211,238,0.28), transparent 70%)" }}
        animate={{ x: [0, 30, 0], y: [0, -24, 0] }}
        transition={{ duration: 24, repeat: Infinity, repeatType: "mirror", ease: "easeInOut" }}
      />
      <motion.div
        className="absolute -right-[10%] top-[20%] h-[440px] w-[440px] rounded-full blur-[80px]"
        style={{ background: "radial-gradient(circle, rgba(167,139,250,0.22), transparent 70%)" }}
        animate={{ x: [0, -24, 0], y: [0, 18, 0] }}
        transition={{ duration: 20, repeat: Infinity, repeatType: "mirror", ease: "easeInOut", delay: 2 }}
      />
      <div
        className="absolute inset-0 opacity-45 [mask-image:radial-gradient(ellipse_80%_60%_at_50%_30%,#000_0%,transparent_75%)]"
        style={{
          backgroundImage:
            "linear-gradient(rgba(34,211,238,0.04) 1px, transparent 1px), linear-gradient(90deg, rgba(34,211,238,0.04) 1px, transparent 1px)",
          backgroundSize: "64px 64px",
        }}
      />
      <div
        className="absolute inset-0 opacity-[0.035]"
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")",
        }}
      />
    </div>
  );
}

export function SectionHeader({
  label,
  title,
  desc,
}: {
  label: string;
  title: string;
  desc?: string;
}) {
  return (
    <BlurFadeIn className="mb-14 text-center">
      <p className="label-gradient mb-2 text-sm font-semibold uppercase tracking-[0.08em]">{label}</p>
      <h2 className="text-gradient text-[clamp(2rem,5vw,3rem)] font-bold tracking-tight">{title}</h2>
      {desc ? <p className="mx-auto mt-3.5 max-w-lg text-muted">{desc}</p> : null}
      <div className="mx-auto mt-4 h-px w-12 bg-gradient-to-r from-transparent via-cyan-400/50 to-transparent" aria-hidden />
    </BlurFadeIn>
  );
}
