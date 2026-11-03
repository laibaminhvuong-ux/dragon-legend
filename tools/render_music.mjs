// Renders the game's original soundtrack (web/src/audio/music.js + data/music.js) to loopable WAV files for the
// Godot version, using the exact same synth code on an OfflineAudioContext in headless Chromium.
// Each track's section order is rendered twice and the second pass is kept, so reverb tails and releases wrap
// into the start and the file loops seamlessly. Mono 22.05 kHz 16-bit; Godot imports them with QOA compression.
//   PLAYWRIGHT_CORE=/path/to/playwright-core [CHROMIUM=/path/to/chrome] node tools/render_music.mjs
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_CORE || 'playwright-core');
const root = path.resolve(new URL('../web/', import.meta.url).pathname);
const out = path.resolve(new URL('../godot/assets/music/', import.meta.url).pathname);
const RATE = 22050;
await fs.mkdir(out, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || path.join(os.homedir(), '.cache/ms-playwright/chromium-1140/chrome-linux/chrome') });
try {
  const page = await browser.newPage();
  const errors = []; page.on('pageerror', (e) => errors.push(String(e)));
  await page.route('http://music.test/**', async (route) => {
    const url = new URL(route.request().url());
    if (url.pathname === '/') return route.fulfill({ contentType: 'text/html', body: '<html><body>music</body></html>' });
    const file = path.join(root, url.pathname);
    try { return route.fulfill({ body: await fs.readFile(file), contentType: file.endsWith('.js') ? 'text/javascript' : file.endsWith('.json') ? 'application/json' : 'application/octet-stream' }); }
    catch { return route.fulfill({ status: 404, body: 'nf' }); }
  });
  await page.goto('http://music.test/');
  const ids = await page.evaluate(async () => Object.keys((await import('/src/data/music.js')).TRACKS));
  for (const id of ids) {
    const pcm = await page.evaluate(async ({ id, RATE }) => {
      const { TRACKS } = await import('/src/data/music.js');
      const T = TRACKS[id];
      const stepDur = 60 / T.bpm / 4;
      const loop = T.order.reduce((n, s) => n + T.sections[s].bars, 0) * 16 * stepDur;
      const total = loop * 2 + 0.5;
      // A fake real-time context: the synth schedules against a clock we advance by hand.
      let now = 0;
      class Fake extends OfflineAudioContext {
        constructor() { super(1, Math.ceil(total * RATE), RATE); Fake.last = this; }
        get currentTime() { return now; }
        get state() { return 'running'; }
        resume() { return Promise.resolve(); }
      }
      globalThis.AudioContext = Fake;
      let tick = null;
      const realSetInterval = globalThis.setInterval;
      globalThis.setInterval = (fn) => { tick = fn; return 1; };
      globalThis.fetch = () => Promise.reject(new Error('offline'));
      const { createMusic } = await import('/src/audio/music.js?' + id);
      const music = createMusic({ get: () => 1 }, null);
      music.play(id, true);
      globalThis.setInterval = realSetInterval;
      for (now = 0; now < total - 0.2; now += 0.05) tick();
      const buf = await Fake.last.startRendering();
      const data = buf.getChannelData(0);
      const a = Math.round(loop * RATE), n = Math.round(loop * RATE);
      let peak = 1e-6;
      for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(data[a + i]));
      const gain = 0.89 / peak;
      const pcm16 = new Int16Array(n);
      // the last samples fade into the end of the first pass, which runs straight into this pass's start: no click at the loop
      const K = 1024;
      for (let i = 0; i < n; i++) {
        const w = i >= n - K ? (i - (n - K)) / K : 0;
        const v = data[a + i] * (1 - w) + data[a + i - n] * w;
        pcm16[i] = Math.max(-32767, Math.min(32767, Math.round(v * gain * 32767)));
      }
      let bin = '';
      const bytes = new Uint8Array(pcm16.buffer);
      for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
      return { b64: btoa(bin), seconds: loop, name: T.name };
    }, { id, RATE }).catch((e) => String(e));
    if (typeof pcm === 'string') { console.log(id, 'failed:', pcm); continue; }
    const raw = Buffer.from(pcm.b64, 'base64');
    const head = Buffer.alloc(44);
    head.write('RIFF', 0); head.writeUInt32LE(36 + raw.length, 4); head.write('WAVE', 8); head.write('fmt ', 12);
    head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(1, 22); head.writeUInt32LE(RATE, 24);
    head.writeUInt32LE(RATE * 2, 28); head.writeUInt16LE(2, 32); head.writeUInt16LE(16, 34); head.write('data', 36); head.writeUInt32LE(raw.length, 40);
    await fs.writeFile(path.join(out, id + '.wav'), Buffer.concat([head, raw]));
    console.log(`${id}: "${pcm.name}" ${pcm.seconds.toFixed(1)} s, ${(raw.length / 1e6).toFixed(1)} MB`);
  }
  if (errors.length) console.log('page errors:', errors.join('\n'));
} finally { await browser.close(); }
