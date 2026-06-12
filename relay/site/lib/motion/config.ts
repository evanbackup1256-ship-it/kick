export const spring = {
  snappy: { type: "spring" as const, stiffness: 480, damping: 34, mass: 0.72 },
  soft: { type: "spring" as const, stiffness: 280, damping: 30, mass: 0.95 },
  panel: { type: "spring" as const, stiffness: 340, damping: 36, mass: 0.88 },
  magnetic: { type: "spring" as const, stiffness: 200, damping: 20, mass: 0.55 },
  layout: { type: "spring" as const, stiffness: 380, damping: 38, mass: 0.9 },
  tooltip: { type: "spring" as const, stiffness: 520, damping: 38, mass: 0.65 },
  status: { type: "spring" as const, stiffness: 420, damping: 32, mass: 0.7 },
};

export const ease = {
  out: [0.16, 1, 0.3, 1] as [number, number, number, number],
  inOut: [0.65, 0, 0.35, 1] as [number, number, number, number],
  expo: [0.19, 1, 0.22, 1] as [number, number, number, number],
};

export const stagger = {
  fast: 0.035,
  base: 0.055,
  slow: 0.085,
  children: 0.04,
};

export const reveal = {
  initial: { opacity: 0, y: 16 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -10 },
};

export const scaleReveal = {
  initial: { opacity: 0, scale: 0.98 },
  animate: { opacity: 1, scale: 1 },
  exit: { opacity: 0, scale: 0.99 },
};

export const slidePanel = {
  initial: { opacity: 0, x: -16 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: 12 },
};
