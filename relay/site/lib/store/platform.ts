import { create } from "zustand";
import { persist } from "zustand/middleware";

export type PlatformView =
  | "overview"
  | "status"
  | "games"
  | "tools"
  | "changelog"
  | "support"
  | "credits";

export type WorkspacePreset = "default" | "admin" | "ops";

interface PlatformState {
  activeView: PlatformView;
  sidebarCollapsed: boolean;
  mobileNavOpen: boolean;
  commandOpen: boolean;
  workspace: WorkspacePreset;
  setView: (view: PlatformView) => void;
  toggleSidebar: () => void;
  setMobileNavOpen: (open: boolean) => void;
  setCommandOpen: (open: boolean) => void;
  setWorkspace: (workspace: WorkspacePreset) => void;
}

export const usePlatformStore = create<PlatformState>()(
  persist(
    (set) => ({
      activeView: "overview",
      sidebarCollapsed: false,
      mobileNavOpen: false,
      commandOpen: false,
      workspace: "default",
      setView: (activeView) => set({ activeView, mobileNavOpen: false }),
      toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
      setMobileNavOpen: (mobileNavOpen) => set({ mobileNavOpen }),
      setCommandOpen: (commandOpen) => set({ commandOpen }),
      setWorkspace: (workspace) => {
        const raw = String(workspace);
        const next: WorkspacePreset =
          raw === "admin" || raw === "ops" ? raw : "default";
        set({ workspace: next });
      },
    }),
    { name: "alleral-platform", partialize: (s) => ({ sidebarCollapsed: s.sidebarCollapsed, workspace: s.workspace }) }
  )
);

export const VIEW_META: Record<PlatformView, { label: string; shortcut: string; desc: string }> = {
  overview: { label: "Overview", shortcut: "O", desc: "Loader, games, and quick links" },
  status: { label: "Status", shortcut: "L", desc: "Relay health and game counts" },
  games: { label: "Games", shortcut: "G", desc: "What works right now" },
  tools: { label: "Executors", shortcut: "E", desc: "WEAO exploit list" },
  changelog: { label: "Updates", shortcut: "H", desc: "Recent changes" },
  support: { label: "Support", shortcut: "S", desc: "Bug reports and questions" },
  credits: { label: "Team", shortcut: "T", desc: "Who built this" },
};
