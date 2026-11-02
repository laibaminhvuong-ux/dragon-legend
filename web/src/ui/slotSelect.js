// Menu screen: the three character slots. Reads app.save.listSlots(), sends intents only
// (createSlot/deleteSlot/startGame). Redraws on the "slots" event.
import { h, btn } from "./dom.js";
import { STR, formatDuration, formatWhen } from "./strings.js";
import { saveCodePanel } from "./saveCode.js";

export function slotSelect(app) {
  let root = null;
  let offSlots = null;
  let confirming = -1;
  let codesOpen = false;

  function draw() {
    if (!root) return;
    root.replaceChildren();

    const menu = h("div", "menu");
    const head = h("header", "menu-head");
    head.append(h("h1", "menu-title", STR.title), h("p", "menu-tagline", STR.tagline));
    menu.append(head);

    const row = h("div", "slot-row");
    app.save.listSlots().forEach((slot, i) => row.append(card(slot, i)));
    menu.append(row);

    const foot = h("footer", "menu-foot");
    foot.append(
      btn(STR.menu.saveCodes, () => { codesOpen = !codesOpen; draw(); }, "ghost small"),
      h("span", "menu-version", STR.menu.version(app.version)),
    );
    menu.append(foot);
    menu.append(h("p", "menu-hint", STR.menu.controlsHint));

    if (!app.save.persistent) menu.append(h("p", "menu-warn", STR.menu.privateWindow));
    if (codesOpen) {
      const panel = saveCodePanel(app, { onImported: () => { confirming = -1; draw(); } });
      panel.classList.add("menu-code");
      menu.append(panel);
    }
    root.append(menu);
  }

  function card(slot, index) {
    const el = h("div", "slot" + (slot ? "" : " slot-empty") + (app.save.lastSlot() === index ? " slot-last" : ""));
    el.append(h("div", "slot-num", STR.slot.label(index + 1)));

    if (!slot) {
      el.append(h("div", "slot-race", STR.slot.empty));
      el.append(h("div", "slot-meta", "—"));
      el.append(btn(STR.slot.create, () => app.ui.show("creator", { slotIndex: index }), "primary wide"));
      return el;
    }

    el.append(h("div", "slot-race", slot.raceName));
    el.append(h("div", "slot-meta", STR.slot.level(slot.level)));
    el.append(h("div", "slot-meta", STR.slot.played(formatDuration(slot.playTime))));
    el.append(h("div", "slot-meta dim", STR.slot.lastPlayed(formatWhen(slot.playedAt))));

    const actions = h("div", "slot-actions");
    if (confirming === index) {
      actions.append(h("div", "slot-confirm", STR.slot.confirmDelete));
      actions.append(btn(STR.slot.delete, () => {
        confirming = -1;
        const result = app.save.deleteSlot(index);
        if (result.ok) draw();
      }, "danger"));
      actions.append(btn(STR.common.cancel, () => { confirming = -1; draw(); }, "ghost"));
    } else {
      actions.append(btn(STR.slot.play, () => app.startGame(index), "primary"));
      actions.append(btn(STR.slot.delete, () => { confirming = index; draw(); }, "ghost"));
    }
    el.append(actions);
    return el;
  }

  return {
    mount(el) {
      root = el;
      confirming = -1;
      codesOpen = false;
      draw();
      offSlots = app.events.on("slots", () => draw());
    },
    unmount() {
      if (offSlots) offSlots();
      offSlots = null;
      root = null;
    },
  };
}
