(() => {
  const STORAGE_KEY = "alleral_gate_ok";
  const cfg = window.ALLERAL_CONFIG || {};
  const FALLBACK_SITE_KEY = "1x00000000000000000000AA";
  const INTERACTIVE_SITE_KEY = "3x00000000000000000000FF";

  function randomRay() {
    const hex = "0123456789abcdef";
    let id = "";
    for (let i = 0; i < 16; i += 1) id += hex[Math.floor(Math.random() * 16)];
    return id;
  }

  function unlockPage() {
    document.documentElement.classList.remove("cf-gate-lock");
    document.body?.classList.remove("cf-gate-lock");
  }

  function finish(gate) {
    sessionStorage.setItem(STORAGE_KEY, "1");
    unlockPage();
    if (gate) {
      gate.classList.add("cf-gate-out");
      setTimeout(() => gate.remove(), 650);
    }
    window.dispatchEvent(new CustomEvent("alleral:gate-passed"));
  }

  function boot() {
    if (sessionStorage.getItem(STORAGE_KEY)) return;
    if (!document.body) return;

    document.documentElement.classList.add("cf-gate-lock");
    document.body.classList.add("cf-gate-lock");

    const gate = document.createElement("div");
    gate.id = "cfGate";
    gate.setAttribute("role", "dialog");
    gate.setAttribute("aria-modal", "true");
    gate.setAttribute("aria-label", "Security check");
    gate.innerHTML = `
      <div class="cf-gate-backdrop" aria-hidden="true"></div>
      <div class="cf-gate-card cf-gate-enter">
        <div class="cf-cloud" aria-hidden="true">
          <svg viewBox="0 0 64 40" width="52" height="32">
            <path fill="#f6821f" d="M19 31c-6.1 0-11-4.9-11-11 0-5.2 3.6-9.6 8.5-10.8C18.2 4.8 23.5 1 29.6 1c7.2 0 13.2 5.1 14.6 11.9 5.5.4 9.8 5.1 9.8 10.8 0 6.1-4.9 11-11 11H19z"/>
          </svg>
        </div>
        <h1 class="cf-gate-title">Just a Moment</h1>
        <p class="cf-gate-lead">Complete the security check to access Alleral Hub.</p>
        <ul class="cf-steps" id="cfSteps">
          <li data-step="browser"><span class="cf-check"></span> Checking your browser</li>
          <li data-step="human"><span class="cf-check"></span> Waiting for verification</li>
          <li data-step="edge"><span class="cf-check"></span> Establishing secure connection</li>
        </ul>
        <div class="cf-progress"><div class="cf-progress-bar" id="cfBar"></div></div>
        <div class="cf-captcha-wrap">
          <p class="cf-captcha-label">Verify you are human</p>
          <div id="cfTurnstile" class="cf-turnstile"></div>
          <p id="cfGateError" class="cf-gate-error hidden"></p>
        </div>
        <p class="cf-ray">Ray ID: <code id="cfRay">${randomRay()}</code></p>
        <p class="cf-powered">Performance &amp; security by <strong>Cloudflare</strong></p>
      </div>
    `;

    document.body.prepend(gate);

    const steps = gate.querySelectorAll(".cf-steps li");
    const bar = gate.querySelector("#cfBar");
    const errorEl = gate.querySelector("#cfGateError");
    let stepIndex = 0;
    let stepTimer = null;
    let verified = false;
    let renderAttempt = 0;

    function tickStep() {
      if (stepIndex > 0) steps[stepIndex - 1].classList.add("done");
      if (stepIndex < steps.length) {
        steps[stepIndex].classList.add("active");
        bar.style.width = `${((stepIndex + 1) / (steps.length + 1)) * 65}%`;
        stepIndex += 1;
        return stepIndex <= steps.length;
      }
      return false;
    }

    tickStep();
    stepTimer = setInterval(() => {
      if (!tickStep()) clearInterval(stepTimer);
    }, 700);

    function showError(msg) {
      if (!errorEl) return;
      errorEl.textContent = msg;
      errorEl.classList.remove("hidden");
    }

    async function resolveSiteKey() {
      const local = (cfg.turnstileSiteKey || "").trim();
      if (local) return local;
      const base = window.ALLERAL_API || "";
      try {
        const res = await fetch(`${base}/api/gate/config`, { cache: "no-store" });
        const data = await res.json();
        if (data.ok && data.siteKey) return data.siteKey;
      } catch {
        /* use interactive default */
      }
      return INTERACTIVE_SITE_KEY;
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

    function complete(token) {
      if (verified) return;
      verified = true;
      clearInterval(stepTimer);
      bar.style.width = "100%";
      steps.forEach((s) => {
        s.classList.add("done");
        s.classList.remove("active");
      });
      verifyToken(token).then((ok) => {
        if (!ok) {
          verified = false;
          showError("Verification failed. Please complete the captcha again.");
          if (window.turnstile && gate.querySelector("#cfTurnstile")) {
            window.turnstile.reset(gate.querySelector("#cfTurnstile"));
          }
          return;
        }
        setTimeout(() => finish(gate), 350);
      });
    }

    function renderTurnstile(siteKey) {
      const mount = gate.querySelector("#cfTurnstile");
      if (!mount || !window.turnstile) {
        showError("Captcha failed to load. Refresh the page to try again.");
        return;
      }
      mount.innerHTML = "";
      window.turnstile.render(mount, {
        sitekey: siteKey,
        theme: "dark",
        size: "normal",
        callback: (token) => complete(token),
        "error-callback": () => {
          if (renderAttempt < 1) {
            renderAttempt += 1;
            renderTurnstile(FALLBACK_SITE_KEY);
            return;
          }
          showError("Captcha error. Refresh the page to try again.");
        },
        "expired-callback": () => {
          verified = false;
          showError("Captcha expired. Complete it again.");
        },
      });
    }

    resolveSiteKey().then((siteKey) => {
      const script = document.createElement("script");
      script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      script.async = true;
      script.onload = () => renderTurnstile(siteKey);
      script.onerror = () => showError("Could not load captcha. Refresh the page.");
      document.head.appendChild(script);
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
