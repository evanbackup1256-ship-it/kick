"use client";

import { useRef, useMemo } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { Float, PerspectiveCamera, Environment, Line as DreiLine } from "@react-three/drei";
import * as THREE from "three";

function Node({ position, color = "#00f0c8", size = 0.3 }: { position: [number, number, number]; color?: string; size?: number }) {
  const mesh = useRef<THREE.Mesh>(null);
  const phase = useRef(Math.random() * 10);

  useFrame(({ clock }) => {
    if (!mesh.current) return;
    const t = clock.getElapsedTime() + phase.current;
    const s = 1 + Math.sin(t * 1.2) * 0.12 + Math.sin(t * 0.7) * 0.06;
    mesh.current.scale.setScalar(s);
  });

  return (
    <mesh ref={mesh} position={position}>
      <sphereGeometry args={[size, 16, 16]} />
      <meshStandardMaterial color={color} emissive={color} emissiveIntensity={0.35} transparent opacity={0.75} />
    </mesh>
  );
}

function Packet({ from, to }: { from: [number, number, number]; to: [number, number, number] }) {
  const ref = useRef<THREE.Mesh>(null);
  const mid: [number, number, number] = [
    (from[0] + to[0]) / 2 + (Math.random() - 0.5) * 0.5,
    (from[1] + to[1]) / 2 + 0.3 + Math.random() * 0.4,
    (from[2] + to[2]) / 2 + (Math.random() - 0.5) * 0.5,
  ];
  const curve = useMemo(() => new THREE.QuadraticBezierCurve3(
    new THREE.Vector3(...from), new THREE.Vector3(...mid), new THREE.Vector3(...to)
  ), [from, to]);
  const t = useRef(Math.random());

  useFrame(({ clock }) => {
    if (!ref.current) return;
    t.current = (t.current + 0.003) % 1;
    ref.current.position.copy(curve.getPoint(t.current));
  });

  return (
    <mesh ref={ref}>
      <sphereGeometry args={[0.05, 6, 6]} />
      <meshBasicMaterial color="#00ffdc" />
    </mesh>
  );
}

function TopologyNetwork() {
  const nodes: { pos: [number, number, number]; color: string; size: number }[] = useMemo(() => [
    { pos: [-2.4, 0.3, 0.2], color: "#00f0c8", size: 0.3 },
    { pos: [-1, 1.4, -0.8], color: "#00d4ff", size: 0.25 },
    { pos: [0.6, -0.5, 0.7], color: "#7c3aed", size: 0.25 },
    { pos: [2.2, 0.6, -0.3], color: "#00f0c8", size: 0.3 },
    { pos: [-0.7, -1.2, 0.6], color: "#00d4ff", size: 0.2 },
    { pos: [1.3, -1, -0.8], color: "#7c3aed", size: 0.2 },
    { pos: [-1.6, -0.7, -1.2], color: "#00f0c8", size: 0.18 },
    { pos: [0, 1.7, 0.8], color: "#00d4ff", size: 0.18 },
  ], []);

  const pairs = [[0,1],[0,2],[1,3],[2,3],[0,4],[2,5],[4,5],[1,6],[4,7],[3,7]];

  return (
    <group>
      {nodes.map((n, i) => <Node key={i} position={n.pos} color={n.color} size={n.size} />)}
      {pairs.map(([i, j], idx) => (
        <DreiLine
          key={idx}
          points={[new THREE.Vector3(...nodes[i].pos), new THREE.Vector3(...nodes[j].pos)]}
          color={nodes[j].color}
          opacity={0.12}
          transparent
          lineWidth={0.5}
        />
      ))}
      {pairs.slice(0, 5).map(([i, j], idx) => (
        <Packet key={idx} from={nodes[i].pos} to={nodes[j].pos} />
      ))}
    </group>
  );
}

export function Hero3D() {
  return (
    <div className="absolute inset-0 z-0">
      <Canvas camera={{ position: [0, 0, 5], fov: 45 }} gl={{ antialias: true, alpha: true }}>
        <PerspectiveCamera makeDefault position={[0, 0, 5]} fov={45} />
        <ambientLight intensity={0.4} />
        <pointLight position={[5, 5, 5]} intensity={0.4} color="#00f0c8" />
        <spotLight position={[-4, 4, 5]} angle={0.3} penumbra={1} intensity={0.2} color="#00d4ff" />
        <fog attach="fog" args={[0x03050a, 4, 10]} />
        <Float speed={1.5} rotationIntensity={0.15} floatIntensity={0.4}>
          <TopologyNetwork />
        </Float>
        <Environment preset="night" />
      </Canvas>
    </div>
  );
}
