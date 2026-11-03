# Godot Stage 6: Characters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Native, user-chosen). Steps use `- [ ]`.

**Goal:** Every fighter and NPC is the CC0 rigged humanoid (Quaternius Universal Animation Library) dressed as our characters: all races, builds, faces, hair, outfits and every transformation, with smooth animation for walking, running, jumping, flying, powering up, fighting and getting hit.

**Architecture:** `characters/fighter.gd` builds a `Fighter` (Node3D) from a look Dictionary (same fields as the JS game: race, skin, face, hair, hairColor, build, outfit, outfitTint, female, kiColor, accessory). The mannequin's skinned mesh is re-coloured by region: `body_regions.gd` tags each vertex once (skin, top, sleeve, forearm, wrist, glove, belt, trousers, boots, undershirt, plate) from its bones and rest position, and `outfit.gdshader` paints the regions with the outfit's colours (`outfits.gd`, ported from `cage_model.js outfitParts`). Face, hair (ported spike hair), race features and outfit extras (armour pads, capes) attach to bones. `anim_controller.gd` blends library animations from the JS `model.update(dt, anim)` contract. `flight_modifier.gd` (a SkeletonModifier3D) layers the hover, full-speed, climb and power-up poses on top. Forms come from `Data.form_looks` (hair style/colour, eyes, brows, size, aura) with `fx/aura.gd`.

**Spec:** `docs/superpowers/specs/2026-11-02-godot-port-design.md` (Characters: CC0 rigged packs restyled)

## Global Constraints
- Same model contract as the JS game: `Fighter.create(look, opts)`, `update(dt, anim)`, `set_form(id)`, `set_ki_color(hex)`, `set_hair_color(hex)`, `dispose()`. `anim` = { speed, vy, onGround, flying, charging, dashing, blocking, attackSerial, attackKind, kaioken }.
- Models face +Z, `rotation.y = yaw`, metres. The mannequin is 1.83 m tall.
- Only CC0 assets (recorded in `godot/assets/LICENSES.md`).

## Review Focus
- **Every outfit × race renders** with no unpainted (mannequin yellow/purple) regions: contact-sheet check plus a test that every vertex has a region.
- **Transformations on every race:** a form with no recipe shows the base look, never crashes.
- **Animation edge cases:** attack while flying, landing mid-punch, charge while moving. The controller never gets stuck in a one-shot animation (a test drives every state transition).
- **Performance:** 20 NPC fighters on screen at 60 fps (shared meshes and materials per look).
- **Dispose:** form swaps and model rebuilds free their nodes (no leaks across 50 swaps).

### Task 1: Body regions + outfit shader + outfits
### Task 2: Face, hair, race features, outfit extras
### Task 3: Animation controller + flight/power-up modifier
### Task 4: Forms (hair, eyes, size, aura)
### Task 5: Contact sheets of all races × outfits × forms on the GPU; performance with 20 fighters
