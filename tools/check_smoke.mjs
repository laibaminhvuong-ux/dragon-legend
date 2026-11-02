// Headless-browser smoke check: boots the game, makes sure it renders with no errors, walks the
// player forward, pauses, saves and goes back to the menu. Saves a screenshot to out/smoke.png.
//   node tools/check_smoke.mjs [folder]     folder = web (default, dev files) or dist/site (the build)
// Needs playwright-core and a Chromium:
//   PLAYWRIGHT_CORE=/path/to/node_modules/playwright-core  CHROMIUM=/path/to/chrome
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

const port = 5199;
const server = await serve(port, folder);
const browser = await chromium.launch({ executablePath, args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

  // menu first
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.waitForFunction(() => globalThis.__dragonball?.scenes.name === "menu");
  assert.equal(await page.locator(".screen-slotSelect").count(), 1, "slot select shown");

  // ?dev goes straight into play with a default Saiyan
  await page.goto(`http://127.0.0.1:${port}/?dev`);
  await page.waitForFunction(() => globalThis.__dragonball?.scenes.name === "play" && globalThis.__dragonball.loop.stats.frames > 30, null, { timeout: 30000 });
  const start = await page.evaluate(() => ({ ...globalThis.__dragonball.game.player.pos }));
  await page.keyboard.down("KeyW");
  await page.waitForTimeout(1500);
  await page.keyboard.up("KeyW");
  const after = await page.evaluate(() => ({ ...globalThis.__dragonball.game.player.pos }));
  const moved = Math.hypot(after.x - start.x, after.z - start.z);
  assert.ok(moved > 2, `player moved ${moved.toFixed(2)} m`);

  const info = await page.evaluate(() => {
    const a = globalThis.__dragonball;
    const r = a.gfx.renderer.info.render;
    return { hud: a.game.hud(), calls: r.calls, triangles: r.triangles, fps: a.loop.stats.fps };
  });
  assert.ok(info.calls > 3 && info.triangles > 1000, `scene draws (${info.calls} calls, ${info.triangles} tris)`);
  assert.equal(info.hud.level, 1);
  fs.mkdirSync(path.join(root, "out"), { recursive: true });
  await page.screenshot({ path: path.join(root, "out", "smoke.png") });

  // pause -> save -> menu
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => globalThis.__dragonball.paused);
  await page.evaluate(() => globalThis.__dragonball.quitToMenu());
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem("dragonball.profile")).slots[0].position);
  assert.ok(saved && Math.abs(saved.z - after.z) < 0.5, "position saved");
  assert.deepEqual(errors, [], "no page errors");
  console.log(`smoke ok (${folder}): moved ${moved.toFixed(1)} m, ${info.calls} draw calls, ${info.triangles} triangles, ${info.fps} fps (software GL)`);
} finally {
  await browser.close();
  server.close();
  if (errors.length) console.error("page errors:\n" + errors.join("\n"));
}
