// NPC voices. Every character speaks their lines with a voice of their own: the system's speech voices
// (Windows has several), picked and tuned from who they are (female, child, giant or boss, race) plus a
// pitch/speed offset unique to their name, so no two characters sound alike. Where no speech voices exist,
// characters "babble" instead: short synthesized syllables in their own pitch and timbre.
//   const voice = createVoice(settings)
//   voice.say(speakerName, text)   speak a line (stops the previous one)
//   voice.stop()
import { CHARACTERS } from "../data/story.js";

/** Name -> who they are, for picking a voice. */
const WHO = new Map();
for (const c of Object.values(CHARACTERS)) {
  if (!WHO.has(c.name)) WHO.set(c.name, { female: !!c.look?.female, scale: c.scale || 1, race: c.look?.race || "Human", build: c.look?.build });
}
const FEMALE_HINTS = /zira|hazel|susan|eva|catherine|linda|heera|female|woman|aria|jenny|michelle|sonia|libby|natasha|clara|emma|samantha|victoria|karen|moira|tessa|fiona/i;

function hash(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0) / 4294967295; }

/** A voice profile for a speaker: { female, pitch, rate, timbre }. */
export function voiceProfile(name) {
  const w = WHO.get(name) || { female: false, scale: 1, race: "Human" };
  if (name === "You") return { female: false, pitch: 1, rate: 1.02, timbre: 0.5, key: name };
  const h = hash(name), h2 = hash(name + "#");
  let pitch = w.female ? 1.25 : 0.95, rate = 1;
  if (w.scale < 0.75) pitch += 0.45, rate += 0.08;            // children and small folk
  if (w.scale > 1.3) pitch -= 0.35, rate -= 0.12;             // giants and brutes
  if (w.build === "Muscular") pitch -= 0.08;
  if (w.race === "FrostDemon") pitch += 0.12, rate -= 0.06;   // cold, precise
  if (w.race === "Majin") pitch += 0.18, rate += 0.05;
  if (w.race === "Namekian") pitch -= 0.1, rate -= 0.04;
  pitch += (h - 0.5) * 0.36;                                   // everyone a little different
  rate += (h2 - 0.5) * 0.2;
  return { female: w.female, pitch: Math.max(0.1, Math.min(2, pitch)), rate: Math.max(0.6, Math.min(1.4, rate)), timbre: h2, key: name };
}

export function createVoice(settings) {
  const synth = typeof speechSynthesis !== "undefined" ? speechSynthesis : null;
  let voices = [];
  const load = () => {
    if (!synth) return;
    const all = synth.getVoices();
    const en = all.filter((v) => /^en/i.test(v.lang));
    voices = en.length ? en : all;
  };
  load();
  synth?.addEventListener?.("voiceschanged", load);
  let ctx = null, babble = null;
  const volume = () => (settings?.get("masterVolume") ?? 0.8) * (settings?.get("voiceVolume") ?? 0.9);

  /** Pick a system voice for a profile: by gender where the names tell us, then spread by name. */
  function pick(p) {
    if (!voices.length) return null;
    const fem = voices.filter((v) => FEMALE_HINTS.test(v.name)), male = voices.filter((v) => !FEMALE_HINTS.test(v.name));
    const pool = (p.female ? fem : male).length ? (p.female ? fem : male) : voices;
    return pool[Math.floor(hash(p.key + "voice") * pool.length) % pool.length];
  }

  function stopBabble() { babble?.forEach((n) => { try { n.stop(); } catch {} }); babble = null; }
  /** Fallback: syllable blips shaped like the line, in the speaker's own pitch and timbre. */
  function sayBabble(p, text) {
    try { ctx ||= new AudioContext(); } catch { return; }
    if (ctx.state === "suspended") ctx.resume();
    stopBabble();
    const base = 110 * Math.pow(2, (p.pitch - 0.6) * 1.6) * (p.female ? 1.6 : 1);
    const syl = Math.min(40, Math.max(3, Math.round(text.replace(/[^a-z]/gi, "").length / 3)));
    const gain = ctx.createGain(); gain.gain.value = 0.18 * volume(); gain.connect(ctx.destination);
    const nodes = [];
    let t = ctx.currentTime + 0.02;
    for (let i = 0; i < syl; i++) {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = p.timbre < 0.33 ? "triangle" : p.timbre < 0.66 ? "square" : "sawtooth";
      const f = base * (1 + 0.18 * Math.sin(i * 1.7 + p.timbre * 9) + (i === syl - 1 && text.trim().endsWith("?") ? 0.25 : 0));
      o.frequency.setValueAtTime(f, t);
      const len = 0.075 / p.rate;
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(p.timbre < 0.66 ? 0.5 : 0.3, t + 0.01); g.gain.linearRampToValueAtTime(0, t + len);
      o.connect(g).connect(gain); o.start(t); o.stop(t + len + 0.02); nodes.push(o);
      t += len + 0.03 / p.rate;
    }
    babble = nodes;
  }

  return {
    say(name, text) {
      if (!text || volume() <= 0) return;
      const p = voiceProfile(name);
      const line = text.replace(/\*/g, "").replace(/\.\.\./g, ", ");
      const v = synth && pick(p);
      if (!v) return sayBabble(p, line);
      synth.cancel();
      const u = new SpeechSynthesisUtterance(line);
      u.voice = v; u.pitch = p.pitch; u.rate = p.rate; u.volume = Math.min(1, volume());
      synth.speak(u);
    },
    stop() { synth?.cancel(); stopBabble(); },
    profile: voiceProfile,
  };
}
