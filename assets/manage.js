(() => {
  const TOKEN_KEY = "alleral_admin_token";
  const KEY_STORAGE = "alleral_admin_key";
  const $ = (s) => document.querySelector(s);
  const toast = $("#toast");

  function apiBase() {
    return (window.ALLERAL_API || window.location.origin).replace(/\/+$/, "");
  }

  function flash(text, isError = false) {
    if (!toast) return;
    toast.textContent = text;
    toast.classList.toggle("error", isError);
    toast.classList.add("show");
    setTimeout(() => toast.classList.remove("show"), 2400);
  }

  function headers() {
    const h = { "Content-Type": "application/json" };
    const token = sessionStorage.getItem(TOKEN_KEY);
    if (token) h["X-Admin-Token"] = token;
    else {
      const key = ($("#manageAdminKey")?.value || localStorage.getItem(KEY_STORAGE) || "").trim();
      if (key) h["X-Admin-Key"] = key;
    }
    return h;
  }

  async function signIn() {
    const key = ($("#manageAdminKey")?.value || "").trim();
    if (!key) {
      $("#manageError").textContent = "Enter ADMIN_API_KEY first.";
      return;
    }
    localStorage.setItem(KEY_STORAGE, key);
    const res = await fetch(`${apiBase()}/api/admin/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key }),
    });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      $("#manageError").textContent = data.error || "Sign in failed";
      flash("Sign in failed", true);
      return;
    }
    sessionStorage.setItem(TOKEN_KEY, data.token);
    $("#manageError").textContent = "";
    flash("Signed in");
    await refreshAll();
  }

  async function loadStatus() {
    const res = await fetch(`${apiBase()}/api/manage/status`, { cache: "no-store" });
    const data = await res.json();
    if (!data.ok) throw new Error(data.error || "status failed");
    const m = data.manage || {};
    const sync = data.sync || {};
    const pill = $("#manageStatusPill");
    if (pill) {
      pill.innerHTML = `<span class="status-dot"></span>${m.provider || "local"}`;
      pill.classList.toggle("online", !!m.enabled);
    }
    const stats = $("#manageStats");
    if (stats) {
      stats.innerHTML = `
        <article class="stat-card card-enter"><span class="stat-card-label">Backend</span><strong>${m.provider || "local"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.05s"><span class="stat-card-label">Supabase</span><strong>${m.supabaseConfigured ? "Connected" : "Not set"}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.1s"><span class="stat-card-label">Audit events</span><strong>${m.localEvents ?? 0}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.15s"><span class="stat-card-label">Pending sync</span><strong>${m.pendingSync ?? 0}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.2s"><span class="stat-card-label">Active bans</span><strong>${data.bans ?? 0}</strong></article>
        <article class="stat-card card-enter" style="animation-delay:0.25s"><span class="stat-card-label">GitHub commit</span><strong>${sync.commit || "—"}</strong></article>
      `;
    }
  }

  async function loadAudit() {
    const q = encodeURIComponent($("#auditSearch")?.value?.trim() || "");
    const res = await fetch(`${apiBase()}/api/manage/audit?q=${q}&limit=80`, { headers: headers(), cache: "no-store" });
    const data = await res.json();
    const root = $("#auditList");
    if (!root) return;
    if (!res.ok || !data.ok) {
      root.innerHTML = `<p class="empty">${data.error === "unauthorized" ? "Sign in to view audit log." : (data.error || "Failed")}</p>`;
      return;
    }
    const events = data.events || [];
    if (!events.length) {
      root.innerHTML = '<p class="empty">No audit events yet.</p>';
      return;
    }
    root.innerHTML = events.map((e) => `
      <article class="manage-audit-item card-enter">
        <div class="manage-audit-head">
          <strong>${e.event}</strong>
          <span class="muted-inline">${e.createdAt || ""}</span>
        </div>
        <p class="manage-audit-meta">actor: ${e.actor || "system"} · synced: ${e.synced ? "yes" : "no"}</p>
        <pre class="manage-audit-payload">${JSON.stringify(e.payload || {}, null, 2)}</pre>
      </article>
    `).join("");
  }

  async function testSupabase() {
    const res = await fetch(`${apiBase()}/api/manage/supabase/test`, { headers: headers(), cache: "no-store" });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      const hint = data.hint ? ` — ${data.hint}` : "";
      flash((data.error || "Supabase test failed") + hint, true);
      return;
    }
    flash(`Supabase OK · table ${data.table}`);
    await refreshAll();
  }

  async function syncSupabase() {
    const res = await fetch(`${apiBase()}/api/manage/sync`, { method: "POST", headers: headers() });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      flash(data.error || "Sync failed", true);
      return;
    }
    flash(`Synced ${data.synced || 0} event(s) to Supabase`);
    await refreshAll();
  }

  async function refreshAll() {
    await loadStatus();
    await loadAudit();
  }

  let auditTimer = 0;
  $("#manageSignIn")?.addEventListener("click", () => void signIn());
  $("#manageTestSupabase")?.addEventListener("click", () => void testSupabase());
  $("#manageSyncSupabase")?.addEventListener("click", () => void syncSupabase());
  $("#auditSearch")?.addEventListener("input", () => {
    clearTimeout(auditTimer);
    auditTimer = setTimeout(() => void loadAudit(), 280);
  });

  if (localStorage.getItem(KEY_STORAGE)) {
    $("#manageAdminKey").value = localStorage.getItem(KEY_STORAGE);
  }

  refreshAll().catch((e) => flash(e.message, true));
})();
