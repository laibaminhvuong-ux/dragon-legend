// Plays a boss cutscene: letterbox bars, the speaker's name and line (typed out), and a camera that frames
// whoever is talking over the other fighter's shoulder. The game is frozen while it plays.
//   const cs = createCutscenePlayer(app)
//   cs.play(scene, { actor(speaker) -> {x,y,z,scale} | null, other(speaker) -> {x,y,z,scale} }, onEnd)
//   cs.active · cs.input(input) once per step · cs.camera(camera, frameDt) every frame after the follow camera
// Controls: Space / Interact / click = next line (or finish typing), Esc = skip the scene.
import * as THREE from "three";
import { formatKey } from "./strings.js";

const CPS = 55; // typed characters per second

export function createCutscenePlayer(app) {
  let scene = null, i = 0, typed = 0, ctx = null, onEnd = null, cut = true;
  const camPos = new THREE.Vector3(), camLook = new THREE.Vector3();
  const el = document.createElement("div");
  el.className = "cutscene";
  el.hidden = true;
  el.innerHTML = `<div class="cs-bar cs-top"></div><div class="cs-bar cs-bottom"><div class="cs-who"></div><div class="cs-line"></div><div class="cs-hint"></div></div>`;
  document.body.appendChild(el);
  const who = el.querySelector(".cs-who"), line = el.querySelector(".cs-line"), hint = el.querySelector(".cs-hint");
  el.addEventListener("click", () => cs.active && next());

  function show() {
    const l = scene.lines[i];
    who.textContent = l.name;
    app.voice?.say(l.name, l.text);
    who.classList.toggle("cs-you", l.speaker === "you");
    typed = 0; line.textContent = "";
    const b = app.input.bindings();
    hint.textContent = `${formatKey(b.jump?.[0])} / click: next · ${formatKey(b.pause?.[0])}: skip · ${i + 1} / ${scene.lines.length}`;
    cut = true;
  }
  function next() {
    const text = scene.lines[i].text;
    if (typed < text.length) { typed = text.length; line.textContent = text; return; }
    if (++i >= scene.lines.length) return end();
    show();
  }
  function end() {
    const done = onEnd;
    scene = null; ctx = null; onEnd = null;
    el.hidden = true;
    app.voice?.stop();
    document.body.classList.remove("in-cutscene");
    done?.();
  }

  const cs = {
    get active() { return !!scene; },
    play(s, context, finished = null) {
      if (!s?.lines?.length) return finished?.();
      scene = s; ctx = context; onEnd = finished; i = 0;
      el.hidden = false;
      el.dataset.kind = s.kind;
      document.body.classList.add("in-cutscene");
      show();
    },
    input(input) {
      if (!scene) return;
      if (input.pressed("pause")) return end();
      if (input.pressed("jump") || input.pressed("interact")) next(); // mouse clicks come through the overlay
    },
    skip() { if (scene) end(); },
    /** Override the camera for this frame. */
    camera(camera, frameDt) {
      if (!scene) return;
      const text = scene.lines[i].text;
      if (typed < text.length) { typed = Math.min(text.length, typed + frameDt * CPS); line.textContent = text.slice(0, Math.floor(typed)); }
      const l = scene.lines[i];
      const S = ctx.actor(l.speaker), O = ctx.other(l.speaker);
      if (!S || !O) return;
      const head = (a) => new THREE.Vector3(a.x, a.y + 1.55 * (a.scale || 1), a.z);
      const s = head(S), o = head(O);
      const d = new THREE.Vector3(s.x - o.x, 0, s.z - o.z);
      if (d.lengthSq() < 0.01) d.set(0, 0, 1);
      d.normalize();
      const side = new THREE.Vector3(-d.z, 0, d.x);
      const big = Math.max(S.scale || 1, 1);
      // over the listener's shoulder, a little to the side and above, looking at the speaker's face
      const want = o.clone().addScaledVector(d, -2.2 - big * 0.6).addScaledVector(side, 1.1).add(new THREE.Vector3(0, 0.35 + big * 0.25, 0));
      const look = s.clone().add(new THREE.Vector3(0, -0.1 * big, 0));
      if (cut) { camPos.copy(want); camLook.copy(look); cut = false; }
      else { const k = 1 - Math.exp(-frameDt * 2.5); camPos.lerp(want, k); camLook.lerp(look, k); }
      camera.position.copy(camPos);
      camera.lookAt(camLook);
    },
    dispose() { el.remove(); },
  };
  return cs;
}
