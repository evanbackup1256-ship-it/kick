(() => {
  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function initHeroMesh() {
    const canvas = document.getElementById("heroMesh");
    if (!canvas || prefersReduced) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let w = 0;
    let h = 0;
    let dpr = 1;
    let t = 0;
    let mx = 0.5;
    let my = 0.4;

    const blobs = [
      { x: 0.32, y: 0.38, r: 0.28, hue: 210, speed: 0.00035 },
      { x: 0.68, y: 0.42, r: 0.24, hue: 275, speed: 0.00028 },
      { x: 0.5, y: 0.58, r: 0.22, hue: 145, speed: 0.00032 },
      { x: 0.42, y: 0.28, r: 0.18, hue: 195, speed: 0.0004 },
    ];

    function resize() {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      const rect = canvas.parentElement?.getBoundingClientRect();
      w = Math.floor((rect?.width || window.innerWidth) * dpr);
      h = Math.floor((rect?.height || window.innerHeight * 0.7) * dpr);
      canvas.width = w;
      canvas.height = h;
      canvas.style.width = `${w / dpr}px`;
      canvas.style.height = `${h / dpr}px`;
    }

    window.addEventListener("mousemove", (e) => {
      mx = e.clientX / window.innerWidth;
      my = e.clientY / window.innerHeight;
    }, { passive: true });

    function draw() {
      t += 1;
      ctx.clearRect(0, 0, w, h);

      blobs.forEach((b, i) => {
        const ox = Math.sin(t * b.speed + i) * 0.06;
        const oy = Math.cos(t * b.speed * 1.3 + i * 2) * 0.05;
        const px = (b.x + ox + (mx - 0.5) * 0.04) * w;
        const py = (b.y + oy + (my - 0.5) * 0.04) * h;
        const rad = b.r * Math.min(w, h);

        const g = ctx.createRadialGradient(px, py, 0, px, py, rad);
        g.addColorStop(0, `hsla(${b.hue}, 90%, 62%, 0.22)`);
        g.addColorStop(0.45, `hsla(${b.hue}, 80%, 50%, 0.08)`);
        g.addColorStop(1, "hsla(0, 0%, 0%, 0)");
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, w, h);
      });

      requestAnimationFrame(draw);
    }

    resize();
    window.addEventListener("resize", resize, { passive: true });
    requestAnimationFrame(draw);
  }

  function initHeroParallax() {
    const scene = document.querySelector(".hero-render-scene");
    if (!scene || prefersReduced) return;

    let targetX = 0;
    let targetY = 0;
    let currentX = 0;
    let currentY = 0;

    window.addEventListener("mousemove", (e) => {
      targetX = (e.clientX / window.innerWidth - 0.5) * 18;
      targetY = (e.clientY / window.innerHeight - 0.5) * 12;
    }, { passive: true });

    function tick() {
      currentX += (targetX - currentX) * 0.06;
      currentY += (targetY - currentY) * 0.06;
      scene.style.transform = `translate(calc(-50% + ${currentX.toFixed(2)}px), calc(-50% + ${currentY.toFixed(2)}px))`;
      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  function boot() {
    initHeroMesh();
    initHeroParallax();
  }

  window.AlleralRenders = { boot };

  window.addEventListener("alleral:gate-passed", boot, { once: true });
  if (!document.body?.classList.contains("cf-gate-active")) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", boot);
    } else {
      boot();
    }
  }
})();
