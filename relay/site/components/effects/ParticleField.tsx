"use client";

export function ParticleField() {
  return (
    <div className="fixed inset-0 z-[1] pointer-events-none overflow-hidden">
      {Array.from({ length: 15 }).map((_, i) => (
        <div
          key={i}
          className="absolute w-[2px] h-[2px] rounded-full bg-cyan"
          style={{
            left: `${Math.random() * 100}%`,
            animation: `particle-float ${6 + Math.random() * 8}s ${Math.random() * 8}s linear infinite`,
            opacity: 0.3,
            boxShadow: "0 0 6px #00d4ff, 0 0 12px rgba(0,212,255,0.3)",
          }}
        />
      ))}
    </div>
  );
}
