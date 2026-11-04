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

## Follow-up assignment: combos, timing and six samples (2026-11-04)

The follow-up adds root numeric `hold_min`, `release_window`, `recovery` to **every** recipe; `phases.recovery.duration` matches root recovery. All times are seconds and visual-only. A quick tap still spends Ki/releases/deals damage immediately. SkillDirector retains an already-created gather for the remaining hold_min while the authoritative release proceeds. Claude's pose consumer should similarly retain/blend the gather visually; do not delay combat, input or projectile motion.

| Sample | hold_min | release_window | recovery | Gather socket |
|---|---:|---:|---:|---|
| KiBlast | .06 | .16 | .12 | hand_r |
| EnergyWave | .14 | .48 | .24 | hand_r |
| DestructoDisc | .18 | .28 | .22 | hand_r + .15 m up |
| WolfFangFist | .10 | .34 | .20 | hand_r |
| InstantTransmission | .12 | .18 | .16 | head + (.12, .10, 0) m |
| SpiritBomb | .32 | .65 | .38 | head + 2.2 m up |

`recipe.phases.prepare.socket` selects the gather socket; `recipe.socket` selects the release socket. Existing Fighter socket names/signatures need **no changes**. EnergyWave now gathers at the cupped-hand side rather than in front of the chest. SpiritBomb's extra world-up offset keeps the gather overhead; DestructoDisc stays just above the raised palm. Gather offsets live in recipe `gather_offset`. GPU review should check these offsets against very large forms too; no actor bones/pose files were edited by Codex.

Six-sample `layers` describe their implemented gather/muzzle/core/sheath/trail/contact/recoil components. Actual host projectiles acquire direction-aligned streaks; the effect never predicts or writes a hit. WolfFangFist uses curved claw ribbons and rush streaks; teleport uses departure/arrival columns instead of a false travel beam; SpiritBomb gathers inward motes and resolves at the original immediate endpoint. Finisher impacts scale up. The audition stage now uses **the actual Fighter and current SkillPoses** via their public APIs, rather than an empty effects stage. H holds the gather indefinitely for repeated loop listening, Q toggles quick-tap release, V changes sound variant; Space/arrow controls remain.

### Combo metadata and integration

Melee and WolfFangFist release events / `player.skillState` / impact context add:

- `combo_step`: 1-based host-selected step.
- `combo_length`: Melee 4, WolfFangFist 6.
- `strike`: `jab`, `cross`, `hook`, `uppercut`, `knee`, `spin_kick`, `axe_kick`, or `palm_strike`.
- `finisher`: true on the final **visual combo step**.

Choices come from the recipe `combo.strikes` options indexed by the host's seed; every peer consumes the transmitted choice. Melee keeps its original four-hit timing/window/damage and final damage multiplier. WolfFangFist advances one visual step per cast, resets after more than `beamCooldown + comboWindow` without a cast, and still does one original immediate hit per activation. It does not simulate six extra damage hits. Its existing guard-break mechanic remains on every cast: damage event `guard_breaker` records that separately from the visual `finisher` flag. Claude should route `strike` and `combo_step` into distinct body clips; the legacy attackKind field is retained for existing consumers.

Release state also includes `released_at`, `hold_elapsed` and the three timing envelope fields, so animation consumers can compare actual hold duration with the visual minimum. A prepare→release action keeps its original action_sequence/started_at. No RNG is introduced on clients.

### Repeatable two-process co-op proof

From the repository root, with a native Godot 4.7.2 executable:

```sh
python3 tools/run_skill_coop_proof.py --output /tmp/dragon-skill-proof
# If Godot is elsewhere:
python3 tools/run_skill_coop_proof.py --godot /path/to/godot --port 18936 --output /tmp/dragon-skill-proof
```

On Windows Python, use `python` and a Windows executable/output path. From WSL with a Windows executable, the runner translates project/artifact paths with wslpath. It imports the project first (use `--skip-import` only for an already imported project), then launches **separate processes** on 127.0.0.1, with temporary level-2000 fixture fighters. It does not import, overwrite or back up your real fighter slots. No build/install/server deployment is involved.

The host starts gathering EnergyWave before the client joins. The client must receive the host's `skillState` in a late-join snapshot; then all six samples are cast on the host. The client verifies remote `actor_id` remains the host's id, its own attack event localises to `player`, event ids survive translation, Wolf combo metadata agrees, and KiBlast/DestructoDisc snapshots retain the correct original actor/sequence/seed without an owner dictionary. Per-cast acknowledgements prevent a short-lived projectile from being skipped between casts. Final JSON compares host/client PIDs, all moves, seeds/sequences and the client's evidence. Host closes the room after the final acknowledgement.

Artifacts: `import.log`, `host.log`, `client.log`, `ready.json`, `host.json`, `client.json`. Success prints PASS and exits zero only after both distinct processes finish with matching evidence. A listener failure, timeout, missing event/state/projectile, lost actor identity or nonzero child exit fails the run. Port 18936 can be changed if occupied. Ordinary unit tests exercise the verifier's collection logic separately; they are **not** a substitute for this socket run.

**Restricted-environment result:** the attempted real run could not open the listener (`ERR_CANT_CREATE`, host exit 78; runner exit 1). Python socket creation is also denied here. No network success is claimed. Claude has been asked in COLLABORATION.md to run the command in his unrestricted terminal and record the artifacts. Real-loopback execution remains an acceptance gate until that evidence exists.

### Audio levels and listening

All 258 WAVs were regenerated with full-clip RMS normalization: one-shots -22 dBFS; sustained loops -24 dBFS. Peak ceilings remain .70/.42, with crest compression when necessary. Sustained percussive charge banks now keep an air/body layer instead of an impact followed by near-silence. Runtime gain/settings/positional playback are unchanged. These are PCM peak/RMS measurements, not perceptual LUFS or a claim of equal perceived loudness.

`python3 tools/report_combat_audio.py` measures actual delivered WAVs and writes `docs/combat-audio-levels.{md,json}` with every bank's peak/RMS range and per-clip boundary diagnostics. Current objective review flag: `shield_charge_1.wav`, head/tail energy difference > 6 dB despite matching endpoint samples. The user/Claude must listen to determine audibility. See `docs/skill-audio-review.md` for the short five-point pass and audition controls. `tools/check_combat_audio.py` now enforces RMS target tolerance ±.25 dB, peak ceilings, format, hash, distinct variations, seams and deterministic sample reproduction.

Follow-up validation: native Godot 4.7.2 `tools/godot_test.sh --check-data` **233 passed, 0 failed**, exit 0; 40 tables verified. Exporter checker six checks passed. All 258 audio files / 86 banks passed normalization/peak/hash/format/seam checks and deterministic sample rerenders; one objective loop-energy listening flag is recorded in the report. In-tree audio smoke passed cleanly. Real two-process execution was attempted and failed at the environment's socket restriction (host 78 / runner 1), so network acceptance remains pending the unrestricted run requested from Claude. No GPU/listening acceptance or publication is claimed.
