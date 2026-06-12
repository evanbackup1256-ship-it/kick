"use client";

import { useEffect, useRef, useState } from "react";
import { mountTurnstileWidget, waitForVisible } from "@/lib/turnstile";

type FormTurnstileProps = {
  formId: string;
  active?: boolean;
  onToken?: (token: string) => void;
};

export function FormTurnstile({ formId, active = true, onToken }: FormTurnstileProps) {
  const mountRef = useRef<HTMLDivElement>(null);
  const handleRef = useRef<{ remove: () => void; reset: () => void } | null>(null);
  const [error, setError] = useState("");
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    if (!active) {
      handleRef.current?.remove();
      handleRef.current = null;
      return;
    }

    const el = mountRef.current;
    if (!el) return;

    let cancelled = false;

    const boot = async () => {
      setError("");
      handleRef.current?.remove();
      handleRef.current = null;

      try {
        await waitForVisible(el);
        if (cancelled) return;

        const handle = await mountTurnstileWidget(el, {
          onToken: (token) => {
            onToken?.(token);
            setError("");
          },
          onError: () => setError("Captcha failed to load. Try again."),
          onExpire: () => {
            onToken?.("");
            setError("Captcha expired. Complete it again.");
          },
          onTimeout: () => setError("Captcha timed out. Try again."),
        });

        if (cancelled) {
          handle.remove();
          return;
        }
        handleRef.current = handle;
      } catch {
        if (!cancelled) setError("Could not load captcha.");
      }
    };

    void boot();

    return () => {
      cancelled = true;
      handleRef.current?.remove();
      handleRef.current = null;
    };
  }, [active, formId, retry, onToken]);

  return (
    <div className="grid gap-2">
      <div ref={mountRef} className="form-turnstile min-h-[65px]" data-turnstile={formId} aria-live="polite" />
      {error ? (
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-sm text-red-400">{error}</p>
          <button
            type="button"
            className="rounded-full border border-border px-3 py-1 text-xs text-muted hover:text-text"
            onClick={() => setRetry((n) => n + 1)}
          >
            Retry captcha
          </button>
        </div>
      ) : null}
    </div>
  );
}
