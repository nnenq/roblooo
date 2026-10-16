import { chromium } from 'playwright';
import fs from 'fs';
const [,, url, outDir, list] = process.argv;
fs.mkdirSync(outDir, { recursive: true });
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] }); // software WebGL, works headless
const page = await browser.newPage({ viewport: { width: 900, height: 900 } });
page.on('console', m => console.log('console:', m.type(), m.text()));
page.on('pageerror', e => console.log('pageerror:', e.message));
await page.goto(url);
await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
for (const item of list.split(',')) {
  const [rarity, mutation, yaw, t] = item.split(':');
  const data = await page.evaluate(([r, m, y, t]) => { v.set('rarity', r); v.set('mutation', m); v.state.yaw = +y; return v.renderAt(+t); }, [rarity, mutation, yaw || '-0.5', t || '1.3']);
  fs.writeFileSync(`${outDir}/${rarity}-${mutation}-${yaw||'d'}.png`, Buffer.from(data.split(',')[1], 'base64'));
}
await browser.close();
