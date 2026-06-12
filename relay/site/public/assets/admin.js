(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const STATUSES = ["working", "detected", "broken", "maintenance", "testing"];
  const TOKEN_KEY = "alleral_admin_token";
  const TOKEN_EXP_KEY = "alleral_admin_token_exp";
  const REMEMBER_KEY = "alleral_admin_remember";
  const KEY_KEY = "alleral_admin_key";

  const toast = $("#toast");
  const errorEl = $("#error");
  const adminKey = $("#adminKey");
  const adminStatus = $("#adminStatus");
  const rememberAdmin = $("#rememberAdmin");
  const sessionLabel = $("#sessionLabel");
  const sessionExpiry = $("#sessionExpiry");
  const signOutBtn = $("#signOutAdmin");
  const refreshSessionBtn = $("#refreshSession");

  let activeTab = "scripts";
  let authReady = false;
  let authFailed = false;
  let authBusy = false;
  let banSearchTimer = 0;
  let playerSearchTimer = 0;
  let playerSearchSeq = 0;
  let selectedPlayer = null;
  let banTypeFilter = "all";
  let cachedBans = [];
  let activeBanSubtab = "manage";

  if (localStorage.getItem(KEY_KEY)) {
    adminKey.value = localStorage.getItem(KEY_KEY);
  }
  if (localStorage.getItem(REMEMBER_KEY) === "1") {
    rememberAdmin.checked = true;
  }

  function apiBase() {
    const cfg = window.ALLERAL_API || "";
    if (cfg) return cfg.replace(/\/+$/, "");
    return window.location.origin.replace(/\/+$/, "");
  }

  function esc(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/"/g, "&quot;");
  }

  function rememberEnabled() {
    return rememberAdmin?.checked !== false;
  }

  function adminToken() {
    const remembered = localStorage.getItem(REMEMBER_KEY) === "1";
    if (remembered) {
      const token = localStorage.getItem(TOKEN_KEY) || "";
      const exp = Number(localStorage.getItem(TOKEN_EXP_KEY) || 0);
      if (token && exp && Date.now() < exp) return token;
      clearStoredToken(false);
    }
    return sessionStorage.getItem(TOKEN_KEY) || "";
  }

  function storeToken(token, expiresAt, remember) {
    sessionStorage.setItem(TOKEN_KEY, token);
    if (remember) {
      localStorage.setItem(TOKEN_KEY, token);
      localStorage.setItem(REMEMBER_KEY, "1");
      const ms = expiresAt ? Date.parse(expiresAt) : Date.now() + 86400000;
      localStorage.setItem(TOKEN_EXP_KEY, String(Number.isFinite(ms) ? ms : Date.now() + 86400000));
    } else {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(TOKEN_EXP_KEY);
      localStorage.removeItem(REMEMBER_KEY);
    }
    updateSessionUi(expiresAt, remember);
  }

  function clearStoredToken(clearKey = false) {
    sessionStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(TOKEN_EXP_KEY);
    if (clearKey) {
      localStorage.removeItem(KEY_KEY);
      if (adminKey) adminKey.value = "";
    }
    authReady = false;
    updateSessionUi(null, false);
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

  function storedAdminKey() {
    return adminKey?.value?.trim() || localStorage.getItem(KEY_KEY) || "";
  }

  function hasAdminCredentials() {
    return Boolean(adminToken() || storedAdminKey());
  }

  function headers() {
    const h = { "Content-Type": "application/json" };
    const token = adminToken();
    if (token) h["X-Admin-Token"] = token;
    const key = storedAdminKey();
    if (key) h["X-Admin-Key"] = key;
    return h;
  }

  function setAdminStatus(label, online = false) {
    if (!adminStatus) return;
    adminStatus.innerHTML = `<span class="status-dot"></span>${label}`;
    adminStatus.classList.toggle("online", online);
  }

  function updateSessionUi(expiresAt, signedIn) {
    if (sessionLabel) {
      sessionLabel.textContent = signedIn ? "Signed in" : "Not signed in";
    }
    if (sessionExpiry) {
      if (signedIn && expiresAt) {
        const date = new Date(expiresAt);
        sessionExpiry.textContent = Number.isFinite(date.getTime())
          ? `Expires ${date.toLocaleString()}`
          : "";
      } else {
        sessionExpiry.textContent = "";
      }
    }
    signOutBtn?.classList.toggle("hidden", !signedIn);
    refreshSessionBtn?.classList.toggle("hidden", !signedIn);
  }

  async function loginAdmin(silent = false) {
    if (authBusy) return authReady;
    authBusy = true;
    authFailed = false;
    const key = adminKey?.value?.trim() || localStorage.getItem(KEY_KEY) || "";
    if (!key) {
      authReady = false;
      setAdminStatus("No key", false);
      if (!silent) errorEl.textContent = "Enter your ADMIN_API_KEY from Railway.";
      authBusy = false;
      return false;
    }
    try {
      const remember = rememberEnabled();
      const res = await fetch(`${apiBase()}/api/admin/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key, remember }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.ok) {
        authReady = false;
        authFailed = true;
        clearStoredToken(false);
        setAdminStatus("Auth failed", false);
        const hint = data.hint ? ` ${data.hint}` : "";
        errorEl.textContent = (data.error === "unauthorized"
          ? "Invalid admin key — use ADMIN_API_KEY from Railway."
          : data.error || "Login failed") + hint;
        if (!silent) flash("Admin login failed", true);
        authBusy = false;
        return false;
      }
      storeToken(data.token, data.expiresAt, remember || data.remember);
      authReady = true;
      authFailed = false;
      setAdminStatus("Signed in", true);
      errorEl.textContent = "";
      if (!silent) flash("Admin session active");
      authBusy = false;
      return true;
    } catch (e) {
      authReady = false;
      authFailed = true;
      errorEl.textContent = e.message || "Could not reach relay";
      setAdminStatus("Offline", false);
      authBusy = false;
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
        const data = await res.json().catch(() => ({}));
        if (res.ok && data.ok) {
          authReady = true;
          authFailed = false;
          setAdminStatus("Signed in", true);
          updateSessionUi(data.expiresAt, true);
          return true;
        }
        clearStoredToken(false);
      } catch {
        /* fall through to login */
      }
    }
    return loginAdmin(true);
  }

  async function recoverAuth() {
    authFailed = false;
    clearStoredToken(false);
    return loginAdmin(true);
  }

  function handleAuthError(data) {
    if (data?.error !== "unauthorized") return false;
    authReady = false;
    setAdminStatus("Session expired", false);
    const key = adminKey?.value?.trim() || localStorage.getItem(KEY_KEY) || "";
    if (key) {
      void recoverAuth().then((ok) => {
        if (ok) {
          errorEl.textContent = "";
          flash("Session refreshed");
          if (activeTab === "bans") void loadBans();
        } else {
          authFailed = true;
          errorEl.textContent = "Session expired — click Sign In again.";
        }
      });
      return true;
    }
    authFailed = true;
    clearStoredToken(false);
    errorEl.textContent = "Session expired — click Sign In again.";
    return true;
  }

  async function signOut() {
    const token = adminToken();
    if (token) {
      try {
        await fetch(`${apiBase()}/api/admin/logout`, {
          method: "POST",
          headers: { "X-Admin-Token": token },
        });
      } catch {
        /* ignore */
      }
    }
    authFailed = false;
    clearStoredToken(false);
    setAdminStatus("Signed out", false);
    errorEl.textContent = "";
    flash("Signed out");
    if (activeTab === "bans") {
      $("#bansGrid").innerHTML = '<div class="panel admin-empty-auth"><strong>Sign in required</strong>Enter your admin key above to manage bans.</div>';
    }
  }

  function animatePanel(panel) {
    if (!panel) return;
    panel.classList.remove("tab-panel-enter");
    void panel.offsetWidth;
    panel.classList.add("tab-panel-enter");
  }

  function setBanSubtab(name) {
    activeBanSubtab = name;
    $$("[data-ban-subtab]").forEach((btn) => {
      btn.classList.toggle("active", btn.dataset.banSubtab === name);
    });
    $$("[data-ban-subpanel]").forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.banSubpanel !== name);
    });
    if (name === "partner") void loadPartnerBanApi();
  }

  async function loadPartnerBanApi() {
    const statusRoot = $("#partnerBanApiStatus");
    const endpointsRoot = $("#partnerBanApiEndpoints");
    const exampleRoot = $("#partnerBanApiExample");
    const docsLink = $("#partnerDocsLink");
    const keyRow = $("#partnerKeyRow");
    const keyInput = $("#partnerApiKey");
    const docsUrl = `${apiBase()}/api/v1/bans/docs`;
    if (docsLink) docsLink.href = docsUrl;

    if (statusRoot) statusRoot.innerHTML = `<p class="empty">Loading Ban API docs…</p>`;
    try {
      const res = await fetch(docsUrl, { cache: "no-store" });
      const data = await res.json();
      if (statusRoot) {
        statusRoot.innerHTML = `
          <div class="ban-api-stat"><span>Active bans</span><strong>${esc(data.activeBans ?? "—")}</strong></div>
          <div class="ban-api-stat"><span>API version</span><strong>v${esc(data.version || "1")}</strong></div>
          <div class="ban-api-stat"><span>Status</span><strong>${data.partnerApi ? "Auto-enabled" : "Off"}</strong></div>
          <div class="ban-api-stat"><span>Endpoints</span><strong>${esc((data.endpoints || []).length)}</strong></div>
        `;
      }
      const endpoints = data.endpoints || [];
      if (endpointsRoot) {
        endpointsRoot.innerHTML = endpoints.map((ep) => `
          <article class="ban-api-endpoint">
            <div class="ban-api-endpoint-head">
              <span class="ban-api-method">${esc(ep.method || "GET")}</span>
              <code>${esc(ep.path || "")}</code>
              ${ep.auth ? `<span class="ban-api-auth">Auth</span>` : `<span class="ban-api-auth public">Public</span>`}
            </div>
            <p>${esc(ep.desc || "")}</p>
          </article>
        `).join("");
      }
      const example = data.checkExample || {};
      if (exampleRoot && example.body) {
        exampleRoot.textContent = JSON.stringify(example.body, null, 2);
      } else if (exampleRoot) {
        exampleRoot.textContent = "No example available.";
      }
    } catch (e) {
      if (statusRoot) statusRoot.innerHTML = `<p class="empty">${esc(e.message || "Could not load Ban API docs.")}</p>`;
    }

    if (await ensureAuth(false)) {
      try {
        const keyRes = await fetch(`${apiBase()}/api/admin/ban-api/key`, { headers: headers() });
        const keyData = await keyRes.json();
        if (keyRes.ok && keyData.ok && keyInput) {
          keyInput.value = keyData.key || "";
          keyRow?.classList.remove("hidden");
        }
      } catch {
        /* ignore */
      }
    }
  }

  async function runPartnerBanCheck() {
    if (!(await ensureAuth())) return;
    const out = $("#partnerBanTestResult");
    const userId = $("#partnerBanUserId")?.value.trim() || "";
    const username = $("#partnerBanUsername")?.value.trim() || "";
    if (!userId && !username) {
      flash("Enter a Roblox UserId or username", true);
      return;
    }
    try {
      const res = await fetch(`${apiBase()}/api/v1/bans/check`, {
        method: "POST",
        headers: headers(),
        body: JSON.stringify({
          player: { userId: userId || undefined, name: username || undefined },
        }),
      });
      const data = await res.json();
      if (out) {
        out.textContent = JSON.stringify(data, null, 2);
        out.classList.toggle("banned", data.allowed === false);
        out.classList.toggle("allowed", data.allowed === true);
      }
      if (!res.ok) flash(data.error || "Check failed", true);
      else flash(data.allowed ? "Player allowed" : "Player banned");
    } catch (e) {
      if (out) out.textContent = e.message || "Request failed";
      flash("Ban check failed", true);
    }
  }

  function setTab(name) {
    activeTab = name;
    $$(".admin-tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === name));
    $$("[data-tab-panel]").forEach((p) => {
      const show = p.dataset.tabPanel === name;
      p.classList.toggle("hidden", !show);
      if (show) animatePanel(p);
    });
    if (name !== "bans") errorEl.textContent = "";
    if (name === "scripts") loadScripts();
    if (name === "bans") {
      if (activeBanSubtab === "partner") void loadPartnerBanApi();
      else void loadBans();
    }
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
          <h3>${esc(entry.name || id)}</h3>
          <p class="modal-meta">${esc(id)} · v${esc(entry.version || "?")} · ${esc(entry.updatedAt || "?")}</p>
        </div>
        <span class="status-chip ${status}">${titleCase(status)}</span>
      </div>
      <p class="modal-desc">${esc(entry.message || "No status message.")}</p>
      <form class="form admin-script-form">
        <label>Status
          <div class="select-wrap">
            <select data-f="status" class="field-select" disabled title="Auto-managed from telemetry">${STATUSES.map((s) => `<option value="${s}" ${s === status ? "selected" : ""}>${titleCase(s)}</option>`).join("")}</select>
          </div>
        </label>
        <p class="admin-auto-note">Status is computed automatically from inject telemetry (48h window).</p>
        <label>Version<input data-f="version" class="field-input" value="${esc(entry.version || "")}" /></label>
        <label>Message<textarea data-f="message" class="field-textarea">${esc(entry.message || "")}</textarea></label>
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
        if (!handleAuthError(out)) errorEl.textContent = out.error || "Save failed";
        return;
      }
      flash(`Updated ${id}`);
      loadScripts();
    });
    root.appendChild(card);
  }

  function filterBans(bans) {
    if (banTypeFilter === "all") return bans;
    return bans.filter((ban) => String(ban.ban_type || "").toLowerCase() === banTypeFilter);
  }

  function renderBanCards(bans) {
    const root = $("#bansGrid");
    const filtered = filterBans(bans);
    root.innerHTML = "";
    if (!filtered.length) {
      root.innerHTML = '<p class="empty">No active bans match your search.</p>';
      return;
    }
    filtered.forEach((ban, i) => {
      const profileUrl = ban.roblox_user_id
        ? `https://www.roblox.com/users/${ban.roblox_user_id}/profile`
        : (ban.ban_type === "userid" ? `https://www.roblox.com/users/${ban.value}/profile` : "");
      const card = document.createElement("article");
      card.className = "panel admin-card card-enter";
      card.style.animationDelay = `${i * 0.04}s`;
      card.innerHTML = `
        <div class="modal-head">
          <div>
            <h3>${esc(ban.player_name || ban.value)}</h3>
            <p class="modal-meta">#${ban.id} · ${titleCase(ban.ban_type)} · ${esc(ban.value)}${ban.roblox_user_id ? ` · Roblox ${esc(ban.roblox_user_id)}` : ""}</p>
          </div>
          <span class="status-chip broken">${titleCase(ban.ban_type)}</span>
        </div>
        <p class="modal-desc">${esc(ban.reason || "No reason provided.")}</p>
        <dl class="ban-card-meta-grid">
          <div>Created <span>${esc(ban.created_at || "—")}</span></div>
          <div>By <span>${esc(ban.created_by || "admin")}</span></div>
          ${ban.expires_at ? `<div>Expires <span>${esc(ban.expires_at)}</span></div>` : ""}
        </dl>
        <div class="ban-card-actions">
          <button class="btn btn-outline btn-sm" type="button" data-copy="${esc(ban.value)}">Copy Value</button>
          ${profileUrl ? `<a class="btn btn-outline btn-sm" href="${esc(profileUrl)}" target="_blank" rel="noopener">Profile</a>` : ""}
          <button class="btn btn-outline btn-sm" type="button" data-remove="${ban.id}">Remove Ban</button>
        </div>`;
      card.querySelector("[data-copy]")?.addEventListener("click", async () => {
        try {
          await navigator.clipboard.writeText(ban.value);
          flash("Copied ban value");
        } catch {
          flash("Copy failed", true);
        }
      });
      card.querySelector("[data-remove]")?.addEventListener("click", async () => {
        const label = ban.player_name || ban.value;
        if (!window.confirm(`Remove ban #${ban.id} for ${label}?`)) return;
        if (!(await ensureAuth())) return;
        const del = await fetch(`${apiBase()}/admin/bans/${ban.id}`, { method: "DELETE", headers: headers() });
        const out = await del.json();
        if (!del.ok || !out.ok) {
          if (!handleAuthError(out)) errorEl.textContent = out.error || "Remove failed";
          return;
        }
        flash(`Removed ban #${ban.id}`);
        loadBans();
      });
      root.appendChild(card);
    });
  }

  async function loadBans() {
    const root = $("#bansGrid");
    if (!hasAdminCredentials()) {
      root.innerHTML = '<div class="panel admin-empty-auth"><strong>Sign in required</strong>Enter your admin key above to search players and manage bans.</div>';
      $("#banCountLabel").innerHTML = 'Active bans: <strong>—</strong>';
      return;
    }
    if (!(await ensureAuth())) {
      root.innerHTML = '<div class="panel admin-empty-auth"><strong>Sign in required</strong>Enter your admin key above to search players and manage bans.</div>';
      $("#banCountLabel").innerHTML = 'Active bans: <strong>—</strong>';
      return;
    }
    if (authFailed) return;
    root.innerHTML = '<p class="empty">Loading bans…</p>';
    try {
      const q = encodeURIComponent($("#banSearch")?.value?.trim() || "");
      const res = await fetch(`${apiBase()}/admin/bans?q=${q}`, { headers: headers(), cache: "no-store" });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        if (!handleAuthError(data)) errorEl.textContent = data.error || "Failed to load bans";
        root.innerHTML = "";
        return;
      }
      cachedBans = data.bans || [];
      $("#banCountLabel").innerHTML = `Active bans: <strong>${cachedBans.length}</strong>`;
      renderBanCards(cachedBans);
    } catch (e) {
      errorEl.textContent = e.message;
      root.innerHTML = "";
    }
  }

  function setSelectedPlayer(player) {
    selectedPlayer = player;
    const preview = $("#playerPreview");
    if (!player) {
      preview?.classList.add("hidden");
      return;
    }
    preview?.classList.remove("hidden");
    $("#playerPreviewName").textContent = player.displayName || player.name || "Player";
    $("#playerPreviewMeta").textContent = `@${player.name || "?"} · ${player.id || "?"}`;
    const avatar = $("#playerPreviewAvatar");
    if (player.headshot) {
      avatar.src = player.headshot;
      avatar.alt = player.displayName || player.name || "Player avatar";
    } else {
      avatar.removeAttribute("src");
      avatar.alt = "";
    }
    const profile = player.profileUrl || `https://www.roblox.com/users/${player.id}/profile`;
    $("#playerPreviewProfile").href = profile;
    $("#robloxUsername").value = player.name || "";
    $("#robloxUserId").value = String(player.id || "");
  }

  function hidePlayerDropdown() {
    const dropdown = $("#playerLookupDropdown");
    dropdown?.classList.add("hidden");
    dropdown.innerHTML = "";
  }

  async function searchPlayers(query) {
    const dropdown = $("#playerLookupDropdown");
    if (!dropdown) return;
    const text = String(query || "").trim();
    if (text.length < 2) {
      hidePlayerDropdown();
      return;
    }
    if (!hasAdminCredentials()) {
      hidePlayerDropdown();
      return;
    }
    if (!(await ensureAuth())) {
      hidePlayerDropdown();
      return;
    }
    const seq = ++playerSearchSeq;
    dropdown.classList.remove("hidden");
    dropdown.innerHTML = '<button class="player-lookup-item" type="button" disabled>Searching…</button>';
    try {
      const res = await fetch(`${apiBase()}/api/admin/users/search?q=${encodeURIComponent(text)}&limit=10`, {
        headers: headers(),
        cache: "no-store",
      });
      const data = await res.json();
      if (seq !== playerSearchSeq) return;
      if (!res.ok || !data.ok) {
        if (handleAuthError(data)) {
          hidePlayerDropdown();
          return;
        }
        dropdown.innerHTML = `<button class="player-lookup-item" type="button" disabled>${esc(data.error || "Search failed")}</button>`;
        return;
      }
      const users = data.users || [];
      if (!users.length) {
        dropdown.innerHTML = '<button class="player-lookup-item" type="button" disabled>No players found</button>';
        return;
      }
      dropdown.innerHTML = users.map((user, index) => `
        <button class="player-lookup-item${index === 0 ? " focused" : ""}" type="button" data-index="${index}">
          ${user.headshot
            ? `<img class="player-lookup-avatar" src="${esc(user.headshot)}" alt="" width="40" height="40" />`
            : '<span class="player-lookup-avatar placeholder">?</span>'}
          <span class="player-lookup-copy">
            <strong>${esc(user.displayName || user.name)}</strong>
            <span>@${esc(user.name)} · ${user.id}</span>
          </span>
        </button>`).join("");
      dropdown.querySelectorAll(".player-lookup-item[data-index]").forEach((btn) => {
        btn.addEventListener("click", () => {
          const user = users[Number(btn.dataset.index)];
          setSelectedPlayer(user);
          hidePlayerDropdown();
        });
      });
    } catch (e) {
      if (seq !== playerSearchSeq) return;
      dropdown.innerHTML = `<button class="player-lookup-item" type="button" disabled>${esc(e.message || "Search error")}</button>`;
    }
  }

  async function loadStats() {
    const root = $("#statsGrid");
    const feedRoot = $("#telemetryFeed");
    root.innerHTML = '<p class="empty">Loading stats…</p>';
    if (feedRoot) feedRoot.innerHTML = '<p class="empty">Loading telemetry…</p>';
    const base = apiBase();
    try {
      const [health, banStatus, site, sync, telemetrySummary, telemetryRecent] = await Promise.all([
        fetch(`${base}/health`).then((r) => r.json()),
        fetch(`${base}/api/ban/status`).then((r) => r.json()),
        fetch(`${base}/api/site`).then((r) => r.json()),
        fetch(`${base}/api/sync/status`).then((r) => r.json()),
        fetch(`${base}/api/admin/telemetry/summary`, { headers: headers(), cache: "no-store" }).then((r) => r.json()).catch(() => ({ ok: false })),
        fetch(`${base}/api/admin/telemetry/recent?limit=30`, { headers: headers(), cache: "no-store" }).then((r) => r.json()).catch(() => ({ ok: false })),
      ]);
      const games = Object.values(site.games || {});
      const working = games.filter((g) => (g.status || "").toLowerCase() === "working").length;
      const summary = telemetrySummary.ok ? telemetrySummary.summary || {} : {};
      const successRate = summary.success_rate != null ? `${Math.round(summary.success_rate * 100)}%` : "—";
      root.innerHTML = `
        <article class="stat-card card-enter"><span class="stat-card-label">Relay Version</span><strong>v${esc(health.version || "?")}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.05s"><span class="stat-card-label">GitHub Commit</span><strong>${esc(sync.commit || health.githubCommit || "—")}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.1s"><span class="stat-card-label">Last Auto Sync</span><strong>${sync.lastSyncAt ? new Date(sync.lastSyncAt).toLocaleTimeString() : "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.15s"><span class="stat-card-label">Active Bans</span><strong>${banStatus.activeBans ?? health.bans ?? 0}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.2s"><span class="stat-card-label">48h Injects OK</span><strong>${summary.inject_loaded ?? "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.25s"><span class="stat-card-label">48h Inject Fail</span><strong>${summary.inject_failed ?? "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.3s"><span class="stat-card-label">48h Errors</span><strong>${summary.errors ?? summary.feed_errors ?? "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.35s"><span class="stat-card-label">48h Game Updates</span><strong>${summary.place_updated ?? "—"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.4s"><span class="stat-card-label">Inject Success</span><strong>${successRate}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.45s"><span class="stat-card-label">Games Listed</span><strong>${games.length}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.5s"><span class="stat-card-label">Working Scripts</span><strong>${working}</strong></article>
      `;
      if (feedRoot) {
        const items = telemetryRecent.ok ? telemetryRecent.items || [] : [];
        if (!items.length) {
          feedRoot.innerHTML = '<p class="empty">No recent telemetry events yet.</p>';
        } else {
          feedRoot.innerHTML = items.map((item) => {
            const build = item.previousPlaceVersion
              ? `build ${esc(item.previousPlaceVersion)} → ${esc(item.placeVersion || "?")}`
              : (item.placeVersion ? `build ${esc(item.placeVersion)}` : "");
            return `
              <article class="telemetry-feed-item">
                <div class="telemetry-feed-head">
                  <strong>${esc(item.event || "?")}</strong>
                  <span>${item.at ? new Date(item.at).toLocaleString() : "—"}</span>
                </div>
                <div class="telemetry-feed-meta">
                  ${esc(item.playerName || "?")} · ${esc(item.gameId || "?")} · ${esc(item.executor || "?")} · loader ${esc(item.loaderVersion || "?")}
                  ${build ? ` · ${build}` : ""}
                </div>
                <div class="telemetry-feed-message">${esc(item.message || "")}</div>
                ${item.details ? `<pre class="telemetry-feed-details">${esc(item.details)}</pre>` : ""}
              </article>`;
          }).join("");
        }
      }
    } catch (e) {
      root.innerHTML = `<p class="empty">${esc(e.message)}</p>`;
      if (feedRoot) feedRoot.innerHTML = "";
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
      if (!handleAuthError(data)) errorEl.textContent = data.error || "Ban failed";
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
      if (!handleAuthError(data)) errorEl.textContent = data.error || "Roblox ban failed";
      return;
    }
    flash(`Banned ${data.bans?.length || 1} identifier(s)`);
    $("#robloxReason").value = "";
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
      if (!handleAuthError(data)) errorEl.textContent = data.error || "Site save failed";
      return;
    }
    flash("Site content saved");
  }

  $("#saveKey")?.addEventListener("click", () => {
    localStorage.setItem(KEY_KEY, adminKey.value.trim());
    flash("Key remembered on this device");
  });

  $("#signInAdmin")?.addEventListener("click", () => {
    authFailed = false;
    void loginAdmin(false).then((ok) => {
      if (ok && activeTab === "bans") void loadBans();
    });
  });

  $("#signOutAdmin")?.addEventListener("click", () => void signOut());

  $("#refreshSession")?.addEventListener("click", () => {
    authFailed = false;
    void loginAdmin(false);
  });

  rememberAdmin?.addEventListener("change", () => {
    if (rememberAdmin.checked) {
      localStorage.setItem(REMEMBER_KEY, "1");
    } else {
      localStorage.removeItem(REMEMBER_KEY);
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(TOKEN_EXP_KEY);
    }
  });

  $("#reload")?.addEventListener("click", () => {
    authFailed = false;
    void ensureAuth(true).then(() => setTab(activeTab));
  });

  $$("[data-ban-subtab]").forEach((btn) => {
    btn.onclick = () => setBanSubtab(btn.dataset.banSubtab || "manage");
  });

  $("#partnerBanTestBtn")?.addEventListener("click", () => void runPartnerBanCheck());
  $("#partnerReloadDocs")?.addEventListener("click", () => void loadPartnerBanApi());
  $("#partnerCopyDocs")?.addEventListener("click", async () => {
    const url = `${apiBase()}/api/v1/bans/docs`;
    try {
      await navigator.clipboard.writeText(url);
      flash("Docs URL copied");
    } catch {
      flash("Copy failed", true);
    }
  });

  $("#partnerCopyKey")?.addEventListener("click", async () => {
    const key = $("#partnerApiKey")?.value || "";
    if (!key) return;
    try {
      await navigator.clipboard.writeText(key);
      flash("Partner key copied");
    } catch {
      flash("Copy failed", true);
    }
  });

  $("#partnerRevealKey")?.addEventListener("click", () => {
    const input = $("#partnerApiKey");
    if (!input) return;
    const show = input.type === "password";
    input.type = show ? "text" : "password";
    $("#partnerRevealKey").textContent = show ? "Hide" : "Show";
  });

  $$(".admin-tabs button").forEach((b) => {
    b.onclick = () => setTab(b.dataset.tab);
  });

  $$("[data-ban-filter]").forEach((btn) => {
    btn.addEventListener("click", () => {
      banTypeFilter = btn.dataset.banFilter || "all";
      $$("[data-ban-filter]").forEach((chip) => chip.classList.toggle("active", chip === btn));
      renderBanCards(cachedBans);
    });
  });

  $$(".admin-quick-reasons button").forEach((btn) => {
    btn.addEventListener("click", () => {
      $("#robloxReason").value = btn.dataset.reason || "";
    });
  });

  $("#addBan")?.addEventListener("click", () => void addBan());
  $("#banRobloxPlayer")?.addEventListener("click", () => void banRobloxPlayer());

  $("#banSearch")?.addEventListener("input", () => {
    if (!hasAdminCredentials() || !authReady || authFailed) return;
    clearTimeout(banSearchTimer);
    banSearchTimer = setTimeout(() => void loadBans(), 300);
  });

  $("#robloxUsername")?.addEventListener("input", (ev) => {
    setSelectedPlayer(null);
    clearTimeout(playerSearchTimer);
    const value = ev.target.value;
    if (!hasAdminCredentials()) {
      hidePlayerDropdown();
      return;
    }
    playerSearchTimer = setTimeout(() => void searchPlayers(value), 250);
  });

  $("#robloxUsername")?.addEventListener("focus", (ev) => {
    const value = ev.target.value.trim();
    if (value.length >= 2 && hasAdminCredentials()) void searchPlayers(value);
  });

  $("#robloxUsername")?.addEventListener("keydown", (ev) => {
    const dropdown = $("#playerLookupDropdown");
    const items = dropdown ? $$(".player-lookup-item[data-index]", dropdown) : [];
    if (!items.length || dropdown?.classList.contains("hidden")) return;
    const current = items.findIndex((el) => el.classList.contains("focused"));
    if (ev.key === "ArrowDown") {
      ev.preventDefault();
      const next = current < items.length - 1 ? current + 1 : 0;
      items.forEach((el, i) => el.classList.toggle("focused", i === next));
    } else if (ev.key === "ArrowUp") {
      ev.preventDefault();
      const prev = current > 0 ? current - 1 : items.length - 1;
      items.forEach((el, i) => el.classList.toggle("focused", i === prev));
    } else if (ev.key === "Enter") {
      const focused = items.find((el) => el.classList.contains("focused"));
      if (focused) {
        ev.preventDefault();
        focused.click();
      }
    } else if (ev.key === "Escape") {
      hidePlayerDropdown();
    }
  });

  document.addEventListener("click", (ev) => {
    if (!ev.target.closest(".player-lookup")) hidePlayerDropdown();
  });

  $("#playerPreviewClear")?.addEventListener("click", () => {
    setSelectedPlayer(null);
    $("#robloxUsername").value = "";
    $("#robloxUserId").value = "";
  });

  $("#playerPreviewCopyId")?.addEventListener("click", async () => {
    const id = selectedPlayer?.id || $("#robloxUserId").value.trim();
    if (!id) return;
    try {
      await navigator.clipboard.writeText(String(id));
      flash("Copied UserId");
    } catch {
      flash("Copy failed", true);
    }
  });

  $("#saveSite")?.addEventListener("click", () => void saveSite());

  window.addEventListener("scroll", () => {
    $("#siteNav")?.classList.toggle("nav-scrolled", window.scrollY > 8);
  }, { passive: true });

  void (async () => {
    const hasStoredKey = Boolean(localStorage.getItem(KEY_KEY) || adminKey?.value?.trim());
    if (hasStoredKey && rememberEnabled()) {
      const ok = await ensureAuth(true);
      if (!ok) setAdminStatus("Sign in required", false);
    } else if (adminToken()) {
      const ok = await ensureAuth(false);
      if (!ok) setAdminStatus("Sign in required", false);
    } else {
      setAdminStatus("Sign in required", false);
    }
    setTab("scripts");
  })();

  setInterval(() => {
    if (activeTab === "scripts") loadScripts();
    if (activeTab === "stats") loadStats();
  }, 30000);
})();
