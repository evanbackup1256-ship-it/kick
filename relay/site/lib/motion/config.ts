export const spring = {
  snappy: { type: "spring" as const, stiffness: 420, damping: 32, mass: 0.8 },
  soft: { type: "spring" as const, stiffness: 260, damping: 28, mass: 1 },
  panel: { type: "spring" as const, stiffness: 320, damping: 34, mass: 0.95 },
  magnetic: { type: "spring" as const, stiffness: 180, damping: 18, mass: 0.6 },
};

export const ease = {
  out: [0.16, 1, 0.3, 1] as [number, number, number, number],
  inOut: [0.65, 0, 0.35, 1] as [number, number, number, number],
};

export const stagger = {
  fast: 0.04,
  base: 0.06,
  slow: 0.09,
};

export const reveal = {
  initial: { opacity: 0, y: 18, filter: "blur(10px)" },
  animate: { opacity: 1, y: 0, filter: "blur(0px)" },
  exit: { opacity: 0, y: -12, filter: "blur(6px)" },
};
