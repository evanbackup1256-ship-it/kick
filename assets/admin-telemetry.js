(() => {
  "use strict";

  const COLORS = {
    inject_loaded: "#34d399",
    inject_failed: "#f87171",
    error: "#fbbf24",
    place_updated: "#38bdf8",
    milestone: "#a78bfa",
  };

  function esc(s) {
    return String(s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function fmtTime(iso) {
    if (!iso) return "—";
    const d = new Date(iso);
    return Number.isNaN(d.getTime()) ? iso : d.toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
  }

  function createTooltip(root) {
    const tip = document.createElement("div");
    tip.className = "telemetry-chart-tooltip";
    root.appendChild(tip);
    return tip;
  }

  function drawLineChart(wrap, buckets, seriesKey, label) {
    const canvas = document.createElement("canvas");
    wrap.innerHTML = "";
    wrap.appendChild(canvas);
    const tip = createTooltip(wrap);
    const ctx = canvas.getContext("2d");
    if (!ctx || !buckets.length) {
      wrap.innerHTML = '<p class="empty">No inject data in this window yet.</p>';
      return;
    }

    const keys = ["inject_loaded", "inject_failed"];
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    let hoverIdx = -1;

    const render = () => {
      const w = wrap.clientWidth;
      const h = wrap.clientHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);

      const pad = { t: 12, r: 12, b: 22, l: 36 };
      const innerW = w - pad.l - pad.r;
      const innerH = h - pad.t - pad.b;
      const max = Math.max(1, ...buckets.flatMap((b) => keys.map((k) => b[k] || 0)));
      const step = innerW / Math.max(buckets.length - 1, 1);

      ctx.strokeStyle = "rgba(255,255,255,0.08)";
      ctx.lineWidth = 1;
      for (let i = 0; i <= 3; i += 1) {
        const y = pad.t + (innerH * i) / 3;
        ctx.beginPath();
        ctx.moveTo(pad.l, y);
        ctx.lineTo(w - pad.r, y);
        ctx.stroke();
      }

      keys.forEach((key) => {
        ctx.beginPath();
        buckets.forEach((b, i) => {
          const x = pad.l + i * step;
          const y = pad.t + innerH - ((b[key] || 0) / max) * innerH;
          if (i === 0) ctx.moveTo(x, y);
          else ctx.lineTo(x, y);
        });
        ctx.strokeStyle = COLORS[key];
        ctx.lineWidth = 2;
        ctx.stroke();
      });

      if (hoverIdx >= 0 && hoverIdx < buckets.length) {
        const x = pad.l + hoverIdx * step;
        ctx.strokeStyle = "rgba(255,255,255,0.35)";
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(x, pad.t);
        ctx.lineTo(x, pad.t + innerH);
        ctx.stroke();
        ctx.setLineDash([]);

        keys.forEach((key) => {
          const y = pad.t + innerH - ((buckets[hoverIdx][key] || 0) / max) * innerH;
          ctx.beginPath();
          ctx.arc(x, y, 4, 0, Math.PI * 2);
          ctx.fillStyle = COLORS[key];
          ctx.fill();
        });
      }
    };

    const onMove = (ev) => {
      const rect = canvas.getBoundingClientRect();
      const x = ev.clientX - rect.left;
      const padL = 36;
      const padR = 12;
      const innerW = rect.width - padL - padR;
      const step = innerW / Math.max(buckets.length - 1, 1);
      let idx = Math.round((x - padL) / step);
      idx = Math.max(0, Math.min(buckets.length - 1, idx));
      hoverIdx = idx;
      const b = buckets[idx];
      tip.classList.add("visible");
      tip.style.left = `${Math.min(rect.width - 80, Math.max(80, x))}px`;
      tip.style.top = `${Math.max(24, ev.clientY - rect.top - 8)}px`;
      tip.innerHTML = `
        <strong>${esc(fmtTime(b.at))}</strong>
        Loaded: ${esc(b.inject_loaded || 0)}<br/>
        Failed: ${esc(b.inject_failed || 0)}<br/>
        Errors: ${esc(b.error || 0)}
      `;
      render();
    };

    const onLeave = () => {
      hoverIdx = -1;
      tip.classList.remove("visible");
      render();
    };

    canvas.addEventListener("mousemove", onMove);
    canvas.addEventListener("mouseleave", onLeave);
    window.addEventListener("resize", render);
    render();
    return () => {
      canvas.removeEventListener("mousemove", onMove);
      canvas.removeEventListener("mouseleave", onLeave);
      window.removeEventListener("resize", render);
    };
  }

  function drawBarChart(wrap, totals) {
    const canvas = document.createElement("canvas");
    wrap.innerHTML = "";
    wrap.appendChild(canvas);
    const tip = createTooltip(wrap);
    const ctx = canvas.getContext("2d");
    const entries = Object.entries(totals || {}).filter(([, v]) => Number(v) > 0);
    if (!ctx || !entries.length) {
      wrap.innerHTML = '<p class="empty">No event totals yet.</p>';
      return;
    }

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    let hoverIdx = -1;

    const render = () => {
      const w = wrap.clientWidth;
      const h = wrap.clientHeight;
      canvas.width = w * dpr;
      canvas.height = h * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);

      const pad = { t: 12, r: 12, b: 28, l: 12 };
      const innerW = w - pad.l - pad.r;
      const innerH = h - pad.t - pad.b;
      const max = Math.max(...entries.map(([, v]) => Number(v)));
      const gap = 10;
      const barW = (innerW - gap * (entries.length - 1)) / entries.length;

      entries.forEach(([key, val], i) => {
        const n = Number(val);
        const bh = (n / max) * innerH;
        const x = pad.l + i * (barW + gap);
        const y = pad.t + innerH - bh;
        ctx.fillStyle = COLORS[key] || "#64748b";
        ctx.fillRect(x, y, barW, bh);
        if (hoverIdx === i) {
          ctx.strokeStyle = "rgba(255,255,255,0.6)";
          ctx.lineWidth = 2;
          ctx.strokeRect(x, y, barW, bh);
        }
        ctx.fillStyle = "rgba(148,163,184,0.9)";
        ctx.font = "10px IBM Plex Mono, monospace";
        ctx.textAlign = "center";
        ctx.fillText(key.replace(/_/g, " "), x + barW / 2, h - 8);
      });
    };

    const onMove = (ev) => {
      const rect = canvas.getBoundingClientRect();
      const x = ev.clientX - rect.left - 12;
      const innerW = rect.width - 24;
      const gap = 10;
      const barW = (innerW - gap * (entries.length - 1)) / entries.length;
      let idx = Math.floor(x / (barW + gap));
      idx = Math.max(0, Math.min(entries.length - 1, idx));
      hoverIdx = idx;
      const [key, val] = entries[idx];
      tip.classList.add("visible");
      tip.style.left = `${ev.clientX - rect.left}px`;
      tip.style.top = `${Math.max(24, ev.clientY - rect.top - 8)}px`;
      tip.innerHTML = `<strong>${esc(key.replace(/_/g, " "))}</strong>${esc(val)} events`;
      render();
    };

    const onLeave = () => {
      hoverIdx = -1;
      tip.classList.remove("visible");
      render();
    };

    canvas.addEventListener("mousemove", onMove);
    canvas.addEventListener("mouseleave", onLeave);
    window.addEventListener("resize", render);
    render();
  }

  let cleanupFns = [];

  function mountCharts(root, series) {
    cleanupFns.forEach((fn) => fn?.());
    cleanupFns = [];
    if (!root) return;

    const buckets = series?.buckets || [];
    const totals = series?.totals || {};

    root.innerHTML = `
      <article class="telemetry-chart-card card-enter">
        <div class="telemetry-chart-head">
          <div>
            <h4>Inject activity (${esc(series?.windowHours || 48)}h)</h4>
            <p>Hover for hourly loaded / failed counts</p>
          </div>
          <span class="telemetry-poll-note">Live · 5s refresh</span>
        </div>
        <div class="telemetry-chart-wrap" data-chart="line"></div>
        <div class="telemetry-chart-legend">
          <span><i style="background:${COLORS.inject_loaded}"></i> Loaded</span>
          <span><i style="background:${COLORS.inject_failed}"></i> Failed</span>
        </div>
      </article>
      <article class="telemetry-chart-card card-enter" style="animation-delay:0.06s">
        <div class="telemetry-chart-head">
          <div>
            <h4>Event breakdown</h4>
            <p>Totals across the selected window</p>
          </div>
        </div>
        <div class="telemetry-chart-wrap" data-chart="bar"></div>
      </article>
    `;

    const lineWrap = root.querySelector('[data-chart="line"]');
    const barWrap = root.querySelector('[data-chart="bar"]');
    drawLineChart(lineWrap, buckets, "inject", "Inject");
    drawBarChart(barWrap, totals);
  }

  window.AlleralAdminTelemetry = {
    mountCharts,
    esc,
    fmtTime,
  };
})();
