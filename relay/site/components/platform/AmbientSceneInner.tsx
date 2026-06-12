"use client";

import { Canvas, useFrame } from "@react-three/fiber";
import { useMemo, useRef } from "react";
import * as THREE from "three";

function Particles({ count = 900 }: { count?: number }) {
  const ref = useRef<THREE.Points>(null);
  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3);
    for (let i = 0; i < count; i += 1) {
      arr[i * 3] = (Math.random() - 0.5) * 28;
      arr[i * 3 + 1] = (Math.random() - 0.5) * 16;
      arr[i * 3 + 2] = (Math.random() - 0.5) * 12;
    }
    return arr;
  }, [count]);

  useFrame((state) => {
    if (!ref.current) return;
    ref.current.rotation.y = state.clock.elapsedTime * 0.015;
    ref.current.rotation.x = Math.sin(state.clock.elapsedTime * 0.08) * 0.04;
  });

  return (
    <points ref={ref}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial size={0.035} color="#818cf8" transparent opacity={0.55} sizeAttenuation depthWrite={false} />
    </points>
  );
}

export function AmbientSceneInner() {
  if (typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    return <div className="pointer-events-none fixed inset-0 z-0 noise-overlay" aria-hidden />;
  }

  return (
    <div className="pointer-events-none fixed inset-0 z-0" aria-hidden>
      <Canvas camera={{ position: [0, 0, 8], fov: 55 }} dpr={[1, 1.5]} gl={{ antialias: false, alpha: true }}>
        <color attach="background" args={["#030406"]} />
        <fog attach="fog" args={["#030406", 8, 22]} />
        <Particles />
      </Canvas>
      <div className="noise-overlay absolute inset-0" />
    </div>
  );
}
