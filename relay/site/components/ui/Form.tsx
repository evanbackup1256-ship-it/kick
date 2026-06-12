"use client";

import clsx from "clsx";
import { motion, AnimatePresence } from "motion/react";
import { useEffect, useId, useRef, useState } from "react";
import { spring } from "@/lib/motion/config";

export type SelectOption = { value: string; label: string };

export function Select({
  name,
  options,
  value,
  defaultValue,
  onChange,
  required,
  placeholder = "Select…",
  className,
}: {
  name: string;
  options: SelectOption[] | string[];
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  required?: boolean;
  placeholder?: string;
  className?: string;
}) {
  const items = options.map((o) => (typeof o === "string" ? { value: o, label: o } : o));
  const [open, setOpen] = useState(false);
  const [internal, setInternal] = useState(defaultValue ?? items[0]?.value ?? "");
  const wrapRef = useRef<HTMLDivElement>(null);
  const listId = useId();
  const current = value ?? internal;
  const label = items.find((o) => o.value === current)?.label ?? placeholder;

  useEffect(() => {
    const onDoc = (e: MouseEvent) => {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  const pick = (next: string) => {
    setInternal(next);
    onChange?.(next);
    setOpen(false);
  };

  return (
    <div ref={wrapRef} className={clsx("select-wrap-enhanced", className)}>
      <input type="hidden" name={name} value={current} required={required && !current} readOnly />
      <div className={clsx("custom-select", open && "open")}>
        <motion.button
          type="button"
          className="custom-select-trigger"
          aria-expanded={open}
          aria-haspopup="listbox"
          aria-controls={listId}
          onClick={() => setOpen((v) => !v)}
          whileTap={{ scale: 0.99 }}
        >
          {label}
        </motion.button>
        <AnimatePresence>
          {open ? (
            <motion.div
              id={listId}
              role="listbox"
              className="custom-select-menu"
              initial={{ opacity: 0, y: -8, scale: 0.98, filter: "blur(4px)" }}
              animate={{ opacity: 1, y: 0, scale: 1, filter: "blur(0px)" }}
              exit={{ opacity: 0, y: -6, scale: 0.98, filter: "blur(4px)" }}
              transition={spring.snappy}
            >
              {items.map((opt) => (
                <button
                  key={opt.value}
                  type="button"
                  role="option"
                  aria-selected={opt.value === current}
                  className={clsx("custom-select-option", opt.value === current && "selected")}
                  onClick={() => pick(opt.value)}
                >
                  {opt.label}
                </button>
              ))}
            </motion.div>
          ) : null}
        </AnimatePresence>
      </div>
    </div>
  );
}

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
