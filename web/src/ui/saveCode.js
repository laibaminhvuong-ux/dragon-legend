// Save code panel: export the whole profile as one text code, or paste one in.
// Used by the menu (slot select) and by the pause screen. Only talks to app.save.
import { h, btn } from "./dom.js";
import { STR } from "./strings.js";

/**
 * @param app             the shared app object
 * @param onImported      called after a successful import (the slot list changed)
 */
export function saveCodePanel(app, { onImported = null } = {}) {
  const wrap = h("div", "code-panel");
  wrap.append(h("h2", "code-title", STR.saveCode.title), h("p", "note", STR.saveCode.help));

  const box = h("textarea", "code-box");
  box.spellcheck = false;
  box.placeholder = STR.saveCode.placeholder;
  box.setAttribute("aria-label", STR.saveCode.title);

  const status = h("p", "code-status");
  let armed = false;

  const setStatus = (text, bad = false) => {
    status.textContent = text || "";
    status.classList.toggle("bad", bad);
  };

  const importBtn = btn(STR.saveCode.import, () => {
    if (!armed) {
      armed = true;
      importBtn.textContent = STR.saveCode.importConfirm;
      setStatus(STR.saveCode.importWarning);
      return;
    }
    armed = false;
    importBtn.textContent = STR.saveCode.import;
    const result = app.save.importCode(box.value);
    if (!result.ok) return setStatus(result.error, true);
    setStatus(STR.saveCode.imported);
    if (onImported) onImported();
  }, "ghost");

  const actions = h("div", "code-actions");
  actions.append(
    btn(STR.saveCode.export, () => {
      armed = false;
      importBtn.textContent = STR.saveCode.import;
      box.value = app.save.exportCode();
      box.focus();
      box.select();
      setStatus(STR.saveCode.exported);
    }, "primary"),
    btn(STR.saveCode.copy, async () => {
      const text = box.value.trim() || app.save.exportCode();
      box.value = text;
      try {
        await navigator.clipboard.writeText(text);
        setStatus(STR.saveCode.copied);
      } catch {
        box.focus();
        box.select();
        setStatus(STR.saveCode.selectToCopy);
      }
    }, "ghost"),
    importBtn,
  );

  wrap.append(box, actions, status);
  return wrap;
}
