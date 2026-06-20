(() => {
  "use strict";

  /** Minimal scroll-reveal fallback when CSS @supports (animation-timeline) is unavailable. */
  if (typeof IntersectionObserver === "undefined") return;

  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (prefersReduced) {
    document.querySelectorAll(".reveal").forEach((el) => el.classList.add("visible"));
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("visible");
          io.unobserve(entry.target);
        }
      });
    },
    { rootMargin: "0px 0px -8% 0px", threshold: 0.08 }
  );

  document.querySelectorAll(".reveal:not(.visible)").forEach((el) => io.observe(el));
})();
