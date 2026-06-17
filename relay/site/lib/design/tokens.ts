export const status = {
  healthy: { label: "Healthy", color: "#34d399", glow: "rgba(52,211,153,0.45)" },
  online: { label: "Online", color: "#22d3ee", glow: "rgba(34,211,238,0.4)" },
  syncing: { label: "Syncing", color: "#818cf8", glow: "rgba(129,140,248,0.45)" },
  idle: { label: "Idle", color: "#94a3b8", glow: "rgba(148,163,184,0.25)" },
  warning: { label: "Warning", color: "#fbbf24", glow: "rgba(251,191,36,0.4)" },
  error: { label: "Error", color: "#f87171", glow: "rgba(248,113,113,0.45)" },
  offline: { label: "Offline", color: "#64748b", glow: "rgba(100,116,139,0.3)" },
} as const;

export type StatusKind = keyof typeof status;

export const chart = {
  grid: "rgba(255,255,255,0.04)",
  axis: "rgba(148,163,184,0.5)",
  linePrimary: "#22d3ee",
  lineSecondary: "#818cf8",
  areaPrimary: "rgba(34,211,238,0.12)",
  crosshair: "rgba(255,255,255,0.25)",
  pointGlow: "rgba(34,211,238,0.6)",
} as const;
