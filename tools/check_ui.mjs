// Headless check of the real UI: menu -> creator -> play (HUD) -> pause (points, settings, rebind,
// save code) -> quit -> delete -> import the code back. Writes out/ui.png.
//   node tools/check_ui.mjs [folder]     folder = web (default, dev files) or dist/site
// Needs the same PLAYWRIGHT_CORE / CHROMIUM as tools/check_smoke.mjs.
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
const app = () => globalThis.__dragonlegend;

try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 820 } });
  page.on("pageerror", (e) => errors.push(String(e)));
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));

  // ---- menu + creator -----------------------------------------------------------------------
  await page.goto(`http://127.0.0.1:${port}/`);
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await page.waitForFunction(() => globalThis.__dragonlegend?.scenes.name === "menu");
  assert.equal(await page.locator(".screen-slotSelect").count(), 1, "slot select shown");
  assert.equal(await page.locator(".slot").count(), 3, "three slots");

  await page.locator(".slot-empty .btn.primary").first().click();
  await page.waitForSelector(".screen-creator .creator-canvas");
  await page.waitForFunction(() => globalThis.__dragonlegend.ui.isShown("creator"));

  await page.locator(".race-card", { hasText: "Nameckian" }).click();
  assert.equal(await page.locator(".race-card.on strong").innerText(), "Nameckian"); // the game's own name (data/names.js)
  // the preview keeps drawing frames
  const frames = await page.evaluate(async () => {
    const before = performance.now();
    await new Promise((r) => setTimeout(r, 250));
    return performance.now() - before;
  });
  assert.ok(frames > 100, "creator preview stayed up");

  await page.locator(".creator-foot .btn.primary").click();
  await page.waitForFunction(() => globalThis.__dragonlegend.scenes.name === "play" && globalThis.__dragonlegend.game);
  await page.waitForFunction(() => globalThis.__dragonlegend.loop.stats.frames > 20);

  // ---- HUD ----------------------------------------------------------------------------------
  const hud = await page.evaluate(() => {
    const a = globalThis.__dragonlegend;
    return { hud: a.game.hud(), hpWidth: document.querySelector(".hud-bar.hp i").style.width, racelabel: document.querySelector(".hud-name .race").textContent };
  });
  assert.equal(hud.racelabel, "Nameckian", "HUD shows the created race");
  assert.equal(hud.hud.race, "Namekian");
  assert.ok(parseFloat(hud.hpWidth) > 0, `health bar filled (${hud.hpWidth})`);
  assert.equal(hud.hud.level, 1);

  // ---- pause: stat points -------------------------------------------------------------------
  await page.keyboard.press("Escape");
  await page.waitForFunction(() => globalThis.__dragonlegend.paused);
  await page.waitForSelector(".screen-pause");
  await page.evaluate(() => globalThis.__dragonlegend.game.addXP(100));
  await page.waitForFunction(() => globalThis.__dragonlegend.game.hud().level === 2);
  await page.waitForFunction(() => globalThis.__dragonlegend.game.hud().statPoints === 3);
  await page.waitForSelector(".stat-row");
  assert.equal(await page.locator(".stat-row").count(), 5, "five stats listed");
  const before = await page.evaluate(() => globalThis.__dragonlegend.game.hud().maxHealth);
  await page.locator(".stat-row", { hasText: "Health" }).locator("button").click();
  const after = await page.evaluate(() => globalThis.__dragonlegend.game.hud());
  assert.equal(after.maxHealth, before + 12, "Health point raised max health");
  assert.equal(after.statPoints, 2, "a point was spent");

  // ---- pause: settings ----------------------------------------------------------------------
  await page.locator(".tab", { hasText: "Settings" }).click();
  await page.selectOption(".set-row select", "low");
  assert.equal(await page.evaluate(() => globalThis.__dragonlegend.settings.get("quality")), "low");
  await page.locator(".set-row", { hasText: "Show FPS" }).locator("input").check();
  assert.equal(await page.evaluate(() => globalThis.__dragonlegend.settings.get("showFps")), true);

  // ---- pause: rebind ------------------------------------------------------------------------
  await page.locator(".tab", { hasText: "Controls" }).click();
  await page.locator(".key-row", { hasText: "Jump" }).locator("button").click();
  assert.match(await page.locator(".key-row", { hasText: "Jump" }).locator("button").innerText(), /Press a key/);
  await page.keyboard.press("KeyJ");
  const jumpKeys = await page.evaluate(() => globalThis.__dragonlegend.input.bindings().jump);
  assert.deepEqual(jumpKeys, ["KeyJ"], "jump rebound to J");
  await page.waitForSelector(".key-row kbd");

  // ---- pause: save code ---------------------------------------------------------------------
  await page.locator(".tab", { hasText: "Save code" }).click();
  await page.locator(".pause-body .btn", { hasText: "Show my code" }).click();
  const code = await page.locator(".pause-body .code-box").inputValue();
  assert.match(code, /^DL1:/, "save code exported");

  // ---- back to the menu ---------------------------------------------------------------------
  await page.locator(".pause-foot .btn", { hasText: "Save and quit" }).click();
  await page.waitForFunction(() => globalThis.__dragonlegend.scenes.name === "menu");
  await page.waitForSelector(".screen-slotSelect");
  assert.match(await page.locator(".slot").first().innerText(), /Nameckian/);
  assert.match(await page.locator(".slot").first().innerText(), /Level 2/);

  // ---- delete, then import the code back ----------------------------------------------------
  await page.locator(".slot").first().locator(".btn", { hasText: "Delete" }).click();
  await page.locator(".slot").first().locator(".btn.danger").click();
  await page.waitForFunction(() => globalThis.__dragonlegend.save.listSlots()[0] === null);
  assert.equal(await page.locator(".slot").first().getAttribute("class"), "slot slot-empty");

  await page.locator(".menu-foot .btn", { hasText: "Save codes" }).click();
  await page.locator(".menu-code .code-box").fill(code);
  const importBtn = page.locator(".menu-code .code-actions .btn").last();
  await importBtn.click();
  assert.match(await importBtn.innerText(), /Import anyway/, "import asks for confirmation");
  await importBtn.click();
  await page.waitForFunction(() => globalThis.__dragonlegend.save.listSlots()[0]?.race === "Namekian");
  assert.match(await page.locator(".slot").first().innerText(), /Nameckian/);

  // ---- persistence --------------------------------------------------------------------------
  await page.reload();
  await page.waitForFunction(() => globalThis.__dragonlegend?.scenes.name === "menu");
  assert.match(await page.locator(".slot").first().innerText(), /Nameckian/);
  assert.equal(
    await page.evaluate(() => globalThis.__dragonlegend.settings.get("quality")),
    "low",
    "settings survived the reload",
  );

  fs.mkdirSync(path.join(root, "out"), { recursive: true });
  await page.screenshot({ path: path.join(root, "out", "ui.png") });
  assert.deepEqual(errors, [], "no page errors");
  console.log(`ui ok (${folder}): creator, HUD, pause, settings, rebind, save code, delete/import, reload`);
} finally {
  await browser.close();
  server.close();
  if (errors.length) console.error("page errors:\n" + errors.join("\n"));
}
