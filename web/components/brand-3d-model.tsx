"use client";

import * as React from "react";
import * as THREE from "three";

/* ------------------------------------------------------------------ */
/*  KORKEM studio 3D logo                                              */
/*  Extruded vector geometry (traced from the official PNG), cream     */
/*  enamel face + brushed brass bevel/sides, lit by a procedural       */
/*  softbox HDRI (PMREM) like a product shot in a photo studio.        */
/* ------------------------------------------------------------------ */

interface ShapeData {
  outer: [number, number][];
  holes: [number, number][][];
}

interface ModelJson {
  aspect: number;
  shapes: ShapeData[];
}

type Variant = "mark" | "lockup";

interface Brand3DModelProps {
  modelJson: string;
  fallbackSrc: string;
  alt: string;
  variant?: Variant;
  className?: string;
  autoSpin?: boolean;
  hint?: string;
}

const PRESET: Record<
  Variant,
  {
    depth: number;
    bevelSize: number;
    bevelThickness: number;
    span: number;
    fov: number;
    camZ: number;
    basePitch: number;
    spinSpeed: number;
    /** 0 = full turntable spin; otherwise idle sway amplitude in radians. */
    sway: number;
  }
> = {
  // Units are the normalized [-1, 1] shape space produced by the tracer.
  mark: {
    depth: 0.15,
    bevelSize: 0.0042,
    bevelThickness: 0.014,
    span: 1.9,
    fov: 30,
    camZ: 4.4,
    basePitch: 0.12,
    spinSpeed: 0.34,
    sway: 0,
  },
  lockup: {
    depth: 0.085,
    bevelSize: 0.001,
    bevelThickness: 0.004,
    span: 2.75,
    fov: 24,
    camZ: 5.6,
    basePitch: 0.1,
    spinSpeed: 0.55,
    sway: 0.6,
  },
};

/* ---------- procedural textures ---------------------------------- */

function makeCanvas(size: number) {
  const c = document.createElement("canvas");
  c.width = size;
  c.height = size;
  return c;
}

