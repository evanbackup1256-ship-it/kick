"use client";

import { motion } from "framer-motion";
import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";
import { gsap } from "gsap";

const Lottie = dynamic(() => import("lottie-react"), { ssr: false });

const orbitLottie = {
  v: "5.7.4",
  fr: 60,
  ip: 0,
  op: 120,
  w: 200,
  h: 200,
  nm: "Pulse",
  ddd: 0,
  assets: [],
  layers: [
    {
      ddd: 0,
      ind: 1,
      ty: 4,
      nm: "Ring",
      sr: 1,
      ks: {
        o: { a: 1, k: [{ t: 0, s: [40] }, { t: 60, s: [90] }, { t: 120, s: [40] }] },
        r: { a: 1, k: [{ t: 0, s: [0] }, { t: 120, s: [360] }] },
        p: { a: 0, k: [100, 100, 0] },
        a: { a: 0, k: [0, 0, 0] },
        s: { a: 1, k: [{ t: 0, s: [80, 80, 100] }, { t: 60, s: [110, 110, 100] }, { t: 120, s: [80, 80, 100] }] },
      },
      shapes: [
        {
          ty: "gr",
          it: [
            {
              ty: "el",
              p: { a: 0, k: [0, 0] },
              s: { a: 0, k: [120, 120] },
            },
            {
              ty: "st",
              c: { a: 0, k: [0.13, 0.83, 0.93, 1] },
              o: { a: 0, k: [100] },
              w: { a: 0, k: 3 },
            },
            { ty: "tr", p: { a: 0, k: [0, 0] }, a: { a: 0, k: [0, 0] }, s: { a: 0, k: [100, 100] }, r: { a: 0, k: 0 }, o: { a: 0, k: 100 } },
          ],
        },
      ],
      ip: 0,
      op: 120,
      st: 0,
      bm: 0,
    },
  ],
};

export function HeroOrbit({ loaderVersion, sydePatch }: { loaderVersion?: string; sydePatch?: number }) {
  const sceneRef = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    setReady(true);
    const scene = sceneRef.current;
    if (!scene || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    let tx = 0;
    let ty = 0;
    const tick = () => {
      gsap.to(scene, { rotateX: ty * 0.15, rotateY: tx * 0.15, duration: 0.6, ease: "power2.out" });
    };

    const onMove = (e: MouseEvent) => {
      const rect = scene.getBoundingClientRect();
      tx = ((e.clientX - rect.left) / rect.width - 0.5) * 24;
      ty = ((e.clientY - rect.top) / rect.height - 0.5) * 18;
      tick();
    };

    scene.addEventListener("mousemove", onMove);
    return () => scene.removeEventListener("mousemove", onMove);
  }, []);

  return (
    <div className="relative grid min-h-[420px] place-items-center">
      {ready && (
        <div className="pointer-events-none absolute inset-[-15%] opacity-60 mix-blend-screen">
          <Lottie animationData={orbitLottie} loop className="h-full w-full" />
        </div>
      )}
      <div
        ref={sceneRef}
        className="relative h-[min(440px,90vw)] w-[min(440px,90vw)] [perspective:1400px]"
        style={{ transformStyle: "preserve-3d" }}
      >
        <motion.div
          className="absolute left-1/2 top-1/2 h-[120px] w-[120px] -translate-x-1/2 -translate-y-1/2"
          animate={{ rotateZ: 360 }}
          transition={{ duration: 34, repeat: Infinity, ease: "linear" }}
        >
          <div className="absolute inset-0 rounded-full border border-dashed border-cyan-400/20" />
          <div className="absolute inset-[-18px] rounded-full border border-violet-400/25" />
          <div className="absolute inset-[-36px] rounded-full border border-cyan-300/15 shadow-[0_0_40px_rgba(34,211,238,0.12)]" />
          <div className="absolute inset-[22px] grid place-items-center rounded-full border border-white/20 bg-gradient-to-br from-cyan-400/35 to-violet-400/20 text-3xl font-extrabold shadow-[0_0_60px_rgba(34,211,238,0.25)]">
            A
          </div>
        </motion.div>

        <OrbitCard label="loader" value={loaderVersion || "8.2.x"} className="animate-[spin_22s_linear_infinite]" radius={165} />
        <OrbitCard label="Syde UI" value={`patch ${sydePatch || 18}`} className="animate-[spin_28s_linear_infinite_reverse]" radius={190} offset={120} />
        <motion.div
          className="absolute left-1/2 top-1/2"
          animate={{ rotate: 360 }}
          transition={{ duration: 18, repeat: Infinity, ease: "linear" }}
        >
          <div
            className="absolute flex items-center gap-2 rounded-xl border border-green-400/30 bg-[rgba(8,12,18,0.78)] px-3 py-2 text-xs text-green-400 backdrop-blur-xl"
            style={{ transform: "translate(145px, -50%)" }}
          >
            <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-green-400 shadow-[0_0_10px_rgba(52,211,153,0.7)]" />
            Hub synced
          </div>
        </motion.div>
      </div>
    </div>
  );
}

function OrbitCard({
  label,
  value,
  className,
  radius,
  offset = 0,
}: {
  label: string;
  value: string;
  className?: string;
  radius: number;
  offset?: number;
}) {
  return (
    <div className={`absolute left-1/2 top-1/2 ${className}`} style={{ transform: `rotate(${offset}deg)` }}>
      <div style={{ transform: `translateX(${radius}px) rotate(-${offset}deg)` }}>
        <div className="flex min-w-[120px] -translate-x-1/2 -translate-y-1/2 flex-col gap-1 rounded-xl border border-white/15 bg-[rgba(8,12,18,0.78)] px-3.5 py-2.5 backdrop-blur-xl shadow-[0_20px_50px_rgba(0,0,0,0.45)]">
          <span className="text-[0.62rem] uppercase tracking-[0.08em] text-muted-2">{label}</span>
          <code className="font-mono text-xs text-cyan-300">{value}</code>
        </div>
      </div>
    </div>
  );
}
