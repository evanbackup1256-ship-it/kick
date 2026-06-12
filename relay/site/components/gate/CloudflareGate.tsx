"use client";

import { useEffect, useState } from "react";
import { API_BASE, TURNSTILE_SITE_KEY } from "@/lib/config";

const STORAGE_KEY = "alleral_gate_ok";
const SESSION_TTL_MS = 4 * 60 * 60 * 1000;

declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, opts: Record<string, unknown>) => string;
      remove: (id: string) => void;
    };
    onTurnstileLoad?: () => void;
  }
}

export function CloudflareGate({ children }: { children: React.ReactNode }) {
  const [passed, setPassed] = useState(false);
  const [checking, setChecking] = useState(true);

  useEffect(() => {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      if (raw) {
        const data = raw === "1" ? { until: Date.now() + SESSION_TTL_MS } : JSON.parse(raw);
        if (data?.until && Date.now() < data.until) {
          setPassed(true);
          setChecking(false);
          return;
        }
      }
    } catch {
      /* ignore */
    }
    setChecking(false);
  }, []);

  useEffect(() => {
    if (passed || checking) return;

    document.documentElement.classList.add("cf-gate-lock");
    document.body.classList.add("cf-gate-lock", "cf-gate-active");

    const backdrop = document.createElement("div");
    backdrop.className = "cf-gate-backdrop";
    backdrop.innerHTML = `
      <div class="cf-gate-card glass">
        <p class="text-sm text-muted mb-2">Alleral Hub</p>
        <h2 class="text-xl font-semibold mb-2">Verify you're human</h2>
        <p class="text-sm text-muted mb-4">Quick check before loading the hub.</p>
        <div id="cfTurnstileHost" class="flex justify-center min-h-[65px]"></div>
        <p id="cfGateError" class="text-sm text-red-400 mt-3 hidden"></p>
      </div>
    `;
    document.body.appendChild(backdrop);

    const finish = () => {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ until: Date.now() + SESSION_TTL_MS }));
      document.documentElement.classList.remove("cf-gate-lock");
      document.body.classList.remove("cf-gate-lock", "cf-gate-active");
      backdrop.remove();
      setPassed(true);
    };

    const mountTurnstile = async () => {
      let siteKey = TURNSTILE_SITE_KEY;
      if (!siteKey) {
        try {
          const res = await fetch(`${API_BASE}/api/gate/config`, { cache: "no-store" });
          const data = await res.json();
          siteKey = data.siteKey || "";
        } catch {
          finish();
          return;
        }
      }
      if (!siteKey) {
        finish();
        return;
      }

      const script = document.createElement("script");
      script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad";
      script.async = true;
      window.onTurnstileLoad = () => {
        const host = document.getElementById("cfTurnstileHost");
        if (!host || !window.turnstile) return;
        window.turnstile.render(host, {
          sitekey: siteKey,
          theme: "dark",
          callback: () => finish(),
          "error-callback": () => {
            const err = document.getElementById("cfGateError");
            if (err) {
              err.textContent = "Verification failed — refresh and try again.";
              err.classList.remove("hidden");
            }
          },
        });
      };
      document.head.appendChild(script);
    };

    void mountTurnstile();

    return () => {
      backdrop.remove();
      document.documentElement.classList.remove("cf-gate-lock");
      document.body.classList.remove("cf-gate-lock", "cf-gate-active");
    };
  }, [passed, checking]);

  if (checking) return null;
  if (!passed) return null;
  return <>{children}</>;
}
