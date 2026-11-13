'use client';

import React, { useEffect, useRef, useState } from 'react';

interface Brand3DModelProps {
  src: string;
  alt: string;
  variant?: 'mark' | 'lockup';
  className?: string;
  layers?: number;
  depthPx?: number;
  autoSpin?: boolean;
  hint?: string;
}

/**
 * Interactive 3D extruded PNG model viewer.
 * Stacks Z-slices of a transparent PNG to form a physical 3D object
 * that users can freely rotate 360° along X and Y axes ("вдоль и поперёк").
 */
export function Brand3DModel({
  src,
  alt,
  variant = 'mark',
  className = '',
  layers = 18,
  depthPx = 22,
  autoSpin = true,
  hint = '3D · потяните в любую сторону',
}: Brand3DModelProps) {
  const [rot, setRot] = useState({ x: variant === 'mark' ? 10 : 8, y: variant === 'mark' ? -18 : -10 });
  const [isDragging, setIsDragging] = useState(false);
  const dragRef = useRef<{
    active: boolean;
    lastX: number;
    lastY: number;
    vx: number;
    vy: number;
  }>({ active: false, lastX: 0, lastY: 0, vx: 0, vy: 0 });

  useEffect(() => {
    let raf = 0;
    let lastTime = performance.now();

    const tick = (now: number) => {
      const dt = Math.min((now - lastTime) / 1000, 0.05);
      lastTime = now;

      if (!dragRef.current.active) {
        const hasInertia =
          Math.abs(dragRef.current.vx) > 0.05 || Math.abs(dragRef.current.vy) > 0.05;

        if (hasInertia) {
          setRot((prev) => ({
            x: prev.x + dragRef.current.vy,
            y: prev.y + dragRef.current.vx,
          }));
          dragRef.current.vx *= 0.93;
          dragRef.current.vy *= 0.93;
        } else if (autoSpin) {
          setRot((prev) => ({
            x: prev.x + Math.sin(now * 0.0009) * 6 * dt,
            y: prev.y + (variant === 'mark' ? 22 : 14) * dt,
          }));
        }
      }

      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [autoSpin, variant]);

  const handlePointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    dragRef.current = {
      active: true,
      lastX: e.clientX,
      lastY: e.clientY,
      vx: 0,
      vy: 0,
    };
    setIsDragging(true);
  };

  const handlePointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!dragRef.current.active) return;
    const dx = e.clientX - dragRef.current.lastX;
    const dy = e.clientY - dragRef.current.lastY;
    dragRef.current.lastX = e.clientX;
    dragRef.current.lastY = e.clientY;
    dragRef.current.vx = dx * 0.45;
    dragRef.current.vy = -dy * 0.45;

    setRot((prev) => ({
      x: prev.x - dy * 0.55,
      y: prev.y + dx * 0.55,
    }));
  };

  const handlePointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    if (e.currentTarget.hasPointerCapture(e.pointerId)) {
      e.currentTarget.releasePointerCapture(e.pointerId);
    }
    dragRef.current.active = false;
    setIsDragging(false);
  };

  const handleDoubleClick = () => {
    dragRef.current.vx = 0;
    dragRef.current.vy = 0;
    setRot({ x: variant === 'mark' ? 10 : 8, y: variant === 'mark' ? -18 : -10 });
  };

  const sliceIndices = Array.from({ length: layers }, (_, i) => i);
  const halfDepth = depthPx / 2;

  return (
    <div className={`relative select-none flex flex-col items-center ${className}`}>
      <div
        onPointerDown={handlePointerDown}
        onPointerMove={handlePointerMove}
        onPointerUp={handlePointerUp}
        onPointerCancel={handlePointerUp}
        onDoubleClick={handleDoubleClick}
        role="img"
        aria-label={alt}
        title="Потяните, чтобы вращать 3D-модель (двойной клик — сброс)"
        className={`relative touch-none select-none ${
          isDragging ? 'cursor-grabbing' : 'cursor-grab'
        } ${
          variant === 'mark'
            ? 'w-52 h-52 sm:w-64 sm:h-64'
            : 'w-full max-w-[540px] aspect-[3245/965]'
        }`}
        style={{ perspective: '1100px' }}
      >
        {/* Subtle ambient glow behind the 3D object */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-4 rounded-full blur-3xl opacity-35"
          style={{
            background:
              'radial-gradient(circle, rgba(222,218,208,0.28) 0%, rgba(127,211,107,0.08) 45%, transparent 75%)',
          }}
        />

        {/* 3D Rotating Object */}
        <div
          className="relative w-full h-full"
          style={{
            transformStyle: 'preserve-3d',
            transform: `rotateX(${rot.x}deg) rotateY(${rot.y}deg)`,
            transition: isDragging ? 'none' : 'transform 0.04s linear',
          }}
        >
          {sliceIndices.map((idx) => {
            const t = layers > 1 ? idx / (layers - 1) : 1; // 0 (back) -> 1 (front)
            const z = -halfDepth + t * depthPx;
            const isFront = idx === layers - 1;
            const isBack = idx === 0;
            // Warm shadowed extrusion depth for interior slices
            const shade = isFront ? 1 : isBack ? 0.88 : 0.42 + 0.35 * Math.sin(t * Math.PI);

            return (
              <img
                key={idx}
                src={src}
                alt={isFront ? alt : ''}
                aria-hidden={!isFront}
                draggable={false}
                className="pointer-events-none absolute inset-0 w-full h-full object-contain"
                style={{
                  transform: `translateZ(${z.toFixed(2)}px)`,
                  filter: isFront
                    ? 'drop-shadow(0 12px 24px rgba(0, 0, 0, 0.45))'
                    : `brightness(${shade.toFixed(2)})`,
                  backfaceVisibility: 'visible',
                }}
              />
            );
          })}
        </div>
      </div>

      {hint && (
        <span className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-[#3D4A3B]/80 bg-[#2B382A]/50 px-3 py-1 font-mono text-[10px] uppercase tracking-[0.18em] text-[#A2A89C]">
          <span className="h-1.5 w-1.5 rounded-full bg-[#7FD36B]" />
          {hint}
        </span>
      )}
    </div>
  );
}
