import { TURNSTILE_SITE_KEY, apiUrl } from "@/lib/config";

const TEST_SITE_KEY = "3x00000000000000000000FF";

function isElementVisible(el: HTMLElement): boolean {
  if (!el.isConnected) return false;
  const style = getComputedStyle(el);
  if (style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return false;
  const rect = el.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
}
declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, opts: Record<string, unknown>) => string;
      remove: (id: string) => void;
      reset: (id: string) => void;
    };
  }
}

let loadPromise: Promise<void> | null = null;

export async function loadTurnstileScript(): Promise<void> {
  if (typeof window === "undefined") return;
  if (window.turnstile) return;

  if (loadPromise) return loadPromise;

  if (document.querySelector('script[data-cf-turnstile="1"]')) {
    loadPromise = new Promise((resolve) => {
      const wait = setInterval(() => {
        if (window.turnstile) {
          clearInterval(wait);
          resolve();
        }
      }, 50);
    });
    return loadPromise;
  }

  loadPromise = new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    script.async = true;
    script.dataset.cfTurnstile = "1";
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("turnstile_load_failed"));
    document.head.appendChild(script);
  });

  return loadPromise;
}

export async function resolveTurnstileSiteKey(): Promise<string> {
  const local = TURNSTILE_SITE_KEY.trim();
  if (local) return local;

  try {
    const res = await fetch(apiUrl("/api/gate/config"), { cache: "no-store" });
    const data = await res.json();
    if (data.ok && data.siteKey) return String(data.siteKey);
  } catch {
    /* fall through */
  }

  return TEST_SITE_KEY;
}

export type TurnstileWidgetHandle = {
  widgetId: string;
  remove: () => void;
  reset: () => void;
};

export async function mountTurnstileWidget(
  el: HTMLElement,
  handlers: {
    onToken: (token: string) => void;
    onError?: () => void;
    onExpire?: () => void;
    onTimeout?: () => void;
    onBeforeInteractive?: () => void;
  }
): Promise<TurnstileWidgetHandle> {
  if (!el.isConnected) throw new Error("turnstile_mount_detached");
  if (!isElementVisible(el)) {
    throw new Error("turnstile_mount_hidden");
  }

  await loadTurnstileScript();
  const sitekey = await resolveTurnstileSiteKey();
  if (!window.turnstile) throw new Error("turnstile_unavailable");

  el.innerHTML = "";

  await new Promise<void>((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  });

  if (!el.isConnected) throw new Error("turnstile_mount_detached");

  const widgetId = window.turnstile.render(el, {
    sitekey,
    theme: "dark",
    size: "normal",
    appearance: "interaction-only",
    retry: "auto",
    "refresh-expired": "auto",
    callback: (token: string) => handlers.onToken(token),
    "before-interactive-callback": () => handlers.onBeforeInteractive?.(),
    "error-callback": () => handlers.onError?.(),
    "expired-callback": () => handlers.onExpire?.(),
    "timeout-callback": () => handlers.onTimeout?.(),
  });

  return {
    widgetId,
    remove: () => {
      try {
        window.turnstile?.remove(widgetId);
      } catch {
        /* stale widget */
      }
      el.innerHTML = "";
    },
    reset: () => {
      try {
        window.turnstile?.reset(widgetId);
      } catch {
        /* ignore */
      }
    },
  };
}

export async function verifyGateToken(token: string): Promise<boolean> {
  try {
    const res = await fetch(apiUrl("/api/gate/verify"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token }),
    });
    const data = await res.json();
    return data.ok === true;
  } catch {
    return false;
  }
}

export function waitForVisible(el: HTMLElement, timeoutMs = 8000): Promise<void> {
  if (isElementVisible(el)) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const started = Date.now();
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting && e.intersectionRatio > 0)) {
          io.disconnect();
          resolve();
        }
      },
      { threshold: 0.01 }
    );
    io.observe(el);

    const tick = () => {
      if (isElementVisible(el)) {
        io.disconnect();
        resolve();
        return;
      }
      if (Date.now() - started > timeoutMs) {
        io.disconnect();
        reject(new Error("turnstile_wait_visible_timeout"));
        return;
      }
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
}
