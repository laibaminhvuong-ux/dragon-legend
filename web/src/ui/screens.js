// The real UI screens. main.js shows "slotSelect", "hud", "pause" and "touchControls"; the creator
// is opened by slotSelect. Anything not registered here still falls back to ui/dev.js.
import { registerScreen } from "./index.js";
import { slotSelect } from "./slotSelect.js";
import { creator } from "./creator.js";
import { hud } from "./hud.js";
import { pause } from "./pause.js";
import { touchControls } from "./touchControls.js";

registerScreen("slotSelect", slotSelect);
registerScreen("creator", creator);
registerScreen("hud", hud);
registerScreen("pause", pause);
registerScreen("touchControls", touchControls);
