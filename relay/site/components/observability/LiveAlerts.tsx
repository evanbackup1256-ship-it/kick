"use client";

import { useEffect, useRef } from "react";
import { motion } from "motion/react";
import { toast } from "sonner";
import type { HubStatusPayload } from "@/lib/types";
import { spring } from "@/lib/motion/config";

function AlertToast({
  title,
  detail,
  tone,
}: {
  title: string;
  detail?: string;
  tone: "error" | "warning" | "info";
}) {
  const colors = {
    error: "border-red-400/35 bg-red-400/10 text-red-100",
    warning: "border-amber-400/30 bg-amber-400/10 text-amber-100",
    info: "border-cyan-400/25 bg-cyan-400/10 text-cyan-100",
  };

  return (
    <motion.div
      layout
      initial={{ opacity: 0, y: 12, scale: 0.98 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: 8, scale: 0.98 }}
      transition={spring.soft}
      className={`glass-float w-[min(420px,calc(100vw-2rem))] rounded-2xl border px-4 py-3 shadow-2xl ${colors[tone]}`}
    >
      <p className="text-sm font-semibold text-text">{title}</p>
      {detail ? <p className="mt-1 font-mono text-[11px] leading-relaxed opacity-90 whitespace-pre-wrap">{detail}</p> : null}
    </motion.div>
  );
}

export function LiveAlerts({
  online,
  errorMessage,
  data,
}: {
  online: boolean;
  errorMessage?: string | null;
  data?: HubStatusPayload | null;
}) {
  const prev = useRef<{ online?: boolean; syncError?: string; broken?: string[] }>({});

  useEffect(() => {
    const syncError = data?.sync?.lastError?.trim() || "";
    const broken =
      data?.games?.items
        ?.filter((g) => (g.status || "working") !== "working")
        .map((g) => g.id) || [];

    const p = prev.current;

    if (p.online === true && online === false) {
      toast.custom(() => (
        <AlertToast title="Relay went offline" detail={errorMessage || "Live status polling failed."} tone="error" />
      ));
    }

    if (p.syncError !== syncError && syncError) {
      toast.custom(() => <AlertToast title="Sync pipeline error" detail={syncError} tone="error" />);
    }

    const newBroken = broken.filter((id) => !(p.broken || []).includes(id));
    if (newBroken.length) {
      const names = newBroken
        .map((id) => data?.games?.items?.find((g) => g.id === id)?.name || id)
        .slice(0, 3)
        .join(", ");
      toast.custom(() => (
        <AlertToast
          title={`${newBroken.length} script${newBroken.length > 1 ? "s" : ""} degraded`}
          detail={names}
          tone="warning"
        />
      ));
    }

    if (p.online === false && online === true) {
      toast.custom(() => <AlertToast title="Relay back online" tone="info" />);
    }

    prev.current = { online, syncError, broken };
  }, [online, errorMessage, data]);

  return null;
}
