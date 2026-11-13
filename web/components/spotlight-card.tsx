"use client";

import * as React from "react";

interface SpotlightCardProps {
  children: React.ReactNode;
  className?: string;
}

export function SpotlightCard({ children, className = "" }: SpotlightCardProps) {
  const ref = React.useRef<HTMLDivElement>(null);
  const [pos, setPos] = React.useState({ x: 0, y: 0, opacity: 0 });

  const handleMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    setPos({
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
      opacity: 1,
    });
  };

  return (
    <div
      ref={ref}
      onMouseMove={handleMove}
      onMouseLeave={() => setPos((p) => ({ ...p, opacity: 0 }))}
      className={`group relative overflow-hidden rounded-2xl border border-[#3D4A3B] bg-[#2B382A] transition-all duration-300 hover:-translate-y-1 hover:border-[#7D8277] hover:shadow-[0_20px_50px_-15px_rgba(0,0,0,0.6)] ${className}`}
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -inset-px transition-opacity duration-300"
        style={{
          opacity: pos.opacity,
          background: `radial-gradient(440px circle at ${pos.x}px ${pos.y}px, rgba(222, 218, 208, 0.12), transparent 60%)`,
        }}
      />
      <div className="relative z-10 h-full">{children}</div>
    </div>
  );
}
