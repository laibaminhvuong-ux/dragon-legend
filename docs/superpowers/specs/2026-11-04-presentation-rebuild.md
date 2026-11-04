# Presentation rebuild: distinct characters, skill choreography, effects and sound

Date: 2026-11-04. Status: work split recorded for Claude; implementation has not started under this plan.

## User direction and current evidence

The user is dissatisfied with SFX, graphics and models, wants visibly different character models instead of the same body for everyone, and asks for the Codex/Claude division before implementation. They also request richer skill visuals and actions, with a little more complexity. Previously accepted GB-scale storage remains acceptable; storage size is not itself a quality target.

Repository findings:

- `characters/fighter.gd` preloads one `AnimationLibrary_Godot_Standard.gltf` base and instantiates it for ordinary fighters. Regions, accessories, hair and body scaling vary, but the underlying body is shared. Procedural Great Ape and wish-dragon exceptions do not solve ordinary-character repetition.
- `fx/combat_audio.gd` generates six short 22.05 kHz sound types. This provides functional cues but too little identity, variation and layering.
- `data/moves.json` defines 26 moves: four blasts, seven beams, ten utility entries, one melee entry, three ultimates and one avatar, in addition to the starter Energy Wave and ordinary melee.
- Combat presentation still groups many moves by broad kind. Existing attack/beam messages omit a stable move id and enough timing detail to distinguish all skills consistently, especially in co-op.

The earlier animation work remains useful as infrastructure. It is not evidence that the model, sound or skill-identity problems have been solved.

## Work split

| Area | Owner | Deliverable |
|---|---|---|
| Art direction and actual character meshes | Claude | Distinct body/head geometry and silhouettes, named-fighter identity, clothing meshes, materials and model assets |
| Rigging and character animation | Claude | Rig adapters/retargeting, action clips, facial/hand poses, form anatomy, locomotion, foot placement and secondary movement |
| World and character rendering | Claude | Consistent lighting, character shading, face readability, shadows, ground contact, environment colour and camera presentation |
| Skill presentation catalogue | Codex | Per-move phase/timing/socket/FX/audio definitions, including active/passive availability audit |
| Skill VFX | Codex | Distinct projectile/beam/disc/rush/utility/ultimate/avatar effect assets and controllers, with bounded cost and quality tiers |
| Combat SFX | Codex | Layered, varied audio assets and sound-bank playback; different preparation, release, travel, hit and recovery sounds |
| Authoritative skill events and co-op metadata | Codex | Move id, actor/sequence/timing/aim/seed data; correct hit/impact events and network replication; rule/protocol regressions |
| Scene/model/FX integration and GPU review | Claude | Integrate the agreed contract into scenes and remote avatars; capture comparisons and measure actual performance |
| Packaging and builds | Claude | Include all required assets/dependencies and validate the final combined game before any release |

Claude's animation/choreography owns **how the body moves**. Codex's skill presentation owns **which effects and sound cues happen at each phase**. Claude wires them together in the play scenes. They must share the same move id and phase markers.

## File boundaries

### Claude

- `godot/characters/**`, including Fighter, animation controller, pose/foot modifiers, rig adapters and character shaders.
- `godot/assets/characters/**` and model/clothing/face textures stored with those assets.
- `godot/world/**`, world-rendering shaders and environment presets.
- `godot/scenes/play/**`, camera work and showcase/review scenes.
- `godot/network/play_session.gd` for consuming new character/animation presentation only, coordinated with Codex's packet contract.
- `godot/tests/characters/**`, view/scene/world tests, GPU tools and packaging.
- Integrator-maintained `godot/assets/LICENSES.md`; incorporate Codex's audio/FX source records when integrating.

### Codex

- `godot/fx/**`, including aura, projectiles, beams, impacts, trails, avatar effects, audio players and FX shaders.
- New `godot/assets/audio/combat/**` and `godot/assets/fx/**`, each with its own source/licence manifest.
- Generated skill-presentation data through `tools/godot_additions.mjs` / `tools/export_godot_data.mjs`, with exporter checks. Never hand-edit generated JSON.
- `godot/rules/combat.gd` and related rule modules only where phase/event support is required; no incidental balance rewrite.
- `godot/network/{codec,room,service,game_mirror,story_mirror}.gd` as necessary for authoritative skill metadata; coordinate schema/protocol compatibility before changing messages.
- New FX/audio/catalogue tests, `godot/tests/rules/**`, relevant networking tests and exporter/runner checks.

