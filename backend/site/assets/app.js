"use strict";
(() => {
  // src/site.ts
  (() => {
    const GRADIENTS = [
      "linear-gradient(135deg, #1a3a5c 0%, #0a1628 50%, #2997ff33 100%)",
      "linear-gradient(135deg, #2d1f4e 0%, #0f0a1a 50%, #bf5af233 100%)",
      "linear-gradient(135deg, #1a3d2e 0%, #0a1a12 50%, #30d15833 100%)",
      "linear-gradient(135deg, #3d2a1a 0%, #1a1008 50%, #ffd60a33 100%)",
      "linear-gradient(135deg, #1a2a3d 0%, #0a101a 50%, #64d2ff33 100%)",
      "linear-gradient(135deg, #3d1a2a 0%, #1a0a10 50%, #ff453a33 100%)"
    ];
    const $ = (sel, root = document) => root.querySelector(sel);
    const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
    const toastEl = $("#toast");
    const modal = $("#gameModal");
    const state = {
      site: null,
      changelogShown: 2,
      gameFilter: "all",
      siteSignature: "",
      thumbs: {},
      gamesRenderToken: 0
    };
    const SITE_POLL_MS = 3e4;
    const VISIT_KEY = "alleral_hub_logged";
    function flash(text, isError = false) {
      if (!toastEl) return;
      toastEl.textContent = text;
      toastEl.classList.toggle("error", isError);
      toastEl.classList.add("show");
      setTimeout(() => toastEl.classList.remove("show"), 2800);
    }
    function submissionMeta() {
      return {
        pageUrl: `${location.pathname}${location.hash}`,
        userAgent: navigator.userAgent
      };
    }
    async function api(path, options = {}) {
      const base = window.ALLERAL_API || "";
      const res = await fetch(base + path, {
        headers: { "Content-Type": "application/json", ...options.headers },
        ...options
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || data.ok === false) {
        throw new Error(String(data.error || `Request failed (${res.status})`));
      }
      return data;
    }
    function gradientFor(id, index) {
      let hash = index;
      for (let i = 0; i < (id || "").length; i += 1) hash += id.charCodeAt(i);
      return GRADIENTS[hash % GRADIENTS.length];
    }
    function placeIdOf(game) {
      const ids = game?.placeIds;
      return Array.isArray(ids) && ids[0] ? String(ids[0]) : null;
    }
    async function fetchThumbnails(games) {
      const placeIds = [...new Set(games.map(placeIdOf).filter(Boolean))];
      if (!placeIds.length) return state.thumbs;
      const missing = placeIds.filter((id) => !state.thumbs[id]);
      if (!missing.length) return state.thumbs;
      try {
        const base = window.ALLERAL_API || "";
        const url = `${base}/api/games/thumbnails?placeIds=${encodeURIComponent(missing.join(","))}`;
        const res = await fetch(url);
        const json = await res.json();
        if (json.ok && json.thumbnails) Object.assign(state.thumbs, json.thumbnails);
      } catch {
      }
      return state.thumbs;
    }
    function statusChipHtml(status, label) {
      return `<span class="status-chip status-animated ${status}"><span class="status-ring"></span><span class="status-dot-core"></span>${label}</span>`;
    }
    function setActiveNav() {
      const id = location.hash.replace("#", "") || "home";
      $$(".nav-links a[data-section]").forEach(
        (a) => a.classList.toggle("active", a.dataset.section === id)
      );
    }
    function titleCaseStatus(value) {
      const text = String(value || "working").toLowerCase();
      return text.charAt(0).toUpperCase() + text.slice(1);
    }
    function formatChangelogDate(raw) {
      if (!raw) return "";
      const d = /* @__PURE__ */ new Date(`${raw}T12:00:00`);
      if (Number.isNaN(d.getTime())) return raw;
      return d.toLocaleDateString(void 0, { month: "short", day: "numeric", year: "numeric" });
    }
    function logHubVisit(source = "load") {
      if (sessionStorage.getItem(VISIT_KEY)) return;
      sessionStorage.setItem(VISIT_KEY, "1");
      const base = window.ALLERAL_API || "";
      fetch(`${base}/api/hub/visit`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          path: `${location.pathname}${location.hash}`,
          referrer: document.referrer || "",
          userAgent: navigator.userAgent,
          host: location.host,
          source
        }),
        keepalive: true
      }).catch(() => {
      });
    }
    function afterRender() {
      window.AlleralEffects?.observeReveals?.();
      window.AlleralEffects?.animateCounters?.();
      window.AlleralEffects?.bindMotion?.();
      window.AlleralSelect?.enhance?.();
    }
    function animateCount(el, target) {
      if (!el || !window.AlleralEffects?.animateNumber) {
        if (el) el.textContent = String(target);
        return;
      }
      window.AlleralEffects.animateNumber(el, target);
    }
    function renderAnnouncement(site) {
      const el = $("#announcement");
      const text = (site.announcement || "").trim();
      if (!el) return;
      el.classList.toggle("hidden", !text);
      if (text) el.textContent = text;
    }
    function renderHero(site) {
      const brand = site.brand || "Alleral";
      const heroBrand = $("#heroBrand");
      const tagline = $("#tagline");
      if (heroBrand) heroBrand.textContent = brand.toUpperCase();
      if (tagline) tagline.textContent = site.tagline || "The ultimate Roblox script library.";
      const lv = $("#loaderVersion");
      const su = $("#scriptsUpdated");
      const ls = $("#loadstringCode");
      if (lv) lv.textContent = site.loaderVersion || "\u2014";
      if (su) su.textContent = site.scriptsUpdatedAt || "\u2014";
      if (ls) ls.textContent = site.loadstring || "";
      const games = Object.values(site.games || {});
      const working = games.filter((g) => (g.status || "working").toLowerCase() === "working").length;
      const gc = $("#gameCount");
      const wc = $("#workingCount");
      if (gc) gc.dataset.count = String(games.length);
      if (wc) wc.dataset.count = String(working);
      animateCount(gc, games.length);
      animateCount(wc, working);
    }
    function renderFeatures(site) {
      const root = $("#featuresGrid");
      if (!root) return;
      root.innerHTML = "";
      const items = site.features || [];
      if (!items.length) {
        root.innerHTML = '<p class="empty reveal">Features coming soon.</p>';
        afterRender();
        return;
      }
      items.forEach((text, i) => {
        const card = document.createElement("article");
        card.className = "feature-card card-enter tilt-card";
        card.style.animationDelay = `${i * 0.07}s`;
        card.innerHTML = `<p>${text}</p>`;
        root.appendChild(card);
      });
      afterRender();
    }
    function setModalArt(thumbUrl, gradient) {
      const art = $("#modalArt");
      if (!art) return;
      art.innerHTML = `
      ${thumbUrl ? `<img src="${thumbUrl}" alt="" loading="lazy" />` : ""}
      <div class="modal-art-fallback" style="background:${gradient}"></div>
    `;
    }
    function openGameModal(game, gradient, thumbUrl) {
      if (!modal) return;
      const title = $("#modalTitle");
      const meta = $("#modalMeta");
      const desc = $("#modalDesc");
      if (title) title.textContent = game.name || game.id || "Game";
      if (meta) meta.textContent = `Version ${game.version || "?"} \xB7 ${game.id || ""}`;
      if (desc) desc.textContent = game.description || game.message || "No description available.";
      const status = (game.status || "working").toLowerCase();
      const badge = $("#modalBadge");
      if (badge) {
        badge.className = `status-chip status-animated modal-badge ${status}`;
        badge.innerHTML = `<span class="status-ring"></span><span class="status-dot-core"></span>${titleCaseStatus(status)}`;
      }
      setModalArt(thumbUrl, gradient);
      const roblox = $("#modalRoblox");
      if (roblox) {
        if (game.robloxUrl) {
          roblox.href = game.robloxUrl;
          roblox.classList.remove("hidden");
        } else {
          roblox.classList.add("hidden");
        }
      }
      modal.showModal();
      const inner = modal.querySelector(".game-modal-inner");
      inner?.classList.remove("modal-enter");
      void inner?.offsetWidth;
      inner?.classList.add("modal-enter");
    }
    async function renderGames(site) {
      const root = $("#gamesGrid");
      if (!root) return;
      const token = ++state.gamesRenderToken;
      const filter = state.gameFilter;
      root.classList.add("is-updating");
      root.innerHTML = "";
      let games = Object.entries(site.games || {}).map(([id, g]) => ({ ...g, id })).sort(
        (a, b) => (a.name || "").localeCompare(b.name || "")
      );
      if (filter !== "all") {
        games = games.filter((g) => (g.status || "working").toLowerCase() === filter);
      }
      if (!games.length) {
        if (token !== state.gamesRenderToken) return;
        root.innerHTML = '<p class="empty reveal">No games match this filter.</p>';
        root.classList.remove("is-updating");
        afterRender();
        return;
      }
      await fetchThumbnails(games);
      if (token !== state.gamesRenderToken) return;
      games.forEach((game, i) => {
        const status = (game.status || "working").toLowerCase();
        const statusLabel = titleCaseStatus(status);
        const grad = gradientFor(game.id || "", i);
        const pid = placeIdOf(game);
        const thumb = pid ? state.thumbs[pid] : null;
        const card = document.createElement("article");
        card.className = "game-card card-enter tilt-card";
        card.style.animationDelay = `${i * 0.06}s`;
        card.innerHTML = `
        <div class="game-art">
          ${thumb ? `<img class="game-thumb" src="${thumb}" alt="${game.name || game.id}" loading="lazy" />` : ""}
          <div class="game-art-fallback" style="background:${grad}"></div>
          <div class="game-art-shine"></div>
        </div>
        <div class="game-body">
          <h3>${game.name || game.id}</h3>
          <div class="game-meta">
            ${statusChipHtml(status, statusLabel)}
            <span class="game-version">v${game.version || "?"}</span>
          </div>
          <p class="game-desc">${game.description || game.message || ""}</p>
          <button class="btn-link" type="button">View Details</button>
        </div>
      `;
        const img = card.querySelector(".game-thumb");
        if (img) {
          img.addEventListener("load", () => img.classList.add("loaded"));
          img.addEventListener("error", () => img.remove());
        }
        card.addEventListener("click", (e) => {
          if (e.target.closest("a")) return;
          openGameModal(game, grad, thumb);
        });
        root.appendChild(card);
      });
      if (token !== state.gamesRenderToken) return;
      root.classList.remove("is-updating");
      const bugGame = $("#bugGame");
      if (bugGame) {
        const current = bugGame.value;
        const allGames = Object.entries(site.games || {}).map(([id, g]) => ({ ...g, id })).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        bugGame.innerHTML = '<option value="">Select a game</option>';
        allGames.forEach((g) => {
          const opt = document.createElement("option");
          opt.value = g.name || g.id || "";
          opt.textContent = g.name || g.id || "";
          bugGame.appendChild(opt);
        });
        if (current) bugGame.value = current;
        window.AlleralSelect?.refresh?.(bugGame);
      }
      afterRender();
    }
    function renderChangelog(site, reset = true) {
      const root = $("#changelogList");
      if (!root) return;
      const entries = site.changelog || [];
      if (reset) {
        root.innerHTML = "";
        state.changelogShown = 2;
      }
      const slice = entries.slice(0, state.changelogShown);
      slice.forEach((entry, i) => {
        if (root.children[i]) return;
        const node = document.createElement("article");
        node.className = "changelog-card reveal tilt-card";
        node.innerHTML = `
        <h3>${entry.title || "Update"}</h3>
        <p class="cl-date">${formatChangelogDate(entry.date)}</p>
        <ul>${(entry.items || []).map((item) => `<li>${item}</li>`).join("")}</ul>
      `;
        root.appendChild(node);
      });
      const btn = $("#loadMoreChangelog");
      if (btn) btn.classList.toggle("hidden", state.changelogShown >= entries.length);
      afterRender();
    }
    async function sendFaqFeedback(question, helpful, comment = "") {
      await api("/api/faq-feedback", {
        method: "POST",
        body: JSON.stringify({ question, helpful, comment, ...submissionMeta() })
      });
      flash(helpful ? "Thanks for the feedback" : "Got it \u2014 we'll improve this answer");
    }
    function renderFaq(site) {
      const root = $("#faqList");
      if (!root) return;
      root.innerHTML = "";
      (site.faq || []).forEach((item, i) => {
        const node = document.createElement("details");
        node.className = "reveal faq-item";
        node.style.transitionDelay = `${Math.min(i * 0.04, 0.24)}s`;
        const q = item.q || "Question";
        node.innerHTML = `
        <summary>${q}</summary>
        <div class="faq-answer"><p>${item.a || ""}</p></div>
        <div class="faq-feedback">
          <span class="faq-feedback-label">Was this helpful?</span>
          <button type="button" class="faq-feedback-btn" data-helpful="yes">Yes</button>
          <button type="button" class="faq-feedback-btn" data-helpful="no">No</button>
        </div>
      `;
        node.querySelectorAll(".faq-feedback-btn").forEach((btn) => {
          btn.addEventListener("click", async (e) => {
            e.preventDefault();
            e.stopPropagation();
            const helpful = btn.dataset.helpful === "yes";
            const bar = node.querySelector(".faq-feedback");
            try {
              await sendFaqFeedback(q, helpful);
              if (bar) {
                bar.innerHTML = `<span class="faq-feedback-thanks">Thanks for letting us know.</span>`;
              }
            } catch (err) {
              flash(err instanceof Error ? err.message : "Could not send feedback", true);
            }
          });
        });
        root.appendChild(node);
      });
      afterRender();
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
      window.AlleralSelect?.refresh?.(select);
    }
    function renderAccess(site) {
      const cfg = window.ALLERAL_CONFIG || {};
      const links = site.links || {};
      const primary = links.website || cfg.publicUrl || `${window.location.origin}/`;
      const mirror = links.mirror || cfg.mirrorUrl || "";
      const primaryEl = $("#primaryUrl");
      const mirrorEl = $("#mirrorUrl");
      const mirrorLink = $("#mirrorLink");
      const footerEl = $("#footerSiteLink");
      if (primaryEl) primaryEl.textContent = primary;
      if (mirrorEl) mirrorEl.textContent = mirror || "Not available";
      if (mirrorLink && mirror) mirrorLink.href = mirror;
      if (footerEl) footerEl.href = primary;
    }
    function siteSignature(data) {
      if (!data) return "";
      return [
        data.scriptsUpdatedAt,
        data.siteUpdatedAt,
        data.githubCommit,
        data.loaderVersion,
        Object.keys(data.games || {}).length
      ].join("|");
    }
    async function applySite(data, { notify = false } = {}) {
      const prev = state.siteSignature;
      const sig = siteSignature(data);
      const changed = Boolean(prev && sig !== prev);
      state.site = data;
      state.siteSignature = sig;
      const brand = data.brand || "Alleral";
      document.title = `${brand} \u2014 Script Library`;
      const brandEl = $("#brandName");
      if (brandEl) brandEl.textContent = brand;
      renderAccess(data);
      renderAnnouncement(data);
      renderHero(data);
      renderFeatures(data);
      await renderGames(data);
      if (changed) renderChangelog(data, true);
      else renderChangelog(data, false);
      renderFaq(data);
      renderBugCategories(data);
      if (notify && changed) flash("Synced from GitHub");
    }
    async function loadSite(notify = false) {
      const data = await api("/api/site");
      await applySite(data, { notify });
    }
    function startSitePolling() {
      setInterval(() => {
        loadSite(true).catch(() => {
        });
      }, SITE_POLL_MS);
    }
    async function copyText(text, msg) {
      try {
        await navigator.clipboard.writeText(text);
        flash(msg);
      } catch {
        flash("Copy failed", true);
      }
    }
    async function checkLiveStatus() {
      const el = $("#liveStatus");
      if (!el) return;
      const base = window.ALLERAL_API || "";
      try {
        const res = await fetch(`${base}/health`, { cache: "no-store" });
        const data = await res.json();
        if (data.ok) {
          el.className = "status-pill online";
          el.innerHTML = '<span class="status-dot"></span>Live';
          const commit = data.githubCommit ? ` \xB7 ${data.githubCommit}` : "";
          el.title = `Relay v${data.version || "?"} \xB7 Auto-sync${commit}`;
        } else throw new Error("offline");
      } catch {
        el.className = "status-pill offline";
        el.innerHTML = '<span class="status-dot"></span>Offline';
      }
    }
    async function copyLoadstring() {
      const text = state.site?.loadstring || $("#loadstringCode")?.textContent || "";
      await copyText(text, "Script copied to clipboard");
    }
    async function submitBug(ev) {
      ev.preventDefault();
      const err = $("#bugError");
      if (err) err.textContent = "";
      try {
        await api("/api/bug-report", {
          method: "POST",
          body: JSON.stringify({
            category: $("#bugCategory")?.value,
            severity: $("#bugSeverity")?.value,
            game: $("#bugGame")?.value,
            robloxUser: $("#bugUser")?.value.trim(),
            executor: $("#bugExecutor")?.value.trim(),
            contact: $("#bugContact")?.value.trim(),
            description: $("#bugDescription")?.value.trim(),
            steps: $("#bugSteps")?.value.trim(),
            ...submissionMeta()
          })
        });
        $("#bugForm")?.reset();
        flash("Report submitted \u2014 sent to Discord");
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Submit failed";
        if (err) err.textContent = msg;
        flash(msg, true);
      }
    }
    async function submitFeature(ev) {
      ev.preventDefault();
      const err = $("#featureError");
      if (err) err.textContent = "";
      try {
        await api("/api/feature-request", {
          method: "POST",
          body: JSON.stringify({
            robloxUser: $("#featureUser")?.value.trim(),
            game: $("#featureGame")?.value.trim(),
            contact: $("#featureContact")?.value.trim(),
            idea: $("#featureIdea")?.value.trim(),
            ...submissionMeta()
          })
        });
        $("#featureForm")?.reset();
        flash("Idea submitted \u2014 sent to Discord");
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Submit failed";
        if (err) err.textContent = msg;
        flash(msg, true);
      }
    }
    async function submitSupport(ev) {
      ev.preventDefault();
      const err = $("#supportError");
      if (err) err.textContent = "";
      try {
        await api("/api/support", {
          method: "POST",
          body: JSON.stringify({
            topic: $("#supportTopic")?.value,
            robloxUser: $("#supportUser")?.value.trim(),
            contact: $("#supportContact")?.value.trim(),
            question: $("#supportQuestion")?.value.trim(),
            ...submissionMeta()
          })
        });
        $("#supportForm")?.reset();
        flash("Question sent \u2014 we'll see it in Discord");
      } catch (e) {
        const msg = e instanceof Error ? e.message : "Submit failed";
        if (err) err.textContent = msg;
        flash(msg, true);
      }
    }
    function bindTabs() {
      $$(".support-tabs button").forEach((btn) => {
        btn.addEventListener("click", (e) => {
          const panel = btn.dataset.panel;
          $$(".support-tabs button").forEach((b) => b.classList.toggle("active", b === btn));
          $$("[data-panel-body]").forEach((body) => {
            const show = body.dataset.panelBody === panel;
            body.classList.toggle("hidden", !show);
            if (show) {
              body.classList.remove("panel-enter");
              void body.offsetWidth;
              body.classList.add("panel-enter");
            }
          });
          const me = e;
          if (me.clientX != null) {
            const r = btn.getBoundingClientRect();
            btn.style.setProperty("--x", `${(me.clientX - r.left) / btn.offsetWidth * 100}%`);
            btn.style.setProperty("--y", `${(me.clientY - r.top) / btn.offsetHeight * 100}%`);
          }
        });
      });
    }
    function bindGameFilters() {
      $$(".filter-pill").forEach((btn) => {
        btn.addEventListener("click", () => {
          state.gameFilter = btn.dataset.filter || "all";
          $$(".filter-pill").forEach((b) => b.classList.toggle("active", b === btn));
          if (state.site) void renderGames(state.site);
        });
      });
    }
    function bindModal() {
      $$(".modal-close, .modal-close-btn").forEach((btn) => {
        btn.addEventListener("click", () => modal?.close());
      });
      modal?.addEventListener("click", (e) => {
        if (e.target === modal) modal.close();
      });
    }
    function bindMobileNav() {
      const toggle = $("#navToggle");
      const nav = $("#mainNav");
      toggle?.addEventListener("click", () => nav?.classList.toggle("open"));
      $$(".nav-links a").forEach((a) => a.addEventListener("click", () => nav?.classList.remove("open")));
    }
    function isGatePassed() {
      try {
        const raw = sessionStorage.getItem("alleral_gate_ok");
        if (!raw) return false;
        if (raw === "1") return true;
        const data = JSON.parse(raw);
        return !!(data?.until && Date.now() < data.until);
      } catch {
        return sessionStorage.getItem("alleral_gate_ok") === "1";
      }
    }
    function initWhenReady() {
      if (isGatePassed()) logHubVisit("return");
      else window.addEventListener("alleral:gate-passed", () => logHubVisit("gate"), { once: true });
      $("#copyLoadstring")?.addEventListener("click", () => void copyLoadstring());
      $("#copyPrimaryUrl")?.addEventListener("click", () => {
        void copyText($("#primaryUrl")?.textContent || "", "Link copied");
      });
      $("#loadMoreChangelog")?.addEventListener("click", () => {
        state.changelogShown += 3;
        if (state.site) renderChangelog(state.site, false);
      });
      $("#bugForm")?.addEventListener("submit", (e) => void submitBug(e));
      $("#featureForm")?.addEventListener("submit", (e) => void submitFeature(e));
      $("#supportForm")?.addEventListener("submit", (e) => void submitSupport(e));
      window.addEventListener("hashchange", setActiveNav);
      const fy = $("#footerYear");
      if (fy) fy.textContent = String((/* @__PURE__ */ new Date()).getFullYear());
      bindTabs();
      bindGameFilters();
      bindModal();
      bindMobileNav();
      setActiveNav();
      void checkLiveStatus();
      setInterval(() => void checkLiveStatus(), 6e4);
      loadSite(false).catch((e) => flash(e instanceof Error ? e.message : "Load failed", true));
      startSitePolling();
    }
    initWhenReady();
    if (!isGatePassed()) {
      window.addEventListener(
        "alleral:gate-passed",
        () => {
          document.documentElement.classList.remove("cf-gate-lock");
          document.body.classList.remove("cf-gate-lock");
        },
        { once: true }
      );
    }
  })();
})();
