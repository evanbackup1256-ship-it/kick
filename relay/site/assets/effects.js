(() => {
  const EASE = (t) => 1 - (1 - t) ** 3;

  function animateNumber(el, target, duration = 1100) {
    if (!el) return;
    const start = parseInt(el.textContent, 10) || 0;
    const diff = target - start;
    if (diff === 0) {
      el.textContent = String(target);
      return;
    }
    const t0 = performance.now();
    function frame(now) {
      const p = Math.min((now - t0) / duration, 1);
      el.textContent = String(Math.round(start + diff * EASE(p)));
      if (p < 1) requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
  }

  function revealEl(el, delay = 0) {
    if (!el || el.classList.contains("visible")) return;
    if (delay <= 0) {
      el.classList.add("visible");
      return;
    }
    setTimeout(() => el.classList.add("visible"), delay);
  }

  function initHeroSequence() {
    const hero = document.querySelector(".hero");
    if (!hero) return;
    [...hero.querySelectorAll(".reveal")].forEach((el, i) => revealEl(el, 120 + i * 80));
  }

  window.AlleralEffects = {
    observeReveals(root = document) {
      const items = root.querySelectorAll(".reveal:not(.visible)");
      if (!items.length) return;

      const io = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            const el = entry.target;
            const delay = parseInt(el.dataset.revealDelay || "0", 10);
            const siblings = el.parentElement?.querySelectorAll(":scope > .reveal:not(.visible)") || [];
            const index = [...siblings].indexOf(el);
            const stagger = index >= 0 ? Math.min(index * 60, 360) : 0;
            setTimeout(() => el.classList.add("visible"), delay + stagger);
            io.unobserve(el);
          });
        },
        { threshold: 0.1, rootMargin: "0px 0px -4% 0px" }
      );

      items.forEach((el) => {
        if (el.closest(".hero")) return;
        io.observe(el);
      });
    },

    animateCounters() {
      document.querySelectorAll("[data-count]").forEach((el) => {
        const target = parseInt(el.dataset.count || el.textContent, 10) || 0;
        animateNumber(el, target);
      });
    },

    bindMotion() {
      /* Card motion is CSS-only (hover lift) — no JS transforms. */
    },

    animateNumber,
  };

  document.addEventListener("toggle", (e) => {
    const item = e.target;
    if (item?.classList?.contains("faq-item")) {
      item.classList.toggle("faq-open", item.open);
    }
  }, true);

  let ambientStarted = false;

  function startAmbientMotion() {
    if (ambientStarted) return;
    ambientStarted = true;

    const aurora = document.querySelector(".aurora");
    const orbs = document.querySelector(".hero-orbs");
    let scrollY = window.scrollY;
    let smoothY = scrollY;

    window.addEventListener("scroll", () => {
      scrollY = window.scrollY;
    }, { passive: true });

    function parallaxFrame() {
      smoothY += (scrollY - smoothY) * 0.06;
      const y = smoothY * 0.05;
      if (aurora) aurora.style.transform = `translate3d(0, ${y.toFixed(2)}px, 0)`;
      if (orbs) orbs.style.transform = `translate3d(0, ${(y * 0.35).toFixed(2)}px, 0)`;
      requestAnimationFrame(parallaxFrame);
    }
    requestAnimationFrame(parallaxFrame);

    const nav = document.getElementById("siteNav") || document.querySelector(".nav-shell");
    if (nav) {
      window.addEventListener("scroll", () => {
        nav.classList.toggle("nav-scrolled", window.scrollY > 16);
      }, { passive: true });
    }
  }

  function bootMotion() {
    initHeroSequence();
    window.AlleralEffects.observeReveals();
    startAmbientMotion();
  }

  window.addEventListener("alleral:gate-passed", () => {
    document.body?.classList.remove("cf-gate-active");
    bootMotion();
  }, { once: true });

  if (!document.body?.classList.contains("cf-gate-active")) {
    bootMotion();
  } else {
    document.querySelectorAll(".reveal").forEach((el) => el.classList.add("visible"));
  }
})();
