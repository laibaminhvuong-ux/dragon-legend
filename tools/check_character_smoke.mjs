// Browser gallery for the same character API used in play and the creator.
// PLAYWRIGHT_CORE=/path/to/playwright-core CHROMIUM=/path/to/chrome node tools/check_character_smoke.mjs
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const root = path.resolve(new URL('../web/', import.meta.url).pathname);
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM || path.join(os.homedir(), '.cache/ms-playwright/chromium-1140/chrome-linux/chrome'),
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  const errors = []; page.on('pageerror', e => errors.push(String(e)));
  // Serve with browser request interception: no localhost listener required.
  await page.route('http://gallery.test/**', async route => {
    const url = new URL(route.request().url());
    if (url.pathname === '/') return route.fulfill({ contentType: 'text/html', body: `
      <style>body { margin:0; background:#152035 } canvas { display:block }</style>
      <script type="importmap">{"imports":{"three":"/vendor/three/three.module.min.js"}}</script>
      <script type="module">
      import * as THREE from 'three';
      import { createCharacterModel } from '/src/character/index.js';
      import { defaultLook } from '/src/game/look.js';
      import { RACE_ORDER } from '/src/data/races.js';
      const renderer = new THREE.WebGLRenderer({ antialias: true });
      renderer.setSize(1440,900); document.body.append(renderer.domElement);
      const scene = new THREE.Scene(); scene.background = new THREE.Color(0x152035);
      scene.add(new THREE.HemisphereLight(0xffffff,0x6a7590,2));
      const light = new THREE.DirectionalLight(0xffedda,3); light.position.set(3,6,5); scene.add(light);
      const camera = new THREE.PerspectiveCamera(35,1440/900,.1,100);
      camera.position.set(4,4.5,10); camera.lookAt(0,1,0);
      const outfits = ['TurtleGi','CapsuleCorp','TurtleGi','NamekRobe','FrostArmor','MajinVest'];
      const models = RACE_ORDER.map((race,i) => {
        const m = createCharacterModel({...defaultLook(race), outfit:outfits[i]});
        m.object3d.position.set((i%3-1)*2,0,-Math.floor(i/3)*2.5);
        m.object3d.rotation.y = .15; scene.add(m.object3d); return m;
      });
      globalThis.gallery = { models, renderer, scene, camera };
      function frame() { for(const m of models) m.update(1/60,{onGround:true,speed:0}); renderer.render(scene,camera); requestAnimationFrame(frame); }
      frame();
      </script>` });
    const file = path.resolve(root, '.' + url.pathname);
    if (!file.startsWith(root + path.sep)) return route.abort();
    try { await route.fulfill({ body: await fs.readFile(file), contentType: 'text/javascript' }); }
    catch { await route.fulfill({ status: 404, body: 'Not found' }); }
  });
  await page.goto('http://gallery.test/');
  await page.waitForFunction(() => globalThis.gallery?.renderer.info.render.calls > 0);
  const calls = await page.evaluate(() => gallery.renderer.info.render.calls);
  assert.ok(calls > 20); assert.deepEqual(errors, []);
  const out = new URL('../out/', import.meta.url); await fs.mkdir(out, { recursive: true });
  await page.screenshot({ path: new URL('characters.png', out).pathname });
  await page.evaluate(() => { for (const m of gallery.models) m.dispose(); });
  assert.equal(await page.evaluate(() => gallery.scene.children.filter(o => o.name === 'fighter').length), 0);
  console.log(`character browser smoke passed: six races, ${calls} draw calls; out/characters.png`);
} finally { await browser.close(); }
