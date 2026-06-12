"use client";

import clsx from "clsx";
import * as Popover from "@radix-ui/react-popover";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { Check, ChevronDown } from "lucide-react";
import { memo, useEffect, useId, useMemo, useState } from "react";
import { spring, stagger } from "@/lib/motion/config";

export type SelectOption = { value: string; label: string };

function normalizeOptions(options: SelectOption[] | string[]): SelectOption[] {
  return options.map((o) => (typeof o === "string" ? { value: o, label: o } : o));
}

export const Select = memo(function Select({
  name,
  options,
  value,
  defaultValue,
  onChange,
  required,
  placeholder = "Select…",
  className,
  disabled,
}: {
  name: string;
  options: SelectOption[] | string[];
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  required?: boolean;
  placeholder?: string;
  className?: string;
  disabled?: boolean;
}) {
  const reduce = useReducedMotion();
  const items = useMemo(() => normalizeOptions(options), [options]);
  const listId = useId();
  const [open, setOpen] = useState(false);
  const [internal, setInternal] = useState(defaultValue ?? items[0]?.value ?? "");
  const current = value ?? internal;
  const selected = items.find((o) => o.value === current);
  const label = selected?.label ?? placeholder;

  useEffect(() => {
    if (defaultValue !== undefined) setInternal(defaultValue);
  }, [defaultValue]);

  const pick = (next: string) => {
    setInternal(next);
    onChange?.(next);
    setOpen(false);
  };

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <input type="hidden" name={name} value={current} required={required && !current} readOnly />
      <Popover.Trigger asChild disabled={disabled}>
        <button
          type="button"
          className={clsx(
            "custom-select-trigger flex w-full items-center justify-between gap-2 text-left",
            open && "border-accent/50 shadow-[0_0_0_3px_rgba(99,102,241,0.15)]",
            disabled && "cursor-not-allowed opacity-50",
            className
          )}
          aria-expanded={open}
          aria-haspopup="listbox"
          aria-controls={listId}
        >
          <span className={clsx("truncate", !selected && "text-muted")}>{label}</span>
          <motion.span animate={{ rotate: open ? 180 : 0 }} transition={spring.tooltip}>
            <ChevronDown className="h-4 w-4 shrink-0 text-muted" />
          </motion.span>
        </button>
      </Popover.Trigger>
      <AnimatePresence>
        {open ? (
          <Popover.Portal forceMount>
            <Popover.Content
              id={listId}
              role="listbox"
              sideOffset={8}
              align="start"
              collisionPadding={12}
              asChild
              onOpenAutoFocus={(e) => e.preventDefault()}
            >
              <motion.div
                initial={reduce ? false : { opacity: 0, y: -8, scale: 0.96, filter: "blur(4px)" }}
                animate={{ opacity: 1, y: 0, scale: 1, filter: "blur(0px)" }}
                exit={reduce ? undefined : { opacity: 0, y: -6, scale: 0.98, filter: "blur(2px)" }}
                transition={spring.panel}
                style={{ transformOrigin: "var(--radix-popover-content-transform-origin)" }}
                className="custom-select-menu z-[600] max-h-60 w-[var(--radix-popover-trigger-width)] overflow-y-auto overscroll-contain p-1"
              >
                {items.map((opt, index) => {
                  const active = opt.value === current;
                  return (
                    <motion.button
                      key={`${opt.value}-${opt.label}`}
                      type="button"
                      role="option"
                      aria-selected={active}
                      initial={reduce ? false : { opacity: 0, x: -8, scale: 0.98 }}
                      animate={{ opacity: 1, x: 0, scale: 1 }}
                      exit={reduce ? undefined : { opacity: 0, x: -4 }}
                      whileHover={reduce ? undefined : { x: 2, backgroundColor: "rgba(255,255,255,0.05)" }}
                      whileTap={reduce ? undefined : { scale: 0.98 }}
                      transition={{ ...spring.tooltip, delay: reduce ? 0 : index * stagger.fast }}
                      className={clsx("custom-select-option", active && "selected")}
                      onClick={() => pick(opt.value)}
                    >
                      <span className="truncate">{opt.label}</span>
                      {active ? <Check className="h-3.5 w-3.5 shrink-0 opacity-80" /> : null}
                    </motion.button>
                  );
                })}
              </motion.div>
            </Popover.Content>
          </Popover.Portal>
        ) : null}
      </AnimatePresence>
    </Popover.Root>
  );
});

export function Input({
  className,
  ...props
}: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={clsx(
        "w-full rounded-xl border border-border bg-black/30 px-3.5 py-2.5 text-sm outline-none transition",
        "focus:border-accent/50 focus:shadow-[0_0_0_3px_rgba(99,102,241,0.15)]",
        className
      )}
      {...props}
    />
  );
}

export function Textarea({
  className,
  ...props
}: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={clsx(
        "min-h-[100px] w-full rounded-xl border border-border bg-black/30 px-3.5 py-2.5 text-sm outline-none transition",
        "focus:border-accent/50 focus:shadow-[0_0_0_3px_rgba(99,102,241,0.15)]",
        className
      )}
      {...props}
    />
  );
}

export function Badge({
  children,
  tone = "neutral",
  className,
}: {
  children: React.ReactNode;
  tone?: "neutral" | "green" | "cyan" | "violet" | "red" | "yellow";
  className?: string;
}) {
  const tones = {
    neutral: "border-border text-muted bg-white/[0.03]",
    green: "border-green-400/25 text-green-300 bg-green-400/10",
    cyan: "border-cyan-400/25 text-cyan-300 bg-cyan-400/10",
    violet: "border-violet-400/25 text-violet-300 bg-violet-400/10",
    red: "border-red-400/25 text-red-300 bg-red-400/10",
    yellow: "border-yellow-400/25 text-yellow-300 bg-yellow-400/10",
  };
  return (
    <span className={clsx("inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[0.68rem] font-medium", tones[tone], className)}>
      {children}
    </span>
  );
}
