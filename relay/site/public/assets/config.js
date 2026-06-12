window.ALLERAL_API = window.ALLERAL_API || "https://alleral-telemetry-production.up.railway.app";

window.ALLERAL_CONFIG = {
  /** Primary URL players should bookmark (shown on the site). */
  publicUrl: "https://alleral-telemetry-production.up.railway.app/",
  /** GitHub Pages mirror — enable Pages in repo settings first. */
  mirrorUrl: "https://evanbackup1256-ship-it.github.io/kick/",
  /**
   * Cloudflare Turnstile site key (public). Leave empty to fetch from /api/gate/config.
   * Create at: Cloudflare Dashboard → Turnstile → Add site.
   * Set TURNSTILE_SECRET_KEY on Railway for server-side verification.
   */
  turnstileSiteKey: "",
};
