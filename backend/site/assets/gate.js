(() => {
  const STORAGE_KEY = "alleral_gate_ok";
  const DEV_TOKEN_KEY = "alleral_dev_token";
  const SESSION_TTL_MS = 4 * 60 * 60 * 1000;
  const TEST_SITE_KEY = "3x00000000000000000000FF";
  const cfg = window.ALLERAL_CONFIG || {};

  function randomRay() {
    const hex = "0123456789abcdef";
    let id = "";
    for (let i = 0; i < 16; i += 1) id += hex[Math.floor(Math.random() * 16)];
    return id;
  }

  function isGatePassed() {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      if (!raw) return false;
      if (raw === "1") return true;
      const data = JSON.parse(raw);
      if (data?.until && Date.now() < data.until) return true;
      sessionStorage.removeItem(STORAGE_KEY);
      return false;
    } catch {
      return sessionStorage.getItem(STORAGE_KEY) === "1";
    }
  }

  function markGatePassed() {
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ until: Date.now() + SESSION_TTL_MS }));
  }

  async function isDevBypass() {
    const token = sessionStorage.getItem(DEV_TOKEN_KEY);
    if (!token) return false;
    const base = window.ALLERAL_API || "";
    try {
      const res = await fetch(`${base}/api/dev/status`, {
        headers: { "X-Dev-Token": token },
        cache: "no-store",
      });
      const data = await res.json();
      return data.ok === true;
    } catch {
      return false;
    }
  }

  function unlockPage() {
    document.documentElement.classList.remove("cf-gate-lock");
    document.body?.classList.remove("cf-gate-lock");
    document.body?.classList.remove("cf-gate-active");
  }

  function finish(gate) {
    markGatePassed();
    gate?.classList.add("cf-gate-success");
    setTimeout(() => {
      unlockPage();
      gate?.classList.add("cf-gate-out");
      setTimeout(() => gate?.remove(), 550);
      window.dispatchEvent(new CustomEvent("alleral:gate-passed"));
    }, 480);
  }

  async function boot() {
    if (isGatePassed() || await isDevBypass()) {
      if (!isGatePassed()) markGatePassed();
      return;
    }
    if (!document.body) return;

    document.documentElement.classList.add("cf-gate-lock");
    document.body.classList.add("cf-gate-lock", "cf-gate-active");

    const hostname = window.location.hostname || "alleral.hub";
    const gate = document.createElement("div");
    gate.id = "cfGate";
    gate.setAttribute("role", "dialog");
    gate.setAttribute("aria-modal", "true");
    gate.setAttribute("aria-label", "Cloudflare security check");
    gate.innerHTML = `
      <div class="cf-gate-backdrop" aria-hidden="true">
        <div class="cf-scan-line"></div>
      </div>
      <div class="cf-gate-card cf-gate-enter">
        <div class="cf-host">${hostname}</div>
        <div class="cf-cloud cf-cloud-pulse" aria-hidden="true">
          <svg viewBox="0 0 64 40" width="56" height="34" role="img" aria-label="Cloudflare">
            <path fill="#f6821f" d="M19 31c-6.1 0-11-4.9-11-11 0-5.2 3.6-9.6 8.5-10.8C18.2 4.8 23.5 1 29.6 1c7.2 0 13.2 5.1 14.6 11.9 5.5.4 9.8 5.1 9.8 10.8 0 6.1-4.9 11-11 11H19z"/>
          </svg>
        </div>
        <h1 class="cf-gate-title">Just a moment…</h1>
        <p class="cf-gate-lead">We need to verify you are human before you can access <strong>${hostname}</strong>.</p>
        <ul class="cf-steps" id="cfSteps">
          <li data-step="browser"><span class="cf-check"></span><span>Checking your browser</span></li>
          <li data-step="human"><span class="cf-check"></span><span>Verifying you are human</span></li>
          <li data-step="edge"><span class="cf-check"></span><span>Establishing secure connection</span></li>
        </ul>
        <div class="cf-progress" aria-hidden="true"><div class="cf-progress-bar" id="cfBar"></div></div>
        <div class="cf-captcha-wrap">
          <p class="cf-captcha-label">Complete the challenge below</p>
          <div id="cfTurnstileLoader" class="cf-turnstile-loader">
            <span class="cf-loader-dot"></span><span class="cf-loader-dot"></span><span class="cf-loader-dot"></span>
            <span class="cf-loader-text">Loading security widget…</span>
          </div>
          <div id="cfTurnstile" class="cf-turnstile hidden"></div>
          <p id="cfGateError" class="cf-gate-error hidden"></p>
          <button id="cfGateRetry" class="btn btn-outline hidden" type="button">Try Again</button>
        </div>
        <p class="cf-ray">Ray ID: <code id="cfRay">${randomRay()}</code></p>
        <p class="cf-powered">Performance &amp; security by <strong>Cloudflare</strong></p>
      </div>
    `;

    document.body.prepend(gate);

    const steps = [...gate.querySelectorAll(".cf-steps li")];
    const bar = gate.querySelector("#cfBar");
    const errorEl = gate.querySelector("#cfGateError");
    const retryBtn = gate.querySelector("#cfGateRetry");
    const loaderEl = gate.querySelector("#cfTurnstileLoader");
    const mountEl = gate.querySelector("#cfTurnstile");
    let verified = false;
    let renderAttempt = 0;
    let widgetId = null;
    let activeSiteKey = TEST_SITE_KEY;

    function setProgress(pct) {
      if (bar) bar.style.width = `${Math.min(100, Math.max(0, pct))}%`;
    }

    function setStep(name) {
      const order = ["browser", "human", "edge"];
      const idx = order.indexOf(name);
      steps.forEach((li, i) => {
        li.classList.toggle("done", i < idx);
        li.classList.toggle("active", i === idx);
      });
      setProgress(((idx + 1) / (order.length + 1)) * 85);
    }

    function showError(msg) {
      if (!errorEl) return;
      errorEl.textContent = msg;
      errorEl.classList.remove("hidden");
      retryBtn?.classList.remove("hidden");
    }

    function clearError() {
      errorEl?.classList.add("hidden");
      retryBtn?.classList.add("hidden");
    }

    function showWidget() {
      loaderEl?.classList.add("hidden");
      mountEl?.classList.remove("hidden");
    }

    setStep("browser");

    async function resolveSiteKey() {
      const local = (cfg.turnstileSiteKey || "").trim();
      if (local) return local;
      const base = window.ALLERAL_API || "";
      try {
        const res = await fetch(`${base}/api/gate/config`, { cache: "no-store" });
        const data = await res.json();
        if (data.ok && data.siteKey) return data.siteKey;
      } catch {
        /* interactive default */
      }
      return TEST_SITE_KEY;
    }

    async function verifyToken(token) {
      if (!token) return false;
      const base = window.ALLERAL_API || "";
      try {
        const res = await fetch(`${base}/api/gate/verify`, {
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

    function resetWidget() {
      verified = false;
      clearError();
      if (widgetId != null && window.turnstile) {
        try { window.turnstile.remove(widgetId); } catch { /* ignore */ }
        widgetId = null;
      }
      mountEl.innerHTML = "";
      loaderEl?.classList.remove("hidden");
      mountEl?.classList.add("hidden");
    }

    function complete(token) {
      if (verified) return;
      verified = true;
      setStep("edge");
      setProgress(95);
      verifyToken(token).then((ok) => {
        if (!ok) {
          verified = false;
          setStep("human");
          showError("Verification failed. Please try the challenge again.");
          if (widgetId != null && window.turnstile) window.turnstile.reset(widgetId);
          return;
        }
        steps.forEach((s) => { s.classList.add("done"); s.classList.remove("active"); });
        setProgress(100);
        finish(gate);
      });
    }

    function renderTurnstile(siteKey) {
      activeSiteKey = siteKey;
      if (!mountEl || !window.turnstile) {
        showError("Security widget failed to load.");
        return;
      }
      resetWidget();
      setStep("human");
      widgetId = window.turnstile.render(mountEl, {
        sitekey: siteKey,
        theme: "dark",
        size: "normal",
        appearance: "always",
        retry: "auto",
        "refresh-expired": "auto",
        callback: (token) => complete(token),
        "before-interactive-callback": () => showWidget(),
        "after-interactive-callback": () => showWidget(),
        "error-callback": () => {
          showError("Challenge error. Click Try Again.");
        },
        "expired-callback": () => {
          verified = false;
          showError("Challenge expired. Complete it again.");
        },
        "timeout-callback": () => {
          showError("Challenge timed out. Click Try Again.");
        },
      });
      showWidget();
    }

    function loadTurnstileScript() {
      if (window.turnstile) return Promise.resolve();
      if (document.querySelector('script[data-cf-turnstile="1"]')) {
        return new Promise((resolve) => {
          const wait = setInterval(() => {
            if (window.turnstile) { clearInterval(wait); resolve(); }
          }, 50);
        });
      }
      return new Promise((resolve, reject) => {
        const script = document.createElement("script");
        script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
        script.async = true;
        script.dataset.cfTurnstile = "1";
        script.onload = () => resolve();
        script.onerror = () => reject(new Error("turnstile_load_failed"));
        document.head.appendChild(script);
      });
    }

    async function startChallenge() {
      clearError();
      renderAttempt = 0;
      try {
        const siteKey = await resolveSiteKey();
        await loadTurnstileScript();
        renderTurnstile(siteKey);
      } catch {
        showError("Could not load Cloudflare Turnstile. Check your connection.");
      }
    }

    retryBtn?.addEventListener("click", () => {
      renderAttempt += 1;
      void startChallenge();
    });
    startChallenge();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