/** Fine stone/enamel grain used as bump on the cream face. */
function createGrainTexture() {
  const size = 256;
  const c = makeCanvas(size);
  const ctx = c.getContext("2d")!;
  const img = ctx.createImageData(size, size);
  for (let i = 0; i < size * size; i++) {
    const v = 128 + (Math.random() - 0.5) * 70;
    img.data[i * 4] = v;
    img.data[i * 4 + 1] = v;
    img.data[i * 4 + 2] = v;
    img.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  // soft mottling
  for (let i = 0; i < 90; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const r = 6 + Math.random() * 26;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r);
    const tone = Math.random() > 0.5 ? 255 : 0;
    g.addColorStop(0, `rgba(${tone},${tone},${tone},0.07)`);
    g.addColorStop(1, `rgba(${tone},${tone},${tone},0)`);
    ctx.fillStyle = g;
    ctx.fillRect(x - r, y - r, r * 2, r * 2);
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(3, 3);
  return tex;
}

/** Brushed-metal streaks: drives roughness variation on the brass. */
function createBrushedTexture() {
  const size = 512;
  const c = makeCanvas(size);
  const ctx = c.getContext("2d")!;
  ctx.fillStyle = "rgb(150,150,150)";
  ctx.fillRect(0, 0, size, size);
  for (let i = 0; i < 2600; i++) {
    const y = Math.random() * size;
    const len = 40 + Math.random() * 380;
    const x = Math.random() * size;
    const v = Math.random() > 0.5 ? 205 : 95;
    ctx.fillStyle = `rgba(${v},${v},${v},${0.05 + Math.random() * 0.12})`;
    ctx.fillRect(x, y, len, 1);
    if (x + len > size) ctx.fillRect(x - size, y, len, 1);
  }
  const tex = new THREE.CanvasTexture(c);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(4, 4);
  return tex;
}

/* ---------- studio environment (softboxes) ------------------------ */

function buildStudioEnvironment(renderer: THREE.WebGLRenderer) {
  const env = new THREE.Scene();

  // Dark forest-tinted cyclorama so reflections stay on-brand.
  const room = new THREE.Mesh(
    new THREE.SphereGeometry(20, 48, 24),
    new THREE.MeshBasicMaterial({ color: new THREE.Color("#0c120b"), side: THREE.BackSide })
  );
  env.add(room);

  const softbox = (
    w: number,
    h: number,
    color: string,
    intensity: number,
    pos: [number, number, number]
  ) => {
    const mat = new THREE.MeshBasicMaterial({ color: new THREE.Color(color), side: THREE.DoubleSide });
    mat.color.multiplyScalar(intensity);
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
    m.position.set(...pos);
    m.lookAt(0, 0, 0);
    env.add(m);
    return m;
  };

  // Key: big warm overhead softbox, front-right.
  softbox(9, 5, "#fff1dc", 7.5, [6, 7, 7]);
  // Fill: soft cool panel front-left.
  softbox(6, 8, "#e9efe6", 2.4, [-8, 1, 6]);
  // Two tall strip lights for crisp vertical highlights on the brass edges.
  softbox(1.1, 14, "#ffffff", 9, [-9, 0, -2]);
  softbox(1.1, 14, "#fff4e2", 9, [9, 0, -1]);
  // Warm gold kicker from behind for the rim.
  softbox(10, 1.4, "#ffcf87", 6, [0, 4, -10]);
  // Faint green floor bounce (KORKEM forest).
  softbox(16, 16, "#2b382a", 1.4, [0, -10, 0]);

  const pmrem = new THREE.PMREMGenerator(renderer);
  const rt = pmrem.fromScene(env, 0.035);
  env.traverse((o) => {
    if (o instanceof THREE.Mesh) {
      o.geometry.dispose();
      (o.material as THREE.Material).dispose();
    }
  });
  pmrem.dispose();
  return rt;
}

/* ---------- geometry ---------------------------------------------- */

function buildGeometry(data: ModelJson, variant: Variant) {
  const p = PRESET[variant];
  const shapes = data.shapes.map((s) => {
    const shape = new THREE.Shape(s.outer.map(([x, y]) => new THREE.Vector2(x, y)));
    s.holes.forEach((h) => {
      shape.holes.push(new THREE.Path(h.map(([x, y]) => new THREE.Vector2(x, y))));
    });
    return shape;
  });

  const geom = new THREE.ExtrudeGeometry(shapes, {
    depth: p.depth,
    bevelEnabled: true,
    bevelThickness: p.bevelThickness,
    bevelSize: p.bevelSize,
    bevelOffset: 0,
    bevelSegments: 5,
    curveSegments: 1,
  });

  geom.computeBoundingBox();
  const box = geom.boundingBox!;
  const center = box.getCenter(new THREE.Vector3());
  const size = box.getSize(new THREE.Vector3());
  geom.translate(-center.x, -center.y, -center.z);
  const s = p.span / Math.max(size.x, size.y);
  geom.scale(s, s, s);
  geom.computeVertexNormals();
  return geom;
}

/* ---------- component --------------------------------------------- */

export function Brand3DModel({
  modelJson,
  fallbackSrc,
  alt,
  variant = "mark",
  className = "",
  autoSpin = true,
  hint,
}: Brand3DModelProps) {
  const mountRef = React.useRef<HTMLDivElement>(null);
  const [ready, setReady] = React.useState(false);
  const [failed, setFailed] = React.useState(false);
  const [dragging, setDragging] = React.useState(false);

  const input = React.useRef({
    dragging: false,
    lastX: 0,
    lastY: 0,
    velX: 0, // rad/frame around screen Y
    velY: 0, // rad/frame around screen X
    lastInteraction: 0,
  });
  const rotateRef = React.useRef<((dx: number, dy: number) => void) | null>(null);
  const resetRef = React.useRef<(() => void) | null>(null);

  React.useEffect(() => {
    const mount = mountRef.current;
    if (!mount) return;

    const preset = PRESET[variant];
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    let renderer: THREE.WebGLRenderer;
    try {
      renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
    } catch {
      setFailed(true);
      return;
    }

    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.setClearColor(0x000000, 0);
    const canvas = renderer.domElement;
    canvas.style.width = "100%";
    canvas.style.height = "100%";
    canvas.style.display = "block";
    mount.appendChild(canvas);

    const scene = new THREE.Scene();
    const envRT = buildStudioEnvironment(renderer);
    scene.environment = envRT.texture;
    scene.environmentIntensity = 1.0;

    const camera = new THREE.PerspectiveCamera(preset.fov, 1, 0.1, 50);
    camera.position.set(0, 0, preset.camZ);

    // A couple of direct lights for crisp clearcoat specular on the cream face.
    const key = new THREE.DirectionalLight("#fff3e0", 1.6);
    key.position.set(2.5, 3.5, 4);
    scene.add(key);
    const rim = new THREE.DirectionalLight("#ffd08a", 2.2);
    rim.position.set(-3, 1.5, -4);
    scene.add(rim);

    const grain = createGrainTexture();
    const brushed = createBrushedTexture();

    const enamel = new THREE.MeshPhysicalMaterial({
      color: new THREE.Color("#ECE5D3"),
      roughness: 0.46,
      metalness: 0,
      bumpMap: grain,
      bumpScale: 0.35,
      clearcoat: 1,
      clearcoatRoughness: 0.14,
      sheen: 0.35,
      sheenColor: new THREE.Color("#fff2d6"),
      sheenRoughness: 0.55,
    });

    const brass = new THREE.MeshPhysicalMaterial({
      color: new THREE.Color("#C9A25B"),
      metalness: 1,
      roughness: 0.3,
      roughnessMap: brushed,
      anisotropy: 0.75,
      clearcoat: 0.25,
      clearcoatRoughness: 0.3,
    });

    const pivot = new THREE.Group();
    scene.add(pivot);

    let mesh: THREE.Mesh | null = null;
    let disposed = false;

    fetch(modelJson)
      .then((r) => {
        if (!r.ok) throw new Error("model");
        return r.json() as Promise<ModelJson>;
      })
      .then((data) => {
        if (disposed) return;
        const geom = buildGeometry(data, variant);
        // Group 0 = caps (enamel face), group 1 = sides + bevel (brass).
        mesh = new THREE.Mesh(geom, [enamel, brass]);
        pivot.add(mesh);
        setReady(true);
      })
      .catch(() => {
        if (!disposed) setFailed(true);
      });

    const resize = () => {
      const w = mount.clientWidth || 1;
      const h = mount.clientHeight || 1;
      renderer.setSize(w, h, false);
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
    };
    resize();
    const ro = new ResizeObserver(resize);
    ro.observe(mount);

    // Pause rendering when off-screen or tab hidden.
    let visible = true;
    const io = new IntersectionObserver((e) => {
      visible = !!e[0]?.isIntersecting;
    });
    io.observe(mount);

    // Orientation state: free trackball rotation + idle "settle" to an upright spin.
    const q = new THREE.Quaternion();
    const qTmp = new THREE.Quaternion();
    const qTarget = new THREE.Quaternion();
    const axisX = new THREE.Vector3(1, 0, 0);
    const axisY = new THREE.Vector3(0, 1, 0);
    const euler = new THREE.Euler(0, 0, 0, "YXZ");
    let yaw = -0.5;
    let swayPhase = -Math.PI / 2;
    q.setFromEuler(euler.set(preset.basePitch, yaw, 0, "YXZ"));

    const start = performance.now();
    let last = start;
    let raf = 0;

    const tick = (now: number) => {
      raf = requestAnimationFrame(tick);
      if (!visible || document.hidden) {
        last = now;
        return;
      }
      const dt = Math.min((now - last) / 1000, 0.05);
      last = now;
      const st = input.current;

      if (st.dragging) {
        // handled in pointer move
      } else if (Math.abs(st.velX) > 0.0002 || Math.abs(st.velY) > 0.0002) {
        // inertia
        qTmp.setFromAxisAngle(axisY, st.velX);
        q.premultiply(qTmp);
        qTmp.setFromAxisAngle(axisX, st.velY);
        q.premultiply(qTmp);
        st.velX *= 0.94;
        st.velY *= 0.94;
        euler.setFromQuaternion(q, "YXZ");
        yaw = euler.y;
      } else if (!reduceMotion) {
        // idle: slowly settle upright and keep a calm turntable spin / sway
        const idleFor = (now - st.lastInteraction) / 1000;
        let targetYaw: number;
        if (preset.sway > 0) {
          // Text lockups sway around the front view so the lettering never reads mirrored.
          if (autoSpin && idleFor > 1.2) swayPhase += preset.spinSpeed * dt;
          targetYaw = Math.sin(swayPhase) * preset.sway;
        } else {
          if (autoSpin && idleFor > 1.2) yaw += preset.spinSpeed * dt;
          targetYaw = yaw;
        }
        const pitch = preset.basePitch + Math.sin(now * 0.0007) * 0.07;
        qTarget.setFromEuler(euler.set(pitch, targetYaw, 0, "YXZ"));
        q.slerp(qTarget, 1 - Math.pow(0.06, dt));
      }

      // Intro: scale + sweep in.
      const t = reduceMotion ? 1 : Math.min((now - start) / 1800, 1);
      const e = 1 - Math.pow(1 - t, 3);
      pivot.quaternion.copy(q);
      if (e < 1) {
        qTmp.setFromAxisAngle(axisY, (1 - e) * -1.4);
        pivot.quaternion.premultiply(qTmp);
      }
      pivot.scale.setScalar(0.82 + 0.18 * e);
      pivot.position.y = reduceMotion ? 0 : Math.sin(now * 0.0013) * 0.03;

      // Glide the studio reflections across the brass.
      scene.environmentRotation.y = reduceMotion ? 0.4 : 0.4 + Math.sin(now * 0.00025) * 0.6;

      renderer.render(scene, camera);
    };
    raf = requestAnimationFrame(tick);

    // Expose rotation hooks to pointer handlers.
    rotateRef.current = (dx: number, dy: number) => {
      qTmp.setFromAxisAngle(axisY, dx);
      q.premultiply(qTmp);
      qTmp.setFromAxisAngle(axisX, dy);
      q.premultiply(qTmp);
      euler.setFromQuaternion(q, "YXZ");
      yaw = euler.y;
    };
    resetRef.current = () => {
      input.current.velX = 0;
      input.current.velY = 0;
      yaw = -0.5;
      input.current.lastInteraction = performance.now();
    };

    return () => {
      disposed = true;
      cancelAnimationFrame(raf);
      ro.disconnect();
      io.disconnect();
      rotateRef.current = null;
      resetRef.current = null;
      if (mesh) mesh.geometry.dispose();
      enamel.dispose();
      brass.dispose();
      grain.dispose();
      brushed.dispose();
      envRT.dispose();
      renderer.dispose();
      if (canvas.parentNode === mount) mount.removeChild(canvas);
    };
  }, [modelJson, variant, autoSpin]);

  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    e.currentTarget.setPointerCapture(e.pointerId);
    const st = input.current;
    st.dragging = true;
    st.lastX = e.clientX;
    st.lastY = e.clientY;
    st.velX = 0;
    st.velY = 0;
    st.lastInteraction = performance.now();
    setDragging(true);
  };

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const st = input.current;
    if (!st.dragging) return;
    const dx = (e.clientX - st.lastX) * 0.0105;
    const dy = (e.clientY - st.lastY) * 0.0105;
    st.lastX = e.clientX;
    st.lastY = e.clientY;
    rotateRef.current?.(dx, dy);
    st.velX = dx;
    st.velY = dy;
    st.lastInteraction = performance.now();
  };

  const onPointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    if (e.currentTarget.hasPointerCapture(e.pointerId)) e.currentTarget.releasePointerCapture(e.pointerId);
    input.current.dragging = false;
    input.current.lastInteraction = performance.now();
    setDragging(false);
  };

  return (
    <div className={`relative flex select-none flex-col items-center ${className}`}>
      <div className="relative h-full w-full">
        {failed ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={fallbackSrc} alt={alt} className="h-full w-full object-contain" />
        ) : (
          <div
            ref={mountRef}
            role="img"
            aria-label={alt}
            title="Потяните, чтобы вращать · двойной клик — сброс"
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
            onDoubleClick={() => resetRef.current?.()}
            className={`h-full w-full touch-none transition-opacity duration-700 ${
              ready ? "opacity-100" : "opacity-0"
            } ${dragging ? "cursor-grabbing" : "cursor-grab"}`}
          />
        )}
      </div>
      {hint && !failed && (
        <span className="pointer-events-none mt-3 inline-flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.22em] text-[#8E9488]">
          <span className="h-px w-6 bg-gradient-to-r from-transparent to-[#C9A25B]" />
          {hint}
          <span className="h-px w-6 bg-gradient-to-l from-transparent to-[#C9A25B]" />
        </span>
      )}
    </div>
  );
}
