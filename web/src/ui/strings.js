import { renameDeep } from "../data/names.js";
// Every player-facing string in the UI. Screens stay layout-only and read text from here.
// Keep this in a separate file so a later translation pass touches one place.

export const STR = {
  title: "Dragon Legend",
  tagline: "Create a fighter, then take on the story.",

  common: {
    cancel: "Cancel",
    back: "Back",
    close: "Close",
  },

  slot: {
    label: (n) => `Slot ${n}`,
    empty: "Empty slot",
    create: "Create fighter",
    play: "Play",
    delete: "Delete",
    confirmDelete: "Delete this fighter for good?",
    level: (level) => `Level ${level}`,
    played: (time) => `Played ${time}`,
    lastPlayed: (when) => `Last played ${when}`,
  },

  menu: {
    saveCodes: "Save codes",
    controlsHint: "WASD move · mouse look · Space jump · Esc pause",
    version: (v) => `v${v}`,
    privateWindow: "This window doesn't keep saves. Export a save code to keep your fighters.",
    slotTaken: "That slot is taken",
  },

  creator: {
    title: "Create a fighter",
    slot: (n) => `Slot ${n}`,
    race: "Race",
    body: "Build",
    skin: "Skin",
    face: "Face",
    hair: "Hair",
    hairColor: "Hair colour",
    outfit: "Outfit",
    outfitColor: "Outfit colour",
    randomize: "Randomize",
    create: "Create",
    pickRaceFirst: "Pick a race",
    colour: (n) => `Colour ${n}`,
  },

  hud: {
    level: (n) => `Lv ${n}`,
    health: (hp, max) => `HP ${Math.ceil(hp)} / ${max}`,
    ki: (ki, max) => `Ki ${Math.floor(ki)} / ${max}`,
    xp: (xp, next) => `XP ${Math.floor(xp)} / ${next}`,
    power: (pl) => `PL ${pl}`,
    zeni: (n) => `${n} zeni`,
    statPoints: (n) => `${n} stat point${n === 1 ? "" : "s"} · Esc`,
    fps: (n) => `${n} fps`,
    offline: "Offline",
  },

  pause: {
    title: "Paused",
    resume: "Resume",
    saveAndQuit: "Save and quit",
    tabs: { game: "Fighter", settings: "Settings", controls: "Controls", codes: "Save code" },
    race: "Race",
    level: "Level",
    power: "Power level",
    zeni: "Zeni",
    playTime: "Played",
    points: (n) => (n === 0 ? "No stat points to spend. Level up to earn more." : `${n} point${n === 1 ? "" : "s"} to spend`),
    statNames: { Health: "Health", Ki: "Ki", Strength: "Strength", KiPower: "Ki Power", Speed: "Speed" },
    statHint: "Each point is permanent. Health and Ki raise your maximums; the rest raise damage and speed.",
    quality: "Graphics",
    qualityOptions: { low: "Low", medium: "Medium", high: "High" },
    qualityHint: "Antialiasing changes apply after a restart.",
    master: "Master volume",
    music: "Music",
    sfx: "Effects",
    sensitivity: "Mouse sensitivity",
    invertY: "Invert look",
    showFps: "Show FPS",
    resetSettings: "Reset settings",
    resetControls: "Reset controls",
    controlsHint: "Pick an action, then press the key you want. Escape cancels.",
    pressKey: "Press a key…",
    change: "Change",
    settingsSaved: "Settings saved.",
    controlsSaved: "Controls saved.",
  },

  saveCode: {
    button: "Save codes",
    title: "Save codes",
    help: "A save code carries all three fighters. Copy it somewhere safe, or paste one in to restore.",
    placeholder: "Paste a save code here…",
    export: "Show my code",
    copy: "Copy",
    import: "Import",
    importConfirm: "Import anyway",
    importWarning: "Importing replaces all three slots. Click again to confirm.",
    exported: "Code ready. Copy it somewhere safe.",
    copied: "Copied to the clipboard.",
    selectToCopy: "Press Ctrl+C / ⌘C to copy the selected code.",
    imported: "Save restored.",
  },

  touch: {
    attack: "ATK",
    ki: "KI",
    block: "BLK",
    jump: "JMP",
    dash: "DASH",
    fly: "FLY",
    charge: "CHG",
    menu: "MENU",
  },
};

const KEY_NAMES = {
  Space: "Space",
  Escape: "Esc",
  Tab: "Tab",
  Enter: "Enter",
  Backspace: "Backspace",
  CapsLock: "Caps",
  ShiftLeft: "L Shift",
  ShiftRight: "R Shift",
  ControlLeft: "L Ctrl",
  ControlRight: "R Ctrl",
  AltLeft: "L Alt",
  AltRight: "R Alt",
  MetaLeft: "L Meta",
  MetaRight: "R Meta",
  Semicolon: ";",
  Quote: "'",
  Comma: ",",
  Period: ".",
  Slash: "/",
  Backslash: "\\",
  BracketLeft: "[",
  BracketRight: "]",
  Minus: "-",
  Equal: "=",
  Backquote: "`",
};

const MOUSE_NAMES = { Mouse0: "Left click", Mouse1: "Middle click", Mouse2: "Right click" };

/** "KeyW" -> "W", "Mouse2" -> "Right click", "Pad5" -> "Pad 5". */
export function formatKey(code) {
  if (!code) return "—";
  if (MOUSE_NAMES[code]) return MOUSE_NAMES[code];
  if (code.startsWith("Pad")) return `Pad ${code.slice(3)}`;
  if (/^Key[A-Z]$/.test(code)) return code.slice(3);
  if (/^Digit\d$/.test(code)) return code.slice(5);
  const arrows = { ArrowUp: "↑", ArrowDown: "↓", ArrowLeft: "←", ArrowRight: "→" };
  if (arrows[code]) return arrows[code];
  return KEY_NAMES[code] || code;
}

/** Seconds -> "2h 05m", "12m" or "8s". */
export function formatDuration(seconds) {
  const s = Math.max(0, Math.round(seconds || 0));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h) return `${h}h ${String(m).padStart(2, "0")}m`;
  if (m) return `${m}m`;
  return `${s}s`;
}

/** Timestamp -> short local date. */
export function formatWhen(ts) {
  const d = new Date(ts || Date.now());
  return d.toLocaleDateString(undefined, { day: "numeric", month: "short" });
}

// player-facing names are the game's own (data/names.js)
renameDeep(STR);
