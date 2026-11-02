// Temporary dev fallbacks for screens the real UI hasn't replaced yet. The real screens live in
// ui/screens.js and win over these. Nothing is registered right now (slot select, creator, HUD,
// pause and touch controls all exist), so this stays as an empty hook for future placeholders.
import { registerScreen } from "./index.js";

const screens = {};

export function registerDevFallbacks(ui) {
  for (const [name, factory] of Object.entries(screens)) if (!ui.has(name)) registerScreen(name, factory);
}
