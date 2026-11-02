// Small DOM helpers. Screens are plain DOM overlays, so this is all the framework we need.

/** Element with optional class and text. */
export function h(tag, cls = "", text = null) {
  const el = document.createElement(tag);
  if (cls) el.className = cls;
  if (text != null) el.textContent = text;
  return el;
}

/** Button with a click handler. */
export function btn(label, onClick, cls = "") {
  const b = h("button", cls ? `btn ${cls}` : "btn", label);
  b.type = "button";
  if (onClick) b.addEventListener("click", onClick);
  return b;
}

/** Replaces an element's children. */
export function clear(el) {
  el.replaceChildren();
  return el;
}

/** 0xRRGGBB -> "#rrggbb". */
export function hex(color) {
  return "#" + (color >>> 0).toString(16).padStart(6, "0");
}
