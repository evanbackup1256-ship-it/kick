"use client";

import { Command } from "cmdk";
import { AnimatePresence, motion } from "motion/react";
import { useEffect } from "react";
import { spring } from "@/lib/motion/config";
import { usePlatformStore, VIEW_META, type PlatformView } from "@/lib/store/platform";

export function CommandPalette({
  onCopyScript,
  onRefresh,
}: {
  onCopyScript?: () => void;
  onRefresh?: () => void;
}) {
  const open = usePlatformStore((s) => s.commandOpen);
  const setOpen = usePlatformStore((s) => s.setCommandOpen);
  const setView = usePlatformStore((s) => s.setView);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(!open);
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, setOpen]);

  const go = (view: PlatformView) => {
    setView(view);
    setOpen(false);
  };

  return (
    <AnimatePresence>
      {open ? (
        <>
          <motion.button
            type="button"
            aria-label="Close command palette"
            className="fixed inset-0 z-[300] bg-black/70 backdrop-blur-md"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setOpen(false)}
          />
          <motion.div
            className="fixed left-1/2 top-[18%] z-[301] w-[min(640px,calc(100vw-24px))] -translate-x-1/2"
            initial={{ opacity: 0, y: -12, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -8, scale: 0.98 }}
            transition={spring.snappy}
          >
            <Command className="glass-float overflow-hidden rounded-2xl border border-border-strong shadow-[0_40px_120px_rgba(0,0,0,0.65)]" label="Command palette">
              <div className="border-b border-border px-4 py-3">
                <Command.Input
                  placeholder="Search views, actions, shortcuts…"
                  className="w-full bg-transparent text-sm outline-none placeholder:text-muted"
                />
              </div>
              <Command.List className="max-h-[360px] overflow-y-auto p-2">
                <Command.Empty className="px-3 py-6 text-center text-sm text-muted">No results.</Command.Empty>
                <Command.Group heading="Navigate" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
                  {(Object.keys(VIEW_META) as PlatformView[]).map((view) => (
                    <Command.Item
                      key={view}
                      value={`${VIEW_META[view].label} ${VIEW_META[view].desc}`}
                      onSelect={() => go(view)}
                      className="flex cursor-pointer items-center justify-between rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
                    >
                      <span>{VIEW_META[view].label}</span>
                      <kbd className="font-mono text-[10px] text-muted-2">⌘{VIEW_META[view].shortcut}</kbd>
                    </Command.Item>
                  ))}
                </Command.Group>
                <Command.Group heading="Actions" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
                  <Command.Item
                    value="copy loader script"
                    onSelect={() => {
                      onCopyScript?.();
                      setOpen(false);
                    }}
                    className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
                  >
                    Copy loader script
                  </Command.Item>
                  <Command.Item
                    value="refresh telemetry"
                    onSelect={() => {
                      onRefresh?.();
                      setOpen(false);
                    }}
                    className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
                  >
                    Refresh live data
                  </Command.Item>
                  <Command.Item
                    value="open admin panel"
                    onSelect={() => {
                      window.open("/admin", "_blank");
                      setOpen(false);
                    }}
                    className="cursor-pointer rounded-xl px-3 py-2.5 text-sm text-muted aria-selected:bg-white/[0.06] aria-selected:text-text"
                  >
                    Open admin panel
                  </Command.Item>
                </Command.Group>
              </Command.List>
            </Command>
          </motion.div>
        </>
      ) : null}
    </AnimatePresence>
  );
}
