import { create } from "zustand";
import { persist } from "zustand/middleware";

export type PlatformView =
  | "overview"
  | "control"
  | "games"
  | "tools"
  | "changelog"
  | "support"
  | "credits";

export type WorkspacePreset = "default" | "telemetry" | "ops";

interface PlatformState {
  activeView: PlatformView;
  sidebarCollapsed: boolean;
  commandOpen: boolean;
  workspace: WorkspacePreset;
  setView: (view: PlatformView) => void;
  toggleSidebar: () => void;
  setCommandOpen: (open: boolean) => void;
  setWorkspace: (workspace: WorkspacePreset) => void;
}

export const usePlatformStore = create<PlatformState>()(
  persist(
    (set) => ({
      activeView: "overview",
      sidebarCollapsed: false,
      commandOpen: false,
      workspace: "default",
      setView: (activeView) => set({ activeView }),
      toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
      setCommandOpen: (commandOpen) => set({ commandOpen }),
      setWorkspace: (workspace) => set({ workspace }),
    }),
    { name: "alleral-platform", partialize: (s) => ({ sidebarCollapsed: s.sidebarCollapsed, workspace: s.workspace }) }
  )
);

export const VIEW_META: Record<PlatformView, { label: string; shortcut: string; desc: string }> = {
  overview: { label: "Overview", shortcut: "O", desc: "Platform summary and loader" },
  control: { label: "Mission Control", shortcut: "M", desc: "Live telemetry and sync" },
  games: { label: "Games", shortcut: "G", desc: "Script library and status" },
  tools: { label: "Executors", shortcut: "E", desc: "WEAO exploit tracker" },
  changelog: { label: "Ship Log", shortcut: "L", desc: "Release history" },
  support: { label: "Support", shortcut: "S", desc: "Bug reports and contact" },
  credits: { label: "Team", shortcut: "T", desc: "Credits and contributors" },
};
