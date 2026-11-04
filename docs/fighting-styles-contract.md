# Fighting-style rules and event contract

Codex's rules/data/network implementation for `2026-11-04-fight-flow-styles-ape-design.md`. Claude owns animation clips/flow, the style menu, scene integration, both new rigged Great Apes, GPU review and shipping. This contract describes authoritative rules and presentation data; passing these tests does not certify rendered animation flow.

## Menu and save API

```gdscript
var choices := RuleStyles.all() # id -> profile; all four available to every fighter
var order: Array = RuleTables.table("fighting_styles").order
var error: Variant = game.set_style("brawler")
# null means success; String is a refusal for the UI to show.
```

IDs: `turtle`, `brawler`, `speedster`, `crane`. Default `turtle`. Canonical fields are **slot.style** and **player.style**, not appearance.style or loadout.style. HUD adds `style`, `styleName`; combat snapshot adds `style`, `styleBusy`. Normal movement, flight and blocking do not prevent choosing a style. A live melee cooldown, active charged technique or outstanding strike envelope prevents changing to another style. Requesting the already selected style is harmless and succeeds. A successful change resets the melee chain and clears the old completed presentation; it does not refill HP/Ki or change derived fighter stats.

Online UI uses the same method on `CoopGameMirror`; it sends `command("set_style", [id])`. The host accepts exactly one string argument and validates the id and strike state. Clients do not predict a successful style change or submit tuning/damage/move ids. Replies/errors follow the existing co-op command path. Untrusted intent fields such as style/damage_scale are discarded. No new boolean input action is required for the menu.

Godot save schema is **7**, with 10 slots. Version 1–6 profiles/DL1 codes remain readable. Migration/normalization adds turtle for a missing/invalid offline style, preserves valid choices, and retains levels, XP, forms/mastery, quests and story flags. It is idempotent; legacy v1–3 level scaling is unchanged. Codes from versions newer than 7 are rejected. Old co-op slot imports may omit style and become turtle; an explicitly malformed/unknown online style is rejected before import. SaveStore and save-code export use the schema's version automatically. The classic web game stays at v6: its parity oracle remains unchanged, while the Godot parity assertion projects the explicit new style field/current save version.

Author data in `tools/fighting_styles.mjs`, then run `node tools/export_godot_data.mjs`. The exporter writes `fighting_styles.json`, character assignments, schema and manifest; it hashes the new authoring module. Claude's separate physique map block in godot_additions.mjs is preserved.

## Moves and release events

There are 24 stable clip ids: four core combo motions, one dash-in and one finisher for each style.

| Style | Four core combo ids | Dash-in | Finisher |
|---|---|---|---|
| turtle | turtle_jab, turtle_cross, turtle_front_kick, turtle_straight_punch | turtle_step_in | turtle_double_palm_push |
| brawler | brawler_wide_hook, brawler_hammer_fist, brawler_shoulder_charge, brawler_uppercut | brawler_charge | brawler_overhead_slam |
| speedster | speedster_jab_flurry, speedster_side_step_knee, speedster_spin_kick, speedster_back_fist | speedster_afterimage_blink | speedster_blur_rush |
| crane | crane_palm_strike, crane_high_kick, crane_knife_hand, crane_crane_kick | crane_gliding_step | crane_one_finger_strike |

`RuleStyles.move(style, step, dashing=false)` deterministically resolves host presentation metadata. Core choices follow the fixed style/step; clients never roll their own move. The existing seed remains attached to events for effects and WolfFangFist variations.

Attack release fields:

| Field | Meaning |
|---|---|
| style | Canonical source style at cast time |
| move | Selected primary clip id |
| combo_move | Core four-hit motion at that step, including hit 4 |
| combo_step / combo_length | 1–4 / 4 for ordinary melee |
| strike | Existing compatible jab/cross/hook/uppercut/knee/spin_kick/axe_kick/palm_strike fallback |
| finisher | True on the fourth damaging hit |
| chain_window | Maximum gap between accepted melee strikes before the chain resets, seconds |
| lunge | Visual root-motion metres; never applied to player position/collision |
| strike_duration | This hit's authoritative melee cadence lock, seconds |
| dash_move | Present when the first hit occurs while dashing |
| finisher_move | Present on hit 4 |

Selection: first hit while dashing uses dash-in; hit 4 uses finisher; otherwise uses the core combo id. `combo_move` always identifies the normal core contact, so Claude can blend hit 4's core contact into its finisher follow-through. This is **one hit**, not a second finisher damage event. The legacy combo/attackKind fields are retained. Socket selection follows the chosen fallback strike (hand or foot).

Technique/WolfFangFist events preserve their existing move_id, damage and cadence. They additionally carry source style, chain_window, zero visual lunge, and a strike envelope. They do not substitute a style melee clip for their skill choreography: unknown style clip ids such as `move="EnergyWave"` should keep using the existing SkillPoses/technique path. Release timing is still authoritative; visual windup/anticipation/contact/follow-through/recovery/blend data in each style move is for the animation engine, not a new delayed hit timer. Contact in rule time is 0 at release. Visual hitstop must not pause the simulation clock, cooldowns or co-op room.

## Balance and feel

Baseline melee damage is 12 × strength, with the existing ×1.65 fourth-hit modifier. All four styles share the same ideal sustained unblocked DPS:

`cycle = sum(cadence)`

`damage_scale = cycle / 1.28`

`ideal DPS = 12 × (3 + 1.65) × damage_scale / cycle = 43.59375 × strength`

