// Music: plays the original soundtrack in data/music.js live with Web Audio (synthesized drums,
// bass, distorted guitar, brass lead, pads, arps), or the player's own files listed in
// web/assets/music/tracks.json. Crossfades between tracks. Volume follows settings
// (masterVolume x musicVolume).
//
//   const music = createMusic(settings, events)
//   music.play(trackIdOrZoneId)      e.g. "menu", "namek", "battle"
//   music.stop()
//   music.current                    what is playing ({ id, name, kind: "built-in" | "file" })
import { TRACKS, DRUMS, ZONE_MUSIC } from "../data/music.js";

const DEGREES = { I: 0, bII: 1, II: 2, bIII: 3, III: 4, IV: 5, "#IV": 6, bV: 6, V: 7, bVI: 8, VI: 9, bVII: 10, VII: 11 };
const NOTE = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
const midiHz = (m) => 440 * Math.pow(2, (m - 69) / 12);

/** "bVI" -> { root offset, minor } relative to the key. */
function chord(sym, key, majorKey) {
  // lower-case numerals are minor chords ("i", "iv", "ii"), upper-case major ("I", "bVI", "V")
  const minor = /^[b#]?[iv]+$/.test(sym);
  const off = DEGREES[sym.replace(/[iv]+/, (m) => m.toUpperCase())] ?? 0;
  return { root: key + off, minor };
}
const triad = (c) => [0, c.minor ? 3 : 4, 7].map((i) => c.root + i);

function parseMelody(str) {
  const out = [];
  for (const tok of (str || "").split(/\s+/)) {
    if (!tok || tok === "|") continue;
    const [n, s] = tok.split(":");
    const steps = Number(s) || 4;
    if (n === "r") { out.push({ midi: null, steps }); continue; }
    const m = n.match(/^([A-G])([#b]?)(-?\d)$/);
    if (!m) continue;
    out.push({ midi: 12 * (Number(m[3]) + 1) + NOTE[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0), steps });
  }
  return out;
}

export function createMusic(settings, events = null) {
  let ctx = null, master = null, comp = null, reverb = null, noise = null;
  let current = null; // { id, bus, stop() }
  let wanted = null;
  let fileTracks = {};
  // the player's own music (optional)
  fetch("assets/music/tracks.json").then((r) => (r.ok ? r.json() : {})).then((j) => (fileTracks = j || {})).catch(() => {}).finally(() => wanted && api.play(wanted, true));

  function volume() {
    return (settings?.get("masterVolume") ?? 0.8) * (settings?.get("musicVolume") ?? 0.6);
  }

  function init() {
    if (ctx) return true;
    const AC = globalThis.AudioContext || globalThis.webkitAudioContext;
    if (!AC) return false;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = volume();
    comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -16; comp.ratio.value = 3.5; comp.attack.value = 0.01; comp.release.value = 0.2;
    comp.connect(master);
    master.connect(ctx.destination);
    // a hall reverb from decaying noise
    reverb = ctx.createConvolver();
    const len = ctx.sampleRate * 2.4, ir = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let ch = 0; ch < 2; ch++) { const d = ir.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6); }
    reverb.buffer = ir;
    const rv = ctx.createGain(); rv.gain.value = 0.22;
    reverb.connect(rv); rv.connect(comp);
    noise = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
    const nd = noise.getChannelData(0);
    for (let i = 0; i < nd.length; i++) nd[i] = Math.random() * 2 - 1;
    return true;
  }

  // browsers only start audio after the player touches something
  const unlock = () => { if (init() && ctx.state !== "running") ctx.resume().then(() => wanted && !current && api.play(wanted, true)); };
  for (const ev of ["pointerdown", "keydown", "touchstart"]) addEventListener(ev, unlock, { passive: true });
  events?.on("settings", ({ key }) => {
    if ((key === "masterVolume" || key === "musicVolume") && master) master.gain.setTargetAtTime(volume(), ctx.currentTime, 0.1);
  });

  // ---------------------------------------------------------------- instruments
  function env(g, t, a, peak, d, sus, rel, end) {
    g.gain.setValueAtTime(0.0001, t);
    g.gain.linearRampToValueAtTime(peak, t + a);
    g.gain.setTargetAtTime(peak * sus, t + a, d);
    g.gain.setTargetAtTime(0.0001, end, rel);
  }
  function osc(type, hz, t, end, dest, detune = 0) {
    const o = ctx.createOscillator();
    o.type = type; o.frequency.value = hz; o.detune.value = detune;
    o.connect(dest); o.start(t); o.stop(end + 1.2);
    return o;
  }
  function noiseSrc(t, dur, dest) {
    const s = ctx.createBufferSource();
    s.buffer = noise; s.connect(dest); s.start(t, Math.random() * 0.5); s.stop(t + dur);
    return s;
  }
  let distCurve = null;
  function dist() {
    if (!distCurve) {
      distCurve = new Float32Array(1024);
      for (let i = 0; i < 1024; i++) { const x = (i / 1023) * 2 - 1; distCurve[i] = ((3 + 40) * x * 20 * (Math.PI / 180)) / (Math.PI + 40 * Math.abs(x)); }
    }
    const w = ctx.createWaveShaper(); w.curve = distCurve; w.oversample = "2x";
    return w;
  }

  const I = {
    kick(t, bus, v = 1) {
      const g = ctx.createGain(); g.connect(bus);
      const o = ctx.createOscillator(); o.type = "sine";
      o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.12);
      o.connect(g); o.start(t); o.stop(t + 0.4);
      g.gain.setValueAtTime(0.9 * v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.35);
    },
    snare(t, bus, v = 1) {
      const g = ctx.createGain(); g.connect(bus); g.connect(reverb);
      const f = ctx.createBiquadFilter(); f.type = "bandpass"; f.frequency.value = 1800; f.Q.value = 0.7; f.connect(g);
      noiseSrc(t, 0.25, f);
      const o = ctx.createOscillator(); o.type = "triangle"; o.frequency.setValueAtTime(220, t); o.frequency.exponentialRampToValueAtTime(140, t + 0.08);
      const og = ctx.createGain(); og.gain.setValueAtTime(0.35 * v, t); og.gain.exponentialRampToValueAtTime(0.001, t + 0.12); o.connect(og); og.connect(bus); o.start(t); o.stop(t + 0.2);
      g.gain.setValueAtTime(0.55 * v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.2);
    },
    hat(t, bus, open = false) {
      const g = ctx.createGain(); g.connect(bus);
      const f = ctx.createBiquadFilter(); f.type = "highpass"; f.frequency.value = 7500; f.connect(g);
      noiseSrc(t, open ? 0.35 : 0.06, f);
      g.gain.setValueAtTime(open ? 0.16 : 0.1, t); g.gain.exponentialRampToValueAtTime(0.001, t + (open ? 0.3 : 0.05));
    },
    crash(t, bus) {
      const g = ctx.createGain(); g.connect(bus); g.connect(reverb);
      const f = ctx.createBiquadFilter(); f.type = "highpass"; f.frequency.value = 4500; f.connect(g);
      noiseSrc(t, 1.6, f);
      g.gain.setValueAtTime(0.22, t); g.gain.exponentialRampToValueAtTime(0.001, t + 1.5);
    },
    bass(t, dur, midi, bus) {
      const g = ctx.createGain(); g.connect(bus);
      const f = ctx.createBiquadFilter(); f.type = "lowpass"; f.Q.value = 6;
      f.frequency.setValueAtTime(1400, t); f.frequency.setTargetAtTime(380, t, 0.06); f.connect(g);
      osc("sawtooth", midiHz(midi), t, t + dur, f);
      osc("sine", midiHz(midi - 12), t, t + dur, g);
      env(g, t, 0.005, 0.32, 0.12, 0.7, 0.05, t + dur);
    },
    guitar(t, dur, root, bus, { mute = false, swell = false } = {}) {
      const g = ctx.createGain();
      const d = dist(); const f = ctx.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = mute ? 1100 : 3200;
      d.connect(f); f.connect(g); g.connect(bus); g.connect(reverb);
      const pre = ctx.createGain(); pre.gain.value = 1.6; pre.connect(d);
      for (const [iv, det] of [[0, -6], [7, 5], [12, 0]]) osc("sawtooth", midiHz(root + iv), t, t + dur, pre, det);
      const peak = mute ? 0.11 : 0.13;
      if (swell) env(g, t, dur * 0.5, peak, 0.3, 0.8, 0.2, t + dur);
      else env(g, t, 0.004, peak, mute ? 0.05 : 0.4, mute ? 0.15 : 0.75, 0.06, t + (mute ? Math.min(dur, 0.12) : dur));
    },
    lead(t, dur, midi, bus) {
      const g = ctx.createGain(); g.connect(bus); g.connect(reverb);
      const f = ctx.createBiquadFilter(); f.type = "lowpass"; f.Q.value = 2;
      f.frequency.setValueAtTime(900, t); f.frequency.linearRampToValueAtTime(3400, t + 0.08); f.frequency.setTargetAtTime(2200, t + 0.1, 0.2);
      f.connect(g);
      const vib = ctx.createOscillator(); vib.frequency.value = 5.5;
      const vg = ctx.createGain(); vg.gain.setValueAtTime(0, t); vg.gain.linearRampToValueAtTime(dur > 0.3 ? 9 : 0, t + 0.25); vib.connect(vg); vib.start(t); vib.stop(t + dur + 0.5);
      for (const det of [-7, 7]) { const o = osc("sawtooth", midiHz(midi), t, t + dur, f, det); vg.connect(o.detune); }
      osc("square", midiHz(midi - 12), t, t + dur, f, 0).detune.value = 3;
      env(g, t, 0.03, 0.085, 0.2, 0.85, 0.08, t + dur * 0.95);
    },
    pad(t, dur, notes, bus, choir = false) {
      const g = ctx.createGain(); g.connect(bus); g.connect(reverb);
      const f = ctx.createBiquadFilter(); f.type = "lowpass"; f.frequency.value = choir ? 1400 : 2200; f.connect(g);
      for (const n of notes) for (const det of [-9, 9]) osc(choir ? "triangle" : "sawtooth", midiHz(n), t, t + dur, f, det);
      env(g, t, dur * 0.25, choir ? 0.06 : 0.04, 0.5, 0.9, 0.4, t + dur);
    },
    pluck(t, midi, bus, kind) {
      const g = ctx.createGain(); g.connect(bus); g.connect(reverb);
      osc(kind === "bells" ? "sine" : "triangle", midiHz(midi), t, t + 0.6, g);
      if (kind === "bells") osc("sine", midiHz(midi) * 2.76, t, t + 0.3, g);
      g.gain.setValueAtTime(kind === "bells" ? 0.09 : 0.08, t); g.gain.exponentialRampToValueAtTime(0.001, t + (kind === "piano" ? 0.9 : 0.5));
    },
  };

  // ---------------------------------------------------------------- the sequencer
  function startBuiltIn(id) {
    const T = TRACKS[id];
    const major = T.mode === "major";
    const bus = ctx.createGain(); bus.gain.value = 0.0001; bus.connect(comp);
    bus.gain.setTargetAtTime(1, ctx.currentTime, 0.6);
    const stepDur = 60 / T.bpm / 4;
    const sections = T.order.map((name) => ({ name, ...T.sections[name], melody: parseMelody(T.sections[name].lead) }));
    let si = 0, bar = 0, step = 0, next = ctx.currentTime + 0.1, melodyPos = 0, melodyStep = 0;
    function scheduleStep(t) {
      const S = sections[si];
      const c = chord(S.chords[bar % S.chords.length], T.key, major);
      const D = DRUMS[S.drums] || DRUMS.none;
      if (D.K[step] === "x") I.kick(t, bus);
      if (D.S[step] === "x") I.snare(t, bus, S.drums === "fill" && step > 8 ? 0.5 + (step - 8) / 14 : 1);
      if (D.h[step] === "x") I.hat(t, bus);
      if (D.o[step] === "x") I.hat(t, bus, true);
      if (step === 0 && bar === 0 && S.drums !== "none") I.crash(t, bus);
      // bass
      const r = c.root - 12;
      const b = S.bass;
      if (b === "whole" && step === 0) I.bass(t, stepDur * 15, r, bus);
      if (b === "eighths" && step % 2 === 0) I.bass(t, stepDur * 1.6, r, bus);
      if (b === "gallop" && [0, 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15].includes(step)) I.bass(t, stepDur * 0.9, r, bus);
      if (b === "octaves" && step % 2 === 0) I.bass(t, stepDur * 1.6, r + (step % 4 === 2 ? 12 : 0), bus);
      if (b === "bounce" && step % 4 === 0) I.bass(t, stepDur * 3, r + [0, 7, 12, 7][step / 4], bus);
      // guitar
      const g = S.guitar, gr = c.root - 12 < 40 ? c.root : c.root - 12;
      if (g === "power" && (step === 0 || step === 8)) I.guitar(t, stepDur * 7.5, gr, bus);
      if (g === "chug" && step % 2 === 0) I.guitar(t, stepDur * 1.5, gr, bus, { mute: true });
      if (g === "stabs" && [0, 3, 6, 10].includes(step)) I.guitar(t, stepDur * 1.8, gr, bus);
      if (g === "swells" && step === 0) I.guitar(t, stepDur * 16, gr, bus, { swell: true });
      // pads
      if (S.pad && step === 0) I.pad(t, stepDur * 16, triad(c).map((n) => n + 12), bus, S.pad === "choir");
      // arps
      if (S.arp) {
        const tri = triad(c), seq = [...tri.map((n) => n + 24), ...tri.map((n) => n + 36)];
        if (S.arp === "up") I.pluck(t, seq[step % 6], bus, "arp");
        if (S.arp === "updown") I.pluck(t, [...seq, ...seq.slice(1, 5).reverse()][step % 10], bus, "arp");
        if (S.arp === "bells" && step % 2 === 0) I.pluck(t, seq[(step / 2) % 6], bus, "bells");
        if (S.arp === "piano" && step % 4 === 0) I.pluck(t, tri[(step / 4) % 3] + 24, bus, "piano");
      }
      // lead melody (loops to fill the section)
      if (S.melody.length) {
        if (melodyStep === 0) {
          const n = S.melody[melodyPos % S.melody.length];
          if (n.midi !== null) I.lead(t, n.steps * stepDur * 0.95, n.midi, bus);
          melodyStep = n.steps;
          melodyPos++;
        }
        melodyStep--;
      }
    }
    function advance() {
      step++;
      if (step >= 16) {
        step = 0; bar++;
        if (bar >= sections[si].bars) { bar = 0; si = (si + 1) % sections.length; melodyPos = 0; melodyStep = 0; }
      }
    }
    const timer = setInterval(() => {
      if (ctx.state !== "running") return;
      if (next < ctx.currentTime - 0.5) next = ctx.currentTime + 0.05; // after a stall, don't machine-gun the backlog
      while (next < ctx.currentTime + 0.18) { scheduleStep(next); advance(); next += stepDur; }
    }, 25);
    return {
      id, name: T.name, kind: "built-in",
      stop() {
        clearInterval(timer);
        bus.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.5);
        setTimeout(() => bus.disconnect(), 2500);
      },
    };
  }

  function startFile(id, url) {
    const el = new Audio(url);
    el.loop = true;
    el.crossOrigin = "anonymous";
    const src = ctx.createMediaElementSource(el);
    const bus = ctx.createGain(); bus.gain.value = 0.0001;
    src.connect(bus); bus.connect(comp);
    bus.gain.setTargetAtTime(1, ctx.currentTime, 0.6);
    el.play().catch(() => {});
    return {
      id, name: url.split("/").pop(), kind: "file",
      stop() { bus.gain.setTargetAtTime(0.0001, ctx.currentTime, 0.5); setTimeout(() => { el.pause(); bus.disconnect(); }, 2500); },
    };
  }

  /** Resolves what to play for a world or mood: the player's file if listed, else a built-in track. */
  function resolve(id) {
    const zones = fileTracks.zones || {}, moods = fileTracks.moods || {};
    const mood = TRACKS[id] ? id : ZONE_MUSIC[id] || "hero";
    const file = zones[id] || (id === "menu" && fileTracks.menu) || moods[mood];
    if (file) return { key: "file:" + file, file: "assets/music/" + file };
    return { key: "track:" + mood, track: mood };
  }

  const api = {
    get current() { return current && { id: current.id, name: current.name, kind: current.kind }; },
    play(id, force = false) {
      wanted = id;
      if (!init() || ctx.state !== "running") return; // starts on the first click/key press
      const r = resolve(id);
      if (!force && current && current.key === r.key) return;
      current?.stop();
      current = r.file ? startFile(id, r.file) : startBuiltIn(r.track);
      current.key = r.key;
      events?.emit("music", { id, name: current.name });
    },
    stop() { wanted = null; current?.stop(); current = null; },
  };
  return api;
}
