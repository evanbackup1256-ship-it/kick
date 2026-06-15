"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { mountTurnstileWidget, resolveTurnstileSiteKey, verifyGateToken } from "@/lib/turnstile";

const STORAGE_KEY = "alleral_gate_ok";
const SESSION_TTL_MS = 4 * 60 * 60 * 1000;

function readSessionPassed(): boolean {
  try {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (!raw) return false;
    if (raw === "1") return true;
    const data = JSON.parse(raw) as { until?: number };
    return Boolean(data?.until && Date.now() < data.until);
  } catch {
    return sessionStorage.getItem(STORAGE_KEY) === "1";
  }
}

function markSessionPassed() {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ until: Date.now() + SESSION_TTL_MS }));
}

export function CloudflareGate({ children }: { children: React.ReactNode }) {
  const [passed, setPassed] = useState<boolean | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [retry, setRetry] = useState(0);
  const mountRef = useRef<HTMLDivElement>(null);
  const widgetRef = useRef<{ remove: () => void; reset: () => void } | null>(null);
  const verifiedRef = useRef(false);

  useEffect(() => {
    setPassed(readSessionPassed());
  }, []);

  const unlock = useCallback(() => {
    document.documentElement.classList.remove("cf-gate-lock");
    document.body.classList.remove("cf-gate-lock", "cf-gate-active");
  }, []);

  const finish = useCallback(() => {
    markSessionPassed();
    unlock();
    window.dispatchEvent(new CustomEvent("alleral:gate-passed"));
    setPassed(true);
  }, [unlock]);

  useEffect(() => {
    if (passed !== false) {
      if (passed === true) unlock();
      return;
    }

    document.documentElement.classList.add("cf-gate-lock");
    document.body.classList.add("cf-gate-lock", "cf-gate-active");

    return () => {
      unlock();
      widgetRef.current?.remove();
      widgetRef.current = null;
    };
  }, [passed, unlock]);

  useEffect(() => {
    if (passed !== false) return;
    if (typeof window !== "undefined") {
      const protocol = window.location.protocol;
      if (protocol !== "http:" && protocol !== "https:") return;
    }

    const el = mountRef.current;
    if (!el) return;

    let cancelled = false;
    verifiedRef.current = false;
    setLoading(true);
    setError("");

    const boot = async () => {
      widgetRef.current?.remove();
      widgetRef.current = null;

      const siteKey = await resolveTurnstileSiteKey();
      if (!siteKey) {
        finish();
        return;
      }

      try {
        const handle = await mountTurnstileWidget(el, {
          onBeforeInteractive: () => {
            if (!cancelled) setLoading(false);
          },
          onToken: async (token) => {
            if (verifiedRef.current || cancelled) return;
            verifiedRef.current = true;
            const ok = await verifyGateToken(token);
            if (cancelled) return;
            if (!ok) {
              verifiedRef.current = false;
              setError("Verification failed. Try again.");
              widgetRef.current?.reset();
              return;
            }
            finish();
          },
          onError: () => {
            if (!cancelled) {
              setLoading(false);
              setError("Challenge error. Click Try Again.");
            }
          },
          onExpire: () => {
            verifiedRef.current = false;
            if (!cancelled) setError("Challenge expired.");
          },
          onTimeout: () => {
            if (!cancelled) {
              setLoading(false);
              setError("Challenge timed out.");
            }
          },
        });

        if (cancelled) {
          handle.remove();
          return;
        }

        widgetRef.current = handle;
        setLoading(false);
      } catch {
        if (!cancelled) {
          setLoading(false);
          setError("Could not load Turnstile.");
        }
      }
    };

    void boot();

    return () => {
      cancelled = true;
      widgetRef.current?.remove();
      widgetRef.current = null;
    };
  }, [passed, retry, finish]);

  if (passed === null) {
    return <>{children}</>;
  }

  return (
    <>
      {children}
      {passed === false ? (
        <div className="cf-gate-backdrop" role="dialog" aria-modal="true" aria-label="Security check">
          <div className="cf-gate-card">
            <p className="text-sm text-muted mb-2">Alleral Hub</p>
            <h2 className="text-xl font-semibold mb-2">Quick verification</h2>
            <p className="text-sm text-muted mb-4">One-time check — the hub loads behind this overlay.</p>
            {loading ? <p className="mb-3 text-xs text-muted-2">Loading…</p> : null}
            <div ref={mountRef} id="cfTurnstileHost" className="flex justify-center min-h-[65px]" />
            {error ? (
              <div className="mt-3 grid gap-2">
                <p className="text-sm text-red-400">{error}</p>
                <button
                  type="button"
                  className="mx-auto rounded-full border border-border px-4 py-2 text-sm text-muted hover:text-text"
                  onClick={() => {
                    verifiedRef.current = false;
                    setRetry((n) => n + 1);
                  }}
                >
                  Try Again
                </button>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}
    </>
  );
}
