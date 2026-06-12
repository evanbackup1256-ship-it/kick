"use client";

import clsx from "clsx";
import { useEffect, useId, useRef, useState } from "react";

export type SelectOption = { value: string; label: string };

type CustomSelectProps = {
  name: string;
  options: SelectOption[] | string[];
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
  required?: boolean;
  className?: string;
  placeholder?: string;
};

function normalizeOptions(options: SelectOption[] | string[]): SelectOption[] {
  return options.map((o) => (typeof o === "string" ? { value: o, label: o } : o));
}

export function CustomSelect({
  name,
  options,
  value,
  defaultValue,
  onChange,
  required,
  className,
  placeholder = "Select…",
}: CustomSelectProps) {
  const items = normalizeOptions(options);
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

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open]);

  const pick = (next: string) => {
    setInternal(next);
    onChange?.(next);
    setOpen(false);
  };

  return (
    <div ref={wrapRef} className={clsx("select-wrap-enhanced", className)}>
      <input type="hidden" name={name} value={current} required={required && !current} readOnly />
      <div className={clsx("custom-select", open && "open")}>
        <button
          type="button"
          className="custom-select-trigger"
          aria-expanded={open}
          aria-haspopup="listbox"
          aria-controls={listId}
          onClick={() => setOpen((v) => !v)}
        >
          {label}
        </button>
        <div id={listId} className="custom-select-menu" role="listbox">
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
        </div>
      </div>
    </div>
  );
}
