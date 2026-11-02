// The tutorial panel: the current step's instruction with the player's own key names, progress, and a
// Skip button (usable whenever the mouse is free, e.g. after Esc).
import { formatKey } from "./strings.js";

export function createTutorialPanel(app) {
  const el = document.createElement("div");
  el.className = "tutorial";
  el.hidden = true;
  el.innerHTML = `<div class="tut-head"><span class="tut-title">Tutorial</span><span class="tut-count"></span><button type="button" class="tut-skip">Skip tutorial</button></div><div class="tut-text"></div>`;
  document.body.appendChild(el);
  const count = el.querySelector(".tut-count"), text = el.querySelector(".tut-text");
  let tut = null, shown = -1, flashUntil = 0;
  el.querySelector(".tut-skip").addEventListener("click", () => { tut?.skip(); app.saveNow?.(); panel.update(); });
  const keys = () => {
    const b = app.input.bindings(), k = {};
    for (const [a, codes] of Object.entries(b)) k[a] = formatKey(codes?.[0]);
    return k;
  };
  const panel = {
    attach(t) { tut = t; shown = -1; panel.update(); },
    detach() { tut = null; el.hidden = true; },
    /** Call when a step completes: a short "done" flash before the next one. */
    flash() { flashUntil = performance.now() + 900; el.classList.add("tut-done"); },
    update() {
      if (!tut || !tut.active) { el.hidden = true; return; }
      el.hidden = !!app.dialogueOpen; // menus and dialogue go on top; the pause screen covers it
      if (performance.now() > flashUntil) el.classList.remove("tut-done");
      if (shown !== tut.index) {
        shown = tut.index;
        count.textContent = `${tut.index + 1} / ${tut.total}`;
        text.textContent = tut.step.text(keys());
      }
    },
    dispose() { el.remove(); },
  };
  return panel;
}
