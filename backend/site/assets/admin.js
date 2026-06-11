(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const STATUSES = ["working", "detected", "broken", "maintenance", "testing"];
  const TOKEN_KEY = "alleral_admin_token";
  const toast = $("#toast");
  const errorEl = $("#error");
  const adminKey = $("#adminKey");
  const adminStatus = $("#adminStatus");
  let activeTab = "scripts";
  let authReady = false;
  let authFailed = false;
  let banSearchTimer = 0;

  if (localStorage.getItem("alleral_admin_key")) {
    adminKey.value = localStorage.getItem("alleral_admin_key");
  }

  function apiBase() {
    const cfg = window.ALLERAL_API || "";
    if (cfg) return cfg.replace(/\/+$/, "");
    return window.location.origin.replace(/\/+$/, "");
  }

  function adminToken() {
    return sessionStorage.getItem(TOKEN_KEY) || "";
  }

  function titleCase(value) {
    const text = String(value || "").toLowerCase();
    return text.charAt(0).toUpperCase() + text.slice(1);
  }

  function flash(text, isError = false) {
    if (!toast) return;
    toast.textContent = text;
    toast.classList.toggle("error", isError);
    toast.classList.add("show");
    setTimeout(() => toast.classList.remove("show"), 2200);
  }

  function headers() {
    const h = { "Content-Type": "application/json" };
    const token = adminToken();
    if (token) {
      h["X-Admin-Token"] = token;
      return h;
    }
    const key = adminKey?.value?.trim() || "";
    if (key) h["X-Admin-Key"] = key;
    return h;
  }

  function setAdminStatus(label, online = false) {
    if (!adminStatus) return;
    adminStatus.innerHTML = `<span class="status-dot"></span>${label}`;
    adminStatus.classList.toggle("online", online);
  }

  async function loginAdmin(silent = false) {
    authFailed = false;
    const key = adminKey?.value?.trim() || "";
    if (!key) {
      authReady = false;
      setAdminStatus("No key", false);
      if (!silent) errorEl.textContent = "Enter your ADMIN_API_KEY from Railway.";
      return false;
    }
    try {
      const res = await fetch(`${apiBase()}/api/admin/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key }),
      });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        authReady = false;
        authFailed = true;
        sessionStorage.removeItem(TOKEN_KEY);
        setAdminStatus("Auth failed", false);
        const hint = data.hint ? ` ${data.hint}` : "";
        errorEl.textContent = (data.error === "unauthorized"
          ? "Invalid admin key — use ADMIN_API_KEY from Railway."
          : data.error || "Login failed") + hint;
        if (!silent) flash("Admin login failed", true);
        return false;
      }
      sessionStorage.setItem(TOKEN_KEY, data.token);
      authReady = true;
      authFailed = false;
      setAdminStatus("Signed in", true);
      errorEl.textContent = "";
      if (!silent) flash("Admin session active");
      return true;
    } catch (e) {
      authReady = false;
      authFailed = true;
      errorEl.textContent = e.message || "Could not reach relay";
      setAdminStatus("Offline", false);
      return false;
    }
  }

  async function ensureAuth(force = false) {
    if (authReady && !force) return true;
    if (authFailed && !force) return false;
    const token = adminToken();
    if (token && !force) {
      try {
        const res = await fetch(`${apiBase()}/api/admin/status`, {
          headers: { "X-Admin-Token": token },
          cache: "no-store",
        });
        const data = await res.json();
        if (res.ok && data.ok) {
          authReady = true;
          authFailed = false;
          setAdminStatus("Signed in", true);
          return true;
        }
        sessionStorage.removeItem(TOKEN_KEY);
      } catch {
        /* fall through to login */
      }
    }
    return loginAdmin(true);
  }

  function handleAuthError(data) {
    if (data?.error === "unauthorized") {
      authReady = false;
      authFailed = true;
      sessionStorage.removeItem(TOKEN_KEY);
      setAdminStatus("Session expired", false);
      errorEl.textContent = "Session expired — click Sign In again.";
    }
  }

  function animatePanel(panel) {
    if (!panel) return;
    panel.classList.remove("tab-panel-enter");
    void panel.offsetWidth;
    panel.classList.add("tab-panel-enter");
  }

  function setTab(name) {
    activeTab = name;
    $$(".admin-tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === name));
    $$("[data-tab-panel]").forEach((p) => {
      const show = p.dataset.tabPanel === name;
      p.classList.toggle("hidden", !show);
      if (show) animatePanel(p);
    });
    errorEl.textContent = "";
    if (name === "scripts") loadScripts();
    if (name === "bans") void loadBans();
    if (name === "stats") loadStats();
    if (name === "site") loadSiteEditor();
  }

  async function loadScripts() {
    const root = $("#scriptsGrid");
    root.innerHTML = '<p class="empty">Loading scripts…</p>';
    try {
      const res = await fetch(`${apiBase()}/scripts`);
      const data = await res.json();
      if (!data.ok) {
        errorEl.textContent = data.error || "Failed to load scripts";
        root.innerHTML = "";
        return;
      }
      root.innerHTML = "";
      const ids = Object.keys(data.scripts || {}).sort();
      if (!ids.length) {
        root.innerHTML = '<p class="empty">No scripts found.</p>';
        return;
      }
      ids.forEach((id, i) => renderScriptCard(id, data.scripts[id], root, i));
    } catch (e) {
      errorEl.textContent = e.message;
      root.innerHTML = "";
    }
  }

  function renderScriptCard(id, entry, root, index) {
    const status = (entry.status || "working").toLowerCase();
    const card = document.createElement("article");
    card.className = "panel admin-card card-enter";
    card.style.animationDelay = `${index * 0.05}s`;
    card.innerHTML = `
      <div class="modal-head">
        <div>
          <h3>${entry.name || id}</h3>
          <p class="modal-meta">${id} · v${entry.version || "?"} · ${entry.updatedAt || "?"}</p>
        </div>
        <span class="status-chip ${status}">${titleCase(status)}</span>
      </div>
      <p class="modal-desc">${entry.message || "No status message."}</p>
      <form class="form admin-script-form">
        <label>Status
          <div class="select-wrap">
            <select data-f="status" class="field-select" disabled title="Auto-managed from telemetry">${STATUSES.map((s) => `<option value="${s}" ${s === status ? "selected" : ""}>${titleCase(s)}</option>`).join("")}</select>
          </div>
        </label>
        <p class="admin-auto-note">Status is computed automatically from inject telemetry (48h window).</p>
        <label>Version<input data-f="version" class="field-input" value="${entry.version || ""}" /></label>
        <label>Message<textarea data-f="message" class="field-textarea">${entry.message || ""}</textarea></label>
        <button class="btn btn-fill" type="submit">Save Script</button>
      </form>`;
    card.querySelector("form").addEventListener("submit", async (ev) => {
      ev.preventDefault();
      if (!(await ensureAuth())) return;
      const payload = {};
      card.querySelectorAll("[data-f]").forEach((el) => { payload[el.dataset.f] = el.value; });
      const res = await fetch(`${apiBase()}/scripts/${encodeURIComponent(id)}`, {
        method: "PATCH",
        headers: headers(),
        body: JSON.stringify(payload),
      });
      const out = await res.json();
      if (!res.ok || !out.ok) {
        handleAuthError(out);
        errorEl.textContent = out.error || "Save failed";
        return;
      }
      flash(`Updated ${id}`);
      loadScripts();
    });
    root.appendChild(card);
  }

  async function loadBans() {
    const root = $("#bansGrid");
    if (!(await ensureAuth())) {
      root.innerHTML = '<p class="empty">Sign in with your admin key to view bans.</p>';
      return;
    }
    if (authFailed) return;
    root.innerHTML = '<p class="empty">Loading bans…</p>';
    try {
      const q = encodeURIComponent($("#banSearch")?.value?.trim() || "");
      const res = await fetch(`${apiBase()}/admin/bans?q=${q}`, { headers: headers(), cache: "no-store" });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        handleAuthError(data);
        errorEl.textContent = data.error || "Failed to load bans";
        root.innerHTML = "";
        return;
      }
      root.innerHTML = "";
      if (!(data.bans || []).length) {
        root.innerHTML = '<p class="empty">No active bans match your search.</p>';
        return;
      }
      data.bans.forEach((ban, i) => {
        const card = document.createElement("article");
        card.className = "panel admin-card card-enter";
        card.style.animationDelay = `${i * 0.04}s`;
        card.innerHTML = `
          <div class="modal-head">
            <div>
              <h3>${ban.player_name || ban.value}</h3>
              <p class="modal-meta">#${ban.id} · ${titleCase(ban.ban_type)} · ${ban.value}${ban.roblox_user_id ? ` · Roblox ${ban.roblox_user_id}` : ""}</p>
            </div>
            <span class="status-chip broken">${titleCase(ban.ban_type)}</span>
          </div>
          <p class="modal-desc">${ban.reason || "No reason provided."}</p>
          <button class="btn btn-outline" type="button">Remove Ban</button>`;
        card.querySelector("button").onclick = async () => {
          if (!(await ensureAuth())) return;
          const del = await fetch(`${apiBase()}/admin/bans/${ban.id}`, { method: "DELETE", headers: headers() });
          const out = await del.json();
          if (!del.ok || !out.ok) {
            handleAuthError(out);
            errorEl.textContent = out.error || "Remove failed";
            return;
          }
          flash(`Removed ban #${ban.id}`);
          loadBans();
        };
        root.appendChild(card);
      });
    } catch (e) {
      errorEl.textContent = e.message;
      root.innerHTML = "";
    }
  }

  async function loadStats() {
    const root = $("#statsGrid");
    root.innerHTML = '<p class="empty">Loading stats…</p>';
    const base = apiBase();
    try {
      const [health, banStatus, site, sync] = await Promise.all([
        fetch(`${base}/health`).then((r) => r.json()),
        fetch(`${base}/api/ban/status`).then((r) => r.json()),
        fetch(`${base}/api/site`).then((r) => r.json()),
        fetch(`${base}/api/sync/status`).then((r) => r.json()),
      ]);
      const games = Object.values(site.games || {});
      const working = games.filter((g) => (g.status || "").toLowerCase() === "working").length;
      root.innerHTML = `
        <article class="stat-card card-enter"><span class="stat-card-label">Relay Version</span><strong>v${health.version || "?"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.05s"><span class="stat-card-label">GitHub Commit</span><strong>${sync.commit || health.githubCommit || "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.1s"><span class="stat-card-label">Last Auto Sync</span><strong>${sync.lastSyncAt ? new Date(sync.lastSyncAt).toLocaleTimeString() : "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.15s"><span class="stat-card-label">Active Bans</span><strong>${banStatus.activeBans ?? health.bans ?? 0}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.2s"><span class="stat-card-label">Games Listed</span><strong>${games.length}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.25s"><span class="stat-card-label">Working Scripts</span><strong>${working}</strong></article>
      `;
    } catch (e) {
      root.innerHTML = `<p class="empty">${e.message}</p>`;
    }
  }

  async function addBan() {
    if (!(await ensureAuth())) return;
    const payload = {
      banType: $("#banType").value,
      value: $("#banValue").value.trim(),
      playerName: $("#banPlayer").value.trim(),
      reason: $("#banReason").value.trim(),
    };
    if (!payload.value) { errorEl.textContent = "Ban value is required."; return; }
    const res = await fetch(`${apiBase()}/admin/bans`, { method: "POST", headers: headers(), body: JSON.stringify(payload) });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      handleAuthError(data);
      errorEl.textContent = data.error || "Ban failed";
      return;
    }
    $("#banValue").value = "";
    $("#banPlayer").value = "";
    $("#banReason").value = "";
    flash("Ban added");
    loadBans();
  }

  async function banRobloxPlayer() {
    if (!(await ensureAuth())) return;
    const payload = {
      username: $("#robloxUsername").value.trim(),
      userId: $("#robloxUserId").value.trim(),
      hwid: $("#robloxHwid").value.trim(),
      fingerprint: $("#robloxFingerprint").value.trim(),
      reason: $("#robloxReason").value.trim(),
      cascade: $("#robloxCascade").checked,
    };
    if (!payload.username && !payload.userId && !payload.hwid && !payload.fingerprint) {
      errorEl.textContent = "Provide a Roblox username, UserId, or hardware identifier.";
      return;
    }
    const res = await fetch(`${apiBase()}/admin/bans/roblox`, {
      method: "POST",
      headers: headers(),
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      handleAuthError(data);
      errorEl.textContent = data.error || "Roblox ban failed";
      return;
    }
    flash(`Banned ${data.bans?.length || 1} identifier(s)`);
    loadBans();
  }

  async function loadSiteEditor() {
    const res = await fetch(`${apiBase()}/api/site`);
    const site = await res.json();
    $("#siteTagline").value = site.tagline || "";
    $("#siteAnnouncement").value = site.announcement || "";
    $("#siteLoaderVersion").value = site.loaderVersion || "";
    $("#siteLoadstring").value = site.loadstring || "";
    $("#siteFeatures").value = (site.features || []).join("\n");
    $("#siteFaq").value = JSON.stringify(site.faq || [], null, 2);
  }

  async function saveSite() {
    if (!(await ensureAuth())) return;
    let faq = [];
    try {
      faq = JSON.parse($("#siteFaq").value || "[]");
    } catch {
      errorEl.textContent = "FAQ must be valid JSON array";
      return;
    }
    const payload = {
      tagline: $("#siteTagline").value.trim(),
      announcement: $("#siteAnnouncement").value.trim(),
      loaderVersion: $("#siteLoaderVersion").value.trim(),
      loadstring: $("#siteLoadstring").value.trim(),
      features: $("#siteFeatures").value.split("\n").map((l) => l.trim()).filter(Boolean),
      faq,
    };
    const res = await fetch(`${apiBase()}/api/site`, { method: "PATCH", headers: headers(), body: JSON.stringify(payload) });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      handleAuthError(data);
      errorEl.textContent = data.error || "Site save failed";
      return;
    }
    flash("Site content saved");
  }

  $("#saveKey")?.addEventListener("click", () => {
    localStorage.setItem("alleral_admin_key", adminKey.value.trim());
    flash("Key remembered locally");
  });

  $("#signInAdmin")?.addEventListener("click", () => {
    void loginAdmin(false).then((ok) => {
      if (ok && activeTab === "bans") void loadBans();
    });
  });

  $("#reload")?.addEventListener("click", () => {
    authFailed = false;
    void ensureAuth(true).then(() => setTab(activeTab));
  });

  $$(".admin-tabs button").forEach((b) => {
    b.onclick = () => setTab(b.dataset.tab);
  });
  $("#addBan")?.addEventListener("click", () => void addBan());
  $("#banRobloxPlayer")?.addEventListener("click", () => void banRobloxPlayer());
  $("#banSearch")?.addEventListener("input", () => {
    if (authFailed || !authReady) return;
    clearTimeout(banSearchTimer);
    banSearchTimer = setTimeout(() => void loadBans(), 300);
  });
  $("#saveSite")?.addEventListener("click", () => void saveSite());

  window.addEventListener("scroll", () => {
    $("#siteNav")?.classList.toggle("nav-scrolled", window.scrollY > 8);
  }, { passive: true });

  void ensureAuth(true).then((ok) => {
    if (!ok) setAdminStatus("Sign in required", false);
    setTab("scripts");
  });

  setInterval(() => {
    if (activeTab === "scripts") loadScripts();
    if (activeTab === "stats") loadStats();
  }, 30000);
})();
