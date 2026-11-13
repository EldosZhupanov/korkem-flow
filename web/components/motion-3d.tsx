"use client";

import * as React from "react";

interface Tilt3DStageProps {
  children: React.ReactNode;
  className?: string;
  intensity?: number;
}

export function Tilt3DStage({
  children,
  className = "",
  intensity = 6,
}: Tilt3DStageProps) {
  const ref = React.useRef<HTMLDivElement>(null);
  const [tilt, setTilt] = React.useState({ rx: 0, ry: 0, gx: 50, gy: 50, active: false });

  const handleMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!ref.current) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const rect = ref.current.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width;
    const py = (e.clientY - rect.top) / rect.height;
    setTilt({
      rx: (0.5 - py) * intensity,
      ry: (px - 0.5) * intensity,
      gx: px * 100,
      gy: py * 100,
      active: true,
    });
  };

  const handleLeave = () => {
    setTilt({ rx: 0, ry: 0, gx: 50, gy: 50, active: false });
  };

  return (
    <div
      style={{ perspective: "1400px" }}
      className={className}
      onMouseMove={handleMove}
      onMouseLeave={handleLeave}
    >
      <div
        ref={ref}
        style={{
          transform: `rotateX(${tilt.rx}deg) rotateY(${tilt.ry}deg)`,
          transformStyle: "preserve-3d",
          transition: tilt.active
            ? "transform 120ms ease-out"
            : "transform 500ms cubic-bezier(0.22, 1, 0.36, 1)",
        }}
        className="relative"
      >
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -inset-px z-20 rounded-2xl transition-opacity duration-300"
          style={{
            opacity: tilt.active ? 1 : 0,
            background: `radial-gradient(520px circle at ${tilt.gx}% ${tilt.gy}%, rgba(222, 218, 208, 0.08), transparent 60%)`,
          }}
        />
        {children}
      </div>
    </div>
  );
}

interface Reveal3DProps {
  children: React.ReactNode;
  className?: string;
  delayMs?: number;
}

export function Reveal3D({
  children,
  className = "",
  delayMs = 0,
}: Reveal3DProps) {
  const ref = React.useRef<HTMLDivElement>(null);
  const [visible, setVisible] = React.useState(false);

  React.useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setVisible(true);
      return;
    }
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.12 }
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div style={{ perspective: "1100px" }} className={className}>
      <div
        ref={ref}
        style={{
          opacity: visible ? 1 : 0,
          transform: visible
            ? "translate3d(0, 0, 0) rotateX(0deg) scale(1)"
            : "translate3d(0, 28px, -24px) rotateX(8deg) scale(0.98)",
          transition: `opacity 700ms cubic-bezier(0.22, 1, 0.36, 1) ${delayMs}ms, transform 750ms cubic-bezier(0.22, 1, 0.36, 1) ${delayMs}ms`,
        }}
      >
        {children}
      </div>
    </div>
  );
}

export function Brand3DMedallion() {
  return (
    <div
      className="relative mx-auto flex h-28 w-28 items-center justify-center sm:h-32 sm:w-32"
      style={{ perspective: "900px", transformStyle: "preserve-3d" }}
    >
      {/* Ambient forest/cream halo */}
      <div
        aria-hidden="true"
        className="absolute inset-0 rounded-full bg-[#DEDAD0]/15 blur-2xl"
      />
      {/* 3D Orbit Rings */}
      <div
        aria-hidden="true"
        className="animate-orbit-slow absolute -inset-4 rounded-full border border-[#DEDAD0]/25"
      />
      <div
        aria-hidden="true"
        className="animate-orbit-reverse absolute -inset-7 rounded-full border border-dashed border-[#7FD36B]/25"
      />
      {/* Floating Official Shanyrak Mark */}
      <div
        className="animate-float-3d relative flex h-24 w-24 items-center justify-center overflow-hidden rounded-full border border-[#DEDAD0]/30 bg-[#070B07] shadow-[0_20px_50px_-10px_rgba(0,0,0,0.85)] sm:h-28 sm:w-28"
        style={{ transformStyle: "preserve-3d" }}
      >
        <img
          src="/brand/korkem_mark.png"
          alt="Официальный логотип KORKEM"
          className="h-20 w-20 object-contain sm:h-24 sm:w-24"
        />
      </div>
    </div>
  );
}
