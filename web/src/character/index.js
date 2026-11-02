// Character model entry point. Everything that draws a fighter (game world, creator preview)
// calls createCharacterModel(), so they always match.
//
// Contract (shared by play and creator previews):
//   createCharacterModel(look, options?) -> model
//     look    = slot appearance + race: { race, skin, face, hair, hairColor, build, outfit, outfitTint }
//     options = { castShadow?: boolean }
//   model.object3d          THREE.Group; origin at the feet, faces +Z, 1.8 m tall at build "Average"
//   model.attach            named THREE.Object3D points: head, chest, back, waist, handL, handR, footL, footR
//   model.update(dt, anim)  anim = { speed (m/s on the ground), onGround, flying, charging, dashing, blocking }
//   model.setHairColor(hex | null)   transformations; null = back to the look's own colour
//   model.setAura(hex | null)        aura on/off (fx/ may draw it instead; this is the hook)
//   model.dispose()
// Fighters use Cage Career 3D's model (character/cage/), dressed for Dragon Ball (cage_model.js).
// Codex's procedural fighter (fighter.js) is kept for reference.
export { createCharacterModel, updateCharacterLod } from "./cage_model.js";
