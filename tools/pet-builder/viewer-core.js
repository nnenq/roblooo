// Кротик-Росток viewer core. Expects `THREE` and `SPEC` in scope (the preview inlines both).
function mountKrotik(canvas, opts) {
  opts = opts || {};
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: !!opts.capture });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.1, 100);

  // a soft studio environment, so gold and diamond have something to reflect
  const pmrem = new THREE.PMREMGenerator(renderer);
  const env = new THREE.Scene();
  const dome = new THREE.Mesh(new THREE.SphereGeometry(20, 32, 16), new THREE.MeshBasicMaterial({ side: THREE.BackSide, vertexColors: true }));
  const dc = [], dp = dome.geometry.attributes.position;
  for (let i = 0; i < dp.count; i++) { const k = (dp.getY(i) / 20 + 1) / 2; dc.push(0.35 + 0.65 * k, 0.33 + 0.62 * k, 0.32 + 0.58 * k); }
  dome.geometry.setAttribute('color', new THREE.Float32BufferAttribute(dc, 3));
  env.add(dome);
  for (const [x, y, z, s] of [[-6, 8, -6, 6], [7, 5, -3, 4], [0, 6, 8, 5]]) {
    const p = new THREE.Mesh(new THREE.PlaneGeometry(s, s), new THREE.MeshBasicMaterial({ color: 0xffffff, side: THREE.DoubleSide }));
    p.position.set(x, y, z); p.lookAt(0, 0, 0); env.add(p);
  }
  scene.environment = pmrem.fromScene(env, 0.04).texture;

  scene.add(new THREE.HemisphereLight(0xfff6ea, 0x8a7360, 1.1));
  const key = new THREE.DirectionalLight(0xffffff, 2.2); key.position.set(4, 7, -6); scene.add(key);
  const rim = new THREE.DirectionalLight(0xfff0d8, 1.2); rim.position.set(-5, 4, 6); scene.add(rim);

  const pet = new THREE.Group(); scene.add(pet);
  const fx = new THREE.Group(); scene.add(fx);
  const ground = new THREE.Mesh(new THREE.CircleGeometry(1.5, 48), new THREE.MeshBasicMaterial({ map: glowTex('40,20,10', 0.45), transparent: true, depthWrite: false }));
  ground.rotation.x = -Math.PI / 2; ground.position.y = 0.01; ground.scale.set(1.25, 1, 1); scene.add(ground);

  const state = { rarity: opts.rarity || 'Common', mutation: opts.mutation || 'None', yaw: opts.yaw != null ? opts.yaw : -0.45, spin: opts.spin !== false, t: 0 };
  let animated = [];   // per-frame updaters
  let built = null;

  function canvasTex(size, draw) {
    const c = document.createElement('canvas'); c.width = c.height = size;
    draw(c.getContext('2d'), size);
    const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
  }
  function glowTex(rgb, a) {
    return canvasTex(128, (g, s) => {
      const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
      gr.addColorStop(0, 'rgba(' + rgb + ',' + a + ')'); gr.addColorStop(0.45, 'rgba(' + rgb + ',' + a * 0.5 + ')');
      gr.addColorStop(1, 'rgba(' + rgb + ',0)'); g.fillStyle = gr; g.fillRect(0, 0, s, s);
    });
  }
  const softTex = glowTex('255,255,255', 1);
  const starTex = canvasTex(64, (g, s) => {
    const m = s / 2; g.fillStyle = '#fff'; g.beginPath();
    for (let i = 0; i < 8; i++) { const r = i % 2 ? s * 0.09 : s * 0.48, a = i * Math.PI / 4; g.lineTo(m + r * Math.sin(a), m - r * Math.cos(a)); }
    g.closePath(); g.fill();
    const gr = g.createRadialGradient(m, m, 0, m, m, s * 0.22); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, s, s);
  });
  const rayTex = canvasTex(256, (g, s) => {
    const m = s / 2;
    for (let i = 0; i < 14; i++) {
      const a = i * Math.PI * 2 / 14, w = 0.09;
      const gr = g.createRadialGradient(m, m, s * 0.08, m, m, m * 0.98); gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
      g.fillStyle = gr; g.beginPath(); g.moveTo(m, m);
      g.arc(m, m, m, a - w, a + w); g.closePath(); g.fill();
    }
  });

  const col = (h) => new THREE.Color(h);
  const R = (d) => d * Math.PI / 180;

  function partColor(p, mut) {
    const cls = SPEC.roleClass[p.role];
    if (!cls || mut.id === 'None' || mut.id === 'Rainbow') return SPEC.palette[p.role];
    return mut.palette[cls];
  }

  function build() {
    pet.clear(); fx.clear(); animated = [];
    const rar = SPEC.rarities.find((r) => r.id === state.rarity);
    const mut = SPEC.mutations.find((m) => m.id === state.mutation);
    const facets = mut.id === 'Diamond';
    const rainbowMeshes = [];
    for (const p of SPEC.parts) {
      if (p.group !== 'base' && rar.groups.indexOf(p.group) < 0) continue;
      const mutated = !!SPEC.roleClass[p.role];
      const big = Math.max.apply(null, p.size);
      const seg = facets && mutated ? (big > 1.5 ? 14 : 8) : big > 1.5 ? 48 : big > 0.5 ? 28 : 16;
      const geo = p.shape === 'sphere' ? new THREE.SphereGeometry(0.5, seg, Math.max(6, seg >> 1)) : new THREE.CylinderGeometry(0.5, 0.5, 1, seg);
      const m = new THREE.MeshPhysicalMaterial({ color: col(partColor(p, mut)), roughness: 0.42, metalness: 0, envMapIntensity: 0.55, flatShading: facets && mutated });
      if (p.role === 'eye') { m.roughness = 0.12; m.clearcoat = 1; }
      if (p.role === 'shine') { m.emissive = col('#ffffff'); m.emissiveIntensity = 0.6; }
      if (rar.fx === 'shine' && p.role === 'fur') { m.roughness = 0.28; m.clearcoat = 0.6; }
      if (rar.glowLeaves && (p.role === 'leaf' || p.role === 'stem') && mut.id === 'None') { m.emissive = col(SPEC.palette.leaf); m.emissiveIntensity = p.role === 'leaf' ? 0.55 : 0.25; }
      if (mutated && mut.id === 'Gold') { m.metalness = 1; m.roughness = 0.22; m.envMapIntensity = 1.4; }
      if (mutated && mut.id === 'Diamond') { m.roughness = 0.04; m.metalness = 0.1; m.transmission = 0.15; m.thickness = 0.6; m.ior = 2.0; m.clearcoat = 1; m.envMapIntensity = 1.1; m.transparent = true; m.opacity = 0.92; }
      if (mutated && mut.id === 'Galaxy') { m.roughness = 0.3; m.emissive = col(mut.palette.main); m.emissiveIntensity = 0.35; m.clearcoat = 0.8; }
      if (mutated && mut.id === 'Rainbow') { m.vertexColors = true; m.color = col('#ffffff'); m.roughness = 0.3; m.clearcoat = 0.5; }
      const mesh = new THREE.Mesh(geo, m);
      mesh.position.set(p.pos[0], p.pos[1], p.pos[2]);
      mesh.rotation.set(R(p.rot[0]), R(p.rot[1]), R(p.rot[2]), 'XYZ');
      mesh.scale.set(p.size[0], p.size[1], p.size[2]);
      pet.add(mesh);
      if (mutated && mut.id === 'Rainbow') rainbowMeshes.push(mesh);
      if (mutated && mut.id === 'Galaxy' && big > 0.25) {
        const o = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: col(mut.glow), side: THREE.BackSide, transparent: true, opacity: 0.9 }));
        o.position.copy(mesh.position); o.rotation.copy(mesh.rotation);
        o.scale.set(p.size[0] + 0.09, p.size[1] + 0.09, p.size[2] + 0.09);
        pet.add(o);
      }
    }
    pet.updateMatrixWorld(true);

    if (rainbowMeshes.length) {
      const stops = mut.colors.map(col);
      for (const mesh of rainbowMeshes) {
        const pos = mesh.geometry.attributes.position, arr = new Float32Array(pos.count * 3);
        mesh.geometry.setAttribute('color', new THREE.BufferAttribute(arr, 3));
      }
      const v = new THREE.Vector3(), c = new THREE.Color();
      const paint = (t) => {
        for (const mesh of rainbowMeshes) {
          const pos = mesh.geometry.attributes.position, ca = mesh.geometry.attributes.color;
          for (let i = 0; i < pos.count; i++) {
            v.fromBufferAttribute(pos, i).applyMatrix4(mesh.matrixWorld);
            let k = ((v.y * 0.32 + v.x * 0.12 - t * 0.25) % 1 + 1) % 1 * stops.length;
            const a = stops[Math.floor(k) % stops.length], b = stops[(Math.floor(k) + 1) % stops.length];
            c.copy(a).lerp(b, k - Math.floor(k)); ca.setXYZ(i, c.r, c.g, c.b);
          }
          ca.needsUpdate = true;
        }
      };
      paint(0); animated.push(paint);
    }

    if (mut.id === 'Galaxy') {
      const pts = [], sizes = [];
      SPEC.parts.filter((p) => p.role === 'fur').forEach((p) => {
        const n = Math.round(p.size[0] * p.size[1] * 34);
        const m4 = new THREE.Matrix4().compose(new THREE.Vector3().fromArray(p.pos), new THREE.Quaternion().setFromEuler(new THREE.Euler(R(p.rot[0]), R(p.rot[1]), R(p.rot[2]), 'XYZ')), new THREE.Vector3(p.size[0] / 2 * 1.015, p.size[1] / 2 * 1.015, p.size[2] / 2 * 1.015));
        for (let i = 0; i < n; i++) {
          const d = new THREE.Vector3(gauss(), gauss(), gauss()).normalize().applyMatrix4(m4);
          pts.push(d.x, d.y, d.z);
        }
      });
      const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pts, 3));
      const sm = new THREE.PointsMaterial({ map: starTex, size: 0.13, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, color: col('#ffffff') });
      pet.add(new THREE.Points(g, sm));
      animated.push((t) => { sm.opacity = 0.75 + 0.25 * Math.sin(t * 3); });
    }

    // rarity effects, kept as quiet as the rarity asks for
    const rc = col(rar.color);
    const centre = new THREE.Vector3(0, 2.0, 0);
    function sprite(tex, color, scale, opacity, z) {
      const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, color, transparent: true, opacity, depthWrite: false }));
      s.scale.set(scale, scale, 1); s.position.copy(centre); s.renderOrder = z || 0; fx.add(s); return s;
    }
    function swarm(count, color, radius, size, mode) {
      const items = [];
      for (let i = 0; i < count; i++) {
        const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: mode === 'dot' ? softTex : starTex, color, transparent: true, depthWrite: false }));
        const a = (i / count) * Math.PI * 2 + rnd(i) * 0.8, r = radius * (0.75 + rnd(i + 7) * 0.4);
        s.userData = { a, r, y: 0.6 + rnd(i + 3) * 3.4, ph: rnd(i + 11) * 6.28, sz: size * (0.6 + rnd(i + 5) * 0.8) };
        fx.add(s); items.push(s);
      }
      animated.push((t) => {
        for (const s of items) {
          const u = s.userData, a = u.a + t * (mode === 'rise' || mode === 'dot' ? 0.25 : 0.4);
          const y = mode === 'rise' || mode === 'dot' ? 0.4 + ((u.y + t * 0.6) % 4) : u.y + Math.sin(t * 1.5 + u.ph) * 0.15;
          s.position.set(Math.cos(a) * u.r, y, Math.sin(a) * u.r);
          const tw = 0.5 + 0.5 * Math.sin(t * 4 + u.ph);
          s.scale.setScalar(u.sz * (0.55 + 0.45 * tw)); s.material.opacity = 0.35 + 0.65 * tw;
        }
      });
    }
    if (rar.fx === 'sparkle') swarm(6, rc, 1.9, 0.5, 'star');
    if (rar.fx === 'aura') { sprite(softTex, rc, 6.4, 0.5, -1); swarm(8, rc, 1.9, 0.5, 'star'); }
    if (rar.fx === 'rays') {
      const glow = sprite(softTex, rc, 6.4, 0.5, -1), rays = sprite(rayTex, rc, 6.8, 0.6, -2);
      swarm(9, col('#ffb000'), 2.0, 0.5, 'star');
      animated.push((t) => { rays.material.rotation = t * 0.25; glow.material.opacity = 0.45 + 0.08 * Math.sin(t * 2); });
    }
    if (rar.fx === 'particles') { sprite(softTex, rc, 6.4, 0.45, -1); swarm(18, rc, 1.7, 0.26, 'dot'); swarm(6, col('#ff2f6e'), 2.0, 0.45, 'star'); }
    if (rar.fx === 'cosmic') {
      const hues = SPEC.mutations.find((m) => m.id === 'Rainbow').colors.map(col);
      const glow = sprite(softTex, hues[0], 7.0, 0.55, -1), ring = sprite(rayTex, hues[3], 7.0, 0.6, -2);
      swarm(10, col('#8a5cff'), 2.1, 0.45, 'star'); swarm(8, col('#19c3ff'), 2.0, 0.4, 'star'); swarm(12, col('#ff5fd2'), 1.8, 0.22, 'dot');
      const c = new THREE.Color();
      animated.push((t) => {
        const k = (t * 0.4) % 1 * hues.length, i = Math.floor(k);
        c.copy(hues[i % hues.length]).lerp(hues[(i + 1) % hues.length], k - i); glow.material.color.copy(c);
        ring.material.rotation = -t * 0.2; ring.material.color.copy(hues[(i + 3) % hues.length]);
        // a short glitch flick now and then
        const g = Math.sin(t * 7.3) > 0.97 ? 0.06 : 0; pet.position.x = g; glow.position.x = -g * 2;
      });
    }
    if (rar.glowLeaves && mut.id === 'None') {
      const l = new THREE.PointLight(col(SPEC.palette.leaf), 1.5, 3); l.position.set(0, 4.0, -0.4); fx.add(l);
    }
    built = { rar, mut };
    const s = rar.scale; pet.scale.setScalar(s);
  }

  function rnd(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
  function gauss() { let u = 0; for (let i = 0; i < 3; i++) u += Math.random() * 2 - 1; return u; }

  function resize() {
    const w = canvas.clientWidth || canvas.width, h = canvas.clientHeight || canvas.height;
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
  }
  function frame(t) {
    state.t = t;
    for (const f of animated) f(t);
    const bob = opts.still ? 0 : Math.abs(Math.sin(t * 2.2)) * 0.12;
    pet.position.y = bob;
    const yaw = state.yaw + (state.spin && !opts.still ? Math.sin(t * 0.5) * 0.5 : 0);
    const d = 12.4, cy = 2.15;
    camera.position.set(Math.sin(yaw) * d, cy + 1.6, -Math.cos(yaw) * d);
    camera.lookAt(0, cy, 0);
    renderer.render(scene, camera);
  }
  let raf = 0, t0 = performance.now();
  function loop() { frame((performance.now() - t0) / 1000); raf = requestAnimationFrame(loop); }

  let drag = null;
  canvas.addEventListener('pointerdown', (e) => { drag = { x: e.clientX, yaw: state.yaw }; state.spin = false; canvas.setPointerCapture(e.pointerId); });
  canvas.addEventListener('pointermove', (e) => { if (drag) state.yaw = drag.yaw - (e.clientX - drag.x) * 0.01; });
  canvas.addEventListener('pointerup', () => { drag = null; });
  if (window.ResizeObserver) new ResizeObserver(resize).observe(canvas);

  resize(); build();
  if (!opts.capture) loop();
  return {
    set(k, v) { state[k] = v; if (k === 'rarity' || k === 'mutation') build(); },
    renderAt(t) { resize(); frame(t); return canvas.toDataURL('image/png'); },
    state,
  };
}
