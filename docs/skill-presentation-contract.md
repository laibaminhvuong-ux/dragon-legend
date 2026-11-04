# Skill presentation contract — Codex → Claude

Implementation: 2026-11-04. Codex owns effects, sound assets and authoritative producers. Claude owns models, animation clips, scene integration and rendered/listening acceptance. This delivers the presentation infrastructure and recipes; it does not certify the final rendered game or replace Claude's model work.

## Data and availability

`RuleTables.table("skill_presentation")` / `SkillCatalog.all()` contains 28 recipes: all 26 move definitions, starter EnergyWave and basic Melee. Author `tools/skill_presentation.mjs`, then `node tools/export_godot_data.mjs`; never edit the generated JSON. Recipes include geometry, animation pose id, semantic socket, primary custom Ki colour plus accent, widths, visual durations, three sound phase keys, availability and quality budgets.

GodKi is passive and FusionDance is not currently castable. Their recipes do not imply new combat mechanics; `RuleCombat.fire()` refuses both without spending Ki. Other move unlock checks remain in the existing loadout/command validation. `delivery=instant_ray` preserves existing beam/ultimate damage timing: do not animate a slow travelling Spirit Bomb and imply that damage waits for arrival. Large skills gather at their socket and burst at the authoritative endpoint/contact. Blast projectiles follow the host's actual projectile positions. Skill complexity here is visual/audio choreography, without extra input locks or damage delays.

## Authoritative events

Existing `attack`, `beam`, `damage`, `avatarStrike` names and legacy fields remain. New fields on cast events:

| Field | Meaning |
|---|---|
| presentation_version | 1; separate from co-op protocol version |
| move_id | Gameplay/catalogue id |
| actor_id | Stable source fighter id; damage `id` remains the victim |
| action_sequence | Increasing per combat instance; charge and release share it |
| event_id | Unique host-issued string, including combat instance, for deduplication |
| phase | prepare, release, impact, recovery, cancel, or dodge |
| server_time, started_at | Combat-clock seconds; never compare directly to client wall time |
| seed | Host-selected deterministic variation seed |
| charge | 0–1 held charge; updated in runtime state |
| socket, pose | Semantic socket and animation recipe id |
| origin, direction | Authoritative aim; Vector3 locally, x/y/z objects over JSON |
| target_id | Locked target or null; impacts identify actual victim |
| color | Integer RGB from fighter Ki customisation |

Damage adds `source_id`, `target_id`, `blocked`, `finisher`, amount and impact position. Ordinary enemy/manual damage falls back to a Melee recipe with source identity. Avatar strikes retain the original manifestation context. Projectile rows add `move_id` and compact `presentation` context; the owner dictionary is stripped from network snapshots as before. A projectile's impact retains its original move/sequence even if the caster starts another move.

Holding a technique emits one prepare event. `player.skillState` and `combat.snapshot().skill` carry the current phase/charge/aim for pose updates and late joins; these are runtime-only and are not saved to fighter slots. Release emits before hit events, with the same sequence. Blocking, stun, changing technique, defeat or insufficient Ki cancel pending presentation. A completed visual envelope emits recovery. Kaioken activation/end and automatic instinct dodges also emit presentation events, without changing their mechanics. Avatar remains 60 seconds with the existing 120-second cooldown.

**Legacy consumer migration:** `CombatView._on_attack` must process release/default only for attack poses/flourish audio. Prepare/cancel/recovery/dodge must not start a legacy melee animation. The new director already filters phases. Do not leave old generic beam/hit/projectile effects and audio enabled alongside it.

## Scene API

```gdscript
var skill_fx := SkillDirector.new()
add_child(skill_fx)
skill_fx.bind(Events, resolve_fighter, "high")
# resolve_fighter(actor_id) returns the live Fighter Node3D, or null.
# Fighter.socket(name) returns a WORLD-space Transform3D.

# Each simulation/render update, include local + all live friend actors:
skill_fx.update_actor_states([local_player] + friend_players)
skill_fx.sync_projectiles(authoritative_projectiles)
# On pause/resume:
skill_fx.set_paused(paused)
# On departure/disconnect:
skill_fx.cancel_actor(actor_id)
# On world replacement/restarting combat clocks:
skill_fx.clear()
```

Sockets: `hand_l`, `hand_r`, `chest`, `head`, `pelvis`, `foot_l`, `foot_r`, `aura_root`, `cast_origin`. The resolver must handle the host's actual co-op player ids. `CoopCodec.localize_event(packet,self_id)` can translate self identities to `player` and restore top-level event vectors while preserving event_id; if used, also translate skillState.actor_id and use a consistent resolver. The director itself accepts raw network x/y/z vectors, so localisation is optional. Use either `bind(Events,...)` or manual `handle_event(name,packet)` delivery, not both.

