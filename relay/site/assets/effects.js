(() => {
  const prefersReduced = false;
  const hasViewTimeline = CSS.supports("(animation-timeline: view())");
  const EASE = (t) => 1 - (1 - t) ** 3;

  if (hasViewTimeline) {
    document.documentElement.classList.add("has-view-timeline");
  }

  function animateNumber(el, target, duration = 1100) {
    if (prefersReduced || !el) {
      if (el) el.textContent = String(target);
      return;
    }
    const start = parseInt(el.textContent, 10) || 0;
    const diff = target - start;
    if (diff === 0) return;
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
    [...hero.querySelectorAll(".reveal")].forEach((el, i) => revealEl(el, 220 + i * 110));
  }

  function bindTilt(card) {
    if (prefersReduced || card.dataset.tiltBound) return;
    card.dataset.tiltBound = "1";
    let targetX = 0;
    let targetY = 0;
    let currentX = 0;
    let currentY = 0;
    let raf = 0;

    function tick() {
      currentX += (targetX - currentX) * 0.08;
      currentY += (targetY - currentY) * 0.08;
      if (Math.abs(targetX - currentX) < 0.01 && Math.abs(targetY - currentY) < 0.01 && targetX === 0 && targetY === 0) {
        card.style.transform = "";
        raf = 0;
        return;
      }
      card.style.transform = `perspective(900px) rotateX(${currentY.toFixed(2)}deg) rotateY(${currentX.toFixed(2)}deg) translateY(-4px)`;
      raf = requestAnimationFrame(tick);
    }

    card.addEventListener("mousemove", (e) => {
      const r = card.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      targetX = x * 5;
      targetY = -y * 4;
      if (!raf) raf = requestAnimationFrame(tick);
    });
    card.addEventListener("mouseleave", () => {
      targetX = 0;
      targetY = 0;
      if (!raf) raf = requestAnimationFrame(tick);
    });
  }

  function bindMagnetic(el, strength = 0.22) {
    if (prefersReduced || el.dataset.magnetic) return;
    el.dataset.magnetic = "1";
    el.addEventListener("mousemove", (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left - r.width / 2) * strength;
      const y = (e.clientY - r.top - r.height / 2) * strength;
      el.style.transform = `translate(${x.toFixed(1)}px, ${y.toFixed(1)}px)`;
    });
    el.addEventListener("mouseleave", () => {
      el.style.transform = "";
    });
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
            const stagger = index >= 0 ? Math.min(index * 70, 420) : 0;
            setTimeout(() => el.classList.add("visible"), delay + stagger);
            io.unobserve(el);
          });
        },
        { threshold: 0.08, rootMargin: "0px 0px -5% 0px" }
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

    bindMotion(root = document) {
      if (prefersReduced) return;
      root.querySelectorAll(".tilt-card:not([data-tilt-bound])").forEach(bindTilt);
      root.querySelectorAll(".hero .btn-fill:not([data-magnetic])").forEach((btn) => bindMagnetic(btn, 0.18));
      root.querySelectorAll(".nav-links a:not([data-magnetic])").forEach((link) => bindMagnetic(link, 0.08));
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
    if (prefersReduced || ambientStarted) return;
    ambientStarted = true;

    document.body.classList.add("has-cursor-glow");
    const cursorGlow = document.querySelector(".cursor-glow");
    let glowX = 0;
    let glowY = 0;
    let smoothGX = 0;
    let smoothGY = 0;

    window.addEventListener("mousemove", (e) => {
      glowX = e.clientX;
      glowY = e.clientY;
    }, { passive: true });

    function cursorFrame() {
      smoothGX += (glowX - smoothGX) * 0.12;
      smoothGY += (glowY - smoothGY) * 0.12;
      if (cursorGlow) {
        cursorGlow.style.transform = `translate3d(${smoothGX.toFixed(1)}px, ${smoothGY.toFixed(1)}px, 0)`;
      }
      requestAnimationFrame(cursorFrame);
    }
    requestAnimationFrame(cursorFrame);

    const aurora = document.querySelector(".aurora");
    const orbs = document.querySelector(".hero-orbs");
    let scrollY = window.scrollY;
    let smoothY = scrollY;

    window.addEventListener("scroll", () => {
      scrollY = window.scrollY;
    }, { passive: true });

    function parallaxFrame() {
      smoothY += (scrollY - smoothY) * 0.06;
      const y = smoothY * 0.08;
      if (aurora) aurora.style.transform = `translate3d(0, ${y.toFixed(2)}px, 0)`;
      if (orbs) orbs.style.transform = `translate3d(0, ${(y * 0.5).toFixed(2)}px, 0)`;
      document.querySelectorAll(".section-intro").forEach((section) => {
        const rect = section.getBoundingClientRect();
        const center = rect.top + rect.height / 2 - window.innerHeight / 2;
        const shift = Math.max(-24, Math.min(24, center * -0.02));
        section.style.transform = `translate3d(0, ${shift.toFixed(2)}px, 0)`;
      });
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
    if (prefersReduced) {
      document.querySelectorAll(".reveal").forEach((el) => el.classList.add("visible"));
      return;
    }
    initHeroSequence();
    window.AlleralEffects?.observeReveals?.();
    window.AlleralEffects?.bindMotion?.();
    startAmbientMotion();
  }

  window.addEventListener("alleral:gate-passed", () => {
    document.body?.classList.remove("cf-gate-active");
    bootMotion();
  }, { once: true });

  if (!document.body?.classList.contains("cf-gate-active")) {
    bootMotion();
  }
})();
