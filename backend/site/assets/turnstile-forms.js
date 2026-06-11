(() => {
  const widgets = new Map();
  let siteKey = null;
  let loadPromise = null;

  async function resolveSiteKey() {
    if (siteKey) return siteKey;
    const cfg = window.ALLERAL_CONFIG || {};
    const local = (cfg.turnstileSiteKey || "").trim();
    if (local) {
      siteKey = local;
      return siteKey;
    }
    const base = window.ALLERAL_API || "";
    try {
      const res = await fetch(`${base}/api/gate/config`, { cache: "no-store" });
      const data = await res.json();
      siteKey = data.siteKey || "3x00000000000000000000FF";
    } catch {
      siteKey = "3x00000000000000000000FF";
    }
    return siteKey;
  }

  function loadTurnstileScript() {
    if (window.turnstile) return Promise.resolve();
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

  async function renderWidget(mount) {
    const id = mount.dataset.turnstile;
    if (!id || widgets.has(id) || mount.dataset.rendered === "1") return;
    if (!mount.isConnected || mount.closest(".hidden")) return;

    await loadTurnstileScript();
    const key = await resolveSiteKey();
    if (!window.turnstile) return;

    mount.dataset.rendered = "1";
    const entry = { mount, token: "", widgetId: null };
    entry.widgetId = window.turnstile.render(mount, {
      sitekey: key,
      theme: "dark",
      size: "flexible",
      appearance: "always",
      callback: (token) => {
        entry.token = token;
      },
      "expired-callback": () => {
        entry.token = "";
      },
      "error-callback": () => {
        entry.token = "";
      },
    });
    widgets.set(id, entry);
  }

  window.AlleralTurnstile = {
    async mountVisible() {
      document.querySelectorAll(".form-turnstile:not([data-rendered])").forEach((el) => {
        if (!el.closest(".hidden")) void renderWidget(el);
      });
    },

    async getToken(formId) {
      const entry = widgets.get(formId);
      if (entry?.token) return entry.token;
      const mount = document.querySelector(`.form-turnstile[data-turnstile="${formId}"]`);
      if (mount && mount.dataset.rendered !== "1") await renderWidget(mount);
      return widgets.get(formId)?.token || "";
    },

    reset(formId) {
      const entry = widgets.get(formId);
      if (!entry || entry.widgetId == null || !window.turnstile) return;
      try {
        window.turnstile.reset(entry.widgetId);
      } catch {
        /* ignore */
      }
      entry.token = "";
    },

    hideAll() {
      document.querySelectorAll(".form-turnstile").forEach((el) => {
        el.classList.add("hidden");
      });
    },
  };
})();
