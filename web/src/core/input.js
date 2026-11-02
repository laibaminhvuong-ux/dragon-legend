// Input: keyboard, mouse, gamepad and touch all feed the same named actions.
// Codes: keyboard = KeyboardEvent.code ("KeyW", "Space"), mouse = "Mouse0" (left) / "Mouse2"
// (right), gamepad = "Pad0".."Pad15" (standard mapping buttons).
// Touch controls live in ui/ and call setVirtual() / setVirtualAxis() / addLook().

/** Stable action ids. Labels are for the rebinding screen. */
export const ACTIONS = [
  { id: "jump", label: "Jump" },
  { id: "melee", label: "Melee attack" },
  { id: "block", label: "Block" },
  { id: "dash", label: "Dash" },
  { id: "flight", label: "Toggle flight" },
  { id: "ascend", label: "Fly up" },
  { id: "descend", label: "Fly down" },
  { id: "charge", label: "Charge ki" },
  { id: "kiBlast", label: "Ki blast" },
  { id: "beam", label: "Beam (hold to charge)" },
  { id: "transform", label: "Transform" },
  { id: "lockOn", label: "Lock on" },
  { id: "interact", label: "Talk / interact" },
  { id: "pause", label: "Pause menu" },
];
/** Axes: "move" {x: right+, y: forward+} and "look" (deltas, via takeLook()). */
export const MOVE_KEYS = { forward: ["KeyW", "ArrowUp"], back: ["KeyS", "ArrowDown"], left: ["KeyA", "ArrowLeft"], right: ["KeyD", "ArrowRight"] };

export const DEFAULT_BINDINGS = {
  jump: ["Space", "Pad0"],
  melee: ["Mouse0", "Pad2"],
  block: ["Mouse2", "Pad4"],
  dash: ["KeyQ", "Pad1"],
  flight: ["KeyF", "Pad3"],
  ascend: ["Space", "Pad0"],
  descend: ["ControlLeft", "Pad10"],
  charge: ["KeyC", "Pad6"],
  kiBlast: ["KeyE", "Pad5"],
  beam: ["KeyR", "Pad7"],
  transform: ["KeyT", "Pad12"],
  lockOn: ["Tab", "Pad11"],
  interact: ["KeyG", "Pad13"],
  pause: ["Escape", "Pad9"],
};

const DEADZONE = 0.18;
const dz = (v) => (Math.abs(v) < DEADZONE ? 0 : (v - Math.sign(v) * DEADZONE) / (1 - DEADZONE));

/**
 * @param target   element that owns mouse look (the game canvas)
 * @param settings app.settings (bindings, mouseSensitivity, invertY)
 * @param events   app.events (rebinds take effect on the "settings" event)
 */