No agent edits the other's active files. Shared contract changes go in this document and the collaboration log before dependent edits. An implementation claim lists exact files. Any file still covered by an earlier active claim must be coordinated before editing it.

## Character requirements

- Replace the universal visible mannequin body with actual model families. Skeletons and animation libraries may be shared where compatible, but sharing a skeleton must not force one visible body mesh on every character.
- Saiyan/Half-Saiyan: varied adult physiques, head/jaw/nose/eye geometry and distinct named-fighter silhouettes. Their shared biology is compatible with a common rig; named fighters still need individual faces, proportions and outfit geometry.
- Human: distinct civilian, martial-artist, large/heavy and smaller/younger silhouettes with actual clothing volume and face variation.
- Namekian: original torso/shoulder/limb/hand/head shapes, ears and antennae; robe/cape geometry must fit that anatomy. Green recolouring and attachments on the ordinary human torso are insufficient.
- Frost Demon: distinct exoskeleton, head/dome, shoulders, hands/feet and tail anatomy. Form changes use appropriate geometry, not only metallic colours.
- Majin: soft body/head/tentacle anatomy, distinct large, athletic and small forms. Uniformly scaling the ordinary humanoid is insufficient.
- Great Ape, Giant and major bulk-changing forms need suitable silhouette, posture and anatomy; minor colour-based forms may reuse their appropriate anatomical family.
- Major named fighters receive individual face/head/physique/outfit profiles. Background NPCs and trainees may reuse a varied archetype library, with deterministic variation so a crowd is not a row of identical clones.
- Existing race/build/hair/outfit/accessory/custom Ki controls must continue to work. Record unsupported combinations explicitly during construction; do not silently fall back to the mannequin and call that model completed.
- New models remain original or use assets permitted by the project's licence rules. Record origin and redistribution terms with the assets before packaging.

### Visible proof

Claude supplies same-camera, same-height contact sheets in **neutral material and black silhouette**, then textured close-ups. Race anatomy and major named fighters must be distinguishable before hair colour or aura is added. Mesh hashes alone do not prove artistic difference. Include faces, side views, outfit fit, transformations and a mixed NPC crowd.

## Skills: richer visuals and actions

Every active skill gets its own presentation recipe with as many phases as it needs:

1. Anticipation/body placement and hand gesture.
2. Energy gathering/shape formation, with an intensity progression for held skills.
3. Release or committed contact action.
4. Projectile travel, sustained beam, rush or utility action.
5. Impact/deflection/guard response and follow-through.
6. Residual energy, smoke/debris where appropriate, recoil and recovery.

The requested complexity should be visible in staging, pose, shape, sound and response. Keep controls readable and responsive. Do not give every move an unskippable long cinematic or introduce arbitrary extra button sequences.

| Family | Claude's action/choreography | Codex's VFX and sound |
|---|---|---|
| Ki blasts | Aimed finger/palm release, alternating hands where appropriate, short recoil | Muzzle formation, shaped core, travelling trail, variable small impacts |
| Energy Wave / Kamehamera | Two-hand gathering at the body, weight transfer, palm thrust and sustained bracing | Growing hand orb, layered beam core/sheath, emission pulses, travel/impact and charge/release/tail sounds |
| Galik Blaster / Final Blaze / Masenka / Triad Beam | Distinct hand positions, stance and release/recovery per move | Different beam silhouettes, thickness, timing, patterns and audio identities |
| Spiral Beam Cannon | Focused two-finger preparation and precision release | Helical energy around a narrow core, piercing travel and distinctive impact/audio |
| Destro Disc / Doom Beam | Throwing/finger-aim actions matched to each projectile type | Spinning disc or thin precision energy shape rather than the generic ball |
| Wolf Claw Fist | Planted rush/step-in, multiple readable strikes and a finisher | Short contact trails, differentiated hit beats and heavier finishing cue |
| Spirit Sphere / Doom Orb | Large-scale gathering, body strain, launch and recovery | Size-dependent energy formation, travel, impact envelope and residual effects |
| Hakaido | Controlled gesture with deliberate follow-through | Distinct destruction-style energy, dissolution/impact and sound; no generic beam substitution |
| Solar Flash / Regeneration / Energy Field | Own gesture/hold/recovery for flare, healing and barrier | Flare, body pulses or shield formation appropriate to the action, with separate sound loops/tails |
| Instant Transfer / Afterimage | Departure and arrival poses aligned to actual authoritative movement | Matching departure/arrival distortion or fading silhouettes, with consistent remote timing |
| Kaiyoken / Instinct focus / Energy Avatar | Activation posture and distinct controlled/aggressive character actions | Separate overlay, focused energy or avatar layers; skill-specific activation/strike/expiry cues |

