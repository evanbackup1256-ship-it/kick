export {};

declare global {
  interface AlleralEffectsApi {
    observeReveals?: (root?: ParentNode) => void;
    animateCounters?: () => void;
    bindMotion?: (root?: ParentNode) => void;
    animateNumber?: (el: HTMLElement, target: number, duration?: number) => void;
  }

  interface AlleralSelectApi {
    enhance?: () => void;
    refresh?: (el: HTMLSelectElement) => void;
  }

  interface AlleralConfig {
    publicUrl?: string;
    mirrorUrl?: string;
    turnstileSiteKey?: string;
  }

  interface AlleralTurnstileApi {
    mountVisible?: () => Promise<void>;
    getToken?: (formId: string) => Promise<string>;
    reset?: (formId: string) => void;
    hideAll?: () => void;
  }

  interface Window {
    ALLERAL_API?: string;
    ALLERAL_CONFIG?: AlleralConfig;
    AlleralEffects?: AlleralEffectsApi;
    AlleralSelect?: AlleralSelectApi;
    AlleralTurnstile?: AlleralTurnstileApi;
  }
}
