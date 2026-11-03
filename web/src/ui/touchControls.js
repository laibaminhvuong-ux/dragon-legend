// On-screen controls for touch devices: a left stick, a drag-anywhere look area and action buttons.
// Everything goes through input.setVirtual / setVirtualAxis / addLook, so gameplay sees the same
// actions as keyboard and gamepad. Touch code stays in ui/; core/input.js is untouched.
import { h } from "./dom.js";
import { STR } from "./strings.js";

const BUTTONS = [
  ["interact", "TALK", "hot"],
  ["beam", "SKILL", "hot"],
  ["ascend", "UP", ""],
  ["descend", "DOWN", ""],
  ["transform", "FORM", ""],
  ["kaioken", "KAIO", ""],
  ["lockOn", "LOCK", ""],
  ["melee", STR.touch.attack, "hot"],
  ["kiBlast", STR.touch.ki, "hot"],
  ["block", STR.touch.block, ""],
  ["jump", STR.touch.jump, ""],
  ["dash", STR.touch.dash, ""],
  ["flight", STR.touch.fly, ""],
  ["charge", STR.touch.charge, ""],
  ["pause", STR.touch.menu, "small"],
];

export function touchControls(app) {
  let offs = [];

  return {
    mount(el) {
      const layer = h("div", "touch");

      const look = h("div", "touch-look");
      const stick = h("div", "touch-stick");
      const knob = h("div", "touch-knob");
      stick.append(knob);

      const buttons = h("div", "touch-btns");
      const held = new Map();

      for (const [action, label, cls] of BUTTONS) {
        const b = h("button", "tbtn " + cls, label);
        b.type = "button";
        b.setAttribute("aria-label", label);
        b.addEventListener("pointerdown", (e) => {
          e.preventDefault();
          b.setPointerCapture?.(e.pointerId);
          b.classList.add("down");
          held.set(e.pointerId, action);
          app.input.setVirtual(action, true);
        });
        const release = (e) => {
          if (held.get(e.pointerId) !== action) return;
          held.delete(e.pointerId);
          b.classList.remove("down");
          app.input.setVirtual(action, false);
        };
        b.addEventListener("pointerup", release);
        b.addEventListener("pointercancel", release);
        b.addEventListener("lostpointercapture", release);
        buttons.append(b);
      }

      // left stick: pointer drag inside the base
      let stickId = null;
      const moveStick = (e) => {
        const r = stick.getBoundingClientRect();
        const max = r.width * 0.36;
        let dx = e.clientX - (r.left + r.width / 2);
        let dy = e.clientY - (r.top + r.height / 2);
        const dist = Math.hypot(dx, dy);
        if (dist > max) { dx = (dx / dist) * max; dy = (dy / dist) * max; }
        knob.style.transform = `translate(${dx}px, ${dy}px)`;
        app.input.setVirtualAxis("move", dx / max, -dy / max);
      };
      const onStickDown = (e) => {
        if (stickId !== null) return;
        e.preventDefault();
        stickId = e.pointerId;
        stick.setPointerCapture?.(e.pointerId);
        moveStick(e);
      };
      const onStickMove = (e) => { if (e.pointerId === stickId) moveStick(e); };
      const onStickUp = (e) => {
        if (e.pointerId !== stickId) return;
        stickId = null;
        knob.style.transform = "";
        app.input.setVirtualAxis("move", 0, 0);
      };
      stick.addEventListener("pointerdown", onStickDown);
      stick.addEventListener("pointermove", onStickMove);
      stick.addEventListener("pointerup", onStickUp);
      stick.addEventListener("pointercancel", onStickUp);

      // look: drag anywhere that isn't the stick or a button
      let lookId = null;
      let lx = 0;
      let ly = 0;
      const onLookDown = (e) => {
        if (lookId !== null) return;
        lookId = e.pointerId;
        lx = e.clientX;
        ly = e.clientY;
        look.setPointerCapture?.(e.pointerId);
      };
      const onLookMove = (e) => {
        if (e.pointerId !== lookId) return;
        app.input.addLook((e.clientX - lx) * 0.004, (e.clientY - ly) * 0.004);
        lx = e.clientX;
        ly = e.clientY;
      };
      const onLookUp = (e) => { if (e.pointerId === lookId) lookId = null; };
      look.addEventListener("pointerdown", onLookDown);
      look.addEventListener("pointermove", onLookMove);
      look.addEventListener("pointerup", onLookUp);
      look.addEventListener("pointercancel", onLookUp);

      layer.append(look, stick, buttons);
      el.append(layer);

      offs.push(() => {
        stick.removeEventListener("pointerdown", onStickDown);
        stick.removeEventListener("pointermove", onStickMove);
        stick.removeEventListener("pointerup", onStickUp);
        stick.removeEventListener("pointercancel", onStickUp);
        look.removeEventListener("pointerdown", onLookDown);
        look.removeEventListener("pointermove", onLookMove);
        look.removeEventListener("pointerup", onLookUp);
        look.removeEventListener("pointercancel", onLookUp);
      });
    },

    unmount() {
      for (const off of offs) off();
      offs = [];
      // never leave a virtual input stuck when the screen goes away
      app.input.setVirtualAxis("move", 0, 0);
      for (const [action] of BUTTONS) app.input.setVirtual(action, false);
    },
  };
}
