"use client";

import { Command } from "cmdk";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useEffect } from "react";
import { spring, stagger } from "@/lib/motion/config";
import { usePlatformStore, VIEW_META, type PlatformView } from "@/lib/store/platform";

function PaletteItem({
  index,
  children,
  className,
  onSelect,
}: {
  index: number;
  children: React.ReactNode;
  className?: string;
  onSelect: () => void;
}) {
  const reduce = useReducedMotion();
  return (
    <Command.Item asChild onSelect={onSelect}>
      <motion.button
        type="button"
        initial={reduce ? false : { opacity: 0, x: -10, scale: 0.98 }}
        animate={{ opacity: 1, x: 0, scale: 1 }}
        exit={reduce ? undefined : { opacity: 0, x: -6 }}
        transition={{ ...spring.tooltip, delay: reduce ? 0 : index * stagger.fast }}
        whileHover={reduce ? undefined : { x: 4, backgroundColor: "rgba(255,255,255,0.06)" }}
        className={className}
      >
        {children}
      </motion.button>
    </Command.Item>
  );
}

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
  const reduce = useReducedMotion();

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

  const views = Object.keys(VIEW_META) as PlatformView[];
  let itemIndex = 0;

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
            transition={spring.soft}
            onClick={() => setOpen(false)}
          />
          <motion.div
            className="fixed left-1/2 top-[18%] z-[301] w-[min(640px,calc(100vw-24px))] -translate-x-1/2"
            initial={reduce ? false : { opacity: 0, y: -16, scale: 0.96, filter: "blur(6px)" }}
            animate={{ opacity: 1, y: 0, scale: 1, filter: "blur(0px)" }}
            exit={reduce ? undefined : { opacity: 0, y: -10, scale: 0.98, filter: "blur(4px)" }}
            transition={spring.panel}
          >
            <Command className="glass-float overflow-hidden rounded-2xl border border-border-strong shadow-[0_40px_120px_rgba(0,0,0,0.65)]" label="Command palette">
              <div className="border-b border-border px-4 py-3">
                <Command.Input
                  placeholder="Search views, actions, shortcuts…"
                  className="w-full bg-transparent text-sm outline-none placeholder:text-muted"
                />
              </div>
              <Command.List className="max-h-[360px] overflow-y-auto overscroll-contain p-2" data-lenis-prevent>
                <Command.Empty className="px-3 py-6 text-center text-sm text-muted">No results.</Command.Empty>
                <Command.Group heading="Navigate" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
                  {views.map((view) => (
                    <PaletteItem
                      key={view}
                      index={itemIndex++}
                      onSelect={() => go(view)}
                      className="flex w-full cursor-pointer items-center justify-between rounded-xl px-3 py-2.5 text-left text-sm text-muted aria-selected:text-text"
                    >
                      <span>{VIEW_META[view].label}</span>
                      <kbd className="font-mono text-[10px] text-muted-2">⌘{VIEW_META[view].shortcut}</kbd>
                    </PaletteItem>
                  ))}
                </Command.Group>
                <Command.Group heading="Actions" className="px-2 py-1 text-[10px] uppercase tracking-wider text-muted-2">
                  <PaletteItem
                    index={itemIndex++}
                    onSelect={() => {
                      onCopyScript?.();
                      setOpen(false);
                    }}
                    className="w-full cursor-pointer rounded-xl px-3 py-2.5 text-left text-sm text-muted aria-selected:text-text"
                  >
                    Copy loader script
                  </PaletteItem>
                  <PaletteItem
                    index={itemIndex++}
                    onSelect={() => {
                      onRefresh?.();
                      setOpen(false);
                    }}
                    className="w-full cursor-pointer rounded-xl px-3 py-2.5 text-left text-sm text-muted aria-selected:text-text"
                  >
                    Refresh live data
                  </PaletteItem>
                  <PaletteItem
                    index={itemIndex++}
                    onSelect={() => {
                      window.open("/admin", "_blank");
                      setOpen(false);
                    }}
                    className="w-full cursor-pointer rounded-xl px-3 py-2.5 text-left text-sm text-muted aria-selected:text-text"
                  >
                    Open admin panel
                  </PaletteItem>
                </Command.Group>
              </Command.List>
            </Command>
          </motion.div>
        </>
      ) : null}
    </AnimatePresence>
  );
}
