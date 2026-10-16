// Renders preview screenshots of the generated island with three.js in headless Chromium.
// It is only a rough look at layout and colours; Roblox Studio is the real renderer.
//
//   PW_MODULE=$(npm root -g)/playwright THREE_DIR=node_modules/three/build \
//     node tools/preview/render.mjs scene.json docs/img

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PW_MODULE || 'playwright');
const [scenePath, outDir] = process.argv.slice(2);
const threeDir = process.env.THREE_DIR;

const VIEWS = [
  { name: 'overview', pos: [430, 340, 540], look: [0, 0, -30], fov: 50 },
  { name: 'plaza', pos: [0, 40, 108], look: [0, 9, 0], fov: 55 },
  { name: 'volcano', pos: [80, 52, -175], look: [0, 24, -272], fov: 55 },
  { name: 'gate', pos: [-78, 24, 88], look: [-138, 6, 150], fov: 55 },
  { name: 'index', pos: [0, 14, 8], look: [0, 9, 37], fov: 60 },
  { name: 'glitch', pos: [225, 75, -150], look: [300, 38, -300], fov: 55 },
];

const page = `<!doctype html><html><body style="margin:0;background:#9fdcff">
<script type="module">
import * as THREE from '/three.module.js';
const parts = await (await fetch('/scene.json')).json();
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(1600, 900);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.05;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.background = new THREE.Color('#a7defc');
scene.fog = new THREE.Fog('#ffe1f2', 700, 1700);
scene.add(new THREE.HemisphereLight('#e6f6ff', '#b9a6e8', 1.25));
const sun = new THREE.DirectionalLight('#ffffff', 2.3);
sun.position.set(320, 520, 260);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
Object.assign(sun.shadow.camera, { left: -560, right: 560, top: 560, bottom: -560, near: 10, far: 1600 });
sun.shadow.bias = -0.0005;
scene.add(sun);

const wedge = (() => {
  const v = [[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]];
  const f = [[0,2,1],[0,3,2],[3,5,2],[3,4,5],[0,1,5],[0,5,4],[0,4,3],[1,2,5]];
  const pos = [];
  for (const t of f) for (const i of t) pos.push(...v[i]);
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals();
  return g;
})();
const geos = {
  block: new THREE.BoxGeometry(1, 1, 1),
  ellipsoid: new THREE.SphereGeometry(0.5, 28, 18),
  ball: new THREE.SphereGeometry(0.5, 28, 18),
  cyl: new THREE.CylinderGeometry(0.5, 0.5, 1, 48).rotateZ(Math.PI / 2),
  wedge,
};
for (const p of parts) {
  const color = new THREE.Color().setRGB(p.col[0], p.col[1], p.col[2], THREE.SRGBColorSpace);
  const mat = new THREE.MeshStandardMaterial({
    color, roughness: 0.55, metalness: 0,
    transparent: p.t > 0, opacity: 1 - p.t, depthWrite: p.t < 0.5,
    emissive: p.n ? color : new THREE.Color(0), emissiveIntensity: p.n ? 0.85 : 0,
    side: p.k === 'wedge' ? THREE.DoubleSide : THREE.FrontSide,
  });
  const mesh = new THREE.Mesh(geos[p.k], mat);
  let [sx, sy, sz] = p.s;
  if (p.k === 'ball') { const d = Math.min(sx, sy, sz); sx = sy = sz = d; }
  if (p.k === 'cyl') { const d = Math.min(sy, sz); sy = sz = d; }
  const c = p.c;
  const m = new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
  m.multiply(new THREE.Matrix4().makeScale(sx, sy, sz));
  mesh.matrixAutoUpdate = false;
  mesh.matrix.copy(m);
  mesh.castShadow = p.t < 0.5 && Math.max(sx, sy, sz) < 300;
  mesh.receiveShadow = true;
  scene.add(mesh);
}
const camera = new THREE.PerspectiveCamera(50, 16 / 9, 0.5, 4000);
window.renderView = (v) => {
  camera.fov = v.fov;
  camera.position.set(...v.pos);
  camera.lookAt(...v.look);
  camera.updateProjectionMatrix();
  renderer.render(scene, camera);
  return true;
};
window.ready = true;
</script></body></html>`;

const server = http.createServer((req, res) => {
  if (req.url === '/three.module.js') {
    res.writeHead(200, { 'content-type': 'text/javascript' });
    return res.end(fs.readFileSync(path.join(threeDir, 'three.module.js')));
  }
  if (req.url === '/scene.json') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(fs.readFileSync(scenePath));
  }
  res.writeHead(200, { 'content-type': 'text/html' });
  res.end(page);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/`;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const tab = await browser.newPage({ viewport: { width: 1600, height: 900 } });
tab.on('console', (m) => console.log('page:', m.text()));
tab.on('pageerror', (e) => console.log('page error:', e.message));
await tab.goto(url);
await tab.waitForFunction(() => window.ready === true, null, { timeout: 120000 });
fs.mkdirSync(outDir, { recursive: true });
for (const v of VIEWS) {
  await tab.evaluate((view) => window.renderView(view), v);
  const file = path.join(outDir, `preview-${v.name}.png`);
  await tab.locator('canvas').screenshot({ path: file });
  console.log('wrote', file);
}
await browser.close();
server.close();
