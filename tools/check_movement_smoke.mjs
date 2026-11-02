// Browser integration: walk, ascend, hover, dash, land and charge through the real input/loop.
// node tools/check_movement_smoke.mjs [web|dist/site]
// Uses the same PLAYWRIGHT_CORE, CHROMIUM and library environment as check_smoke.mjs.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import { serve } from "./serve.mjs";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const folder = path.resolve(root, process.argv[2] || "web");
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_CORE || "playwright-core");
const executablePath = process.env.CHROMIUM || path.join(os.homedir(), ".cache/ms-playwright/chromium-1140/chrome-linux/chrome");

const port = 5198;
const server = await serve(port, folder);
const browser = await chromium.launch({ executablePath, args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

  // menu first
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForFunction(() => globalThis.__dragonlegend?.scenes.name === "menu");
  assert.equal(await page.locator(".screen-slotSelect").count(), 1, "slot select shown");

  // ?dev goes straight into play with a default Saiyan
  await page.goto(`http://127.0.0.1:${port}/?dev`);
  await page.waitForFunction(() => globalThis.__dragonlegend?.scenes.name === "play" && globalThis.__dragonlegend.loop.stats.frames > 10, null, { timeout: 90000 });
  const start = await page.evaluate(() => ({ ...globalThis.__dragonlegend.game.player.pos }));
  await page.keyboard.down("KeyW");
  await page.waitForFunction(s => {
    const p = globalThis.__dragonlegend.game.player.pos;
    return Math.hypot(p.x-s.x,p.z-s.z)>2;
  }, start, {timeout:90000});
  await page.keyboard.up("KeyW");
  const after = await page.evaluate(() => ({ ...globalThis.__dragonlegend.game.player.pos }));
  const moved = Math.hypot(after.x - start.x, after.z - start.z);
  assert.ok(moved > 2, `player moved ${moved.toFixed(2)} m`);

  const info = await page.evaluate(() => {
    const a = globalThis.__dragonlegend;
    const r = a.gfx.renderer.info.render;
    return { hud: a.game.hud(), calls: r.calls, triangles: r.triangles, fps: a.loop.stats.fps };
  });
  assert.ok(info.calls > 3 && info.triangles > 1000, `scene draws (${info.calls} calls, ${info.triangles} tris)`);
  assert.equal(info.hud.level, 1);
  fs.mkdirSync(path.join(root, "out"), { recursive: true });
  await page.screenshot({ path: path.join(root, "out", "smoke.png") });

  // Drive the same virtual actions used by touch controls through the real fixed-step loop.
  await page.evaluate(() => {
    const a = globalThis.__dragonlegend;
    a.input.setVirtual('flight', true); a.input.setVirtual('ascend', true);
  });
  await page.waitForFunction(() => globalThis.__dragonlegend.game.player.flying);
  await page.evaluate(() => globalThis.__dragonlegend.input.setVirtual('flight', false));
  page.setDefaultTimeout(90000);
  const altitude = await page.evaluate(() => globalThis.__dragonlegend.game.player.pos.y);
  await page.waitForFunction(y => globalThis.__dragonlegend.game.player.pos.y > y + 3, altitude);
  await page.evaluate(() => globalThis.__dragonlegend.input.setVirtual('ascend', false));
  const hover = await page.evaluate(() => globalThis.__dragonlegend.game.player.pos.y);
  await page.waitForTimeout(250);
  assert.equal(await page.evaluate(() => globalThis.__dragonlegend.game.player.pos.y), hover);
  await page.evaluate(() => globalThis.__dragonlegend.input.setVirtual('dash', true));
  await page.waitForFunction(() => globalThis.__dragonlegend.game.player.dashing);
  await page.evaluate(() => {
    const a = globalThis.__dragonlegend;
    a.input.setVirtual('dash', false); a.input.setVirtual('descend', true);
  });
  await page.waitForFunction(() => globalThis.__dragonlegend.game.player.onGround);
  await page.evaluate(() => {
    const a = globalThis.__dragonlegend;
    a.input.setVirtual('descend', false); a.input.setVirtual('charge', true);
  });
  await page.waitForFunction(() => globalThis.__dragonlegend.game.player.charging);
  await page.screenshot({ path: path.join(root, 'out', 'movement-charge.png') });
  await page.evaluate(() => globalThis.__dragonlegend.input.setVirtual('charge', false));
  await page.waitForFunction(() => !globalThis.__dragonlegend.game.player.charging);
  assert.deepEqual(errors, [], 'no page errors');
  console.log('movement smoke ok: walk, flight, ascent, hover, dash, landing, charge and rendering');
} finally {
  await browser.close();
  server.close();
  if (errors.length) console.error("page errors:\n" + errors.join("\n"));
}
