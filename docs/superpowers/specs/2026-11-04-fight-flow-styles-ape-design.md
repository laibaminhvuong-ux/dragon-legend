# Fight flow, fighting styles and the new Great Ape — design (2026-11-04)

## What the user asked for
- "I am not happy with the animation. Change the model of both oozaru and also the fighting movement too. The move flow is not that good. I reckon we can add different fight styles."
- Clarified: fighting "looks stiff, robotic and no transition at all".
- Choices made: styles are **picked from a menu and switchable any time**; the style list is **Turtle School, Brawler, Speedster, Crane**; the Great Ape is a **real rigged giant** (its own skeleton and animations), for both the normal and the Golden form.

Success = combos flow (wind-up → strike → follow-through → blend into the next move), every style looks and feels different, transitions between locomotion/attacks/dash/block/techniques never snap, and both apes are a single convincing animated creature. Judged on GPU recordings shown to the user before release.

## Approach
Code-authored keyframed animations (Godot `Animation` resources generated in GDScript), not downloaded mocap (downloads are blocked in this environment; licensing/style fit uncertain) and not physics-driven ragdolls (hard to control). Every move is a real clip with easing, overlapping action and root motion, blended through the AnimationTree.

## 1. Move-flow engine (Claude: `godot/characters/**`)
- **Move clips:** each attack has phases wind-up → strike (contact frame) → follow-through → recovery. Clips key hips, spine, chest, neck, both arms/forearms/hands, both legs, plus root motion (step-in / lunge toward the target, 0.2–1.2 m depending on move).
- **Body mechanics:** hip rotation leads the shoulders, weight shifts onto the front foot, arms trail by a few frames (overlapping action), small settle after each strike.
- **Transitions:** crossfades of 0.08–0.2 s between any two states (locomotion, combat stance, attack, dash, block, hurt, technique hold/release, flight). The next combo hit may start during the previous follow-through (chain window supplied by the rules, see Codex).
- **Combat stance:** a per-style guard idle (breathing, weight shifting, light bounce for Speedster) used whenever a target is locked or a fight is near, blended with walk/run.
- **Hit feel (presentation only):** hit-stop of 40–90 ms on the attacker and victim (finishers heavier), victim stagger/knockback/launch poses, camera nudge. Damage and timing stay authoritative in the rules.
- Existing per-skill poses (`SkillPoses`) and procedural layers (flight, charge, block) stay, but become clips/blend targets in the same tree instead of additive overrides where that causes snapping.

## 2. Fighting styles
| Style | Feel | Stance | 4-hit combo (visual) | Dash-in | Finisher |
|---|---|---|---|---|---|
| Turtle School (default) | balanced, classic | solid, fists up | jab, cross, front kick, straight punch | short step-in | double-palm push |
| Brawler | heavy, wide, slow | wide, low, shoulders hunched | wide hook, hammer fist, shoulder charge, uppercut | lumbering charge | overhead slam |
| Speedster | light, fast, evasive | on the toes, bouncing | rapid jab flurry, side-step knee, spin kick, back-fist | afterimage blink | blur rush |
| Crane | low, calm, precise | one-leg-ready, open palms | palm strike, high kick, knife-hand, crane kick | gliding step | one-finger strike |

- Picked from a style menu (like the form picker); saved per fighter; switchable any time outside a strike.
- **Balance (Codex):** styles change timing and feel, not total damage: e.g. Brawler slower hits / more knockback / guard pressure; Speedster faster lighter hits / shorter chain windows; Crane longer reach / precise; Turtle middle. Per-style tuning numbers live in the rules data.
- NPC/enemy fighters get fitting styles (e.g. Nappo/Brolo Brawler, Hitto/Speedster types, Crane-school characters Crane, students Turtle).

## 3. New Great Ape (normal and Golden)
- One continuous skinned mesh generated in code on its own `Skeleton3D` (hips, spine x3, neck, head, jaw, shoulders, arms, forearms, hands, thighs, shins, feet, 4-bone tail): hunched torso, sculpted fur volume (clumped silhouette at shoulders, forearms, back), long arms, digitigrade-ish legs, muzzle with fangs, brow ridge, glowing red eyes.
- Own clips: idle breathing, heavy walk (knuckle-assisted), roar, chest pound, stomp, two-handed swipe, grab-slam, mouth blast (wind-up head pull-back, release), hurt, transform-in.
- Ground shake + dust on footfalls and slams. Golden = same body, golden fur + brighter glow/eyes.
- Replaces `godot/characters/great_ape.gd`; keeps the Fighter's ape contract (create(golden), update(dt, anim)).

## 4. Ownership
- **Claude:** `godot/characters/**` (move clips, flow engine, stances, ape), `godot/ui/**` style menu, `godot/scenes/play/**` integration, GPU review, builds.
- **Codex:** style rules and data (`rules/`, `data/` exporter, tests): style ids and per-style tuning; chain windows; knockback/launch/stagger amounts; saving the chosen style in the fighter slot + schema migration; NPC style assignment; attack/damage event fields `style`, `move` (per-style move id), `chain_window`, `knockback`, `launch`, `hitstop` and co-op replication of them; a command to change style.

## 5. Event contract (proposal for Codex)
Attack release events add: `style` (turtle|brawler|speedster|crane), `move` (style move id, e.g. `brawler_hammer_fist`), `combo_step`, `finisher`, `chain_window` (s), `lunge` (m, visual root-motion distance). Damage events add: `knockback` (m), `launch` (bool), `stagger` (s), `hitstop` (s). Snapshot / `player.style` for late join. Existing fields stay.

## 6. Testing / acceptance
- Unit: every style × every combo step resolves a clip; transitions never jump (pose distance between consecutive frames bounded); clips end in a blendable pose; ape builds, skins and plays every clip.
- GPU: recorded combos per style, technique transitions, and both apes (walk, roar, swipe, mouth blast) shown to the user before shipping.