Forms/Kaioken/Ultra Ego multiply the same underlying damage as before. Integer hit rounding and 60 Hz cooldown quantization introduce small differences; target travel/guard/interruptions also affect practical DPS. This is roughly equal sustained output, not identical damage per hit.

| Style | Cadences, seconds (hits 1–4) | Chain window | Base reach, m | Damage scale | Ideal cycle damage | Measured 60 Hz DPS |
|---|---|---:|---:|---:|---:|---:|
| Turtle School | .32 / .32 / .32 / .32 | 1.10 | 2.80 | 1.00000 | 55.8000 | 42.0420 |
| Brawler | .46 / .48 / .50 / .48 | 1.35 | 2.65 | 1.50000 | 83.7000 | 43.0843 |
| Speedster | .22 / .22 / .24 / .24 | .72 | 2.50 | .71875 | 40.10625 | 42.4577 |
| Crane | .34 / .36 / .34 / .40 | 1.15 | 3.20 | 1.12500 | 62.7750 | 43.1946 |

Measured numbers are actual RuleCombat runs: strength 1, 40 consecutive in-range unblocked hits, fixed 1/60 s updates, including the final cooldown; not a formula-only test. All are within 4% of Turtle (largest measured difference about 2.74%). At base strength, per-cycle rounded HP damage is 56/84/41/64. Higher strength reduces the relative rounding effect. Tests also verify original Turtle damage and unchanged NPC/technique timing.

| Style | Guard Ki cost on a normal blocked melee hit | Horizontal knockback velocity multiplier | Visual knockback m | Stagger seconds | Normal / finisher hitstop seconds |
|---|---:|---:|---:|---:|---:|
| turtle | 7.00000 | 1.00 | .28 | .14 | .050 / .065 |
| brawler | 10.50000 | 1.35 | .60 | .22 | .075 / .090 |
| speedster | 5.03125 | .70 | .18 | .10 | .040 / .055 |
| crane | 7.87500 | .95 | .36 | .18 | .060 / .075 |

Guard pressure scales with cycle duration like damage, so Brawler costs more Ki per hit and Speedster less; sustained cost across the three guarded non-finisher hits is equal at the ideal cycle rate. The fourth hit retains the original guard-break behavior. Reach scales with form size as before. Horizontal authoritative impulse is the original 4 m/s × the table multiplier for basic melee; techniques retain their original impulse and guard cost. These controls change reach/feel without changing derived Strength/KiPower/HP.

## Damage reactions and NPCs

Damage keeps original source/victim/amount/blocked/event identity and adds:

- `knockback`: visual offset metres (×1.5 for a finisher, ×.4 on a blocked hit).
- `launch`: boolean visual launch pose; true for an unblocked Brawler finisher.
- `stagger`: visual stagger seconds (×1.3 on a finisher).
- `hitstop`: visual seconds, capped at .09.

No new vertical velocity, collision teleport, HP delay or simulation freeze is created by launch/stagger/hitstop/lunge. Existing hit-stun rules remain authoritative and unchanged. Snapshot styles and original projectile context are preserved: a shot fired before a legal style switch still reports its original cast style when it hits.

Character definitions now have a top-level style. Nappo/Brolo/Rekume and heavy fighters use Brawler; Hitto/Burtor and fast fighters use Speedster; Tenzo/Piccor/Nael and precise fighters use Crane; Roshu, students, patrols and unassigned characters default to Turtle. Full assignment map is in fighting_styles.npc_assignments. RuleStory carries character style into visible NPC and encounter rows; RuleCombat.spawn stores style on the actual enemy entity. Thus snapshots include style for enemies and late-joining friends without a second roster lookup.

NPC attacks emit host-selected style move release events and matching damage reactions. Their existing AI windup/cooldown/base HP damage is deliberately unchanged, so assigning a visual fighting style does not unexpectedly speed up a story boss or increase its DPS. NPC ordinary blocking costs/knockback can reflect the style's per-hit guard/impulse feel. They cycle their four visual moves using their attack serial. This is not a new NPC multi-hit AI or damage burst.

## Validation and handoff

Owned tests cover all 24 ids, four-step/dash/finisher resolution, chain reset, style refusal during strikes/channels, runtime save/code/store migration, future/malformed styles, real 60 Hz DPS, reach/guard/impulse, NPC metadata with original damage/cadence, no visual root-motion physics writes, cast-style retention, independent co-op fighter choices, late-join snapshots, local/remote event localisation, validated commands and non-predicting client menu calls. The existing two-process skill proof remains available for unrestricted transport regression; new style replication checks use the authoritative service and JSON codec and do not claim a new real-socket pass in this restricted environment.

Claude integration: consume `player.style` for stance; `move`/`combo_move`/`finisher_move`/`dash_move` for the clips; reaction fields for attacker/victim visual hitstop and stagger; the menu calls set_style and displays refusals. Keep animation pauses/root motion local to the rendered rig. Clips and both Great Ape implementations, transition continuity tests and GPU recordings remain Claude's owned work. No commit/build/install/publish by Codex.

Validation recorded 2026-11-04: native Godot 4.7.2 `tools/godot_test.sh --check-data` **259 passed, 0 failed**, exit 0; 41 generated tables verified, including save schema/manifest v7. Log: `/tmp/dragon-styles-full-check.log`. Exporter/runner checker: seven checks passed (`/tmp/dragon-style-export-final.log`). Owned style rule/save checks: 12 passed including legacy schema projection; network style checks: four passed. Full suite includes Claude's concurrently authored style-clip checks. Existing post-test focus/resource shutdown diagnostics remain outside test cases; no GPU, new real-socket or published-build acceptance is claimed by this run. `git diff --check` passed.
