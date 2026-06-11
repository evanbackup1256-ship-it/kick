(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

  const toastEl = $("#toast");
  const state = { site: null };

  function flash(text, isError = false) {
    if (!toastEl) return;
    toastEl.textContent = text;
    toastEl.classList.toggle("error", isError);
    toastEl.classList.add("show");
    setTimeout(() => toastEl.classList.remove("show"), 2600);
  }

  async function api(path, options = {}) {
    const res = await fetch(path, {
      headers: { "Content-Type": "application/json", ...(options.headers || {}) },
      ...options,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || data.ok === false) {
      throw new Error(data.error || `Request failed (${res.status})`);
    }
    return data;
  }

  function setActiveNav() {
    const id = location.hash.replace("#", "") || "home";
    $$(".nav a").forEach((a) => a.classList.toggle("active", a.dataset.section === id));
  }

  function renderAnnouncement(site) {
    const el = $("#announcement");
    const text = (site.announcement || "").trim();
    if (!el) return;
    if (!text) {
      el.classList.add("hidden");
      return;
    }
    el.textContent = text;
    el.classList.remove("hidden");
  }

  function renderHero(site) {
    $("#tagline").textContent = site.tagline || "";
    $("#loaderVersion").textContent = site.loaderVersion || "—";
    $("#scriptsUpdated").textContent = site.scriptsUpdatedAt || "—";
    $("#loadstringCode").textContent = site.loadstring || "";
    $("#gameCount").textContent = String(Object.keys(site.games || {}).length);
  }

  function renderFeatures(site) {
    const root = $("#features");
    root.innerHTML = "";
    (site.features || []).forEach((item) => {
      const row = document.createElement("div");
      row.className = "feature";
      row.innerHTML = `<span class="feature-dot"></span><div>${item}</div>`;
      root.appendChild(row);
    });
  }

  function renderGames(site) {
    const root = $("#gamesGrid");
    root.innerHTML = "";
    const games = Object.values(site.games || {}).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
    if (!games.length) {
      root.innerHTML = '<div class="empty">No games listed yet.</div>';
      return;
    }
    games.forEach((game) => {
      const status = (game.status || "working").toLowerCase();
      const card = document.createElement("article");
      card.className = "card";
      card.innerHTML = `
        <div class="card-head">
          <div>
            <div class="title">${game.name || game.id}</div>
            <div class="meta">v${game.version || "?"} · ${game.id || ""}</div>
          </div>
          <span class="badge ${status}">${status}</span>
        </div>
        <div class="desc">${game.description || game.message || ""}</div>
        <div class="actions" style="margin-top:12px;">
          ${game.robloxUrl ? `<a class="btn secondary" href="${game.robloxUrl}" target="_blank" rel="noopener">Open on Roblox</a>` : ""}
        </div>
      `;
      root.appendChild(card);
    });

    const bugGame = $("#bugGame");
    if (bugGame) {
      const current = bugGame.value;
      bugGame.innerHTML = '<option value="">Select game</option>';
      games.forEach((g) => {
        const opt = document.createElement("option");
        opt.value = g.name || g.id;
        opt.textContent = g.name || g.id;
        bugGame.appendChild(opt);
      });
      if (current) bugGame.value = current;
    }
  }

  function renderFaq(site) {
    const root = $("#faq");
    root.innerHTML = "";
    (site.faq || []).forEach((item) => {
      const node = document.createElement("details");
      node.innerHTML = `<summary>${item.q || "Question"}</summary><p>${item.a || ""}</p>`;
      root.appendChild(node);
    });
  }

  function renderChangelog(site) {
    const root = $("#changelog");
    root.innerHTML = "";
    (site.changelog || []).forEach((entry) => {
      const node = document.createElement("div");
      node.className = "changelog-item";
      node.innerHTML = `
        <h3>${entry.date || ""} — ${entry.title || "Update"}</h3>
        <ul>${(entry.items || []).map((i) => `<li>${i}</li>`).join("")}</ul>
      `;
      root.appendChild(node);
    });
  }

  function renderBugCategories(site) {
    const select = $("#bugCategory");
    if (!select) return;
    select.innerHTML = "";
    (site.bugCategories || ["Other"]).forEach((cat) => {
      const opt = document.createElement("option");
      opt.value = cat;
      opt.textContent = cat;
      select.appendChild(opt);
    });
  }

  async function loadSite() {
    const data = await api("/api/site");
    state.site = data;
    document.title = `${data.brand || "Alleral"} Hub`;
    $("#brandName").textContent = data.brand || "Alleral";
    renderAnnouncement(data);
    renderHero(data);
    renderFeatures(data);
    renderGames(data);
    renderFaq(data);
    renderChangelog(data);
    renderBugCategories(data);
  }

  async function copyLoadstring() {
    const text = state.site?.loadstring || $("#loadstringCode")?.textContent || "";
    try {
      await navigator.clipboard.writeText(text);
      flash("Loadstring copied");
    } catch {
      flash("Copy failed — select the text manually", true);
    }
  }

  async function submitBug(ev) {
    ev.preventDefault();
    const err = $("#bugError");
    err.textContent = "";
    const payload = {
      category: $("#bugCategory").value,
      severity: $("#bugSeverity").value,
      game: $("#bugGame").value,
      robloxUser: $("#bugUser").value.trim(),
      executor: $("#bugExecutor").value.trim(),
      contact: $("#bugContact").value.trim(),
      description: $("#bugDescription").value.trim(),
      steps: $("#bugSteps").value.trim(),
    };
    try {
      await api("/api/bug-report", { method: "POST", body: JSON.stringify(payload) });
      $("#bugForm").reset();
      flash("Bug report sent — thank you");
    } catch (e) {
      err.textContent = e.message;
      flash(e.message, true);
    }
  }

  async function submitFeature(ev) {
    ev.preventDefault();
    const err = $("#featureError");
    err.textContent = "";
    const payload = {
      robloxUser: $("#featureUser").value.trim(),
      game: $("#featureGame").value.trim(),
      idea: $("#featureIdea").value.trim(),
    };
    try {
      await api("/api/feature-request", { method: "POST", body: JSON.stringify(payload) });
      $("#featureForm").reset();
      flash("Feature request sent");
    } catch (e) {
      err.textContent = e.message;
      flash(e.message, true);
    }
  }

  function bindTabs() {
    $$(".panel-tabs button").forEach((btn) => {
      btn.addEventListener("click", () => {
        const panel = btn.dataset.panel;
        $$(".panel-tabs button").forEach((b) => b.classList.toggle("active", b === btn));
        $$("[data-panel-body]").forEach((body) => body.classList.toggle("hidden", body.dataset.panelBody !== panel));
      });
    });
  }

  $("#copyLoadstring")?.addEventListener("click", copyLoadstring);
  $("#refreshSite")?.addEventListener("click", () => loadSite().then(() => flash("Refreshed")).catch((e) => flash(e.message, true)));
  $("#bugForm")?.addEventListener("submit", submitBug);
  $("#featureForm")?.addEventListener("submit", submitFeature);
  window.addEventListener("hashchange", setActiveNav);

  bindTabs();
  setActiveNav();
  loadSite().catch((e) => flash(e.message, true));
})();
