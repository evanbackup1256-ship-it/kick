"use client";

import { useCallback, useEffect, useState } from "react";
import { LogIn, Shield, Sparkles } from "lucide-react";
import { toast } from "sonner";

export function AdminGate({ children }: { children: React.ReactNode }) {
  const [authed, setAuthed] = useState(false);
  const [checking, setChecking] = useState(true);
  const [password, setPassword] = useState("");

  useEffect(() => {
    if (typeof window !== "undefined") {
      const stored = sessionStorage.getItem("alleral_admin_auth");
      if (stored === "true") setAuthed(true);
    }
    setChecking(false);
  }, []);

  const login = useCallback(() => {
    if (password === "sammy2026") {
      sessionStorage.setItem("alleral_admin_auth", "true");
      setAuthed(true);
      toast.success("Authenticated");
    } else {
      toast.error("Invalid password");
    }
  }, [password]);

  if (checking) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-bg-0">
        <div className="flex items-center gap-2 text-muted">
          <Sparkles className="h-4 w-4 animate-pulse" />
          <span className="text-sm">Checking auth…</span>
        </div>
      </div>
    );
  }

  if (!authed) {
    return (
      <div className="flex min-h-dvh items-center justify-center bg-bg-0 p-4">
        <div className="card w-full max-w-sm p-6">
          <div className="flex items-center gap-3 mb-5">
            <Shield className="h-5 w-5 text-accent" />
            <h3 className="text-lg font-semibold text-text">Admin access</h3>
          </div>
          <p className="mb-4 text-sm text-muted">Enter the admin password to continue.</p>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => { if (e.key === "Enter") login(); }}
            placeholder="Password"
            className="w-full rounded-lg border border-white/10 bg-bg-0/80 px-4 py-2.5 text-sm text-text outline-none transition focus:border-accent/40 focus:ring-1 focus:ring-accent/20"
            autoFocus
          />
          <button className="btn btn-primary mt-4 w-full" onClick={login}>
            <LogIn className="h-4 w-4" /> Sign in
          </button>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