export function createInput(target, settings, events = null) {
  const codesDown = new Set();
  const virtualDown = new Set();
  const virtualAxes = { move: { x: 0, y: 0 } };
  let actionsDown = new Set();
  const pressed = new Set();
  const released = new Set();
  const look = { x: 0, y: 0 };
  let padMove = { x: 0, y: 0 };
  let padLook = { x: 0, y: 0 };
  let lastDevice = "keyboard";
  let bindings = {};

  function rebuildBindings() {
    bindings = { ...DEFAULT_BINDINGS, ...(settings?.get("bindings") || {}) };
  }
  rebuildBindings();

  const isDown = (code) => codesDown.has(code);
  function recompute() {
    const now = new Set(virtualDown);
    for (const [action, codes] of Object.entries(bindings)) if (codes.some(isDown)) now.add(action);
    for (const a of now) if (!actionsDown.has(a)) pressed.add(a);
    for (const a of actionsDown) if (!now.has(a)) released.add(a);
    actionsDown = now;
  }

  // Keys the browser would otherwise act on (Tab focus, Space scroll, Ctrl shortcuts) while playing.
  const swallow = new Set(["Tab", "Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "ControlLeft"]);
  const typing = (e) => /^(INPUT|TEXTAREA|SELECT)$/.test(e.target?.tagName) || e.target?.isContentEditable;

  const onKeyDown = (e) => {
    if (typing(e)) return;
    if (input.pointerLockWanted && swallow.has(e.code)) e.preventDefault();
    lastDevice = "keyboard";
    codesDown.add(e.code);
    recompute();
  };
  const onKeyUp = (e) => {
    codesDown.delete(e.code);
    recompute();
  };
  const onMouseDown = (e) => {
    if (e.target !== target && document.pointerLockElement !== target) return;
    lastDevice = "keyboard";
    codesDown.add("Mouse" + e.button);
    recompute();
  };
  const onMouseUp = (e) => {
    codesDown.delete("Mouse" + e.button);
    recompute();
  };
  const onMouseMove = (e) => {
    if (document.pointerLockElement !== target) return;
    look.x += e.movementX * 0.0025;
    look.y += e.movementY * 0.0025;
  };
  const onBlur = () => {
    codesDown.clear();
    recompute();
  };
  const onClick = () => {
    if (input.pointerLockWanted && document.pointerLockElement !== target && !matchMedia("(pointer: coarse)").matches) {
      try { target.requestPointerLock()?.catch?.(() => {}); } catch { /* not allowed right now */ }
    }
  };

  addEventListener("keydown", onKeyDown);
  addEventListener("keyup", onKeyUp);
  addEventListener("mousedown", onMouseDown);
  addEventListener("mouseup", onMouseUp);
  addEventListener("mousemove", onMouseMove);
  addEventListener("blur", onBlur);
  target.addEventListener("click", onClick);
  target.addEventListener("contextmenu", (e) => e.preventDefault());
  events?.on("settings", ({ key }) => key === "bindings" && rebuildBindings());

  const input = {
    /** Set false in menus so clicking the canvas doesn't grab the mouse. */
    pointerLockWanted: true,

    /** Call once per frame before simulation steps (gamepad polling). */
    poll() {
      const pads = navigator.getGamepads ? navigator.getGamepads() : [];
      const pad = [...pads].find((p) => p && p.connected);
      for (let i = 0; i < 16; i++) codesDown.delete("Pad" + i);
      padMove = { x: 0, y: 0 };
      padLook = { x: 0, y: 0 };
      if (pad) {
        pad.buttons.forEach((b, i) => {
          if (b.pressed || b.value > 0.5) { codesDown.add("Pad" + i); lastDevice = "gamepad"; }
        });
        padMove = { x: dz(pad.axes[0] || 0), y: -dz(pad.axes[1] || 0) };
        padLook = { x: dz(pad.axes[2] || 0), y: dz(pad.axes[3] || 0) };
        if (padMove.x || padMove.y || padLook.x || padLook.y) lastDevice = "gamepad";
      }
      recompute();
    },

    /** Held right now. */
    down: (action) => actionsDown.has(action),
    /** Went down since the last endTick(). */
    pressed: (action) => pressed.has(action),
    /** Went up since the last endTick(). */
    released: (action) => released.has(action),
    /** Call after each simulation step that consumed pressed()/released(). */
    endTick() {
      pressed.clear();
      released.clear();
    },

    /** "move" axis: {x: right+, y: forward+}, length <= 1, from keys + stick + touch. */
    axis(name) {
      if (name !== "move") return { x: 0, y: 0 };
      const k = (codes) => (codes.some(isDown) ? 1 : 0);
      let x = k(MOVE_KEYS.right) - k(MOVE_KEYS.left) + padMove.x + virtualAxes.move.x;
      let y = k(MOVE_KEYS.forward) - k(MOVE_KEYS.back) + padMove.y + virtualAxes.move.y;
      const len = Math.hypot(x, y);
      if (len > 1) { x /= len; y /= len; }
      return { x, y };
    },

    /** Camera look deltas since the last call (radians-ish, sensitivity applied). Call once per frame. */
    takeLook(frameDt) {
      const sens = settings?.get("mouseSensitivity") ?? 1;
      const inv = settings?.get("invertY") ? -1 : 1;
      const out = { x: (look.x + padLook.x * 2.6 * frameDt) * sens, y: (look.y + padLook.y * 2.0 * frameDt) * sens * inv };
      look.x = 0;
      look.y = 0;
      return out;
    },

    // touch / on-screen controls (ui/) ------------------------------------------------------
    setVirtual(action, isDown) {
      lastDevice = "touch";
      if (isDown) virtualDown.add(action);
      else virtualDown.delete(action);
      recompute();
    },
    setVirtualAxis(name, x, y) {
      if (name !== "move") return;
      lastDevice = "touch";
      virtualAxes.move = { x, y };
    },
    /** Adds camera look from a touch drag (already in radians). */
    addLook(dx, dy) {
      lastDevice = "touch";
      look.x += dx;
      look.y += dy;
    },

    /** "keyboard" | "gamepad" | "touch": for button prompts. */
    get lastDevice() { return lastDevice; },
    /** Current bindings (defaults + overrides). */
    bindings: () => ({ ...bindings }),
    rebuildBindings,
  };
  return input;
}