Audit all 26 definitions plus starter/basic attacks. Mark passive unlocks (such as God Ki Control) separately from castable moves. Resolve currently unsupported action entries explicitly; do not advertise a passive or missing mechanic as a completed active skill.

## Shared model/skill contract

- Stable `move_id`, `actor_id`, `action_sequence`, authoritative start/contact/finish information, aim/target data, deterministic variation seed and cancellation reason where needed.
- Semantic attachment sockets: left/right hand, chest, head, pelvis, feet, aura root and cast origin. Fighter exposes transforms through rig adapters instead of FX hardcoding the old mannequin's bone names.
- Animation markers describe gather/release/contact/recovery; FX/audio use those same markers. A beam must come from the casting hands and follow the same aim used by the rules.
- Rules remain authoritative for damage, hitboxes, range, Ki cost, cooldowns, quest credit, movement and teleport endpoints. A visual rush must not secretly teleport the client or award extra damage.
- Any needed committed wind-up/channel/cancel timing is an explicit rule change with tests. Do not let an animation length accidentally change combat balance or make damage and visible contact drift apart.
- Remote friends must see the correct move, pose, form, effect and audio timing. Verify actor ids, per-actor sequences, simultaneous casts, joins in progress, travel and cancellation/disconnect.
- Preserve `Fighter.create/update/set_form/set_terrain/...` compatibility while extending the socket/skill contract. Save migrations are needed only if new persistent customization fields are actually introduced.

## Audio requirements

Replace the six-cue-only foundation with a sound bank covering light/heavy punches, kicks, guards, whiffs, blasts, individual beam families, charge loops, transformation stages, flight/dash, landings and utility actions. Layer transients/body/tails where they improve impact. Supply variations and controlled random selection to prevent repetitive machine-gun playback. Match audio markers to the action and actual hit response. Check loudness, clipping, loop joins, spatial attenuation, simultaneous-player mixing, pause and scene-exit cleanup.

Judge the sound by listening to real gameplay, not by counting sample rate, files or passing tests. New recordings/assets must have documented usable licences. No asset purchase or paid service is implied by this plan.

## Delivery order

1. **Contract and inventory:** Claude acknowledges the work split and supplies model families/rig mapping/sockets and first target character identities. Codex inventories active/passive skills and publishes the phase/event/audio catalogue shape. Agree through the collaboration file; no user permission question is needed for routine decisions.
2. **Visible model proof:** Claude builds an untextured six-race lineup and several individually recognisable named-fighter heads/physiques. Test rig retargeting, accessories, foot placement and body-changing forms before populating the world.
3. **First complete skill samples, in parallel:** Claude authors body actions; Codex builds matching FX/audio for a hand blast, Energy Wave, disc, melee rush, one utility and one large ultimate. Claude integrates and records a playable comparison with the current game.
4. **Expand the approved technical/art direction:** cover all character families, important named fighters, outfits/forms and every supported active skill. Background NPCs gain varied archetypes. Codex completes the skill/audio catalogue and co-op event coverage.
5. **Combined quality review:** Claude captures real GPU gameplay/contact sheets; review audio by listening. Codex runs rule/event/asset coverage and co-op regressions. Fix visible issues as well as script errors.
6. **Build:** Claude packages the complete dependency set after review. Existing publication instructions continue to apply.

Showing the first comparison gives the user concrete results to steer; do not pause independent work awaiting optional feedback. Do not call the entire overhaul complete after only the sample set.

## Completion criteria

- Visibly distinct bodies/faces/silhouettes and varied crowds, rather than one retextured mannequin everywhere.
- Demonstrably different active skills in pose, shape, travel/contact response and sound; complete catalogue coverage documented.
- Hand/aim alignment, readable hit reactions and animation recovery on ground/in flight and across different rigs/forms.
- Player customization, saves, quest tracking, world travel and private co-op remain functional.
- Headless checks: `tools/godot_test.sh --check-data`, relevant asset/catalogue checks and `coop-sockets` where sockets are allowed. Headless passes do not establish visual/audio quality.
- GPU review includes a busy mixed-character fight, several simultaneous skills, transformations and private co-op. Aim for 60 fps at 1080p on the user's GTX 1650 Ti with measured quality tiers and recorded conditions; do not reuse earlier FPS claims for the new assets.
- Use storage for useful mesh/texture/audio detail, with sensible streaming/LOD. GB-scale storage is permitted; arbitrary size inflation is not a deliverable.
