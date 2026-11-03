// The Dragon Radar: a round green scope that shows the Dragon Orbs still to find. It appears whenever an orb
// hunt is active and turns with the camera, so "up" is the way you're looking. Orbs out of range sit on the rim
// as arrows. Below it: the distance to the nearest orb here, and how many wait in other worlds.
//   const radar = createDragonRadar(app);  radar.update(story, playerPos, cameraYaw, frameDt)  ·  radar.toggle()
import { formatKey } from "./strings.js";

const RANGE = 160;  // metres from the centre to the rim
const SIZE = 168;   // CSS pixels

export function createDragonRadar(app) {
  const el = document.createElement("div");
  el.className = "dragon-radar";
  el.hidden = true;
  el.innerHTML = `<canvas width="${SIZE * 2}" height="${SIZE * 2}"></canvas><div class="dr-read"></div>`;
  document.body.appendChild(el);
  const canvas = el.querySelector("canvas"), read = el.querySelector(".dr-read");
  const g = canvas.getContext("2d");
  let on = true, t = 0, redraw = 0, lastText = "";

  function draw(here, pos, yaw) {
    const S = SIZE * 2, c = S / 2, R = c - 10;
    g.clearRect(0, 0, S, S);
    // body: a dark-green glass disc with a grid, like the classic radar
    const bg = g.createRadialGradient(c, c, R * 0.1, c, c, R);
    bg.addColorStop(0, "#1f6b3a"); bg.addColorStop(1, "#0b2e19");
    g.fillStyle = bg; g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.fill();
    g.strokeStyle = "rgba(160,255,190,0.28)"; g.lineWidth = 2;
    for (let k = -3; k <= 3; k++) {
      const o = (k / 4) * R;
      const h = Math.sqrt(Math.max(0, R * R - o * o));
      g.beginPath(); g.moveTo(c + o, c - h); g.lineTo(c + o, c + h); g.stroke();
      g.beginPath(); g.moveTo(c - h, c + o); g.lineTo(c + h, c + o); g.stroke();
    }
    g.strokeStyle = "#cfd6dc"; g.lineWidth = 6; g.beginPath(); g.arc(c, c, R + 2, 0, Math.PI * 2); g.stroke();
    // sweep
    const a = t * 2.2;
    const sw = g.createConicGradient ? g.createConicGradient(a, c, c) : null;
    if (sw) { sw.addColorStop(0, "rgba(140,255,170,0.35)"); sw.addColorStop(0.12, "rgba(140,255,170,0)"); sw.addColorStop(1, "rgba(140,255,170,0)"); g.fillStyle = sw; g.beginPath(); g.arc(c, c, R, 0, Math.PI * 2); g.fill(); }
    // you: a small arrow pointing up (the camera's forward)
    g.fillStyle = "#e9fff0"; g.beginPath(); g.moveTo(c, c - 12); g.lineTo(c - 8, c + 8); g.lineTo(c, c + 3); g.lineTo(c + 8, c + 8); g.closePath(); g.fill();
    // orbs: world offset rotated into camera space (forward = up)
    const fx = Math.sin(yaw), fz = Math.cos(yaw);  // camera forward on the ground
    const blink = 0.55 + 0.45 * Math.sin(t * 6);
    for (const o of here) {
      const dx = o.x - pos.x, dz = o.z - pos.z;
      const fwd = dx * fx + dz * fz, right = dx * -fz + dz * fx;
      let px = right / RANGE * R, py = -fwd / RANGE * R;
      const d = Math.hypot(px, py), edge = d > R - 12;
      if (edge) { px *= (R - 12) / d; py *= (R - 12) / d; }
      g.save(); g.translate(c + px, c + py);
      if (edge) { // an arrow on the rim towards it
        g.rotate(Math.atan2(py, px));
        g.fillStyle = `rgba(255,200,40,${0.6 + 0.4 * blink})`;
        g.beginPath(); g.moveTo(10, 0); g.lineTo(-6, -7); g.lineTo(-6, 7); g.closePath(); g.fill();
      } else {
        g.shadowColor = "#ffb000"; g.shadowBlur = 18 * blink;
        g.fillStyle = "#ffcc33"; g.beginPath(); g.arc(0, 0, 9, 0, Math.PI * 2); g.fill();
        g.shadowBlur = 0; g.fillStyle = "#fff6c8"; g.beginPath(); g.arc(-2.5, -2.5, 3, 0, Math.PI * 2); g.fill();
      }
      g.restore();
    }
  }

  return {
    toggle() { on = !on; app.events?.emit("notify", { text: on ? "Dragon Radar on" : "Dragon Radar off" }); },
    get on() { return on; },
    update(story, pos, yaw, frameDt) {
      const r = story?.radar?.();
      const active = !!r && (r.here.length || r.elsewhere.length);
      el.hidden = !active || !on || app.paused || app.dialogueOpen;
      if (el.hidden) return;
      t += frameDt;
      if ((redraw += frameDt) < 1 / 30) return;  // 30 fps is plenty for a radar
      redraw = 0;
      draw(r.here, pos, yaw);
      const near = r.here.reduce((m, o) => Math.min(m, Math.hypot(o.x - pos.x, o.z - pos.z)), Infinity);
      const parts = [];
      if (r.here.length) parts.push(`${r.here.length} here · nearest ${Math.round(near)} m`);
      for (const e of r.elsewhere) parts.push(`${e.count} on ${e.name}`);
      const text = `<b>Dragon Radar</b> <span>${formatKey(app.input.bindings().radar?.[0])}</span><br>${parts.join("<br>")}`;
      if (text !== lastText) { read.innerHTML = text; lastText = text; }
    },
    hide() { el.hidden = true; },
    dispose() { el.remove(); },
  };
}
