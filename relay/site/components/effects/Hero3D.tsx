"use client";

import { useRef, useMemo } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { Float, PerspectiveCamera, Environment, Line as DreiLine } from "@react-three/drei";
import * as THREE from "three";

function Node({ position, color = "#00f0c8", size = 0.3 }: { position: [number, number, number]; color?: string; size?: number }) {
  const mesh = useRef<THREE.Mesh>(null);

  useFrame(({ clock }) => {
    if (!mesh.current) return;
    const s = 1 + Math.sin(clock.getElapsedTime() * 1.5 + position[0]) * 0.15;
    mesh.current.scale.setScalar(s);
  });

  return (
    <mesh ref={mesh} position={position}>
      <sphereGeometry args={[size, 16, 16]} />
      <meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.4} transparent opacity={0.8} />
    </mesh>
  );
}

function Packet({ from, to, color = "#00ffdc", speed = 1 }: { from: [number, number, number]; to: [number, number, number]; color?: string; speed?: number }) {
  const ref = useRef<THREE.Mesh>(null);
  const mid: [number, number, number] = [(from[0] + to[0]) / 2, (from[1] + to[1]) / 2 + 0.5, (from[2] + to[2]) / 2];
  const curve = useMemo(() => new THREE.QuadraticBezierCurve3(new THREE.Vector3(...from), new THREE.Vector3(...mid), new THREE.Vector3(...to)), [from, to]);
  const total = useRef(Math.random() * 100);

  useFrame(({ clock }) => {
    if (!ref.current) return;
    total.current += 0.005 * speed;
    const t = (total.current % 1);
    const pt = curve.getPoint(t);
    ref.current.position.copy(pt);
  });

  return (
    <mesh ref={ref}>
      <sphereGeometry args={[0.06, 8, 8]} />
      <meshBasicMaterial color={color} />
    </mesh>
  );
}

function TopologyNetwork() {
  const nodes: { pos: [number, number, number]; color: string; size: number }[] = [
    { pos: [-2.5, 0.5, 0], color: "#00f0c8", size: 0.35 },
    { pos: [-0.8, 1.2, -1], color: "#00d4ff", size: 0.3 },
    { pos: [0.8, -0.3, 0.5], color: "#7c3aed", size: 0.3 },
    { pos: [2.5, 0.8, -0.5], color: "#00f0c8", size: 0.35 },
    { pos: [-0.5, -1, 0.8], color: "#00d4ff", size: 0.25 },
    { pos: [1.5, -0.8, -1], color: "#7c3aed", size: 0.25 },
    { pos: [-1.8, -0.5, -1.5], color: "#00f0c8", size: 0.2 },
    { pos: [0, 1.5, 1], color: "#00d4ff", size: 0.2 },
  ];

  const connections = [
    [0, 1], [0, 2], [1, 3], [2, 3], [0, 4], [2, 5], [4, 5], [1, 6], [4, 7], [3, 7], [6, 1], [5, 3],
  ];

  return (
    <group>
      {nodes.map((n, i) => (
        <Node key={i} position={n.pos} color={n.color} size={n.size} />
      ))}
      {connections.map(([i, j], idx) => {
        if (idx % 2 !== 0) return null;
        const points = [new THREE.Vector3(...nodes[i].pos), new THREE.Vector3(...nodes[j].pos)];
        return <DreiLine key={idx} points={points} color={nodes[j].color} opacity={0.15} transparent lineWidth={0.5} />;
      })}
      {connections.slice(0, 6).map(([i, j], idx) => (
        <Packet key={idx} from={nodes[i].pos} to={nodes[j].pos} color="#00ffdc" speed={0.8 + idx * 0.2} />
      ))}
    </group>
  );
}

export function Hero3D() {
  return (
    <div className="absolute inset-0 z-0">
      <Canvas camera={{ position: [0, 0, 5], fov: 45 }} gl={{ antialias: true, alpha: true }}>
        <PerspectiveCamera makeDefault position={[0, 0, 5]} fov={45} />
        <ambientLight intensity={0.3} />
        <pointLight position={[5, 5, 5]} intensity={0.5} color="#00f0c8" />
        <spotLight position={[-5, 5, 5]} angle={0.3} penumbra={1} intensity={0.3} color="#00d4ff" />
        <fog attach="fog" args={[0x03050a, 5, 12]} />
        <Float speed={1.5} rotationIntensity={0.2} floatIntensity={0.5}>
          <TopologyNetwork />
        </Float>
        <Environment preset="night" />
      </Canvas>
    </div>
  );
}
