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
      gameQuery: "",
      faqQuery: "",
      siteSignature: "",
      thumbs: {},
      creditRenders: {},
      gamesRenderToken: 0,
      weaoExploits: [],
      weaoSummary: {},
      weaoQuery: "",
      weaoFilter: "all",
      weaoFetchedAt: "",
      weaoPollSec: 35,
      weaoLive: false,
      weaoChanges: [],
      weaoRecentChanges: [],
      weaoChangedSlugs: {},
      weaoFingerprints: {},
      weaoPollTimer: 0,
      weaoCountdownTimer: 0,
      weaoNextPollAt: 0
    };
    const WEAO_LIVE_POLL_MS = 35e3;
    const WEAO_IDLE_POLL_MS = 12e4;
    const SITE_POLL_MS = 3e4;
    const EXECUTOR_PREF_KEY = "alleral_last_executor";
    const VISIT_KEY = "alleral_hub_logged";
    function escapeHtml(value) {
      return String(value ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }
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
      const coreMeta = $("#coreVersionMeta");
      if (coreMeta) {
        const bits = [];
        if (site.coreVersion) bits.push(`core ${site.coreVersion}`);
        if (site.uiLibrary) {
          const uiLabel = site.uiVersion
            ? `${site.uiLibrary} ${site.uiVersion}`
            : site.uiLibrary;
          bits.push(uiLabel);
        }
        if (site.sydePatch) bits.push(`patch v${site.sydePatch}`);
        coreMeta.textContent = bits.length ? ` \u00b7 ${bits.join(" \u00b7 ")}` : "";
      }
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
        card.className = "feature-card card-enter";
        card.style.animationDelay = `${i * 0.07}s`;
        card.innerHTML = `<p>${escapeHtml(text)}</p>`;
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
    function gameFeatureText(game) {
      return (game.scriptFeatures || []).map((f) => `${f.name || ""} ${f.category || ""} ${f.desc || ""}`).join(" ");
    }
    function renderFeatureChips(features, limit = 4) {
      if (!features.length) return "";
      const shown = features.slice(0, limit);
      const rest = features.length - shown.length;
      return `
      <div class="game-features-preview">
        ${shown.map((f) => `<span class="game-feature-chip" title="${escapeHtml(f.desc || f.category || "")}">${escapeHtml(f.name || "Feature")}</span>`).join("")}
        ${rest > 0 ? `<span class="game-feature-more">+${rest} more</span>` : ""}
      </div>`;
    }
    function renderModalFeatures(game) {
      const tabsRoot = $("#modalTabs");
      const featuresRoot = $("#modalFeatures");
      const countEl = $("#modalFeatureCount");
      const features = game.scriptFeatures || [];
      const tabs = game.uiTabs || [];
      if (countEl) countEl.textContent = features.length ? `${features.length} features` : "";
      if (tabsRoot) {
        if (!tabs.length) {
          tabsRoot.innerHTML = "";
          tabsRoot.classList.add("hidden");
        } else {
          tabsRoot.classList.remove("hidden");
          tabsRoot.innerHTML = tabs.map((tab) => `<span class="game-ui-tab">${escapeHtml(tab)}</span>`).join("");
        }
      }
      if (!featuresRoot) return;
      if (!features.length) {
        featuresRoot.innerHTML = `<p class="modal-desc">Feature list coming soon for this script.</p>`;
        return;
      }
      const byCategory = {};
      features.forEach((f) => {
        const cat = f.category || "General";
        if (!byCategory[cat]) byCategory[cat] = [];
        byCategory[cat].push(f);
      });
      featuresRoot.innerHTML = Object.entries(byCategory).map(
        ([cat, items]) => `
      <section class="game-feature-group">
        <h4>${escapeHtml(cat)}</h4>
        <ul class="game-feature-list">
          ${items.map(
          (f) => `<li><strong>${escapeHtml(f.name || "Feature")}</strong>${f.desc ? `<span>${escapeHtml(f.desc)}</span>` : ""}</li>`
        ).join("")}
        </ul>
      </section>`
      ).join("");
    }
    function openGameModal(game, gradient, thumbUrl) {
      if (!modal) return;
      const title = $("#modalTitle");
      const meta = $("#modalMeta");
      const desc = $("#modalDesc");
      if (title) title.textContent = game.name || game.id || "Game";
      if (meta) meta.textContent = `Version ${game.version || "?"} \xB7 ${game.id || ""}`;
      if (desc) desc.textContent = game.description || game.message || "No description available.";
      renderModalFeatures(game);
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
      const query = state.gameQuery.trim().toLowerCase();
      if (query) {
        games = games.filter((g) => {
          const hay = `${g.name || ""} ${g.id || ""} ${g.description || ""} ${g.message || ""} ${gameFeatureText(g)}`.toLowerCase();
          return hay.includes(query);
        });
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
        card.className = "game-card card-enter";
        card.style.animationDelay = `${i * 0.06}s`;
        card.innerHTML = `
        <div class="game-art">
          ${thumb ? `<img class="game-thumb" src="${escapeHtml(thumb)}" alt="${escapeHtml(game.name || game.id)}" loading="lazy" />` : ""}
          <div class="game-art-fallback" style="background:${grad}"></div>
          <div class="game-art-shine"></div>
        </div>
        <div class="game-body">
          <h3>${escapeHtml(game.name || game.id)}</h3>
          <div class="game-meta">
            ${statusChipHtml(status, statusLabel)}
            <span class="game-version">v${escapeHtml(game.version || "?")}</span>
          </div>
          <p class="game-desc">${escapeHtml(game.description || game.message || "")}</p>
          ${renderFeatureChips(game.scriptFeatures || [])}
          <button class="btn-link" type="button">View${(game.scriptFeatures || []).length ? ` ${(game.scriptFeatures || []).length}` : ""} Features</button>
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
      renderGameStatsBar(site);
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
        node.className = "changelog-card reveal";
        node.innerHTML = `
        <h3>${escapeHtml(entry.title || "Update")}</h3>
        <p class="cl-date">${escapeHtml(formatChangelogDate(entry.date))}</p>
        <ul>${(entry.items || []).map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>
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
      const empty = $("#faqEmpty");
      if (!root) return;
      root.innerHTML = "";
      const query = state.faqQuery.trim().toLowerCase();
      const items = (site.faq || []).filter((item) => {
        if (!query) return true;
        const hay = `${item.q || ""} ${item.a || ""}`.toLowerCase();
        return hay.includes(query);
      });
      if (empty) empty.classList.toggle("hidden", items.length > 0);
      items.forEach((item, i) => {
        const node = document.createElement("details");
        node.className = "reveal faq-item";
        node.id = `faq-${i}`;
        node.style.transitionDelay = `${Math.min(i * 0.04, 0.24)}s`;
        const q = item.q || "Question";
        const a = item.a || "";
        node.innerHTML = `
        <summary>${escapeHtml(q)}</summary>
        <div class="faq-answer">
          <div class="faq-answer-inner">
            <p>${escapeHtml(a)}</p>
            <div class="faq-feedback">
              <span class="faq-feedback-label">Was this helpful?</span>
              <div class="faq-feedback-actions">
                <button type="button" class="faq-feedback-btn" data-helpful="yes">Yes</button>
                <button type="button" class="faq-feedback-btn" data-helpful="no">No</button>
              </div>
            </div>
          </div>
        </div>
      `;
        node.querySelectorAll(".faq-feedback-btn").forEach((btn) => {
          btn.addEventListener("click", async (e) => {
            e.preventDefault();
            e.stopPropagation();
            const helpful = btn.dataset.helpful === "yes";
            const bar = node.querySelector(".faq-feedback");
            node.querySelectorAll(".faq-feedback-btn").forEach((b) => {
              b.disabled = true;
              b.classList.toggle("selected", b === btn);
            });
            try {
              await sendFaqFeedback(q, helpful);
              if (bar) {
                bar.innerHTML = `<span class="faq-feedback-thanks">Thanks for letting us know.</span>`;
              }
            } catch (err) {
              node.querySelectorAll(".faq-feedback-btn").forEach((b) => {
                b.disabled = false;
                b.classList.remove("selected");
              });
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
    function initials(name) {
      const parts = name.trim().split(/\s+/).filter(Boolean);
      if (!parts.length) return "?";
      if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
      return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }
    function renderGameStatsBar(site) {
      const root = $("#gameStatsBar");
      if (!root) return;
      const games = Object.values(site.games || {});
      const counts = {
        all: games.length,
        working: 0,
        testing: 0,
        maintenance: 0,
        broken: 0
      };
      games.forEach((g) => {
        const s = (g.status || "working").toLowerCase();
        if (s in counts) counts[s] += 1;
      });
      const labels = {
        all: "All",
        working: "Working",
        testing: "Testing",
        maintenance: "Maintenance",
        broken: "Broken"
      };
      root.innerHTML = Object.entries(counts).map(([key, n]) => {
        const dot = key === "all" ? "" : `<span class="dot ${key}"></span>`;
        return `<button type="button" class="game-stat-chip${state.gameFilter === key ? " active" : ""}" data-filter="${key}">${dot}${labels[key]} <strong>${n}</strong></button>`;
      }).join("");
      const totalFeatures = games.reduce((n, g) => n + (g.scriptFeatures || []).length, 0);
      if (totalFeatures) {
        root.innerHTML += `<span class="game-stat-chip game-stat-static">Script features <strong>${totalFeatures}</strong></span>`;
      }
      root.querySelectorAll(".game-stat-chip").forEach((btn) => {
        btn.addEventListener("click", () => {
          state.gameFilter = btn.dataset.filter || "all";
          $$(".filter-pill").forEach(
            (b) => b.classList.toggle("active", b.dataset.filter === state.gameFilter)
          );
          if (state.site) void renderGames(state.site);
          renderGameStatsBar(state.site);
        });
      });
    }
    async function fetchCreditRenders() {
      try {
        const data = await api("/api/credits/renders");
        state.creditRenders = data.members || {};
      } catch {
        state.creditRenders = {};
      }
    }
    function creditAvatarHtml(member, render) {
      const img = render?.renders?.body || render?.renders?.bust || render?.renders?.headshot;
      const name = member.displayName || render?.displayName || "Member";
      if (img) {
        return `<img class="credit-avatar-body" src="${escapeHtml(img)}" alt="${escapeHtml(name)} Roblox avatar" loading="lazy" />`;
      }
      return `<div class="credit-avatar-fallback" aria-hidden="true">${escapeHtml(initials(name))}</div>`;
    }
    function renderCredits(site) {
      const teamsRoot = $("#creditsTeams");
      const thanksRoot = $("#creditsThanks");
      if (!teamsRoot) return;
      const credits = site.credits || {};
      const headline = $("#creditsHeadline");
      const sub = $("#creditsSubheadline");
      if (headline) headline.textContent = credits.headline || "The team behind Alleral";
      if (sub) sub.textContent = credits.subheadline || "";
      teamsRoot.innerHTML = "";
      const totalMembers = (credits.teams || []).reduce((n, t) => n + (t.members || []).length, 0);
      (credits.teams || []).forEach((team) => {
        const section = document.createElement("div");
        section.className = `credits-team reveal${totalMembers <= 1 ? " solo-team" : ""}`;
        section.innerHTML = `<h3 class="credits-team-title">${escapeHtml(team.title || "Team")}</h3>`;
        const grid = document.createElement("div");
        grid.className = `credits-grid${totalMembers <= 1 ? " solo" : ""}`;
        (team.members || []).forEach((member) => {
          const mid = member.id || member.displayName || "";
          const render = state.creditRenders[mid];
          const robloxName = render?.robloxUsername || member.robloxUsername || "";
          const profileUrl = render?.profileUrl || (render?.robloxUserId ? `https://www.roblox.com/users/${render.robloxUserId}/profile` : "");
          const card = document.createElement("article");
          card.className = `credit-card reveal${member.featured ? " featured" : ""}`;
          if (member.accent) {
            card.style.setProperty("--credit-accent", member.accent);
            card.dataset.accent = "1";
          }
          const tags = (member.tags || []).map((t) => `<span class="credit-tag">${escapeHtml(t)}</span>`).join("");
          const links = Object.entries(member.links || {}).map(([k, url]) => `<a class="credit-link" href="${escapeHtml(url)}" target="_blank" rel="noopener">${escapeHtml(k)}</a>`).join("");
          card.innerHTML = `
          <div class="credit-render-stage">
            <div class="credit-pedestal"></div>
            <div class="credit-pedestal-ring"></div>
            <div class="credit-avatar-glow"></div>
            <div class="credit-avatar-ring"></div>
            ${creditAvatarHtml(member, render)}
          </div>
          <div class="credit-meta">
            <span class="credit-role-badge">${escapeHtml(member.role || "Member")}</span>
            <h3>${escapeHtml(member.displayName || "Member")}</h3>
            ${robloxName ? `<p class="credit-roblox-name">${profileUrl ? `<a href="${escapeHtml(profileUrl)}" target="_blank" rel="noopener">@${escapeHtml(robloxName)}</a>` : `@${escapeHtml(robloxName)}`}</p>` : ""}
            <p class="credit-bio">${escapeHtml(member.bio || "")}</p>
            ${tags ? `<div class="credit-tags">${tags}</div>` : ""}
            ${links ? `<div class="credit-links">${links}</div>` : ""}
          </div>
        `;
          grid.appendChild(card);
        });
        section.appendChild(grid);
        teamsRoot.appendChild(section);
      });
      if (thanksRoot) {
        const thanks = credits.specialThanks || [];
        if (!thanks.length) {
          thanksRoot.innerHTML = "";
        } else {
          thanksRoot.innerHTML = `
          <div class="credits-thanks reveal">
            <h3>Special thanks</h3>
            <div class="credits-thanks-grid">
              ${thanks.map((t) => `<div class="credits-thanks-item"><strong>${escapeHtml(t.name || "")}</strong><span>${escapeHtml(t.note || "")}</span></div>`).join("")}
            </div>
          </div>
        `;
        }
      }
      afterRender();
    }
    async function loadAndRenderCredits(site) {
      await fetchCreditRenders();
      renderCredits(site);
    }
    function resolveResourceUrl(site, item) {
      if (item.url) {
        if (item.url.startsWith("#")) return item.url;
        if (item.url.startsWith("http") || item.url.startsWith("//")) return item.url;
        const base = window.ALLERAL_API || window.location.origin;
        return `${base.replace(/\/$/, "")}${item.url.startsWith("/") ? item.url : `/${item.url}`}`;
      }
      const key = item.urlKey || "";
      const links = site.links || {};
      const cfg = window.ALLERAL_CONFIG || {};
      if (key === "github") return links.github || "";
      if (key === "loaderRaw") return links.loaderRaw || "";
      if (key === "admin") return links.admin || "";
      if (key === "website") return links.website || cfg.publicUrl || "";
      return links[key] || "";
    }
    async function renderBanApiPanel() {
      const statusRoot = $("#banApiStatus");
      const endpointsRoot = $("#banApiEndpoints");
      const exampleRoot = $("#banApiExample");
      try {
        const base = window.ALLERAL_API || window.location.origin;
        const res = await fetch(`${base.replace(/\/$/, "")}/api/v1/bans/docs`, { cache: "no-store" });
        const data = await res.json();
        if (statusRoot) {
          statusRoot.innerHTML = `
          <div class="ban-api-stat"><span>Active bans</span><strong>${escapeHtml(String(data.activeBans ?? "\u2014"))}</strong></div>
          <div class="ban-api-stat"><span>API version</span><strong>v${escapeHtml(String(data.version || "1"))}</strong></div>
          <div class="ban-api-stat"><span>Status</span><strong class="live">${data.partnerApi ? "Auto-enabled" : "Off"}</strong></div>
          <div class="ban-api-stat"><span>Base URL</span><strong>${escapeHtml(String(data.baseUrl || base).replace(/^https?:\/\//, ""))}</strong></div>
        `;
        }
        const endpoints = data.endpoints || [];
        if (endpointsRoot) {
          endpointsRoot.innerHTML = endpoints.map(
            (ep) => `
          <article class="ban-api-endpoint">
            <div class="ban-api-endpoint-head">
              <span class="ban-api-method">${escapeHtml(ep.method || "GET")}</span>
              <code>${escapeHtml(ep.path || "")}</code>
              ${ep.auth ? `<span class="ban-api-auth">Auth</span>` : `<span class="ban-api-auth public">Public</span>`}
            </div>
            <p>${escapeHtml(ep.desc || "")}</p>
          </article>`
          ).join("");
        }
        const example = data.checkExample;
        if (exampleRoot && example?.body) {
          exampleRoot.textContent = JSON.stringify(example.body, null, 2);
        }
      } catch {
        if (statusRoot) statusRoot.innerHTML = `<p class="tool-panel-desc">Could not load Ban API docs.</p>`;
      }
    }
    async function runBanApiTest() {
      const out = $("#banApiTestResult");
      const key = $("#banTestKey")?.value.trim() || "";
      const userId = $("#banTestUserId")?.value.trim() || "";
      const username = $("#banTestUsername")?.value.trim() || "";
      if (!userId && !username) {
        flash("Enter a Roblox UserId or username", true);
        return;
      }
      if (!key) {
        flash("Partner API key required — copy from admin after sign-in or set BAN_PARTNER_API_KEY", true);
        if (out) {
          out.textContent = JSON.stringify({
            ok: false,
            error: "unauthorized",
            hint: "Send X-Ban-Api-Key. Keys auto-provision on first relay boot.",
          }, null, 2);
        }
        return;
      }
      const base = window.ALLERAL_API || window.location.origin;
      const headers = { "Content-Type": "application/json" };
      if (key) headers["X-Ban-Api-Key"] = key;
      try {
        const res = await fetch(`${base.replace(/\/$/, "")}/api/v1/bans/check`, {
          method: "POST",
          headers,
          body: JSON.stringify({
            player: { userId: userId || void 0, name: username || void 0 }
          })
        });
        const data = await res.json();
        if (out) {
          out.textContent = JSON.stringify(data, null, 2);
          out.classList.toggle("banned", data.allowed === false);
          out.classList.toggle("allowed", data.allowed === true);
        }
        if (!res.ok) flash(String(data.error || "Check failed"), true);
        else flash(data.allowed ? "Player allowed" : "Player banned");
      } catch (e) {
        if (out) out.textContent = e instanceof Error ? e.message : "Request failed";
        flash("Ban check failed", true);
      }
    }
    function bindBanApiTools() {
      $("#banApiTestBtn")?.addEventListener("click", () => void runBanApiTest());
      $("#banApiCopyDocs")?.addEventListener("click", () => {
        void copyText(`${window.location.origin}/api/v1/bans/docs`, "Docs URL copied");
      });
    }
    async function renderSyncPanel() {
      const root = $("#syncPanelBody");
      if (!root) return;
      root.innerHTML = `<p class="tool-panel-desc">Loading sync status\u2026</p>`;
      try {
        const base = window.ALLERAL_API || "";
        const res = await fetch(`${base}/api/sync/status`, { cache: "no-store" });
        const data = await res.json();
        const live = data.autoStatus === true || data.enabled === true;
        root.innerHTML = `
        <div class="sync-status-grid">
          <div class="sync-stat"><span>Auto-sync</span><strong class="${live ? "live" : ""}">${live ? "Active" : "Off"}</strong></div>
          <div class="sync-stat"><span>Commit</span><strong>${escapeHtml(String(data.commit || data.githubCommit || "\u2014")).slice(0, 12)}</strong></div>
          <div class="sync-stat"><span>Branch</span><strong>${escapeHtml(String(data.branch || "main"))}</strong></div>
          <div class="sync-stat"><span>Last pull</span><strong>${escapeHtml(String(data.lastSyncAt || data.updatedAt || "\u2014"))}</strong></div>
        </div>
      `;
      } catch {
        root.innerHTML = `<p class="tool-panel-desc">Could not reach sync endpoint.</p>`;
      }
    }
    function weaoStatusLabel(status) {
      const map = {
        recommended: "Best pick",
        supported: "Supported",
        detected: "Detected",
        outdated: "Outdated",
        working: "Working",
        not_working: "Not working"
      };
      return map[status] || titleCaseStatus(status);
    }
    function formatWeaoChangeTime(at) {
      if (!at) return "Just now";
      const diff = Math.max(0, Date.now() - at * 1e3);
      if (diff < 6e4) return "Just now";
      if (diff < 36e5) return `${Math.floor(diff / 6e4)}m ago`;
      return new Date(at * 1e3).toLocaleTimeString();
    }
    function filterWeaoList() {
      let list = state.weaoExploits;
      const q = state.weaoQuery.trim().toLowerCase();
      if (q) {
        list = list.filter(
          (entry) => (entry.title || "").toLowerCase().includes(q) || (entry.slug || "").includes(q) || (entry.platform || "").toLowerCase().includes(q)
        );
      }
      if (state.weaoFilter === "free") return list.filter((entry) => entry.free);
      if (state.weaoFilter === "working") return list.filter((entry) => entry.liveStatus === "working");
      if (state.weaoFilter === "not_working") return list.filter((entry) => entry.liveStatus === "not_working");
      if (state.weaoFilter !== "all") {
        return list.filter(
          (entry) => entry.alleralStatus === state.weaoFilter || entry.liveStatus === state.weaoFilter
        );
      }
      return list;
    }
    function updateExecutorDatalist() {
      const dl = $("#executorDatalist");
      if (!dl) return;
      dl.innerHTML = state.weaoExploits.map((entry) => `<option value="${escapeHtml(entry.title || "")}"></option>`).join("");
    }
    function setBugExecutor(name) {
      const input = $("#bugExecutor");
      if (!input || !name) return;
      input.value = name;
      localStorage.setItem(EXECUTOR_PREF_KEY, name);
      flash(`Executor set to ${name}`);
    }
    function renderWeaoStats() {
      const root = $("#weaoStats");
      if (!root) return;
      const s = state.weaoSummary;
      if (!s.total) {
        root.innerHTML = "";
        return;
      }
      root.innerHTML = `
      <div class="weao-stat"><span>Tracked</span><strong>${s.total || 0}</strong></div>
      <div class="weao-stat"><span>Working</span><strong class="live">${s.working || 0}</strong></div>
      <div class="weao-stat"><span>Not working</span><strong class="warn">${s.notWorking || 0}</strong></div>
      <div class="weao-stat"><span>Detected</span><strong>${s.detected || 0}</strong></div>
      <div class="weao-stat"><span>Best for Alleral</span><strong>${s.recommended || 0}</strong></div>
    `;
    }
    function renderWeaoLiveBadge() {
      const badge = $("#weaoLiveBadge");
      const countdown = $("#weaoCountdown");
      if (!badge) return;
      if (state.weaoLive) {
        badge.innerHTML = `<span class="weao-live-dot"></span> Live \xB7 WEAO`;
        badge.classList.add("active");
      } else {
        badge.innerHTML = `WEAO`;
        badge.classList.remove("active");
      }
      if (countdown && state.weaoNextPollAt) {
        const sec = Math.max(0, Math.ceil((state.weaoNextPollAt - Date.now()) / 1e3));
        countdown.textContent = state.weaoLive ? `Next check in ${sec}s` : `Paused \xB7 scroll to Tools for live updates`;
      }
    }
    function renderWeaoActivityFeed() {
      const feed = $("#weaoActivityFeed");
      if (!feed) return;
      const items = [...state.weaoChanges || [], ...state.weaoRecentChanges || []].filter((item, index, arr) => arr.findIndex((x) => x.message === item.message && x.slug === item.slug) === index).slice(0, 12);
      if (!items.length) {
        feed.innerHTML = `<p class="weao-feed-empty">Watching WEAO \u2014 status changes appear here in real time when Roblox or executors patch.</p>`;
        return;
      }
      feed.innerHTML = items.map(
        (item) => `
      <div class="weao-feed-item severity-${escapeHtml(item.severity || "warning")}">
        <span class="weao-feed-time">${escapeHtml(formatWeaoChangeTime(item.at))}</span>
        <p>${escapeHtml(item.message || "Status changed")}</p>
      </div>`
      ).join("");
    }
    function markWeaoClientChanges(prev, next) {
      const changes = [];
      for (const entry of next) {
        const slug = entry.slug || "";
        if (!slug) continue;
        const fp = entry.fingerprint || "";
        const old = prev[slug];
        if (old && fp && old !== fp) {
          changes.push({
            slug,
            title: entry.title,
            severity: entry.liveStatus === "working" ? "good" : entry.liveStatus === "not_working" ? "bad" : "warning",
            message: `${entry.title}: ${entry.liveLabel || "Status updated"}`,
            at: Date.now() / 1e3
          });
          state.weaoChangedSlugs[slug] = Date.now();
        }
        if (slug && fp) prev[slug] = fp;
      }
      return changes;
    }
    function renderWeaoExecutors() {
      const root = $("#executorList");
      if (!root) return;
      const list = filterWeaoList();
      const updated = $("#weaoUpdated");
      if (updated) {
        updated.textContent = state.weaoFetchedAt ? `Last sync ${new Date(state.weaoFetchedAt).toLocaleTimeString()} \xB7 ${state.weaoExploits.length} executors from WEAO` : "";
      }
      renderWeaoLiveBadge();
      renderWeaoActivityFeed();
      if (!state.weaoExploits.length) {
        root.innerHTML = `<p class="tool-panel-desc">Loading live executor data from WEAO\u2026</p>`;
        return;
      }
      if (!list.length) {
        root.innerHTML = `<p class="tool-panel-desc">No executors match your search. Try clearing filters.</p>`;
        return;
      }
      const now = Date.now();
      root.innerHTML = list.map((ex) => {
        const slug = ex.slug || "";
        const changed = slug && state.weaoChangedSlugs[slug] && now - state.weaoChangedSlugs[slug] < 12e4;
        const live = ex.liveStatus || "supported";
        return `
      <article class="weao-exec-card status-${escapeHtml(live)}${changed ? " weao-changed" : ""}" data-slug="${escapeHtml(slug)}">
        <div class="weao-exec-live-row">
          <span class="weao-live-pill ${escapeHtml(live)}"><span class="weao-live-pill-dot"></span>${escapeHtml(ex.liveLabel || weaoStatusLabel(live))}</span>
          ${ex.updatedDate ? `<span class="weao-updated-date">${escapeHtml(ex.updatedDate)}</span>` : ""}
        </div>
        <div class="weao-exec-head">
          ${ex.logo ? `<img class="weao-exec-logo" src="${escapeHtml(ex.logo)}" alt="" width="44" height="44" loading="lazy" />` : `<span class="weao-exec-logo-fallback">${escapeHtml((ex.title || "?").charAt(0))}</span>`}
          <div class="weao-exec-title">
            <strong>${escapeHtml(ex.title || "Executor")}</strong>
            <small>v${escapeHtml(ex.version || "?")} \xB7 ${escapeHtml(ex.platform || "Windows")}</small>
            ${ex.liveDetail ? `<span class="weao-exec-detail">${escapeHtml(ex.liveDetail)}</span>` : ""}
          </div>
          <span class="executor-badge ${escapeHtml(ex.alleralStatus || "supported")}">${escapeHtml(weaoStatusLabel(ex.alleralStatus || "supported"))}</span>
        </div>
        <dl class="weao-exec-meta">
          <div><dt>Hyperion</dt><dd>${ex.detected ? "Detected" : "Undetected"}</dd></div>
          <div><dt>Roblox patch</dt><dd>${ex.updateStatus ? "Executor updated" : "Needs update"}</dd></div>
          ${ex.suncPercentage != null ? `<div><dt>sUNC</dt><dd>${ex.suncPercentage}%</dd></div>` : ""}
          <div><dt>Cost</dt><dd>${escapeHtml(ex.cost || (ex.free ? "Free" : "Paid"))}</dd></div>
        </dl>
        <div class="weao-exec-actions">
          ${ex.websitelink ? `<a class="btn btn-outline btn-sm" href="${escapeHtml(ex.websitelink)}" target="_blank" rel="noopener">Website</a>` : ""}
          ${ex.discordlink ? `<a class="btn btn-outline btn-sm" href="${escapeHtml(ex.discordlink)}" target="_blank" rel="noopener">Discord</a>` : ""}
          <button type="button" class="btn btn-outline btn-sm" data-use-exec="${escapeHtml(ex.title || "")}">Use in report</button>
          <button type="button" class="btn btn-outline btn-sm" data-copy-exec="${escapeHtml(ex.title || "")}">Copy</button>
        </div>
      </article>`;
      }).join("");
      root.querySelectorAll("[data-use-exec]").forEach((btn) => {
        btn.addEventListener("click", () => setBugExecutor(btn.dataset.useExec || ""));
      });
      root.querySelectorAll("[data-copy-exec]").forEach((btn) => {
        btn.addEventListener("click", () => {
          void copyText(btn.dataset.copyExec || "", "Executor copied");
        });
      });
      afterRender();
    }
    function scheduleWeaoPoll(delayMs) {
      clearTimeout(state.weaoPollTimer);
      const ms = delayMs ?? (state.weaoLive ? WEAO_LIVE_POLL_MS : WEAO_IDLE_POLL_MS);
      state.weaoNextPollAt = Date.now() + ms;
      state.weaoPollTimer = window.setTimeout(() => {
        void fetchWeaoExploits(false, state.weaoLive);
      }, ms);
    }
    function startWeaoCountdown() {
      clearInterval(state.weaoCountdownTimer);
      state.weaoCountdownTimer = window.setInterval(() => renderWeaoLiveBadge(), 1e3);
    }
    async function fetchWeaoExploits(refresh = false, live = state.weaoLive) {
      const root = $("#executorList");
      try {
        const params = new URLSearchParams();
        if (refresh) params.set("refresh", "1");
        if (live) params.set("live", "1");
        const qs = params.toString();
        const data = await api(`/api/weao/exploits${qs ? `?${qs}` : ""}`);
        const prevPrints = { ...state.weaoFingerprints };
        const nextExploits = data.exploits || [];
        const serverChanges = data.changes || [];
        const clientChanges = markWeaoClientChanges(prevPrints, nextExploits);
        state.weaoFingerprints = prevPrints;
        state.weaoExploits = nextExploits;
        state.weaoSummary = data.summary || {};
        state.weaoFetchedAt = String(data.fetchedAt || "");
        state.weaoPollSec = Number(data.pollIntervalSec) || (live ? 35 : 120);
        state.weaoChanges = serverChanges.length ? serverChanges : clientChanges;
        state.weaoRecentChanges = data.recentChanges || [];
        const updated = $("#weaoUpdated");
        if (updated) {
          if (data.warning) {
            updated.textContent = `${data.stale ? "Cached WEAO data" : "WEAO warning"} \xB7 ${String(data.warning)}`;
          }
        }
        for (const change of state.weaoChanges) {
          if (change.slug) state.weaoChangedSlugs[change.slug] = Date.now();
        }
        renderWeaoStats();
        renderWeaoExecutors();
        updateExecutorDatalist();
        if (state.weaoChanges.length && state.weaoLive) {
          const headline = state.weaoChanges[0]?.message;
          if (headline) flash(headline);
        }
        scheduleWeaoPoll(state.weaoPollSec * 1e3);
      } catch {
        if (root) {
          root.innerHTML = `<p class="tool-panel-desc">Could not reach WEAO. <button type="button" class="btn-text" id="weaoRetry">Retry</button></p>`;
          $("#weaoRetry")?.addEventListener("click", () => void fetchWeaoExploits(true, true));
        }
        scheduleWeaoPoll(WEAO_IDLE_POLL_MS);
      }
    }
    function bindExecutorTools() {
      $("#executorSearch")?.addEventListener("input", (e) => {
        state.weaoQuery = e.target.value;
        renderWeaoExecutors();
      });
      $("#weaoRefresh")?.addEventListener("click", () => void fetchWeaoExploits(true, true));
      $$("[data-weao-filter]").forEach((btn) => {
        btn.addEventListener("click", () => {
          state.weaoFilter = btn.dataset.weaoFilter || "all";
          $$("[data-weao-filter]").forEach((chip) => chip.classList.toggle("active", chip === btn));
          renderWeaoExecutors();
        });
      });
      const bugExec = $("#bugExecutor");
      const savedExec = localStorage.getItem(EXECUTOR_PREF_KEY);
      if (bugExec && savedExec) bugExec.value = savedExec;
      bugExec?.addEventListener("change", () => {
        const value = bugExec.value.trim();
        if (value) localStorage.setItem(EXECUTOR_PREF_KEY, value);
      });
      const tools = $("#tools");
      if (tools) {
        const observer = new IntersectionObserver(
          (entries) => {
            const visible = entries.some((e) => e.isIntersecting);
            const wasLive = state.weaoLive;
            state.weaoLive = visible;
            renderWeaoLiveBadge();
            if (visible && !wasLive) void fetchWeaoExploits(false, true);
            else if (visible !== wasLive) scheduleWeaoPoll(visible ? WEAO_LIVE_POLL_MS : WEAO_IDLE_POLL_MS);
          },
          { threshold: 0.15 }
        );
        observer.observe(tools);
      }
    }
    function startWeaoPolling() {
      startWeaoCountdown();
      scheduleWeaoPoll(WEAO_IDLE_POLL_MS);
    }
    function renderTools(site) {
      void fetchWeaoExploits(false, false);
      void renderBanApiPanel();
      const resRoot = $("#resourcesGrid");
      if (resRoot) {
        resRoot.innerHTML = (site.resources || []).map((item) => {
          const url = resolveResourceUrl(site, item);
          if (!url) return "";
          const external = !url.startsWith("#");
          return `<a class="resource-card reveal" href="${escapeHtml(url)}"${external ? ' target="_blank" rel="noopener"' : ""}><strong>${escapeHtml(item.title || "Link")}</strong><span>${escapeHtml(item.desc || "")}</span></a>`;
        }).filter(Boolean).join("");
      }
      void renderSyncPanel();
      afterRender();
    }
    function bindQuickActions() {
      $("#quickCopyScript")?.addEventListener("click", () => void copyLoadstring());
      $("#quickViewGames")?.addEventListener("click", () => {
        location.hash = "#games";
        $("#games")?.scrollIntoView({ behavior: "smooth" });
      });
      $("#quickSupport")?.addEventListener("click", () => {
        location.hash = "#support";
        $("#support")?.scrollIntoView({ behavior: "smooth" });
      });
      $("#quickExecutors")?.addEventListener("click", () => {
        location.hash = "#tools";
        $("#tools")?.scrollIntoView({ behavior: "smooth" });
        setTimeout(() => $("#executorSearch")?.focus(), 350);
      });
      $("#quickTeam")?.addEventListener("click", () => {
        location.hash = "#credits";
        $("#credits")?.scrollIntoView({ behavior: "smooth" });
      });
    }
    const CMD_ACTIONS = [
      { label: "Go to Home", hash: "#home", keys: "G H" },
      { label: "Go to Games", hash: "#games", keys: "G G" },
      { label: "Go to Ban API", hash: "#ban-api", keys: "G B" },
      { label: "Go to Creator", hash: "#credits", keys: "G C" },
      { label: "Go to FAQ", hash: "#faq", keys: "G F" },
      { label: "Go to Support", hash: "#support", keys: "G S" },
      { label: "Copy loadstring", action: "copy", keys: "C L" },
      { label: "Search games", action: "search", keys: "/" }
    ];
    function bindCommandPalette() {
      const dialog = $("#cmdPalette");
      const input = $("#cmdInput");
      const list = $("#cmdList");
      if (!dialog || !input || !list) return;
      const dlg = dialog;
      const inp = input;
      const lst = list;
      let focusIdx = 0;
      function renderList(query = "") {
        const q = query.trim().toLowerCase();
        const items = CMD_ACTIONS.filter((a) => a.label.toLowerCase().includes(q));
        focusIdx = 0;
        if (!items.length) {
          lst.innerHTML = `<p class="cmd-palette-empty">No matching actions</p>`;
          return;
        }
        lst.innerHTML = items.map(
          (a, i) => `<button type="button" class="cmd-palette-item${i === 0 ? " focused" : ""}" data-idx="${i}" data-hash="${a.hash || ""}" data-action="${a.action || ""}">${escapeHtml(a.label)}<kbd>${escapeHtml(a.keys)}</kbd></button>`
        ).join("");
        lst.querySelectorAll(".cmd-palette-item").forEach((btn) => {
          btn.addEventListener("click", () => runAction(items[parseInt(btn.dataset.idx || "0", 10)]));
        });
      }
      function runAction(item) {
        dlg.close();
        if (item.hash) {
          location.hash = item.hash;
          document.querySelector(item.hash)?.scrollIntoView({ behavior: "smooth" });
        } else if (item.action === "copy") void copyLoadstring();
        else if (item.action === "search") $("#gameSearch")?.focus();
      }
      function openPalette() {
        inp.value = "";
        renderList();
        dlg.showModal();
        inp.focus();
      }
      document.addEventListener("keydown", (e) => {
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
          e.preventDefault();
          openPalette();
        }
      });
      inp.addEventListener("input", () => renderList(inp.value));
      inp.addEventListener("keydown", (e) => {
        const items = lst.querySelectorAll(".cmd-palette-item");
        if (!items.length) return;
        if (e.key === "ArrowDown") {
          e.preventDefault();
          focusIdx = Math.min(focusIdx + 1, items.length - 1);
        } else if (e.key === "ArrowUp") {
          e.preventDefault();
          focusIdx = Math.max(focusIdx - 1, 0);
        } else if (e.key === "Enter") {
          e.preventDefault();
          items[focusIdx]?.click();
          return;
        } else return;
        items.forEach((el, i) => el.classList.toggle("focused", i === focusIdx));
        items[focusIdx]?.scrollIntoView({ block: "nearest" });
      });
      dlg.addEventListener("click", (e) => {
        if (e.target === dlg) dlg.close();
      });
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
      renderTools(data);
      renderGameStatsBar(data);
      void loadAndRenderCredits(data);
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
    async function copyText(text, msg, btn) {
      try {
        await navigator.clipboard.writeText(text);
        flash(msg);
        if (btn) {
          const prev = btn.textContent;
          btn.textContent = "Copied!";
          btn.classList.add("copied");
          setTimeout(() => {
            btn.textContent = prev;
            btn.classList.remove("copied");
          }, 2e3);
        }
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
      await copyText(text, "Script copied to clipboard", $("#copyLoadstring"));
    }
    async function requireTurnstile(formId) {
      const ts = window.AlleralTurnstile;
      if (!ts?.getToken) return "";
      const token = await ts.getToken(formId);
      const mount = document.querySelector(`.form-turnstile[data-turnstile="${formId}"][data-rendered="1"]`);
      if (mount && !token) {
        throw new Error("Complete the security check below before submitting.");
      }
      return token;
    }
    async function submitBug(ev) {
      ev.preventDefault();
      const err = $("#bugError");
      if (err) err.textContent = "";
      try {
        const captcha = await requireTurnstile("bug");
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
            turnstileToken: captcha,
            ...submissionMeta()
          })
        });
        $("#bugForm")?.reset();
        window.AlleralTurnstile?.reset?.("bug");
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
        const captcha = await requireTurnstile("feature");
        await api("/api/feature-request", {
          method: "POST",
          body: JSON.stringify({
            robloxUser: $("#featureUser")?.value.trim(),
            game: $("#featureGame")?.value.trim(),
            contact: $("#featureContact")?.value.trim(),
            idea: $("#featureIdea")?.value.trim(),
            turnstileToken: captcha,
            ...submissionMeta()
          })
        });
        $("#featureForm")?.reset();
        window.AlleralTurnstile?.reset?.("feature");
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
        const captcha = await requireTurnstile("support");
        await api("/api/support", {
          method: "POST",
          body: JSON.stringify({
            topic: $("#supportTopic")?.value,
            robloxUser: $("#supportUser")?.value.trim(),
            contact: $("#supportContact")?.value.trim(),
            question: $("#supportQuestion")?.value.trim(),
            turnstileToken: captcha,
            ...submissionMeta()
          })
        });
        $("#supportForm")?.reset();
        window.AlleralTurnstile?.reset?.("support");
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
              void window.AlleralTurnstile?.mountVisible?.();
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
    function bindGameSearch() {
      const input = $("#gameSearch");
      if (!input) return;
      let timer = 0;
      input.addEventListener("input", () => {
        window.clearTimeout(timer);
        timer = window.setTimeout(() => {
          state.gameQuery = input.value;
          if (state.site) void renderGames(state.site);
        }, 180);
      });
    }
    function bindFaqSearch() {
      const input = $("#faqSearch");
      if (!input) return;
      let timer = 0;
      input.addEventListener("input", () => {
        window.clearTimeout(timer);
        timer = window.setTimeout(() => {
          state.faqQuery = input.value;
          if (state.site) renderFaq(state.site);
        }, 180);
      });
      $("#faqExpandAll")?.addEventListener("click", () => {
        $$(".faq-item").forEach((item) => {
          item.open = true;
        });
      });
      $("#faqCollapseAll")?.addEventListener("click", () => {
        $$(".faq-item").forEach((item) => {
          item.open = false;
        });
      });
    }
    function bindKeyboardShortcuts() {
      document.addEventListener("keydown", (e) => {
        if (e.key !== "/" || e.metaKey || e.ctrlKey || e.altKey) return;
        const tag = e.target?.tagName;
        if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
        e.preventDefault();
        $("#gameSearch")?.focus();
      });
    }
    function bindBackToTop() {
      const btn = $("#backToTop");
      if (!btn) return;
      window.addEventListener("scroll", () => {
        const show = window.scrollY > 480;
        btn.hidden = !show;
        btn.classList.toggle("visible", show);
      }, { passive: true });
      btn.addEventListener("click", () => {
        window.scrollTo({ top: 0, behavior: "smooth" });
      });
    }
    function bindScrollSpy() {
      const sections = $$("main section[id]");
      if (!sections.length) return;
      const links = $$(".nav-links a[data-section]");
      const observer = new IntersectionObserver(
        (entries) => {
          const visible = entries.filter((e) => e.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
          if (!visible?.target?.id) return;
          links.forEach((a) => a.classList.toggle("active", a.dataset.section === visible.target.id));
        },
        { rootMargin: "-40% 0px -45% 0px", threshold: [0, 0.15, 0.4] }
      );
      sections.forEach((s) => observer.observe(s));
    }
    function bindMobileNav() {
      const toggle = $("#navToggle");
      const nav = $("#mainNav");
      toggle?.addEventListener("click", () => nav?.classList.toggle("open"));
      $$(".nav-links a").forEach((a) => a.addEventListener("click", () => nav?.classList.remove("open")));
    }
    async function initFormCaptcha() {
      try {
        const data = await api("/api/gate/config");
        if (data.serverVerify) {
          void window.AlleralTurnstile?.mountVisible?.();
        } else {
          window.AlleralTurnstile?.hideAll?.();
        }
      } catch {
        void window.AlleralTurnstile?.mountVisible?.();
      }
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
        void copyText($("#primaryUrl")?.textContent || "", "Link copied", $("#copyPrimaryUrl"));
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
      bindGameSearch();
      bindFaqSearch();
      bindKeyboardShortcuts();
      bindBackToTop();
      bindScrollSpy();
      bindModal();
      bindMobileNav();
      bindQuickActions();
      bindCommandPalette();
      bindExecutorTools();
      bindBanApiTools();
      startWeaoPolling();
      void initFormCaptcha();
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
          document.body.classList.remove("cf-gate-lock", "cf-gate-active");
        },
        { once: true }
      );
    }
  })();
})();
