import type { CreditMember, CreditRenderMember, GameEntry, SitePayload } from "./types";

(() => {
  const GRADIENTS = [
    "linear-gradient(135deg, #1a3a5c 0%, #0a1628 50%, #2997ff33 100%)",
    "linear-gradient(135deg, #2d1f4e 0%, #0f0a1a 50%, #bf5af233 100%)",
    "linear-gradient(135deg, #1a3d2e 0%, #0a1a12 50%, #30d15833 100%)",
    "linear-gradient(135deg, #3d2a1a 0%, #1a1008 50%, #ffd60a33 100%)",
    "linear-gradient(135deg, #1a2a3d 0%, #0a101a 50%, #64d2ff33 100%)",
    "linear-gradient(135deg, #3d1a2a 0%, #1a0a10 50%, #ff453a33 100%)",
  ];

  const $ = <T extends Element = Element>(sel: string, root: ParentNode = document): T | null =>
    root.querySelector(sel) as T | null;
  const $$ = <T extends Element = Element>(sel: string, root: ParentNode = document): T[] =>
    [...root.querySelectorAll(sel)] as T[];

  const toastEl = $("#toast");
  const modal = $("#gameModal") as HTMLDialogElement | null;
  const state = {
    site: null as SitePayload | null,
    changelogShown: 2,
    gameFilter: "all",
    gameQuery: "",
    faqQuery: "",
    siteSignature: "",
    thumbs: {} as Record<string, string>,
    creditRenders: {} as Record<string, CreditRenderMember>,
    gamesRenderToken: 0,
  };
  const SITE_POLL_MS = 30000;
  const VISIT_KEY = "alleral_hub_logged";

  function escapeHtml(value: unknown): string {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function flash(text: string, isError = false): void {
    if (!toastEl) return;
    toastEl.textContent = text;
    toastEl.classList.toggle("error", isError);
    toastEl.classList.add("show");
    setTimeout(() => toastEl.classList.remove("show"), 2800);
  }

  function submissionMeta(): Record<string, string> {
    return {
      pageUrl: `${location.pathname}${location.hash}`,
      userAgent: navigator.userAgent,
    };
  }

  async function api(path: string, options: RequestInit = {}): Promise<Record<string, unknown>> {
    const base = window.ALLERAL_API || "";
    const res = await fetch(base + path, {
      headers: { "Content-Type": "application/json", ...(options.headers as Record<string, string>) },
      ...options,
    });
    const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
    if (!res.ok || data.ok === false) {
      throw new Error(String(data.error || `Request failed (${res.status})`));
    }
    return data;
  }

  function gradientFor(id: string, index: number): string {
    let hash = index;
    for (let i = 0; i < (id || "").length; i += 1) hash += id.charCodeAt(i);
    return GRADIENTS[hash % GRADIENTS.length];
  }

  function placeIdOf(game: GameEntry): string | null {
    const ids = game?.placeIds;
    return Array.isArray(ids) && ids[0] ? String(ids[0]) : null;
  }

  async function fetchThumbnails(games: GameEntry[]): Promise<Record<string, string>> {
    const placeIds = [...new Set(games.map(placeIdOf).filter(Boolean) as string[])];
    if (!placeIds.length) return state.thumbs;

    const missing = placeIds.filter((id) => !state.thumbs[id]);
    if (!missing.length) return state.thumbs;

    try {
      const base = window.ALLERAL_API || "";
      const url = `${base}/api/games/thumbnails?placeIds=${encodeURIComponent(missing.join(","))}`;
      const res = await fetch(url);
      const json = (await res.json()) as { ok?: boolean; thumbnails?: Record<string, string> };
      if (json.ok && json.thumbnails) Object.assign(state.thumbs, json.thumbnails);
    } catch {
      /* keep cached */
    }
    return state.thumbs;
  }

  function statusChipHtml(status: string, label: string): string {
    return `<span class="status-chip status-animated ${status}"><span class="status-ring"></span><span class="status-dot-core"></span>${label}</span>`;
  }

  function setActiveNav(): void {
    const id = location.hash.replace("#", "") || "home";
    $$<HTMLAnchorElement>(".nav-links a[data-section]").forEach((a) =>
      a.classList.toggle("active", a.dataset.section === id)
    );
  }

  function titleCaseStatus(value: string): string {
    const text = String(value || "working").toLowerCase();
    return text.charAt(0).toUpperCase() + text.slice(1);
  }

  function formatChangelogDate(raw: string | undefined): string {
    if (!raw) return "";
    const d = new Date(`${raw}T12:00:00`);
    if (Number.isNaN(d.getTime())) return raw;
    return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" });
  }

  function logHubVisit(source = "load"): void {
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
        source,
      }),
      keepalive: true,
    }).catch(() => {});
  }

  function afterRender(): void {
    window.AlleralEffects?.observeReveals?.();
    window.AlleralEffects?.animateCounters?.();
    window.AlleralEffects?.bindMotion?.();
    window.AlleralSelect?.enhance?.();
  }

  function animateCount(el: HTMLElement | null, target: number): void {
    if (!el || !window.AlleralEffects?.animateNumber) {
      if (el) el.textContent = String(target);
      return;
    }
    window.AlleralEffects.animateNumber(el, target);
  }

  function renderAnnouncement(site: SitePayload): void {
    const el = $("#announcement");
    const text = (site.announcement || "").trim();
    if (!el) return;
    el.classList.toggle("hidden", !text);
    if (text) el.textContent = text;
  }

  function renderHero(site: SitePayload): void {
    const brand = site.brand || "Alleral";
    const heroBrand = $("#heroBrand");
    const tagline = $("#tagline");
    if (heroBrand) heroBrand.textContent = brand.toUpperCase();
    if (tagline) tagline.textContent = site.tagline || "The ultimate Roblox script library.";
    const lv = $("#loaderVersion");
    const su = $("#scriptsUpdated");
    const ls = $("#loadstringCode");
    if (lv) lv.textContent = site.loaderVersion || "—";
    if (su) su.textContent = site.scriptsUpdatedAt || "—";
    if (ls) ls.textContent = site.loadstring || "";
    const games = Object.values(site.games || {});
    const working = games.filter((g) => (g.status || "working").toLowerCase() === "working").length;
    const gc = $("#gameCount") as HTMLElement | null;
    const wc = $("#workingCount") as HTMLElement | null;
    if (gc) gc.dataset.count = String(games.length);
    if (wc) wc.dataset.count = String(working);
    animateCount(gc, games.length);
    animateCount(wc, working);
  }

  function renderFeatures(site: SitePayload): void {
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

  function setModalArt(thumbUrl: string | null, gradient: string): void {
    const art = $("#modalArt");
    if (!art) return;
    art.innerHTML = `
      ${thumbUrl ? `<img src="${thumbUrl}" alt="" loading="lazy" />` : ""}
      <div class="modal-art-fallback" style="background:${gradient}"></div>
    `;
  }

  function openGameModal(game: GameEntry, gradient: string, thumbUrl: string | null): void {
    if (!modal) return;
    const title = $("#modalTitle");
    const meta = $("#modalMeta");
    const desc = $("#modalDesc");
    if (title) title.textContent = game.name || game.id || "Game";
    if (meta) meta.textContent = `Version ${game.version || "?"} · ${game.id || ""}`;
    if (desc) desc.textContent = game.description || game.message || "No description available.";
    const status = (game.status || "working").toLowerCase();
    const badge = $("#modalBadge");
    if (badge) {
      badge.className = `status-chip status-animated modal-badge ${status}`;
      badge.innerHTML = `<span class="status-ring"></span><span class="status-dot-core"></span>${titleCaseStatus(status)}`;
    }
    setModalArt(thumbUrl, gradient);
    const roblox = $("#modalRoblox") as HTMLAnchorElement | null;
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
    void (inner as HTMLElement | null)?.offsetWidth;
    inner?.classList.add("modal-enter");
  }

  async function renderGames(site: SitePayload): Promise<void> {
    const root = $("#gamesGrid");
    if (!root) return;

    const token = ++state.gamesRenderToken;
    const filter = state.gameFilter;
    root.classList.add("is-updating");
    root.innerHTML = "";

    let games = Object.entries(site.games || {}).map(([id, g]) => ({ ...g, id })).sort((a, b) =>
      (a.name || "").localeCompare(b.name || "")
    );
    if (filter !== "all") {
      games = games.filter((g) => (g.status || "working").toLowerCase() === filter);
    }
    const query = state.gameQuery.trim().toLowerCase();
    if (query) {
      games = games.filter((g) => {
        const hay = `${g.name || ""} ${g.id || ""} ${g.description || ""} ${g.message || ""}`.toLowerCase();
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
          <button class="btn-link" type="button">View Details</button>
        </div>
      `;
      const img = card.querySelector(".game-thumb") as HTMLImageElement | null;
      if (img) {
        img.addEventListener("load", () => img.classList.add("loaded"));
        img.addEventListener("error", () => img.remove());
      }
      card.addEventListener("click", (e) => {
        if ((e.target as Element).closest("a")) return;
        openGameModal(game, grad, thumb);
      });
      root.appendChild(card);
    });

    if (token !== state.gamesRenderToken) return;
    root.classList.remove("is-updating");
    renderGameStatsBar(site);

    const bugGame = $("#bugGame") as HTMLSelectElement | null;
    if (bugGame) {
      const current = bugGame.value;
      const allGames = Object.entries(site.games || {})
        .map(([id, g]) => ({ ...g, id }))
        .sort((a, b) => (a.name || "").localeCompare(b.name || ""));
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

  function renderChangelog(site: SitePayload, reset = true): void {
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

  async function sendFaqFeedback(question: string, helpful: boolean, comment = ""): Promise<void> {
    await api("/api/faq-feedback", {
      method: "POST",
      body: JSON.stringify({ question, helpful, comment, ...submissionMeta() }),
    });
    flash(helpful ? "Thanks for the feedback" : "Got it — we'll improve this answer");
  }

  function renderFaq(site: SitePayload): void {
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
          const helpful = (btn as HTMLButtonElement).dataset.helpful === "yes";
          const bar = node.querySelector(".faq-feedback");
          node.querySelectorAll(".faq-feedback-btn").forEach((b) => {
            (b as HTMLButtonElement).disabled = true;
            b.classList.toggle("selected", b === btn);
          });
          try {
            await sendFaqFeedback(q, helpful);
            if (bar) {
              bar.innerHTML = `<span class="faq-feedback-thanks">Thanks for letting us know.</span>`;
            }
          } catch (err) {
            node.querySelectorAll(".faq-feedback-btn").forEach((b) => {
              (b as HTMLButtonElement).disabled = false;
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

  function renderBugCategories(site: SitePayload): void {
    const select = $("#bugCategory") as HTMLSelectElement | null;
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

  function initials(name: string): string {
    const parts = name.trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return "?";
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  function renderGameStatsBar(site: SitePayload): void {
    const root = $("#gameStatsBar");
    if (!root) return;
    const games = Object.values(site.games || {});
    const counts: Record<string, number> = {
      all: games.length,
      working: 0,
      testing: 0,
      maintenance: 0,
      broken: 0,
    };
    games.forEach((g) => {
      const s = (g.status || "working").toLowerCase();
      if (s in counts) counts[s] += 1;
    });
    const labels: Record<string, string> = {
      all: "All",
      working: "Working",
      testing: "Testing",
      maintenance: "Maintenance",
      broken: "Broken",
    };
    root.innerHTML = Object.entries(counts)
      .map(([key, n]) => {
        const dot = key === "all" ? "" : `<span class="dot ${key}"></span>`;
        return `<button type="button" class="game-stat-chip${state.gameFilter === key ? " active" : ""}" data-filter="${key}">${dot}${labels[key]} <strong>${n}</strong></button>`;
      })
      .join("");
    root.querySelectorAll(".game-stat-chip").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.gameFilter = (btn as HTMLButtonElement).dataset.filter || "all";
        $$<HTMLButtonElement>(".filter-pill").forEach((b) =>
          b.classList.toggle("active", b.dataset.filter === state.gameFilter)
        );
        if (state.site) void renderGames(state.site);
        renderGameStatsBar(state.site!);
      });
    });
  }

  async function fetchCreditRenders(): Promise<void> {
    try {
      const data = (await api("/api/credits/renders")) as { members?: Record<string, CreditRenderMember> };
      state.creditRenders = data.members || {};
    } catch {
      state.creditRenders = {};
    }
  }

  function creditAvatarHtml(member: CreditMember, render?: CreditRenderMember): string {
    const img = render?.renders?.body || render?.renders?.bust || render?.renders?.headshot;
    const name = member.displayName || render?.displayName || "Member";
    if (img) {
      return `<img class="credit-avatar-body" src="${escapeHtml(img)}" alt="${escapeHtml(name)} Roblox avatar" loading="lazy" />`;
    }
    return `<div class="credit-avatar-fallback" aria-hidden="true">${escapeHtml(initials(name))}</div>`;
  }

  function renderCredits(site: SitePayload): void {
    const teamsRoot = $("#creditsTeams");
    const thanksRoot = $("#creditsThanks");
    if (!teamsRoot) return;

    const credits = site.credits || {};
    const headline = $("#creditsHeadline");
    const sub = $("#creditsSubheadline");
    if (headline) headline.textContent = credits.headline || "The team behind Alleral";
    if (sub) sub.textContent = credits.subheadline || "";

    teamsRoot.innerHTML = "";
    (credits.teams || []).forEach((team) => {
      const section = document.createElement("div");
      section.className = "credits-team reveal";
      section.innerHTML = `<h3 class="credits-team-title">${escapeHtml(team.title || "Team")}</h3>`;
      const grid = document.createElement("div");
      grid.className = "credits-grid";

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

        const tags = (member.tags || [])
          .map((t) => `<span class="credit-tag">${escapeHtml(t)}</span>`)
          .join("");
        const links = Object.entries(member.links || {})
          .map(([k, url]) => `<a class="credit-link" href="${escapeHtml(url)}" target="_blank" rel="noopener">${escapeHtml(k)}</a>`)
          .join("");

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

  async function loadAndRenderCredits(site: SitePayload): Promise<void> {
    await fetchCreditRenders();
    renderCredits(site);
  }

  function resolveResourceUrl(site: SitePayload, item: { url?: string; urlKey?: string }): string {
    if (item.url) {
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
    return (links as Record<string, string>)[key] || "";
  }

  async function renderSyncPanel(): Promise<void> {
    const root = $("#syncPanelBody");
    if (!root) return;
    root.innerHTML = `<p class="tool-panel-desc">Loading sync status…</p>`;
    try {
      const base = window.ALLERAL_API || "";
      const res = await fetch(`${base}/api/sync/status`, { cache: "no-store" });
      const data = (await res.json()) as Record<string, unknown>;
      const live = data.autoStatus === true || data.enabled === true;
      root.innerHTML = `
        <div class="sync-status-grid">
          <div class="sync-stat"><span>Auto-sync</span><strong class="${live ? "live" : ""}">${live ? "Active" : "Off"}</strong></div>
          <div class="sync-stat"><span>Commit</span><strong>${escapeHtml(String(data.commit || data.githubCommit || "—")).slice(0, 12)}</strong></div>
          <div class="sync-stat"><span>Branch</span><strong>${escapeHtml(String(data.branch || "main"))}</strong></div>
          <div class="sync-stat"><span>Last pull</span><strong>${escapeHtml(String(data.lastSyncAt || data.updatedAt || "—"))}</strong></div>
        </div>
      `;
    } catch {
      root.innerHTML = `<p class="tool-panel-desc">Could not reach sync endpoint.</p>`;
    }
  }

  function renderTools(site: SitePayload): void {
    const execRoot = $("#executorList");
    if (execRoot) {
      execRoot.innerHTML = (site.executors || [])
        .map(
          (ex) => `
        <div class="executor-row">
          <strong>${escapeHtml(ex.name || "Executor")}</strong>
          <small>${escapeHtml(ex.note || "")}</small>
          <span class="executor-badge ${escapeHtml(ex.status || "supported")}">${escapeHtml(ex.status || "supported")}</span>
        </div>`
        )
        .join("");
    }

    const resRoot = $("#resourcesGrid");
    if (resRoot) {
      resRoot.innerHTML = (site.resources || [])
        .map((item) => {
          const url = resolveResourceUrl(site, item);
          if (!url) return "";
          return `<a class="resource-card reveal" href="${escapeHtml(url)}" target="_blank" rel="noopener"><strong>${escapeHtml(item.title || "Link")}</strong><span>${escapeHtml(item.desc || "")}</span></a>`;
        })
        .filter(Boolean)
        .join("");
    }

    void renderSyncPanel();
    afterRender();
  }

  function bindQuickActions(): void {
    $("#quickCopyScript")?.addEventListener("click", () => void copyLoadstring());
    $("#quickViewGames")?.addEventListener("click", () => {
      location.hash = "#games";
      $("#games")?.scrollIntoView({ behavior: "smooth" });
    });
    $("#quickSupport")?.addEventListener("click", () => {
      location.hash = "#support";
      $("#support")?.scrollIntoView({ behavior: "smooth" });
    });
    $("#quickTeam")?.addEventListener("click", () => {
      location.hash = "#credits";
      $("#credits")?.scrollIntoView({ behavior: "smooth" });
    });
  }

  const CMD_ACTIONS = [
    { label: "Go to Home", hash: "#home", keys: "G H" },
    { label: "Go to Games", hash: "#games", keys: "G G" },
    { label: "Go to Tools", hash: "#tools", keys: "G T" },
    { label: "Go to Team / Credits", hash: "#credits", keys: "G C" },
    { label: "Go to FAQ", hash: "#faq", keys: "G F" },
    { label: "Go to Support", hash: "#support", keys: "G S" },
    { label: "Copy loadstring", action: "copy", keys: "C L" },
    { label: "Search games", action: "search", keys: "/" },
  ];

  function bindCommandPalette(): void {
    const dialog = $("#cmdPalette") as HTMLDialogElement | null;
    const input = $("#cmdInput") as HTMLInputElement | null;
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
      lst.innerHTML = items
        .map(
          (a, i) =>
            `<button type="button" class="cmd-palette-item${i === 0 ? " focused" : ""}" data-idx="${i}" data-hash="${a.hash || ""}" data-action="${a.action || ""}">${escapeHtml(a.label)}<kbd>${escapeHtml(a.keys)}</kbd></button>`
        )
        .join("");

      lst.querySelectorAll(".cmd-palette-item").forEach((btn) => {
        btn.addEventListener("click", () => runAction(items[parseInt((btn as HTMLElement).dataset.idx || "0", 10)]));
      });
    }

    function runAction(item: (typeof CMD_ACTIONS)[number]) {
      dlg.close();
      if (item.hash) {
        location.hash = item.hash;
        document.querySelector(item.hash)?.scrollIntoView({ behavior: "smooth" });
      } else if (item.action === "copy") void copyLoadstring();
      else if (item.action === "search") ($("#gameSearch") as HTMLInputElement | null)?.focus();
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
        (items[focusIdx] as HTMLButtonElement)?.click();
        return;
      } else return;
      items.forEach((el, i) => el.classList.toggle("focused", i === focusIdx));
      (items[focusIdx] as HTMLElement)?.scrollIntoView({ block: "nearest" });
    });

    dlg.addEventListener("click", (e) => {
      if (e.target === dlg) dlg.close();
    });
  }

  function renderAccess(site: SitePayload): void {
    const cfg = window.ALLERAL_CONFIG || {};
    const links = site.links || {};
    const primary = links.website || cfg.publicUrl || `${window.location.origin}/`;
    const mirror = links.mirror || cfg.mirrorUrl || "";

    const primaryEl = $("#primaryUrl");
    const mirrorEl = $("#mirrorUrl");
    const mirrorLink = $("#mirrorLink") as HTMLAnchorElement | null;
    const footerEl = $("#footerSiteLink") as HTMLAnchorElement | null;

    if (primaryEl) primaryEl.textContent = primary;
    if (mirrorEl) mirrorEl.textContent = mirror || "Not available";
    if (mirrorLink && mirror) mirrorLink.href = mirror;
    if (footerEl) footerEl.href = primary;
  }

  function siteSignature(data: SitePayload | null): string {
    if (!data) return "";
    return [
      data.scriptsUpdatedAt,
      data.siteUpdatedAt,
      data.githubCommit,
      data.loaderVersion,
      Object.keys(data.games || {}).length,
    ].join("|");
  }

  async function applySite(data: SitePayload, { notify = false } = {}): Promise<void> {
    const prev = state.siteSignature;
    const sig = siteSignature(data);
    const changed = Boolean(prev && sig !== prev);
    state.site = data;
    state.siteSignature = sig;
    const brand = data.brand || "Alleral";
    document.title = `${brand} — Script Library`;
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

  async function loadSite(notify = false): Promise<void> {
    const data = (await api("/api/site")) as unknown as SitePayload;
    await applySite(data, { notify });
  }

  function startSitePolling(): void {
    setInterval(() => {
      loadSite(true).catch(() => {});
    }, SITE_POLL_MS);
  }

  async function copyText(text: string, msg: string, btn?: HTMLButtonElement | null): Promise<void> {
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
        }, 2000);
      }
    } catch {
      flash("Copy failed", true);
    }
  }

  async function checkLiveStatus(): Promise<void> {
    const el = $("#liveStatus") as HTMLElement | null;
    if (!el) return;
    const base = window.ALLERAL_API || "";
    try {
      const res = await fetch(`${base}/health`, { cache: "no-store" });
      const data = (await res.json()) as { ok?: boolean; version?: string; githubCommit?: string };
      if (data.ok) {
        el.className = "status-pill online";
        el.innerHTML = '<span class="status-dot"></span>Live';
        const commit = data.githubCommit ? ` · ${data.githubCommit}` : "";
        el.title = `Relay v${data.version || "?"} · Auto-sync${commit}`;
      } else throw new Error("offline");
    } catch {
      el.className = "status-pill offline";
      el.innerHTML = '<span class="status-dot"></span>Offline';
    }
  }

  async function copyLoadstring(): Promise<void> {
    const text = state.site?.loadstring || $("#loadstringCode")?.textContent || "";
    await copyText(text, "Script copied to clipboard", $("#copyLoadstring") as HTMLButtonElement | null);
  }

  async function requireTurnstile(formId: string): Promise<string> {
    const ts = window.AlleralTurnstile;
    if (!ts?.getToken) return "";
    const token = await ts.getToken(formId);
    const mount = document.querySelector(`.form-turnstile[data-turnstile="${formId}"][data-rendered="1"]`);
    if (mount && !token) {
      throw new Error("Complete the security check below before submitting.");
    }
    return token;
  }

  async function submitBug(ev: Event): Promise<void> {
    ev.preventDefault();
    const err = $("#bugError");
    if (err) err.textContent = "";
    try {
      const captcha = await requireTurnstile("bug");
      await api("/api/bug-report", {
        method: "POST",
        body: JSON.stringify({
          category: ($("#bugCategory") as HTMLSelectElement)?.value,
          severity: ($("#bugSeverity") as HTMLSelectElement)?.value,
          game: ($("#bugGame") as HTMLSelectElement)?.value,
          robloxUser: ($("#bugUser") as HTMLInputElement)?.value.trim(),
          executor: ($("#bugExecutor") as HTMLInputElement)?.value.trim(),
          contact: ($("#bugContact") as HTMLInputElement)?.value.trim(),
          description: ($("#bugDescription") as HTMLTextAreaElement)?.value.trim(),
          steps: ($("#bugSteps") as HTMLTextAreaElement)?.value.trim(),
          turnstileToken: captcha,
          ...submissionMeta(),
        }),
      });
      ($("#bugForm") as HTMLFormElement)?.reset();
      window.AlleralTurnstile?.reset?.("bug");
      flash("Report submitted — sent to Discord");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Submit failed";
      if (err) err.textContent = msg;
      flash(msg, true);
    }
  }

  async function submitFeature(ev: Event): Promise<void> {
    ev.preventDefault();
    const err = $("#featureError");
    if (err) err.textContent = "";
    try {
      const captcha = await requireTurnstile("feature");
      await api("/api/feature-request", {
        method: "POST",
        body: JSON.stringify({
          robloxUser: ($("#featureUser") as HTMLInputElement)?.value.trim(),
          game: ($("#featureGame") as HTMLInputElement)?.value.trim(),
          contact: ($("#featureContact") as HTMLInputElement)?.value.trim(),
          idea: ($("#featureIdea") as HTMLTextAreaElement)?.value.trim(),
          turnstileToken: captcha,
          ...submissionMeta(),
        }),
      });
      ($("#featureForm") as HTMLFormElement)?.reset();
      window.AlleralTurnstile?.reset?.("feature");
      flash("Idea submitted — sent to Discord");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Submit failed";
      if (err) err.textContent = msg;
      flash(msg, true);
    }
  }

  async function submitSupport(ev: Event): Promise<void> {
    ev.preventDefault();
    const err = $("#supportError");
    if (err) err.textContent = "";
    try {
      const captcha = await requireTurnstile("support");
      await api("/api/support", {
        method: "POST",
        body: JSON.stringify({
          topic: ($("#supportTopic") as HTMLSelectElement)?.value,
          robloxUser: ($("#supportUser") as HTMLInputElement)?.value.trim(),
          contact: ($("#supportContact") as HTMLInputElement)?.value.trim(),
          question: ($("#supportQuestion") as HTMLTextAreaElement)?.value.trim(),
          turnstileToken: captcha,
          ...submissionMeta(),
        }),
      });
      ($("#supportForm") as HTMLFormElement)?.reset();
      window.AlleralTurnstile?.reset?.("support");
      flash("Question sent — we'll see it in Discord");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Submit failed";
      if (err) err.textContent = msg;
      flash(msg, true);
    }
  }

  function bindTabs(): void {
    $$<HTMLButtonElement>(".support-tabs button").forEach((btn) => {
      btn.addEventListener("click", (e) => {
        const panel = btn.dataset.panel;
        $$<HTMLButtonElement>(".support-tabs button").forEach((b) => b.classList.toggle("active", b === btn));
        $$("[data-panel-body]").forEach((body) => {
          const show = (body as HTMLElement).dataset.panelBody === panel;
          body.classList.toggle("hidden", !show);
        if (show) {
          body.classList.remove("panel-enter");
          void (body as HTMLElement).offsetWidth;
          body.classList.add("panel-enter");
          void window.AlleralTurnstile?.mountVisible?.();
        }
        });
        const me = e as MouseEvent;
        if (me.clientX != null) {
          const r = btn.getBoundingClientRect();
          btn.style.setProperty("--x", `${((me.clientX - r.left) / btn.offsetWidth) * 100}%`);
          btn.style.setProperty("--y", `${((me.clientY - r.top) / btn.offsetHeight) * 100}%`);
        }
      });
    });
  }

  function bindGameFilters(): void {
    $$<HTMLButtonElement>(".filter-pill").forEach((btn) => {
      btn.addEventListener("click", () => {
        state.gameFilter = btn.dataset.filter || "all";
        $$<HTMLButtonElement>(".filter-pill").forEach((b) => b.classList.toggle("active", b === btn));
        if (state.site) void renderGames(state.site);
      });
    });
  }

  function bindModal(): void {
    $$(".modal-close, .modal-close-btn").forEach((btn) => {
      btn.addEventListener("click", () => modal?.close());
    });
    modal?.addEventListener("click", (e) => {
      if (e.target === modal) modal.close();
    });
  }

  function bindGameSearch(): void {
    const input = $("#gameSearch") as HTMLInputElement | null;
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

  function bindFaqSearch(): void {
    const input = $("#faqSearch") as HTMLInputElement | null;
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
      $$<HTMLDetailsElement>(".faq-item").forEach((item) => {
        item.open = true;
      });
    });
    $("#faqCollapseAll")?.addEventListener("click", () => {
      $$<HTMLDetailsElement>(".faq-item").forEach((item) => {
        item.open = false;
      });
    });
  }

  function bindKeyboardShortcuts(): void {
    document.addEventListener("keydown", (e) => {
      if (e.key !== "/" || e.metaKey || e.ctrlKey || e.altKey) return;
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;
      e.preventDefault();
      ($("#gameSearch") as HTMLInputElement | null)?.focus();
    });
  }

  function bindBackToTop(): void {
    const btn = $("#backToTop") as HTMLButtonElement | null;
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

  function bindScrollSpy(): void {
    const sections = $$("main section[id]");
    if (!sections.length) return;
    const links = $$<HTMLAnchorElement>(".nav-links a[data-section]");
    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (!visible?.target?.id) return;
        links.forEach((a) => a.classList.toggle("active", a.dataset.section === visible.target.id));
      },
      { rootMargin: "-40% 0px -45% 0px", threshold: [0, 0.15, 0.4] }
    );
    sections.forEach((s) => observer.observe(s));
  }

  function bindMobileNav(): void {
    const toggle = $("#navToggle");
    const nav = $("#mainNav");
    toggle?.addEventListener("click", () => nav?.classList.toggle("open"));
    $$(".nav-links a").forEach((a) => a.addEventListener("click", () => nav?.classList.remove("open")));
  }

  async function initFormCaptcha(): Promise<void> {
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

  function isGatePassed(): boolean {
    try {
      const raw = sessionStorage.getItem("alleral_gate_ok");
      if (!raw) return false;
      if (raw === "1") return true;
      const data = JSON.parse(raw) as { until?: number };
      return !!(data?.until && Date.now() < data.until);
    } catch {
      return sessionStorage.getItem("alleral_gate_ok") === "1";
    }
  }

  function initWhenReady(): void {
    if (isGatePassed()) logHubVisit("return");
    else window.addEventListener("alleral:gate-passed", () => logHubVisit("gate"), { once: true });

    $("#copyLoadstring")?.addEventListener("click", () => void copyLoadstring());
    $("#copyPrimaryUrl")?.addEventListener("click", () => {
      void copyText($("#primaryUrl")?.textContent || "", "Link copied", $("#copyPrimaryUrl") as HTMLButtonElement | null);
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
    if (fy) fy.textContent = String(new Date().getFullYear());
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
    void initFormCaptcha();
    setActiveNav();
    void checkLiveStatus();
    setInterval(() => void checkLiveStatus(), 60000);
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
