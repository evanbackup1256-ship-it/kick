(() => {
  const TOKEN_KEY = "alleral_dev_token";
  const EXPIRES_KEY = "alleral_dev_expires";
  const base = window.ALLERAL_API || "";

  const loginPanel = document.getElementById("devLoginPanel");
  const dashboard = document.getElementById("devDashboard");
  const loginForm = document.getElementById("devLoginForm");
  const keyInput = document.getElementById("devKeyInput");
  const loginBtn = document.getElementById("devLoginBtn");
  const loginError = document.getElementById("devLoginError");
  const statusPill = document.getElementById("devStatusPill");
  const refreshBtn = document.getElementById("devRefreshBtn");
  const logoutBtn = document.getElementById("devLogoutBtn");

  function setStatus(label, online = false) {
    if (!statusPill) return;
    statusPill.innerHTML = `<span class="status-dot"></span>${label}`;
    statusPill.classList.toggle("online", online);
  }

  function showError(msg) {
    if (!loginError) return;
    loginError.textContent = msg || "";
    loginError.style.display = msg ? "block" : "none";
  }

  function token() {
    return sessionStorage.getItem(TOKEN_KEY) || "";
  }

  function clearSession() {
    sessionStorage.removeItem(TOKEN_KEY);
    sessionStorage.removeItem(EXPIRES_KEY);
  }

  function showLogin() {
    loginPanel?.classList.remove("hidden");
    dashboard?.classList.add("hidden");
    setStatus("Locked", false);
  }

  function showDashboard(expiresAt) {
    loginPanel?.classList.add("hidden");
    dashboard?.classList.remove("hidden");
    setStatus("Signed in", true);
    const el = document.getElementById("devExpires");
    if (el) el.textContent = expiresAt || sessionStorage.getItem(EXPIRES_KEY) || "—";
  }

  async function api(path, options = {}) {
    const headers = { ...(options.headers || {}) };
    const t = token();
    if (t) headers["X-Dev-Token"] = t;
    const res = await fetch(`${base}${path}`, { ...options, headers });
    const data = await res.json().catch(() => ({}));
    return { res, data };
  }

  function renderStatus(data) {
    document.getElementById("devVersion").textContent = data.version || "—";
    const commit = data.githubCommit || "—";
    document.getElementById("devCommit").innerHTML = `<code>${commit}</code>`;
    document.getElementById("devSync").textContent = data.autoSync ? "Enabled" : "Disabled";
    document.getElementById("devBans").textContent = String(data.bans ?? "—");
    if (data.expiresAt) {
      sessionStorage.setItem(EXPIRES_KEY, data.expiresAt);
      document.getElementById("devExpires").textContent = data.expiresAt;
    }
  }

  async function refreshStatus() {
    const { res, data } = await api("/api/dev/status");
    if (!res.ok || !data.ok) {
      clearSession();
      showLogin();
      showError("Session expired. Sign in again.");
      return false;
    }
    showDashboard(sessionStorage.getItem(EXPIRES_KEY));
    renderStatus(data);
    return true;
  }

  async function login(key) {
    showError("");
    loginBtn.disabled = true;
    try {
      const { res, data } = await api("/api/dev/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key }),
      });
      if (!res.ok || !data.ok) {
        const msg = data.error === "disabled"
          ? "Dev login is not configured on the server."
          : data.error === "rate_limited"
            ? "Too many attempts. Wait a minute."
            : "Invalid access key.";
        showError(msg);
        return;
      }
      sessionStorage.setItem(TOKEN_KEY, data.token);
      if (data.expiresAt) sessionStorage.setItem(EXPIRES_KEY, data.expiresAt);
      keyInput.value = "";
      showDashboard(data.expiresAt);
      await refreshStatus();
    } catch {
      showError("Could not reach the relay. Check your connection.");
    } finally {
      loginBtn.disabled = false;
    }
  }

  loginForm?.addEventListener("submit", () => {
    const key = (keyInput?.value || "").trim();
    if (!key) {
      showError("Enter your dev access key.");
      return;
    }
    login(key);
  });

  refreshBtn?.addEventListener("click", () => refreshStatus());
  logoutBtn?.addEventListener("click", async () => {
    await api("/api/dev/logout", { method: "POST" }).catch(() => null);
    clearSession();
    showLogin();
    showError("");
  });

  if (token()) {
    refreshStatus().then((ok) => {
      if (!ok) showLogin();
    });
  } else {
    showLogin();
  }
})();