`bind` connects typed attack/beam/damage/avatar_strike signals and disconnects previous bindings. `unbind`, `clear`, `cancel_actor`, and node teardown release owned effects/loop voices. Leave existing base charging/form aura, ground contact and world effects under their current owners. The director creates its own CombatAudio child for skill audio; avoid retaining duplicate generic skill sounds in CombatView. Existing CombatAudio.clip/play_cue/update_player interfaces remain compatible for other cues and base charging.

`ghost_factory(actor_id,color) -> Node3D` is an optional callback for Afterimage. Return an independently owned, non-colliding visual clone of the **actual new fighter model**; the effect owns its lifetime. Do not return the live Fighter, duplicate scripts/physics, or use a generic mannequin clone. Without the callback, the effect uses distortion/rings; a recognisable body ghost requires Claude's model integration.

Quality tiers cap active effects at 12/28/48 and geometric segments at 12/24/40. Audio caps 24 overlapping one-shots and eight sustained loops. Event deduplication keeps 512 ids; old prepare/cancel packets cannot resurrect or cancel a newer cast. Repeated snapshot charge updates change intensity/socket tracking without restarting audio. All effects are visual-only Nodes, with no damage/collision/reward writes.

## Effects and animations

Implemented shapes include tapered waves/lances, twin Galick streams, TriBeam's three lobes, narrow Death Beam, a helical Special Beam Cannon ribbon, rotating flattened discs, layered ultimate spheres with orbit rings, claw fans, radial flare/shards, healing rings, shields, instinct focus and transfer rings. Flow shaders provide animated surface bands/rims. Custom Ki remains the main colour; each recipe has a secondary accent. The catalogue's pose names are animation integration targets, not a claim that Codex authored new body clips. Claude must author/route those clips through his rebuilt rigs.

## Sound bank and audition

`godot/assets/audio/combat/`: 258 original 44.1 kHz mono 16-bit WAVs, 86 cue/phase banks, three variants each; approximately 26 MiB. Source/provenance in SOURCES.md and manifest.json. These are original designed/synthesized layered assets rendered offline (modal bodies, transients, filtered noise/air, energy layers and reflection tails), **not recorded human foley or downloaded Kenney samples**. No external samples were obtained in this restricted environment. License CC0-1.0. Reproduce with `python3 tools/build_combat_audio.py`.

CombatAudio caches imported WAV resources, uses deterministic variations or round-robin legacy cues, positional attenuation, phase loops with smoothed gain and the CombatSFX limiter bus. Same-frame voices are reserved until playback starts, preventing a burst of events from overwriting one queued player. Settings master/SFX gains and pause are honoured.

Run the isolated audition stage:

```sh
godot --path godot res://fx/skill_showcase.tscn
```

Left/right chooses a recipe; Space pauses; V cycles three sound variants. It automatically advances every six seconds through prepare/release/impact, with catalogue geometry and phase sounds. It has no save or gameplay combat instance and is not a substitute for a real fighter animation review.

Validation commands:

```sh
node tools/check_godot_export.mjs
python3 tools/check_combat_audio.py
tools/godot_test.sh --check-data
godot --headless --path godot res://tests/fx/audio_smoke.tscn --quit-after 180
```

Automated checks cover catalogue coverage, hashes/audio format and loop seams, deterministic sample reproduction, engine-side geometry construction, effect limits, deduplication/cancellation/late-join charge state, projectile context, original damage timing and co-op JSON snapshots. Runtime audio smoke checks actual in-tree stream-player limits, pause/resume and teardown. Headless checks cannot establish audible or rendered quality. Claude still needs to wire the director into CombatView, author the pose clips, attach Afterimage model ghosts, run GPU screenshots/performance review and listen in solo/co-op before building/publishing.

## Validation recorded 2026-11-04

Native Godot 4.7.2 `tools/godot_test.sh --check-data`: **223 passed, 0 failed**, exit 0; 40 generated tables verified. Exporter/runner checker: six checks passed. Audio validator: all 258 files / 86 banks passed, including two deterministic rerenders. Separate in-tree audio smoke: passed, with clean teardown after the audio server's deferred cleanup. The full suite still prints existing post-test focus/exit resource diagnostics and sandbox TCP-listen denials during editor import; these were not counted as clean visual/network acceptance. Showcase scene was loaded headlessly; a forced immediate `--quit-after` can print an audio playback resource-exit diagnostic. GPU visuals, actual listening and real multi-machine co-op remain Claude's acceptance work.
