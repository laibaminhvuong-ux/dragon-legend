import { MAX_LEVEL } from "./stats.js";
import { hasFormPath } from "../game/forms.js";
// Ultra Instinct's energy projection is an advanced learned ability, not a fourth form.
export const INSTINCT_AVATAR = {
  id:'UltraInstinctAvatar', forms:['UIPerfected','UITrue'], path:'instinct',
  duration:60, cooldown:120, strikeInterval:.8, range:14, halfWidth:4, verticalReach:10,
  scale:5, cameraScale:2.4, color:0x91ceff, coreColor:0xe8f4ff, opacity:.2,
};
export function canManifestAvatar(slot,player){
  return ['Saiyan','HalfSaiyan'].includes(slot.race) && slot.level>=MAX_LEVEL && slot.forms.includes(player.form) && hasFormPath(slot,INSTINCT_AVATAR.path) && player.health>0 &&
    INSTINCT_AVATAR.forms.includes(player.form) && slot.moves.includes(INSTINCT_AVATAR.id);
}
