(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const STATUSES = ["working", "detected", "broken", "maintenance", "testing"];
  const toast = $("#toast");
  const errorEl = $("#error");
  const adminKey = $("#adminKey");
  let activeTab = "scripts";

  if (localStorage.getItem("alleral_admin_key")) {
    adminKey.value = localStorage.getItem("alleral_admin_key");
  }

  function flash(text, isError = false) {
    toast.textContent = text;
    toast.classList.toggle("error", isError);
    toast.classList.add("show");
    setTimeout(() => toast.classList.remove("show"), 2200);
  }

  function headers() {
    return {
      "Content-Type": "application/json",
      "X-Admin-Key": adminKey.value.trim(),
    };
  }

  function requireKey() {
    if (!adminKey.value.trim()) {
      errorEl.textContent = "Enter your admin API key first.";
      return false;
    }
    return true;
  }

  function setTab(name) {
    activeTab = name;
    $$(".admin-tabs button").forEach((b) => b.classList.toggle("active", b.dataset.tab === name));
    $$("[data-tab-panel]").forEach((p) => p.classList.toggle("hidden", p.dataset.tabPanel !== name));
    errorEl.textContent = "";
    if (name === "scripts") loadScripts();
    if (name === "bans") loadBans();
    if (name === "site") loadSiteEditor();
  }

  async function loadScripts() {
    $("#scriptsGrid").innerHTML = "Loading…";
    const res = await fetch("/scripts");
    const data = await res.json();
    if (!data.ok) {
      errorEl.textContent = data.error || "Failed to load scripts";
      $("#scriptsGrid").innerHTML = "";
      return;
    }
    const root = $("#scriptsGrid");
    root.innerHTML = "";
    Object.keys(data.scripts || {}).sort().forEach((id) => renderScriptCard(id, data.scripts[id], root));
  }

  function renderScriptCard(id, entry, root) {
    const status = (entry.status || "working").toLowerCase();
    const card = document.createElement("div");
    card.className = "card";
    card.innerHTML = `
      <div class="card-head">
        <div>
          <div class="title">${entry.name || id}</div>
          <div class="meta">${id} · v${entry.version || "?"} · ${entry.updatedAt || "?"}</div>
        </div>
        <span class="badge ${status}">${status}</span>
      </div>
      <div class="desc">${entry.message || ""}</div>
      <div class="editor" style="margin-top:12px;display:grid;gap:10px;">
        <label>Status <select data-f="status">${STATUSES.map((s) => `<option ${s===status?"selected":""}>${s}</option>`).join("")}</select></label>
        <label>Version <input data-f="version" value="${entry.version || ""}" /></label>
        <label>Message <textarea data-f="message">${entry.message || ""}</textarea></label>
        <button class="primary" type="button">Save script</button>
      </div>`;
    card.querySelector("button").onclick = async () => {
      if (!requireKey()) return;
      const payload = {};
      card.querySelectorAll("[data-f]").forEach((el) => { payload[el.dataset.f] = el.value; });
      const res = await fetch(`/scripts/${encodeURIComponent(id)}`, { method: "PATCH", headers: headers(), body: JSON.stringify(payload) });
      const out = await res.json();
      if (!res.ok || !out.ok) { errorEl.textContent = out.error || "Save failed"; return; }
      flash(`Updated ${id}`);
      loadScripts();
    };
    root.appendChild(card);
  }

  async function loadBans() {
    if (!requireKey()) { $("#bansGrid").innerHTML = ""; return; }
    $("#bansGrid").innerHTML = "Loading…";
    const res = await fetch("/admin/bans", { headers: headers() });
    const data = await res.json();
    if (!res.ok || !data.ok) {
      errorEl.textContent = data.error || "Failed to load bans";
      $("#bansGrid").innerHTML = "";
      return;
    }
    const root = $("#bansGrid");
    root.innerHTML = "";
    if (!(data.bans || []).length) {
      root.innerHTML = '<div class="empty">No active bans.</div>';
      return;
    }
    data.bans.forEach((ban) => {
      const card = document.createElement("div");
      card.className = "card";
      card.innerHTML = `
        <div class="card-head">
          <div>
            <div class="title">${ban.player_name || ban.value}</div>
            <div class="meta">#${ban.id} · ${ban.ban_type} · ${ban.value}</div>
          </div>
          <span class="badge broken">${ban.ban_type}</span>
        </div>
        <div class="desc">${ban.reason || ""}</div>
        <button class="secondary" type="button" style="margin-top:10px;">Remove ban</button>`;
      card.querySelector("button").onclick = async () => {
        const res = await fetch(`/admin/bans/${ban.id}`, { method: "DELETE", headers: headers() });
        const out = await res.json();
        if (!res.ok || !out.ok) { errorEl.textContent = out.error || "Remove failed"; return; }
        flash(`Removed ban #${ban.id}`);
        loadBans();
      };
      root.appendChild(card);
    });
  }

  async function addBan() {
    if (!requireKey()) return;
    const payload = {
      banType: $("#banType").value,
      value: $("#banValue").value.trim(),
      playerName: $("#banPlayer").value.trim(),
      reason: $("#banReason").value.trim(),
    };
    if (!payload.value) { errorEl.textContent = "Ban value required"; return; }
    const res = await fetch("/admin/bans", { method: "POST", headers: headers(), body: JSON.stringify(payload) });
    const data = await res.json();
    if (!res.ok || !data.ok) { errorEl.textContent = data.error || "Ban failed"; return; }
    $("#banValue").value = ""; $("#banPlayer").value = ""; $("#banReason").value = "";
    flash("Ban added");
    loadBans();
  }

  async function loadSiteEditor() {
    const res = await fetch("/api/site");
    const site = await res.json();
    $("#siteTagline").value = site.tagline || "";
    $("#siteAnnouncement").value = site.announcement || "";
    $("#siteLoaderVersion").value = site.loaderVersion || "";
    $("#siteLoadstring").value = site.loadstring || "";
    $("#siteFeatures").value = (site.features || []).join("\n");
    $("#siteFaq").value = JSON.stringify(site.faq || [], null, 2);
  }

  async function saveSite() {
    if (!requireKey()) return;
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
    const res = await fetch("/api/site", { method: "PATCH", headers: headers(), body: JSON.stringify(payload) });
    const data = await res.json();
    if (!res.ok || !data.ok) { errorEl.textContent = data.error || "Site save failed"; return; }
    flash("Site content saved — public page updates immediately");
  }

  $("#saveKey").onclick = () => {
    localStorage.setItem("alleral_admin_key", adminKey.value.trim());
    flash("Admin key saved");
  };
  $("#reload").onclick = () => setTab(activeTab);
  $$(".admin-tabs button").forEach((b) => b.onclick = () => setTab(b.dataset.tab));
  $("#addBan").onclick = addBan;
  $("#saveSite").onclick = saveSite;

  setTab("scripts");
})();
