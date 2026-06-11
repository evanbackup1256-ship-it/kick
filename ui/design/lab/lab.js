/** Lightweight spr-style spring (no deps). */
function springTo(el, props, preset = "snappy") {
  const presets = {
    snappy: { f: 7.5, d: 1 },
    soft: { f: 4.8, d: 1.12 },
    bouncy: { f: 5.8, d: 0.72 },
    micro: { f: 9.5, d: 1 },
    open: { f: 5.6, d: 0.88 },
    tab: { f: 6, d: 0.85 },
    toggle: { f: 7.2, d: 0.78 },
    press: { f: 11, d: 0.68 },
  };
  const { f, d } = presets[preset] || presets.snappy;
  const state = {};
  for (const [key, goal] of Object.entries(props)) {
    const cur = parseFloat(getComputedStyle(el)[key]) || goal;
    state[key] = { pos: cur, vel: 0, goal };
  }
  let last = performance.now();
  function tick(now) {
    const dt = Math.min((now - last) / 1000, 1 / 30);
    last = now;
    let settled = true;
    for (const key of Object.keys(state)) {
      const s = state[key];
      const omega = Math.PI * 2 * f;
      const offset = s.pos - s.goal;
      if (d >= 1) {
        const exp = Math.exp(-omega * dt);
        const newPos = s.goal + (offset + (s.vel + omega * offset) * dt) * exp;
        s.vel = (s.vel - omega * (s.vel + omega * offset) * dt) * exp;
        s.pos = newPos;
      } else {
        const z = d;
        const od = omega * Math.sqrt(Math.max(0, 1 - z * z)) || 1e-4;
        const exp = Math.exp(-z * omega * dt);
        s.pos =
          s.goal +
          exp *
            (offset * (Math.cos(od * dt) + (z * omega / od) * Math.sin(od * dt)) +
              (s.vel / od) * Math.sin(od * dt));
        s.vel =
          exp *
          (s.vel * Math.cos(od * dt) -
            ((offset * omega * omega + s.vel * z * omega) / od) * Math.sin(od * dt));
      }
      if (Math.abs(s.pos - s.goal) > 0.001 || Math.abs(s.vel) > 0.001) settled = false;
      el.style[key] = `${s.pos}px`;
    }
    if (!settled) requestAnimationFrame(tick);
  }
  requestAnimationFrame(tick);
}

function initLab() {
  const reduced = document.getElementById("reduced-motion")?.checked;
  document.documentElement.classList.toggle("reduced-motion", reduced);

  document.querySelectorAll(".nav-tab").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".nav-tab").forEach((b) => b.classList.remove("active"));
      document.querySelectorAll(".panel").forEach((p) => p.classList.remove("active"));
      btn.classList.add("active");
      document.getElementById(btn.dataset.panel)?.classList.add("active");
    });
  });

  document.querySelectorAll(".sidebar-tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      document.querySelectorAll(".sidebar-tab").forEach((t) => t.classList.remove("active"));
      tab.classList.add("active");
    });
  });

  document.querySelectorAll(".toggle").forEach((toggle) => {
    toggle.addEventListener("click", () => {
      toggle.classList.toggle("on");
      const knob = toggle.querySelector(".toggle-knob");
      if (!knob || reduced) return;
      springTo(knob, { left: toggle.classList.contains("on") ? 22 : 3 }, "toggle");
    });
  });

  document.querySelectorAll(".btn-row").forEach((btn) => {
    btn.addEventListener("mousedown", () => btn.classList.add("pressed"));
    btn.addEventListener("mouseup", () => btn.classList.remove("pressed"));
    btn.addEventListener("mouseleave", () => btn.classList.remove("pressed"));
  });

  const windowEl = document.querySelector(".hub-window");
  if (windowEl && !reduced) {
    windowEl.style.transform = "scale(0.962)";
    windowEl.style.opacity = "0.88";
    requestAnimationFrame(() => {
      windowEl.style.transition = "transform 0.55s var(--spring-open), opacity 0.4s ease";
      windowEl.style.transform = "scale(1)";
      windowEl.style.opacity = "1";
    });
  }

  document.getElementById("reduced-motion")?.addEventListener("change", (e) => {
    document.documentElement.classList.toggle("reduced-motion", e.target.checked);
  });

  document.getElementById("notify-demo")?.addEventListener("click", () => {
    const stack = document.getElementById("notify-stack");
    if (!stack) return;
    const n = document.createElement("div");
    n.className = "notification";
    n.innerHTML =
      '<div class="notification-rail"></div><div class="notification-body"><strong>Alleral</strong><span>Notification preview</span></div>';
    stack.prepend(n);
    requestAnimationFrame(() => n.classList.add("show"));
    setTimeout(() => {
      n.classList.remove("show");
      setTimeout(() => n.remove(), 400);
    }, 3200);
    while (stack.children.length > 8) stack.lastElementChild?.remove();
  });
}

document.addEventListener("DOMContentLoaded", initLab);
