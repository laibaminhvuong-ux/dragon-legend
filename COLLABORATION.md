# Dragon Legend

A standalone 3D action RPG inspired by Dragon Ball, shipped as a **downloadable app** (Windows first, then Android, Mac and Linux). It is not a Roblox game. It has the same idea and systems as our earlier Roblox project (`~/dbz-project`), rebuilt as our own engine-free web game packaged as an app.

Three AI agents work in this one folder at the same time: **Claude Code**, **Codex** and **Freebuff**.

Status: brand new (started 2026-11-01). No code yet. The first step is for the user to confirm the tech setup below. The game design is carried over from the Roblox project, which the user has already confirmed.

## Tech setup (proposed, waiting for the user's confirmation)

We use the same pipeline as Cage Career 3D, which already ships as a Windows app:

- **Engine:** [Three.js](https://threejs.org) (version pinned and vendored in `web/vendor/`, no CDN at runtime) with plain ES modules. No game engine, no framework.
- **Bundling:** esbuild bundles `web/` into `dist/site/`.
- **Desktop app:** Electron in `desktop/`. It loads the bundled game from a custom `app://game/` protocol and forces the dedicated GPU. electron-builder makes `Dragon-Legend-Setup.exe` and a portable zip (`tools/build_installer.sh`); installed copies update themselves from GitHub releases (electron-updater reads `latest.yml`).
- **Mobile app:** Capacitor in `mobile/` wraps the same bundle as an Android APK. iPhone needs an Apple Developer account, which the user doesn't have.
- **Saves:** 3 character slots in the app's local storage, with a versioned schema and migrations. There's also an export/import save code. The game is offline and single-player first. Online/PvP comes later, if at all.
- **Releases:** GitHub releases. The app checks `releases/latest` for updates. Only the integrator publishes.

### Layout
```
web/
  index.html
  src/
    main.js            boot, game loop, scene switching
    core/              input (keyboard, mouse, gamepad, touch), save/load, events, rng, settings
    data/              tunable tables only: races, forms, outfits, appearance, stats, moves, quests, enemies
    game/              rules: progression, ki, stats, combat resolution, quests (no rendering here)
    character/         3D character builder: body, hair, face, outfits, race features, auras
    world/             zones, terrain, sky, NPC placement, spawners
    combat/            hitboxes, melee, ki blasts, beams, AI
    fx/                particles, aura, beam and impact VFX, camera shake
    ui/                menus, slot select, character creator, HUD, dialogue, stat screen, shop
    audio/
  assets/              our own models, textures, sounds
  vendor/              three.js and other pinned libraries
desktop/               Electron shell
mobile/                Capacitor shell
tools/                 build scripts + automated checks (node, headless browser)
```

### Rules of thumb
- **`game/` is the authority** for damage, ki, XP and stats. Rendering, input and UI only read game state and send intents. This is the same split as the Roblox server/client, so online play can be added later without a rewrite.
- **Tunable numbers live in `web/src/data/`**, never hard-coded in systems.
- **Saves stay backward compatible:** add fields with defaults and never rename or remove them. Every schema change bumps `version` and adds a migration.
- **Performance budget:** 60 fps on the user's laptop (GTX 1650 Ti) and a playable frame rate on a mid-range Android phone. There's a quality setting (low/medium/high).
- **Every feature ships with a check** in `tools/` (node unit check for `game/` logic, headless-browser smoke check for anything visual) that the integrator can run.

### Assets and naming
- The Roblox asset policy (marketplace faces and costumes) **does not carry over**. Those were Roblox-hosted ids and can't be used in an app. All models, textures, VFX and sounds in this project are **our own**: built in code (low-poly / toon-shaded Three.js geometry) or made by us. We don't copy code, UI or exact numbers from other games.
- **Name:** the game is called **"Dragon Legend"** (renamed from "Dragon Ball" by the user on 2026-11-02). Use this name in every title, window, installer and store text. The story, character and move names still come from Dragon Ball, and those are trademarks of their owners. That's fine for a personal project, but the integrator raises it with the user before any public release or store listing.

## Game design (carried over from the Roblox project, confirmed by the user 2026-11-01)

An open-world action RPG that follows the story of **Dragon Ball Z and Dragon Ball Super**. Players make their own fighter, take quests from NPCs to level up, and unlock their race's transformations at set levels.

### Core loop
Create a character → take story and side quests from NPCs → earn XP and zeni → level up and spend stat points → unlock moves, outfits and race forms → beat each arc's boss → the next arc's zone opens.

### Character creator
- **Race:** Saiyan, Half-Saiyan (Saiyan + Human, like Gohan and Trunks), Human, Namekian, Frost Demon (Frieza's race), Majin. Race sets base stats, starter moves and the transformation path. Half-Saiyan has a slightly lower power ceiling than a full Saiyan but grows faster at low levels, and can use Saiyan and Human hair and outfits.
- **Looks:** skin colour (limited by race), face, hair style and colour (Saiyan/Half-Saiyan/Human), height/build presets.
- **Clothing:** outfit sets from the series (Turtle School gi, Saiyan armour, Namekian robes, Capsule Corp, gi variants and more), with colour tints. Some are available at creation; the rest are quest or shop rewards.
- Up to 3 character slots.

### Progression
- Max level 150 at launch. Each level gives 3 stat points: **Health, Ki, Strength (melee), Ki Power (blasts), Speed**.
- XP curve `100 * level^1.5`. Human and Half-Saiyan get an XP bonus. (Same numbers as the Roblox project's `Progression.luau`; port them over.)
- Moves unlock by level or quest: ki blast, charge, dash and flight first; then signature beams (Kamehameha, Galick Gun, Special Beam Cannon, Death Beam and more) and race-specific moves.

### Transformations (unlock levels are placeholders; tune in `web/src/data/forms.js`)
| Race | Forms in order |
|---|---|
| Saiyan | Super Saiyan (25) → SS2 (50) → SS3 (75) → SS God (100) → SS Blue (125) |
| Half-Saiyan | Super Saiyan (25) → SS2 (50) → Super Saiyan Rage (80) → Ultimate (100) → Beast (135) |
| Human | Kaioken (25) → Kaioken x10 (50) → Potential Unleashed (90) |
| Namekian | Namekian Fusion boost (25) → Giant Form (50) → Orange (110) |
| Frost Demon | Final Form (25) → 100% Full Power (55) → Golden (100) → Black (130) |
| Majin | Super Majin (25) → Kid Form (60) → Pure Majin (110) |

Each form multiplies stats, drains ki per second, has its own look (hair, aura, colours) and an unlock quest at the required level.

### Story arcs (one zone + quest givers + boss each)
- **DBZ:** Saiyan Saga → Namek / Frieza Saga → Android / Cell Saga → Buu Saga
- **Super:** Battle of Gods → Resurrection 'F' → Universe 6 → Goku Black → Tournament of Power
- Side quests in each zone: defeat X enemies, deliveries, training trials, hunting Dragon Balls. Rewards are XP, zeni and outfits.

### Combat
4-hit melee combo, guard break, block, dash, flight, ki charge, ki blasts, chargeable beams with beam clashes, knockback, and a stun limit so nobody gets combo-locked forever. Third-person camera with lock-on. PvE first.

### Controls (defaults, rebindable)
- **Keyboard + mouse:** WASD move, mouse camera, left click melee, right click block, Q dash, F toggle flight, Space/Ctrl ascend/descend in flight, hold C charge ki, E ki blast, R beam (hold to charge), T transform, Tab lock-on, Interact = G.
- **Gamepad** and **touch** (on-screen stick + buttons on Android) map the same actions.

### Milestones
1. **Foundation:** project + build pipeline (browser dev server, Electron app, installer), game loop, input, save system (3 slots), data tables, character creator (races, looks, starter outfits), procedural character models, one test zone, movement (run, jump, dash, flight, ki charge), HUD, settings/pause menu.
2. **Combat:** melee, ki blast, first beam, block, NPC enemy AI, damage numbers, XP from kills.
3. **Quests and levels:** quest system (NPC dialogue, objectives, rewards), stat points screen, Saiyan Saga zone with Raditz → Nappa → Vegeta bosses.
4. **Transformations:** form system and the first form for every race, with unlock quests.
5. **More arcs:** Namek, then the rest, one at a time.
6. **Ship:** Android APK, Mac/Linux builds, update checker, What's new screen.

### Porting from the Roblox project
`~/dbz-project` is reference only. **Read it, don't edit it.** Its data tables (`src/shared/Config/*.luau`), `Progression.luau`, save schema, movement tuning and hair/face shape tables can be translated to JavaScript. Roblox-only parts (DataStore, Rojo, R15 rigs, Remotes, asset ids) don't carry over.

---

# THREE-AGENT PROTOCOL (Claude Code · Codex · Freebuff) — read this first

1. **Claim before you edit.** Append a `## <Agent> — claiming (<feature>)` section at the end of this file listing every file you will touch. Check the latest claims first: if a file is claimed by someone else and not yet released, don't edit it. Pick other work or wait.
2. **One owner per file at a time.** Prefer new modules over big edits to shared files. If you need a change in someone else's file, ask in this file.
3. **Release when done.** Append `## <Agent> — released (<feature>)` with: files, what changed, what you tested and how (which `tools/` check, browser or app run).
4. **Integrator:** Claude Code reviews released work, commits it crediting the agent, builds the app and publishes releases. Builds are made from committed sources in a clean `git worktree`, never from the dirty working tree. Nobody else commits, pushes, builds installers or publishes unless the user says so.
5. **Never delete another agent's files**; never force-push; never `git add -A` (other agents' unreleased files sit in the tree).
6. **Keep saves compatible** (see rules of thumb above).
7. **Public text** (What's new, release notes, in-game credits) doesn't credit individual agents.

Suggested lanes (the user can change these):
- **Claude Code:** integration, review, builds and releases; the build pipeline (`tools/build_*`, `desktop/`, `mobile/`); core systems (`core/` save/input/loop, `data/`, `game/` rules).
- **Codex:** movement, flight, camera, combat feel (`combat/`), VFX (`fx/`), character models (`character/`), automated checks in `tools/`.
- **Freebuff:** UI (`ui/`): slot select, character creator screens, HUD, menus, dialogue, stat/shop screens, text; plus `world/` zone dressing and new self-contained features in new files.

## Claude — project created

Created this folder (git repo, branch `main`), `COLLABORATION.md`, `README.md`, `.gitignore`, plus `AGENTS.md` (for Codex) and `knowledge.md` (for Freebuff) pointing here.

**Codex and Freebuff:** please read this file and add a `## <Agent> — acknowledged` section with any comments on the tech setup and lanes. **Wait for the user to confirm the tech setup before claiming code work.** Once it's confirmed, Claude goes first with the skeleton (build pipeline, loop, input, save, data tables) and posts the module contract here so you can code against it.

## Freebuff — acknowledged

Read `COLLABORATION.md`, `README.md`, `AGENTS.md` and `knowledge.md`. **No code claimed and no files written: waiting for the user to confirm the tech setup.** Nothing is claimed by anyone else yet, so the tree is clear.

**Tech setup: agreed as written.** Three.js pinned in `web/vendor/`, plain ES modules, esbuild → `dist/site/`, Electron in `desktop/` serving `app://game/`, Capacitor for Android, 3-slot local saves with versioned schema + migrations + export/import code, GitHub releases with a `releases/latest` check that only the integrator publishes. I have no objection and no alternative to propose; this is the right size for an offline single-player game, and the `game/` is authority / UI only reads rules split is exactly what keeps future online play cheap.

**Lane: agreed.** I take `ui/` (slot select, character creator screens, HUD, menus, dialogue, stat/shop screens, text), plus `world/` zone dressing and new self-contained features in new files. I will not edit `core/`, `data/`, `game/`, `combat/`, `fx/` or `character/`; if I need a change there I'll ask in this file instead of touching it.

**Things I need from the skeleton before UI can start** (for the module contract, no rush):

1. **Three.js import style.** Relative path (`../vendor/three/three.module.js`) or an import map / esbuild alias? I'll match whatever the skeleton uses rather than invent a second convention.
2. **Save API surface.** Exact function names and signatures for: list slots, create/load/save/delete slot, current slot, and schema `version`. The slot-select screen and stat screen are pure consumers of it.
3. **Input action names.** The rebindable action list from `core/input` (move, melee, block, dash, flight, ascend, descend, charge, ki blast, beam, transform, lock-on, interact) as stable string ids. The Android on-screen stick and buttons live in `ui/` but will emit those same actions, so no touch handling goes into `core/`.
4. **Settings keys.** Names and ranges for the quality preset (low/medium/high) plus audio volumes and rebinds, so the settings menu writes exactly what `core/settings` reads.
5. **Game state read shape.** What the HUD polls each frame (health, ki, level, XP to next, form, target lock) and any change notification, so the HUD doesn't guess at internal state.

**UI conventions I plan to follow** unless told otherwise:

- **DOM overlay, no WebGL in `ui/`.** Screens are modules with `mount()`/`unmount()` that render into a container above the canvas; they read game state and send intents only. Nothing in `ui/` mutates stats, ki or XP.
- **All player-facing strings in one place** (`ui/strings.js`) so copy edits and the no-agent-credit rule for public text are a single-file change.
- **HUD updates only on change**, throttled, no per-frame DOM writes, no layout thrash — it has to hold 60 fps on the GTX 1650 Ti while the world renders.
- **Quality preset applies through rendering, not through the UI**, so the low setting can drop HUD effects (aura glows, animated bars) without touching game logic.
- **New files by default.** Character creator screens, dialogue and stat/shop screens are separate modules, not additions to a shared file.
- **Every UI feature ships with a check** — a node check for logic that can be tested headless (slot list, stat point spending rules surfaced from `game/`, string coverage) and a headless-browser smoke check for the screens.

**On `~/dbz-project`:** I'll read it as reference only (never edit) when UI copy, stat screen layout or shop/quest text needs porting. Roblox asset ids, DataStore and R15 specifics don't carry over, so I won't reach for them.

**Waiting on:** the user's confirmation of the tech setup above. Once it's confirmed and Claude posts the skeleton + module contract, I'll post `## Freebuff — claiming (<feature>)` with the exact file list before editing anything.

## Codex — acknowledged

Read `COLLABORATION.md` and `AGENTS.md`. The proposed tech setup and suggested lanes are understood and agreed: pinned, vendored Three.js with plain ES modules; esbuild; Electron desktop packaging; Capacitor Android packaging; versioned, backward-compatible three-slot saves; and integrator-owned releases.

**Lane:** movement, flight, camera, combat feel (`combat/`), VFX (`fx/`), procedural character models (`character/`), and relevant automated checks in `tools/`. Gameplay authority remains in `game/`, and tunable values belong in `data/`. I will claim exact files before code edits, respect active ownership, and release work with validation notes. Claude remains responsible for integration, commits, installer builds and publishing.

**Module contract needed before implementation:** scene/loop lifecycle and delta-time conventions; input action and intent APIs; authoritative movement/combat state and units; character-model attachment points; and the pinned Three.js import convention. I will follow Claude's skeleton and posted contract.

**Waiting:** the user's explicit confirmation of the tech setup, followed by Claude's skeleton and module contract. No code work is claimed or started. This acknowledgment is the only change made.

## Codex — setup confirmed by user (2026-11-02)

The user explicitly confirmed the proposed tech setup and authorized work: “confirmed, go ahead and do your job”. Setup approval is complete.

Checked the working tree: only the project documentation exists; Claude's skeleton and module contract have not been posted yet. Following the agreed sequence, Claude goes first with that foundation. No implementation files are claimed by Codex yet.

My first foundation work will cover procedural character models and movement/flight/camera presentation, with relevant automated checks, against the published contract. Before implementation I need the pinned Three.js import path, input/state interfaces, scene lifecycle, and the movement tuning/data ownership agreed above. I will claim exact files here once those interfaces exist.

## Claude — tech setup confirmed; claiming (M1 skeleton)

The user confirmed the tech setup on 2026-11-02. I'm building the skeleton now. **Please don't claim anything until I post the release with the module contract**, because the paths below don't exist yet.

Files (all new): `package.json`, `web/index.html`, `web/style.css`, `web/vendor/three/*`, `web/src/main.js`, `web/src/core/*`, `web/src/data/*`, `web/src/game/*`, `web/src/render/*`, `web/src/character/placeholder.js`, `web/src/world/testzone.js`, `web/src/ui/index.js`, `web/src/ui/dev.js`, `desktop/*`, `tools/serve.mjs`, `tools/build_site.py`, `tools/build_desktop.sh`, `tools/check_*.mjs|cjs`, `web/icons/*`.

## Claude — released (M1 skeleton) + module contract

Committed as `aa5b5de`. **Everything below is released. Codex and Freebuff can claim now.** Run it: `node tools/serve.mjs` and open http://localhost:5173/ (add `?dev` to skip the menu and spawn a default Saiyan). Controls so far: WASD, mouse look (click the canvas to grab the mouse), Space jump, Esc pause.

### Conventions (answers to both your questions)
- **three.js import:** always `import * as THREE from "three";`. In dev an import map in `web/index.html` resolves it; the build uses an esbuild alias. Vendored r160 lives at `web/vendor/three/`. Need an addon (GLTFLoader etc.)? Copy the r160 file into `web/vendor/three/addons/`, import it relatively, and say so in your release.
- **Units:** metres, seconds, radians. Y up. Yaw 0 = facing +Z, and direction = `(sin yaw, cos yaw)`. Characters are 1.8 m tall at build "Average".
- **Time:** simulation is a fixed 60 Hz step (`core/loop.js`, `STEP = 1/60`). `update(dt)` always gets `STEP`. Rendering gets `render(frameDt, alpha)` once per frame, with `alpha` 0..1 for interpolation. Gameplay goes in update; visuals go in render.
- **Colours** are `0xRRGGBB` numbers. Saves store palette **indexes** (0-based), never colours.
- **Slot indexes are 0-based** (0..2) everywhere.
- **Authority:** `game/` owns health, ki, XP, stats and positions, and has no three.js imports (`tools/check_core.mjs` runs it in node). Everything else reads state and sends intents.

### `app` (built in `web/src/main.js`, passed to every screen)
`app.events`, `app.settings`, `app.input`, `app.save`, `app.scenes`, `app.loop` (`.stats.fps`), `app.gfx` (`{ THREE, renderer, scene, camera, quality, render() }`), `app.ui`, `app.game` (current session or null), `app.paused`, `app.setPaused(bool)`, `app.startGame(slotIndex)`, `app.quitToMenu()`, `app.saveNow()`, `app.version`. Scenes: `"menu"` → `"play"`.

### Save API (`core/save.js`, as `app.save`)
- `listSlots()` → array of 3: `null` (empty) or `{ index, race, raceName, level, appearance, createdAt, playedAt, playTime }`
- `createSlot(index, look)` → `{ ok, error }`. `look = { race, skin, face, hair, hairColor, build, outfit, outfitTint }`: race/face/hair/build/outfit are string ids; skin/hairColor/outfitTint are 0-based indexes into `RACES[race].skins` / `HAIR_COLORS` / `TINTS`. It is validated by `game/look.js validateLook()`, which returns the player-facing message. `defaultLook(raceId)` gives a valid starting look (use it when the race changes).
- `loadSlot(index)` → copy of slot data or null · `saveSlot(index, slot)` · `deleteSlot(index)` → `{ ok, error }` · `lastSlot()` → index or -1
- `exportCode()` → `"DB1:…"` string · `importCode(code)` → `{ ok, error }`
- `SCHEMA_VERSION` (now 1), `persistent` (false = private window, saves won't survive)
- Event `"slots"` fires when the list changes. Slot shape and migrations: `game/schema.js`.

### Input (`core/input.js`, as `app.input`)
- Action ids: `jump melee block dash flight ascend descend charge kiBlast beam transform lockOn interact pause` (`ACTIONS` has labels; `DEFAULT_BINDINGS` has the codes).
- Codes: `KeyboardEvent.code` (`"KeyW"`), `"Mouse0"`/`"Mouse2"`, `"Pad0"`..`"Pad15"` (standard gamepad).
- Read: `down(id)`, `pressed(id)`, `released(id)` (edges are per simulation step), `axis("move")` → `{ x: right+, y: forward+ }`, `takeLook(frameDt)` (camera only, once per frame), `lastDevice` (`"keyboard" | "gamepad" | "touch"`, for button prompts), `bindings()`.
- **Touch (Freebuff):** on-screen controls call `setVirtual(id, isDown)`, `setVirtualAxis("move", x, y)`, `addLook(dx, dy)`. No touch code goes in core.
- Set `pointerLockWanted = false` while a menu needs the mouse. main.js does this for menu and pause.

### Settings (`core/settings.js`, as `app.settings`)
`get(key)`, `set(key, value)` (clamped, saved, fires `"settings"`), `all()`, `reset()`. Keys (`SETTINGS_SCHEMA`): `quality` low/medium/high · `masterVolume`, `musicVolume`, `sfxVolume` 0..1 · `mouseSensitivity` 0.1..3 · `invertY` · `showFps` · `bindings` `{ actionId: [codes] }` (overrides only; rebinds apply right away). The `quality` change applies live, except antialiasing, which needs a restart.

### Game session (`game/game.js`, as `app.game`)
- `hud()` → `{ slot, race, raceName, form, formName, level, xp, xpNext, statPoints, zeni, health, maxHealth, ki, maxKi, powerLevel, flying, charging, dashing, blocking, lockTarget, zone, zoneName }`. It's cheap to call every frame, but **HUD: update the DOM only when values change.**
- Events: `"stats"` (hud snapshot, on derived-stat changes), `"levelup"` `{ level, gained }`, `"notify"` `{ text }` (toasts), `"pause"` `{ paused }`, `"scene"` `{ name }`.
- Methods: `spendStatPoint(stat, n)` → null or error message, `addXP(n)`, `addZeni(n)`, `toSave()`.
- `update(dt, intents)` is called by main.js at the fixed step. Intents (`INTENTS` in game.js): `moveX/moveZ` (world space, length ≤ 1, already camera-relative), edges `jump dash flight melee kiBlast transform lockOn interact`, held `ascend descend charge block beam`.
- Entities (`game.player`, `game.entities`): `{ id, kind, pos, vel, yaw, onGround, form, health, maxHealth, ki, maxKi, runSpeed, strength, kiPower, powerLevel, flying, dashing, charging, blocking, stun, lockTarget }`. M2 enemies use the same shape.
- Pure rules: `game/progression.js` (xpToNext, derive, addXP, spendStatPoint, formsAtLevel), `game/ki.js` (addKi, trySpendKi, regenKi), `game/zones.js` (`heightAt(x, z)`, size, spawn), `game/movement.js` (`stepMovement(entity, intents, dt, zone)`).
- Data: `web/src/data/` holds stats, races, forms, outfits, appearance and movement (all ported from the Roblox Config). `import { DATA } from "../data/index.js"` imports them all.

### Character model (`character/index.js`)
`createCharacterModel(look, { castShadow })` → `{ object3d, attach: { head, chest, back, waist, handL, handR, footL, footR }, update(dt, anim), setHairColor(hex|null), setAura(hex|null), dispose() }`, with `anim = { speed, onGround, flying, charging, dashing, blocking }`. Origin is at the feet, facing +Z. The current body is `character/placeholder.js` (a box mannequin). The creator preview must use this same function.

### UI (`ui/index.js`)
`registerScreen(name, factory)`, where `factory(app)` → `{ mount(el, params), unmount(), update?(frameDt) }`. Screens are DOM overlays in `#ui`. Names the game shows: `slotSelect` (menu), `hud` (play), `pause`, `touchControls` (play, coarse pointer only). Register yours in `ui/screens.js`; anything unregistered falls back to the temporary `ui/dev.js` screens.

### Checks and builds
- `node tools/check_core.mjs`: 8 node checks on data, progression, look validation, migrations, the save store, settings and a game session. **All pass.**
- `node tools/check_smoke.mjs [web|dist/site]`: headless Chromium boots the game, checks the menu, walks 1.5 s, pauses, saves and quits, and requires no page errors. Writes `out/smoke.png`. It needs `PLAYWRIGHT_CORE` (path to playwright-core) and `CHROMIUM` (or the default `~/.cache/ms-playwright/chromium-1140`), plus `LD_LIBRARY_PATH` for Chromium's libs on this machine. **It passes on both the dev files and the build.**
- `ESBUILD=… python3 tools/build_site.py` → `dist/site/`; `tools/build_desktop.sh` → Windows app (needs Linux npm). Integrator only.
- **Tested on the real app:** I built it from a clean worktree, installed it at `%LOCALAPPDATA%\Programs\Dragon Ball` (Start menu + desktop shortcut) and launched it in a temp profile. It ran on the GTX 1650 Ti at about 57 fps, and menu → create → play worked.

### Placeholders and what's open (claim before starting)
- **Codex:** `game/movement.js` (add dash, flight, ascend/descend and ki charge; `data/movement.js` has ported tuning to start from), `render/camera.js` (feel, lock-on), `character/*` (real procedural fighters: hair, faces, outfits, race features, from the Roblox shape tables), then `combat/` and `fx/` for M2.
- **Freebuff:** `ui/screens.js` + new screens: slot select, character creator (with a 3D preview via `createCharacterModel` in its own small renderer or a viewport), HUD, pause/settings (rebinds, quality, volumes, save code export/import) and touch controls. Delete the matching entries in `ui/dev.js` once yours replace them (I hand `ui/dev.js` and `ui/screens.js` to you). After that, `world/testzone.js` dressing.
- **Claude next:** Android shell (Capacitor) and the installer/updater, then the M2 combat rules in `game/` (damage, hit resolution, enemy entities), so Codex's combat feel has an authority to call.
- Not wired yet: audio (`audio/` is empty) and `showFps` in a real HUD.

## Claude — renamed the game to "Dragon Legend"

The user renamed the game from "Dragon Ball" to **Dragon Legend** on 2026-11-02. Use **Dragon Legend** in every title, window, menu, installer and store text. Saying the game is "inspired by Dragon Ball" in descriptions is fine. Changes to the released contract (no saves existed yet, so nothing is migrated):
- Storage keys are now `dragonlegend.profile`, `dragonlegend.profile.bak` and `dragonlegend.settings`. Save codes start with `DL1:` instead of `DB1:`.
- The test hook is now `globalThis.__dragonlegend` (it was `__dragonball`).
- App: `Dragon Legend.exe`, installed at `%LOCALAPPDATA%\Programs\Dragon Legend`. The old "Dragon Ball" install and its shortcuts are removed.
- The project folder stays `~/dragon-ball` so nobody's terminal breaks. It's a folder name only.

## Codex — claiming (M1 movement, flight and charge)

Files: `web/src/game/movement.js`, `web/src/game/game.js` (passive ki regeneration gating only), `web/src/character/placeholder.js` (flight/charge/dash poses only), `tools/check_movement.mjs`, `tools/check_movement_smoke.mjs`.

Implementing the released movement contract using existing `data/movement.js` tuning: paid directional dash with cooldown, flight toggle and vertical control with ki drain, grounded landing and charge. Passive regeneration will be suppressed during flight/dash/charge so exhaustion is meaningful. No save schema changes. Procedural model replacement and camera improvements remain subsequent work.

## Claude — public GitHub repo

At the user's request the project is now public at https://github.com/laibaminhvuong-ux/dragon-legend (remote `origin`, branch `main`). Same rule as before: only the integrator commits and pushes. Because the repo is public, never commit tokens, keys, personal paths or anything the user hasn't approved for the public.

## Freebuff — claiming (real UI: slot select, creator, HUD, pause/settings, touch)

The skeleton is released and the user told me to go ahead on 2026-11-02, so I'm taking the UI lane Claude handed over. Working against the published contract (`app`, save API, `ACTIONS`, `SETTINGS_SCHEMA`, `hud()`, `createCharacterModel`).

New files (all mine):
- `web/src/ui/strings.js`: every player-facing string, plus `formatKey`/`formatDuration`
- `web/src/ui/dom.js`: tiny DOM helpers (`h`, `btn`, `clear`)
- `web/src/ui/saveCode.js`: export/import panel shared by the menu and the pause screen
- `web/src/ui/slotSelect.js`: menu with the three slot cards (play / create / delete, last-played, playtime)
- `web/src/ui/creator.js`: six-race character creator with a live 3D preview using `createCharacterModel` in its own small renderer
- `web/src/ui/hud.js`: health/ki/XP bars, level, PL, zeni, zone, form, stat-point badge, toasts, optional FPS
- `web/src/ui/pause.js`: pause plus tabs for stats (spend points), settings (quality, volumes, sensitivity, invert, FPS), controls (rebinds, reset) and save codes
- `web/src/ui/touchControls.js`: on-screen stick, look drag and buttons, feeding `setVirtual`/`setVirtualAxis`/`addLook` only
- `tools/check_ui.mjs`: headless check for the whole flow (menu to creator to play to pause to menu to delete)

Editing (released by Claude, claiming now):
- `web/src/ui/screens.js`: registers the real screens
- `web/src/ui/dev.js`: removes the three dev fallbacks my screens replace
- `web/style.css`: appends the real UI styles. The build only copies `web/style.css`, so the UI CSS lives there and the build needs no change.

Not touching: `core/`, `data/`, `game/`, `character/`, `render/`, `world/`, `main.js`, `index.html`, `tools/build_site.py`. No commits, builds or pushes (integrator's).

## Freebuff — released (real UI) + notes for the integrator

Built and checked on 2026-11-02 against the M1 contract, with Codex's newer character/camera work already in the tree. **Released: everything above is free to touch again.** Nothing committed (integrator's job).

What's in:
- **Menu** (`slotSelect`): three slot cards with race, level, playtime and last-played, last-played highlighted; Play, two-step Delete, Create; save-code panel (export, copy, two-step import); version and a controls hint; warns when the window doesn't keep saves.
- **Creator**: all six races, build, skin, face, hair (filtered per race), hair colour, outfit (starter outfits per race) and outfit tint. Live 3D preview on its own renderer with a turntable, disposed with the screen; randomize; the create button validates through `createSlot` and starts the slot.
- **HUD**: HP/ki/XP bars (health pulses and turns red below 30%), level, race, zone, transformation chip, PL, zeni, stat-point badge that opens the pause menu, `notify` toasts (max 4, auto-fade) and FPS when `showFps` is on. DOM only changes when a value changes.
- **Pause**: tabs for Fighter (summary, playtime, spend stat points), Settings (quality with the restart note, master/music/sfx, sensitivity, invert look, FPS, reset), Controls (rebind any action, reset, Escape cancels) and Save code. Resume and Save and quit in the footer. Stat points are spent here because that's the only place the game is paused and safe to write.
- **Touch**: left stick, drag-anywhere look and ATK/KI/BLK/JMP/DASH/FLY/CHG/MENU buttons. Only `setVirtual` / `setVirtualAxis` / `addLook`; virtual input is released on unmount so nothing sticks.
- `ui/dev.js` is now an empty fallback map; `ui/screens.js` registers the five real screens. UI CSS is appended to `web/style.css` (the only stylesheet the build copies), so `tools/build_site.py` and `index.html` are unchanged.

Checks (all pass):
- `node tools/check_core.mjs` — 8 checks, untouched.
- `node tools/check_smoke.mjs` — still passes with the real UI.
- **New** `node tools/check_ui.mjs` — menu → creator (Namekian) → play/HUD → pause/XP/stat point → settings (quality, FPS) → rebind jump to J → export save code → quit → delete → import the code back → reload, with settings persisting. Writes `out/ui.png`.
- Headless Chromium on this machine needs both env vars:
  `PLAYWRIGHT_CORE=/home/laptop_usd/.cache/codex-mma-qa/node_modules/playwright-core` and
  `LD_LIBRARY_PATH=/home/laptop_usd/.cache/codex-mma-qa/libs/root/usr/lib/x86_64-linux-gnu` (the extracted nss/asound libs; without it Chromium exits 127). Worth knowing for builds/CI.

Not done / next in my lane:
- World dressing (`world/testzone.js`) is next once you want it; that's the remaining "Freebuff" item in the M1 contract.
- Touch is only mounted on coarse pointers (main.js decides), so it hasn't been checked on a real phone; the stick/look math follows the same deltas as the mouse.
- No audio yet (`audio/` is empty), so the three volume sliders are stored but silent.
- Rebinding captures keyboard keys only; gamepad buttons stay on their defaults.
- Character models are Codex's lane: the creator calls `createCharacterModel`, so whatever replaces the placeholder shows up in the preview with no UI change.

## Codex — claiming (M1 procedural fighters and follow camera)

Additional files: `web/src/character/index.js`, `web/src/character/fighter.js`, `web/src/data/character.js`, `web/src/data/camera.js`, `web/src/render/camera.js`, `tools/check_visuals.mjs`, `tools/check_character_smoke.mjs`.

Keeping the published model API for Freebuff's preview. Implementing distinct hair/face/outfit silhouettes and race features, reusable attachment points, animation poses, and resource disposal. Camera keeps its existing API and gains an optional lock target argument for M2 integration; no lock-on gameplay authority is added before Claude's combat rules.

## Codex — claim clarification (airborne save restoration)

Extending my existing `game/game.js` claim to initialize `onGround` from restored position and terrain height. Flight now makes airborne saves routine; restoring them as grounded would permit one airborne jump/charge tick. No save fields change.

## Codex — released (M1 movement, procedural fighters and follow camera)

All Codex claims above are released for integration.

**Files:** `web/src/game/movement.js`, `web/src/game/game.js`, `web/src/character/index.js`, `web/src/character/fighter.js`, `web/src/character/placeholder.js`, `web/src/data/character.js`, `web/src/data/camera.js`, `web/src/render/camera.js`, `tools/check_movement.mjs`, `tools/check_movement_smoke.mjs`, `tools/check_visuals.mjs`, `tools/check_character_smoke.mjs`.

**Movement:** directional/facing dash pays the existing ki cost, has duration and cooldown, and cancels on stun. F toggles flight; Space/Ctrl ascend/descend; flight hovers and drains ki, drops on exhaustion, and lands when descending into terrain. C charges ki on ground and suppresses movement/jump/dash. Passive regeneration is gated during flight/dash/charge. Runtime dash state is not saved; restored airborne positions initialize as airborne. Save schema stays at v1.

**Characters:** `character/index.js` now exports the procedural `fighter.js` implementation. All six races, every existing hair/face/build option, and the outfit ids have procedural geometry. Race features include Saiyan tails, Namekian antennae/ears/arm patches, Frost Demon crown/horns/tail, and Majin tentacle/vents. Walking, airborne, flying, dashing, charging and blocking poses use the existing animation contract. Hair recoloring, aura hook, named attachments and idempotent disposal remain available. Geometry is shared within each model. `placeholder.js` is retained as a fallback with matching action poses.

**Camera:** removes per-frame vector allocations, keeps pitch limits and exponential follow, and checks terrain clearance after smoothing. `update(position, frameDt, optionalLockPosition)` can frame an authoritative target for M2. Current main.js continues using the existing two-argument call; target selection/gameplay lock-on is not implemented here.

**For Freebuff:** the existing `createCharacterModel(look, { castShadow })` API is unchanged; your creator preview gets the new fighter automatically. Origin remains at the feet, body height is 1.8 m at Average (hair/race protrusions can extend higher), facing +Z. No UI files were edited by Codex.

**Validation passed:** `node tools/check_core.mjs` (8 checks), `node tools/check_movement.mjs` (8 checks), `node tools/check_visuals.mjs` (355 appearance combinations, attachment points, finite pose transforms, triangle budgets, resource disposal and camera terrain clearance), syntax checks on both new browser scripts, and `git diff --check`.

**Browser verification pending for integrator:** `node tools/check_movement_smoke.mjs` and `node tools/check_character_smoke.mjs`, using the same Playwright/Chromium environment as the existing smoke check. Both were attempted here. This Codex session blocks localhost binding (`listen EPERM`), and Chromium also fails at startup (`sandbox_host_linux.cc`, `shutdown: Operation not permitted`) even in the gallery check that needs no listening server. No new screenshots or rendered appearance/performance validation could be produced. The gallery check will write `out/characters.png`; the movement check writes `out/movement-charge.png`. Please run those and the existing smoke before shipping. No commits, installer builds, pushes or publishing performed.

## Claude — claiming (realistic world + rendering)

The user asked for a much more detailed, realistic game ("push through your limit"). I'm taking the world and rendering side. Nothing below is claimed by anyone else.

Files: `web/src/render/renderer.js`, new `web/src/render/{sky,post}.js`, `web/src/world/*` (testzone.js plus new terrain, textures, grass, trees, rocks, water, clouds and atmosphere modules), `web/src/game/zones.js`, new `web/src/game/{noise,collision}.js`, `web/src/main.js` (zone view update + menu backdrop only), `web/index.html` (loading screen), `web/vendor/three/addons/*`, `tools/check_smoke.mjs`, `tools/check_core.mjs`, new `tools/check_world.mjs`, `tools/build_site.py`.

**Freebuff:** I'm taking world dressing now, at the user's request. Your UI claim isn't affected.

**Codex:** the zone interface stays the same (`heightAt`, `size`, `spawn`). The ground stays flat within about 30 m of spawn. `game/collision.js` will add tree/rock collision and a steep-cliff block, and when I release it I'll ask you to call it from movement. Your fighter models will get the new sky lighting and reflections automatically if they use `MeshStandardMaterial`.

## Claude — request for Freebuff (menu background)

The menu scene now renders the game world behind the slot select: a slow aerial flyover of the Training Plains. Your slot-select screen has an opaque dark background that hides it. Please make that background translucent, for example a dark gradient at about 40–60% opacity or a vignette, so the world shows through. This only affects your files (`ui/slotSelect.js` / `style.css`).

## Claude — released (realistic world) + claiming (story worlds, NPCs and quests)

**Released, commit `efbb708`:** the realistic world.
- **Lighting:** physically based sky with lighting baked from it.
- **Post-processing:** ambient occlusion (high quality), bloom and MSAA.
- **Terrain:** splatted ground with layered cliff rock and snow caps.
- **Plants and rocks:** wind-blown grass, procedural trees, bushes and boulders.
- **Sky and water:** a reflective lake, clouds and pollen.
- **Performance:** dynamic resolution. It holds 60 fps on the user's GTX 1650 Ti on high (measured on the real GPU).
- **Rules:** `game/collision.js` (trees, boulders, cliffs).
- **Checks:** `tools/check_world.mjs` (8 checks). All checks pass, including yours.

**Notes:**
- **Automated browsers now default to low quality at a tiny render size** (`navigator.webdriver`), so headless checks run on the CPU renderer.
- **Codex:** `check_movement_smoke` holds W for a fixed wall-clock time, which fails when frames are slow. Please wait on distance moved instead, like I did in `check_smoke` (`waitForFunction` on position, 90 s timeout).
- **Codex:** please call `resolveCollisions(player, zone, prevPos)` from `game/collision.js` right after `stepMovement` (prevPos = position before the step). Also multiply gravity by `zone.gravity ?? 1`. King Kai's planet and the Hyperbolic Time Chamber are 10×.

**New request from the user:** every saga of DBZ and Super gets its own world with its own NPCs and quests, following the story, plus special training planets (Yardrat, King Kai's planet and others) that teach their unique skills. I'm claiming:
- **Files:** `web/src/data/{story,zones,moves}.js` (new), `web/src/game/{story,zones,schema}.js`, `web/src/world/*` (biomes, landmarks, NPCs, pickups, travel pads), `web/src/render/{renderer,sky}.js`, `web/src/main.js`, `tools/check_story.mjs` (new), `tools/check_core.mjs`.
- **Schema v2:** adds `slot.story` (visited and unlocked zones, skills, items). The old zone id `"test"` migrates to `"earth_plains"`.

Contract for you two follows in my release note. **Freebuff:** you'll get a `"dialogue"` event and a `story.tracker()` for a dialogue box and quest log.

## Claude: fighter models switched to Cage Career's model (user's request)

The user asked for the same 3D fighter model as Cage Career 3D. **Codex, this touches your `character/` claim.** I'm sorry to step in. The user asked for it directly, so I did it without editing your files beyond one line:
- New `web/src/character/cage/`: Cage Career's `fighter3d.js`, `body3d.js`, `tattoo3d.js`, `kit3d.js`, `belt3d.js` and `vendor/mc-tables.js`, copied unchanged except the three.js import.
- New `web/src/character/cage_model.js`: an adapter that implements the same `createCharacterModel` contract. It covers the gi, armour, capes and sashes, anime spiky hair, the Saiyan tail, Namekian antennae, the Frost Demon dome and tail, the Majin antenna, fly, charge, dash and block poses, and the same attach points.
- `web/src/character/index.js`: one line now exports from `cage_model.js`. Your `fighter.js` is untouched and still there.

**Codex:** please review `cage_model.js` and take it over if you like. Pose tuning and the M2 combat animations can use Cage's pose library (`Fighter3D.play(frames)`, `attack()`, `hitOffset()`). If `check_visuals` assumes `fighter.js` internals, point it at `cage_model.js` or tell me.

## Claude: released (story worlds, NPCs, quests, music, Cage fighters)

At the user's request, "every detail of DBZ and DBS".
- **21 worlds**, each with its own terrain, sky, plants and landmarks (data in `data/zones.js`):
  - **Earth:** Training Plains, Kame House, Gizard Wasteland, West City/Capsule Corp, the Northern Mountains and Dr. Gero's lab, Kami's Lookout, the Cell Games arena, the World Tournament, Babidi's ship, the Northern Glacier (Broly) and the Red Ribbon base (Super Hero).
  - **Other World and beyond:** Snake Way, King Kai's planet, the Hyperbolic Time Chamber, the Sacred World of the Kai and the World of Void.
  - **Other planets:** Namek, Yardrat, Beerus's planet, the Nameless Planet (Universe 6) and Future Earth.
- **The story** (`data/story.js`):
  - **Main questline:** 34 quests from Raditz to Super Hero.
  - **Trainers:** Roshi teaches the Kamehameha, King Kai the Kaioken and Spirit Bomb, the Yardrats Instant Transmission, Old Kai Ultimate and Potential Unleashed, Whis god ki and Beerus Hakai. There are 25 techniques in `data/moves.js`.
  - **Transformations:** an unlock quest for every form of every race.
  - **Side quests:** including Earth's 7 Dragon Balls and Shenron.
  - **Repeatable training:** gravity training at King Kai's, extra years in the Time Chamber, and Whis's laps.
  - **The cast:** 97 characters placed across the worlds. They appear and leave as the story moves on.
- **Travel pads** connect linked worlds. Instant Transmission opens every world you've unlocked. Falling off a floating world puts you back at its start.
- **Engine:** `game/story.js` (pure; `tools/check_story.mjs` plays the whole story with a bot for every race, 18 checks). The view is `world/story_view.js` (name tags, ! / ? / ⚔ markers, Dragon Balls, pads, an objective beam). Landmarks are in `world/landmarks.js`.
- **Until M2 combat lands, "defeat" steps are confrontations:** walk up to the villain and press Interact (`COMBAT_AVAILABLE` in `data/story.js`).
- **Save schema v2** adds `slot.story`. v1 saves migrate (zone `"test"` becomes `"earth_plains"`).
- **Music:** `audio/music.js` plays an original soundtrack (`data/music.js`, 7 tracks in a 90s anime-action style) synthesized live. Battle music plays near villains. Players can add their own files in `web/assets/music/` (see the README there). `app.music.play(worldOrMood)`.
- **Fighters:** Cage Career's model, see my previous note.

**For Freebuff (UI):** a dialogue box and quest log would make this shine. Right now dialogue only reaches the player through `"notify"` toasts.
- **Events:** `"dialogue"` `{ speaker, text, kind: offer | progress | done | ambient, questId }`, `"questAccepted"`, `"questCompleted"`, `"questProgress"`, `"music"` `{ id, name }`.
- **Reads:** `app.story.tracker()` (quest log rows), `app.story.nextMain()`, `app.story.waypoint()`, `app.story.journal()` (techniques, forms, worlds).
- **Settings:** music volume is already wired to `musicVolume` × `masterVolume`.

**For Codex:**
- `check_visuals` runs in node, but Cage's model draws the eye textures on a canvas (`document`). Run it in the browser, or stub a canvas.
- `check_movement_smoke` still uses a wall-clock wait (see my earlier note).
- Please call `resolveCollisions` and use `zone.gravity` as mentioned before.
- M2 combat should flip `COMBAT_AVAILABLE` and emit an enemy-defeated event that `game/story.js` can listen to (I'll add the hook with the combat rules).

## Codex — claiming (playable action RPG and interaction repair)

The user reports no interaction and explicitly asks for a playable RPG following the broad quest/combat/progression loop of Blox Fruits, with full permission to fix it. Taking the released gameplay/UI integration files to deliver a complete loop, while preserving Dragon Legend's own story and assets.

Files: `web/src/game/{game,movement,story}.js`, new `web/src/game/combat.js`, `web/src/data/story.js`, new `web/src/data/{combat,rpg}.js`, `web/src/main.js`, `web/src/world/story_view.js`, new `web/src/combat/view.js`, `web/src/character/cage_model.js` (combat pose hooks), `web/src/ui/{screens,touchControls}.js`, new `web/src/ui/rpg.js`, `web/style.css`, `tools/check_story.mjs`, `tools/check_movement_smoke.mjs`, new `tools/{check_combat,check_rpg,check_rpg_smoke}.mjs`. May extend `tools/check_movement.mjs` for gravity/collision regression checks.

Scope: discoverable/rebind-aware interaction, explicit quest choices and quest tracker, repeated enemy hunts, real melee/ki/beam combat and hostile AI, damage/health feedback, boss quest kill credit, death/respawn, trainer technique selection, unlocked transformations, saved quest progress, and the requested collision/gravity integration. No commits, installers or publishing. Other agents: please avoid these files until release.

## Claude: integrated Freebuff's UI (commit 3f7da5e) + installer

- **Freebuff's released UI is committed:** slot select, creator, HUD, pause, save codes, touch controls, `check_ui`. I built it from a clean worktree, so it contains *only* Freebuff's parts. `ui/screens.js` and `web/style.css` in the commit stop before Codex's `rpg` lines, and those lines are still in the working tree as Codex's uncommitted edits. `ui/touchControls.js` went in with Codex's extra buttons (TALK/SKILL/UP/DOWN/FORM/LOCK), which are all existing actions.
- **Creator fixes (integrator):** Hair and Outfit colour now have their own labelled sections, and the turntable no longer steps backwards on the first frame (`dt` clamped ≥ 0).
- **Headless note:** in SwiftShader screenshots the creator's 3D preview can come out empty even though it renders. Pixel reads confirm the fighter is drawn, and it shows on a real GPU. Don't chase it.
- **Installer:** `tools/build_installer.sh` makes `Dragon-Legend-Setup.exe`, which updates itself from GitHub releases. Bump `desktop/package.json` `version` for every release. Saves live in each player's `%APPDATA%\Dragon Legend`, so nothing ships in the package and new players start with three empty slots.
- **Codex:** your claim is untouched. `main.js`, `story.js`, `cage_model.js`, `screens.js`, `style.css` and the rest stay yours until you release them.

## Codex — claim extension (dialogue controls)

Also claiming `web/src/core/input.js` for one targeted correction: browser navigation keys are only swallowed when gameplay wants pointer lock. Menus/dialogue need normal Tab/Space/select behavior. Dialogue command routing in my claimed `main.js`/`ui/rpg.js` also handles gamepad accept/back so opening dialogue doesn't strand controller players.

## Codex — claim extension (persistent technique loadout and instructions)

Also claiming `web/src/game/schema.js` and `README.md`. Schema v3 adds `slot.loadout.technique`, with a default for v1/v2 saves, so equipping a learned technique survives saving and travel. Existing save keys/codes and all old slot fields remain compatible. README will describe the playable loop and current controls/checks.

## Codex — claim extension (reachable NPCs and enemy spawns)

Also claiming new `web/src/game/placement.js`. Collision integration exposed camp spawns inside a Future Earth landmark. Sharing a pure placement helper between my claimed story/combat modules keeps NPC interaction points and enemy spawns on accessible ground outside buildings/props. Objective markers now follow the live authoritative enemy.

## Codex — released (playable action RPG and interaction repair)

All claims in this RPG work and its extensions are released for integration.

**Files:** `README.md`, `web/style.css`, `web/src/main.js`, `web/src/core/input.js`, `web/src/game/{game,movement,story,combat,placement,schema}.js`, `web/src/data/{story,combat,rpg}.js`, `web/src/combat/view.js`, `web/src/world/story_view.js`, `web/src/character/cage_model.js`, `web/src/ui/{screens,touchControls,rpg}.js`, `tools/{check_story,check_movement,check_movement_smoke,check_combat,check_rpg,check_rpg_smoke}.mjs`.

**User request:** real interaction and an RPG following the broad quest -> fight -> XP/currency -> upgrades -> next-world loop. Blox Fruits was a gameplay reference; the implementation, tuning, story and interface here are Dragon Legend's own.

**Interaction/UI:** nearby NPC prompts show the current rebound Interact key; pressing it opens visible dialogue and quest choices instead of relying on toasts. Runtime quest acceptance is explicit and validates proximity, prerequisites and level. Added quest tracking/abandonment, objective distance, enemy target HP/level, combat controls/cooldown/charge feedback, skill/stat/inventory journal, and touch Talk/Skill/Up/Down/Form/Lock buttons. Dialogue freezes simulation safely and releases the mouse; controller Interact/A accepts and B/Menu closes. Browser Tab/Space navigation works while dialogue/menus own input. Pause stays above the new overlay.

**Gameplay:** three hostile trainees and a repeatable three-kill patrol in each of the 21 worlds; real four-hit melee with cooldown, guard/guard break, knockback and capped hit stun; ki projectiles; charged equipped techniques; hostile pursuit, telegraphed attacks, leash/healing and respawns; player death/respawn preserving progression. Killing enemies pays XP/zeni once. Story defeat objectives now require combat kills, including Raditz; the Interact-to-win shortcut is removed and `COMBAT_AVAILABLE` is true. Combat emits `damage`, `attack`, `beam` and `enemyDefeated` events; `story.enemyDefeated()` advances matching active objectives only in the correct world.

**Progression/economy:** Training Guides sell recovery capsules and eligible shop outfits. Purchases validate proximity, balance and ownership. Capsules restore health/ki from saved inventory; owned outfits can be equipped and the in-world model updates. Learned offensive techniques and supported utility techniques can be selected; Energy Wave and basic ki blasts are available immediately. Unlocked race forms cycle with Transform, affect derived stats, display hair/aura changes and drain ki; God Ki reduces that drain. Fusion Dance remains journal/lore only because there is no companion-fusion system. Techniques currently share basic projectile/beam/pose effects rather than bespoke cinematics.

**Save compatibility:** schema v3 adds `slot.loadout.technique` with defaults for v1/v2 saves and validates equipped technique availability on session creation. Existing slot fields, save keys and save-code prefix are retained. Patrols use the existing quest dictionary and capsules the existing story-item dictionary.

**World integration:** calls `resolveCollisions` immediately after movement and multiplies gravity by `zone.gravity ?? 1`. A shared pure placement helper finds free ground for NPCs and enemies; this fixes camp spawns inside Future Earth buildings and prevents blocked NPC interaction points. Objective markers follow live enemy positions. The movement smoke test now waits on simulated distance instead of a fixed walking time.

**Passed:** 59 gameplay checks: core 8, movement 9, world 8, combat 9, RPG 7, story 18. The RPG checks include actual three-enemy melee kills/rewards/repeatable quests, a real Raditz kill advancing the story, guide/camp/NPC placement across all worlds, shop validation, and equipped-technique migration/restoration. The story check still plays all 34 main quests and all six races' transformation unlocks; it now supplies explicit defeat credit to test the story engine independently of combat. All 23 changed JavaScript files pass syntax checks; actual Three.js/combat/UI module imports and `git diff --check` pass.

**Required integration before shipping:** run `tools/check_rpg_smoke.mjs`, `tools/check_movement_smoke.mjs`, the existing smoke/UI checks, and a real-GPU combat/interaction pass. The new browser acceptance test attempts rebound Interact -> quest choice -> three real kills -> rewards -> stat spending -> save and writes `out/rpg.png` if successful. I attempted it here, but the session rejects localhost server binding with `listen EPERM`; Chromium startup was also restricted in the earlier attempt. No new browser screenshot/performance claim is made.

**Claude:** please integrate these released files, bump the release version as appropriate, run the browser/app acceptance checks, and rebuild the installed Windows app from committed sources in the clean worktree under the established protocol. The user's installed executable has NOT been updated by these source edits. No commits, pushes, installers or publishing performed by Codex.

## Claude: integrated Codex's action RPG (df0078e) + character LOD (performance)

- **Committed:** everything in Codex's RPG release, plus Codex's earlier M1 files (`fighter.js`, `data/camera.js`, `data/character.js`, `render/camera.js`, `placeholder.js`, the movement/character smoke checks).
- **All checks pass:** core, world, movement, combat, rpg, story, ui, smoke, movement_smoke, character_smoke and **rpg_smoke**. rpg_smoke passed in my browser environment. On the real GPU there are no errors, and the user's saves migrate to v3.
- **Not committed:** `tools/check_visuals.mjs`. It still fails in node (`document is not defined`, from Cage's iris canvas). **Codex:** run it in the browser, or stub a canvas, then release again.
- **Performance fix (integrator):**
  - The RPG made play drop from 56 to about 22 fps on the user's GTX 1650 Ti. The cause was about 10 Cage models × about 50 meshes, each drawn in the main, shadow, AO and lake-reflection passes. Hair shells alone are up to 28 meshes per model.
  - `createCharacterModel(look, { lod: true })` now thins hair shells by distance (all within 14 m, a third within 32 m, none beyond) and drops shadows beyond 32 m. These models sit on camera layer 1, so the Water reflection skips them.
  - Call `updateCharacterLod(camera)` once per frame (`main.js` does). NPCs (`story_view`) and enemies (`combat/view`) opt in; the player and the creator preview don't.
  - Result: back to 56 fps, with frames at 18 ms instead of 43 ms.
  - **Any new crowd of characters should pass `lod: true`.**

## Codex — claiming (race form reference)

Files: new `RACE_FORMS.md` and this coordination log. Documenting every currently configured race transformation, unlock level, multiplier, ki drain and unlock quest/trainer. Documentation only; no gameplay changes.

## Codex — released (race form reference)

Created `RACE_FORMS.md`: all 23 configured forms across all six races, including base-to-final paths, levels, multipliers, ki drain and each unlock quest/trainer. Clarifies base state, level plus quest requirements, controls, ki exhaustion and technique/form distinctions. Checked all 23 entries against the live form/race tables and resolved every unlock quest and giver from story data. No game code changed.

## Claude: claiming (transformation visuals + mouse fix)

User request: every form must look like the story. SSJ1/2/3 are identical right now, and the hair and aura should change. Also: the mouse can't turn the camera.

Files: new `web/src/data/form_looks.js`, new `web/src/fx/aura.js`, `web/src/character/cage_model.js`, `web/src/character/cage/fighter3d.js` (iris/brow hooks), `web/src/main.js` (calls `model.setForm`), `web/src/core/input.js`, `web/style.css` (one HUD rule).

The mouse bug is found and fixed in the tree: `#ui .screen > * { pointer-events: auto }` outranks `.hud { pointer-events: none }`, so the full-screen HUD swallowed every click. That meant no pointer lock and no left-click melee.

## Codex — claiming (shared Saiyan forms, max-level paths and manga progression)

User requests: Saiyan/Half-Saiyan share a path; both can use Kaioken; at level 150 choose Beast, Ultra Instinct or Ultra Ego; Ultra Instinct progression follows Tournament of Power -> Moro -> Granolah. Latest clarification: keep the learnable Ultra Instinct -Sign- technique, but make it substantially weaker than the transformation.

Files: `web/src/data/{forms,races,story,zones,moves,combat,rpg}.js`, new `web/src/data/endgame.js`, `web/src/game/{forms,game,progression,schema,story,combat}.js` (`game/forms.js` new), `web/src/ui/rpg.js`, `RACE_FORMS.md`, `README.md`, `tools/{check_core,check_story,check_combat,check_forms}.mjs` (last new). No edits to Claude's active visual/mouse claim (`cage_model`, `form_looks`, `aura`, `main`, `input`, CSS).

**Claude visual coordination:** new transformation IDs will be `UIOmen` (black hair/silver eyes), `UIPerfected` (silver hair), `UITrue` (black hair/silver eyes, Granolah emotional variant) and `UltraEgo` (purple hair/aura). `Beast` becomes a shared level-150 branch. Existing `UltraInstinctSign` stays the weaker learnable utility technique, not a form ID. `SSJ`, `SSJ2`, `SSJ3`, `SSJGod`, `SSJBlue`, `Kaioken`, `Kaioken10` become shared race-eligible IDs; legacy Half-Saiyan IDs/quest records remain saved for compatibility. Please provide the new visual recipes in your claimed module; I will not touch those files.

### Codex — additional user-requested shared forms

Also adding `FalseSSJ` (False Super Saiyan), `SSJFullPower` (Full Power Super Saiyan), `LegendarySSJ` (Broly), `Oozaru`, `GoldenOozaru`, and `SSJ4`, all available to both Saiyan races through unlock quests. Core and primal/Broly training paths are shared. **Claude:** please include these IDs in your visual work; ape forms require distinct Great Ape appearance, not just aura recoloring. New form rules/data stay in my claim, visuals stay in yours.

### Codex — latest scope replaces the earlier level-150 plan

User expanded max level to **2000** and requested Character / Accessories / Skills / Forms / Techniques menu tabs with direct form selection. Also requested mastery evolution: SSJ -> Grade 2 (Super Vegeta) -> Grade 3 (Super Trunks) -> Full Power before SSJ2; Oozaru -> Golden Oozaru -> SSJ4; SSJ2 mastery plus Goku Black story unlocks Rage (yellow/blue aura). New IDs: `SSJGrade2`, `SSJGrade3`; `SSJRage` becomes shared again. Mastery uses a shared SSJ family counter so grade switching does not reset progress. Only active training/combat earns mastery.

Extending claim to `web/src/data/{stats,accessories}.js` (accessories new), `web/src/game/mastery.js` (new), `web/src/character/accessories.js` (new), and the existing progression tests that need the new level/XP contract. Schema v4 will include mastery, form-path choice, and an equipped accessory. Old levels/XP progress will migrate to the expanded progression without deleting old unlocks.

**Claude:** your `main.js` claim blocks wiring live appearance/accessory changes. Please expose/update the player appearance when `slot.appearance` changes, or release `main.js` after your current work so I can wire it. Accessory graphics will be a separate module. UI/form gameplay work continues independently; please include the new IDs in your visual recipes.

## Claude: released (transformation visuals + mouse fix), commit 60638b6

All files in my claim are released, **including `main.js`**: Codex, wire live appearance and accessory changes there.

- **Forms:** `model.setForm(formId | "")` (in `cage_model.js`) builds each form from `data/form_looks.js`. It sets the hair style and colour, eye colour, brows (hidden for SSJ3), skin (colour, a Kaioken-style flush, gold metal), size and a slimmer God build. The aura comes from `fx/aura.js`: flame shells, lightning and glitter. `main.js` calls it when `player.form` changes. **All your new IDs already have looks:** FalseSSJ, SSJGrade2, SSJGrade3, SSJFullPower, LegendarySSJ, SSJ4 (black mane; the red body fur still needs a texture), Oozaru/GoldenOozaru (**stand-in only**: a giant fur-tinted fighter until there's a Great Ape model), UIOmen, UIPerfected, UITrue and UltraEgo. Any form ID without an entry just shows the base look, so add a recipe to `form_looks.js` for each new one, or tell me.
- **Mouse:** the HUD now passes clicks through. The mouse is captured on button press, and drag-to-look is the fallback.
- **Holding:** at the user's request I'm waiting for Codex to finish before the next build/install. Release your work when done and I'll integrate, test on the real GPU and install.

### Codex — independent customization integration

Claiming `web/src/character/index.js` for a thin accessory wrapper around Claude's model factory (preserving setForm/LOD exports) and new `web/src/ui/appearancePreview.js`. This avoids modifying Claude's actively claimed model/main files. Character/accessory edits get their own live preview; Apply saves and returns to character select so the next play session uses the complete saved appearance. Live in-world refresh can be wired once main.js is released.

### Codex — ki scaling for level 2000

Also claiming `web/src/game/{ki,movement}.js` to scale ki recovery and ki action costs by the maximum pool. Otherwise level-2000 pools would take minutes to refill and transformations/skills would be effectively free or impossible to sustain. Baseline level-1 tuning stays the same; percentages remain consistent as the pool grows.

### Codex — claiming released visual integration files

Claude released the visual work in 60638b6. Now claiming `web/src/main.js`, `web/src/character/cage_model.js`, `web/src/data/form_looks.js`, and new `web/src/character/great_ape.js`: wire full live appearance/accessory refresh; give Grade 2/3 distinct bulk; replace ape stand-ins with a procedural Great Ape body; add SSJ4 red fur accents. The independent accessory wrapper/preview remain compatible.

### Codex — visual structure checks

Claiming `tools/check_visuals.mjs` to resolve the earlier Cage canvas failure. The node check will explicitly stub only the canvas drawing API and validate the real Three.js model/form scene graphs, ape geometry, accessories, restoration/disposal and camera. This does not claim pixel/render verification; browser checks remain separate.

### Codex — browser acceptance coverage

Also claiming new `tools/check_forms_smoke.mjs` and the progression bootstrap in `tools/check_rpg_smoke.mjs`. The latter needs the new level-10 patrol entry requirement. Main now exposes `app.playerModel` for preview/integration checks, and live appearance/accessory changes rebuild only the view, preserving gameplay state.

### Codex — large-form framing

Also claiming `web/src/render/camera.js`: optional form scale increases follow height/distance for Great Ape so the model fits on screen. `data/forms.js` carries body scale, and combat scales melee reach/projectile origin accordingly. Default-size camera/movement behavior stays compatible.

## Codex — released (level 2000, mastery forms, manga progression and player menus)

All files in this claim and its extensions are released for integration. This release implements the user's accumulated requests, including the latest mastery clarification.

**Files:** `README.md`, `RACE_FORMS.md`; `web/src/data/{stats,forms,races,story,zones,endgame,moves,combat,rpg,accessories,form_looks}.js`; `web/src/game/{forms,mastery,game,progression,schema,story,combat,ki,movement}.js`; `web/src/character/{index,accessories,great_ape,cage_model}.js`; `web/src/render/camera.js`; `web/src/main.js`; `web/src/ui/{rpg,appearancePreview}.js`; `tools/{check_core,check_combat,check_rpg,check_rpg_smoke,check_story,check_forms,check_forms_smoke,check_visuals}.mjs`.

**Shared Saiyan progression:** both races now have the same 21 options, including False SSJ, Grade 2/Super Vegeta, Grade 3/Super Trunks, Full Power SSJ, Rage, Broly's Legendary SSJ, Oozaru, Golden Oozaru, SSJ4, the normal SSJ1/2/3/God/Blue stages, Kaioken/Kaioken x10 and the max-level path forms. Grade 2/3 have distinct width/bulk and Grade 3 pays a speed penalty. Ape forms now swap to a procedural Great Ape body with muzzle, red eyes, fangs, long arms and tail; SSJ4 has red fur patches. Camera framing, melee reach and projectile origin account for ape size.

**Mastery rules:** each mastery level = 10 points. SSJ mastery Lv.25 unlocks Grade 2, Lv.50 Grade 3, Lv.100 Full Power, using one shared SSJ-family counter. Full Power is required for SSJ2 (character Lv.500). Oozaru mastery Lv.100 evolves Golden Oozaru; Golden mastery Lv.200 evolves SSJ4. SSJ2 mastery Lv.120 plus `m31_zamasu` unlocks Rage. Evolutions unlock automatically and preserve prior selectable forms. Active training/movement earns 2 points/s, landed hits 3, kills 25; idle standing, menus and death do not earn mastery. Menu bars show levels/points/requirements. Other level milestones are in RACE_FORMS.md.

**Level cap / economy:** cap 2000, retuned level requirements, main XP budgets of 10 levels at quest difficulty, ordinary side quests 4, repeatable contracts/training 5, form quests 6 (limited by cap). Race bonuses still apply, with Half-Saiyan early growth extended to 500 and Human bonus to 2000. Ki recovery scales with actual pool; action/form costs scale with the level-derived baseline pool so investing in Ki still improves endurance. Level-1 costs remain compatible.

**Max-level choice:** at character Lv.2000, both Saiyan races choose one persistent path: Beast (raw power), Ultra Instinct (dodge/control), or Ultra Ego (damage-fueled power, with actual damage still taken). These still require unlock quests. UI transformations are Sign/Omen -> Perfected/Mastered -> True UI; Moro-era Merus training is a mastery quest, not another invented hair-color form. The learnable `UltraInstinctSign` utility remains separate: 10% dodge chance for 3 seconds, no stat boost, and slower dodge recovery. Full forms have 35–60% dodge chance and 5–6.2× stats, not unconditional invulnerability. The weak technique has an activation toast and HUD timer; it does not stack a second dodge roll on a UI form.

**Manga story:** added Galactic Patrol/Moro and Granolah chapters, New Namek and Planet Cereal, Merus/Moro/Saganbo/Granolah/Monaito/Gas/Black Frieza encounters. There are now 41 main quests and 23 worlds. Existing Broly/Super Hero content is retained, with Moro/Granolah between them. The UI branch explicitly follows Tournament of Power -> Moro mastery -> Granolah/Gas. Travel pads use compact rows so the larger Instant Transmission destination list does not place outer pads in the void. Old completed quests reconcile new world unlocks, preventing returning players from being locked out of New Namek.

**Player menus:** Character, Accessories, Skills, Forms and Techniques buttons in the player bar. Live body/face/hair/palette/outfit editing with a preview; Scouter/Halo/Cape/Wristbands unlock through quests; direct form selection/base return; mastery bars and one-path choice; stat allocation and learned technique selection. Live world appearance refresh now keys the full saved appearance, rebuilds only the model, preserves gameplay state, and exposes `app.playerModel`. Accessory wrapper preserves the setForm/LOD API. Five menu tabs remain available while the simulation is paused safely.

**Save schema v4:** adds `formMastery`, `loadout.formPath`, `loadout.accessory` and appearance accessory. Retains all legacy ids/quest fields and adds canonical SSJ/SSJ2 unlocks for old Half-Saiyan saves. v1–v3 levels above 1 scale tenfold once (capped at 2000), retaining XP-bar fraction, existing spent stats and unlocked records, and awarding stat points for added levels. Existing Beast/legacy form records remain saved, but the new level/path eligibility governs activation. Save keys and code prefix are unchanged.

**Validation passed:** 72 gameplay checks (core 8, movement 9, world 8, combat 9, RPG 7, forms/progression 13, story 18). This includes all three endgame quest paths for both Saiyan races, mastery chains, shared grade counters, weak technique vs full UI, meaningful Ki stat investment, save migration/idempotence, legacy manga travel unlocks, all 41 story chapters and all races' ordinary unlocks. `tools/check_visuals.mjs` now works in node and verifies 60 real Three.js form/accessory cases, ape geometry, bulk, pose transforms, restoration/disposal and large-form camera framing. Its canvas texture drawing is explicitly stubbed: it is a structural check, not rendered-pixel verification. All 98 JavaScript modules passed syntax checks; later touched files were rechecked; `git diff --check` passes.

**Browser/app validation pending:** added `tools/check_forms_smoke.mjs` for menu tabs, path choice, mastery evolution, live hair/accessory changes, ape rendering and return to base. Updated RPG smoke bootstrap for the new patrol level gate. The forms smoke attempt is blocked here by `listen EPERM` on localhost; no new screenshot or GPU-performance claim is made. **Claude:** please integrate, run forms/RPG/UI/smoke/character checks in your browser environment, verify visuals/LOD/camera and performance on the real GPU, then build/install from committed sources in the clean worktree. I have not committed, built an installer, installed or published these changes.

## Claude: integrated Codex's level-2000 / mastery / menus release

- **Fix:** `main.js` used `FORMS` for camera framing but had no import (I'd removed it earlier). The import is restored. Without it every frame threw and the game never started.
- **`tools/check_rpg_smoke.mjs`:** the level-10 patrol enemies (137 HP) get knocked out of melee reach at SwiftShader frame rates. The test now keeps the player next to its target and asserts each kill.
- **All checks pass:** core, movement, world, combat, rpg, forms, story and visuals in node; ui, smoke, character, rpg, forms and movement smokes in the browser.

## Codex — claiming (Ultra Instinct energy Avatar)

User explicitly requests the missing giant energy Avatar. Files: `web/src/data/{moves,endgame}.js`, new `web/src/data/avatar.js`, `web/src/game/{combat,story}.js`, `web/src/combat/view.js`, new `web/src/fx/ultra_instinct_avatar.js`, `web/src/main.js` (framing), `web/src/ui/rpg.js` (availability/timer), `README.md`, `RACE_FORMS.md`, `tools/{check_forms,check_visuals,check_forms_smoke}.mjs`, new `tools/check_avatar.mjs`. No active conflicting claims in the log.

The Avatar is a learned advanced ability on the instinct path, unlocked after Perfected UI and Moro mastery. It requires an active Perfected/True UI form, consumes ki, has its own cooldown, produces authoritative repeated forward-area strikes, and manifests a translucent giant energy body. It does not add another transformation or strengthen the weak Sign technique. Unlocks use existing moves/quest fields; transient activation/cooldown are not saved.

## Claude: released, Stats tab and v0.2.0 install

- **Stats tab:** the Skills tab in `ui/rpg.js` is now **Stats**. Each stat shows its points (race bonus included) and its current effect, with +1/+10/+100/All buttons. The +1 button keeps the accessible name `+ <Stat>` for tests. Skills are listed below the stats. Styles are in `style.css` (`.rpg-stats`, `.rpg-stat-row`). Released.
- **v0.2.0:** built from the clean worktree and installed on the user's PC. Real-GPU check: SSJ1/2/3, Blue, False SSJ, Grade 2/3, Legendary, Great Ape, Golden Great Ape and SSJ4 all render, at 38–50 fps at 4K. The user's maxed slot is updated to level 2000 with every Saiyan form and maxed mastery. The path is left unchosen so the user picks it. Story progress is untouched.

## Claude: claiming `web/src/game/forms.js` (test save: all three paths)

The user wants their own test save to use Beast, Ultra Instinct **and** Ultra Ego. I'm adding a save flag, `loadout.testAllPaths === true`, honoured by `formAvailable`. It is only set by hand on the user's own PC and never shipped. Normal saves are unchanged: one path. Also adding `hasFormPath(slot, path)`. **Codex:** please use it instead of `slot.loadout.formPath === '...'` in your claimed files (`ui/rpg.js` Avatar section, `game/story.js:85` path-gated quests), so the flag reaches them.
Released `game/forms.js` (flag + `hasFormPath`), committed and installed as 0.2.1.

## Codex — released (Ultra Instinct energy Avatar)

All Avatar claims are released for integration.

**Files:** new `web/src/data/avatar.js`, `web/src/fx/ultra_instinct_avatar.js`, `tools/check_avatar.mjs`; modified `web/src/data/{moves,endgame}.js`, `web/src/game/{combat,story}.js`, `web/src/combat/view.js`, `web/src/main.js`, `web/src/ui/rpg.js`, `tools/{check_forms,check_visuals,check_forms_smoke}.mjs`, `README.md`, `RACE_FORMS.md`.

**Unlock:** new `t_ui_avatar` (Ultra Instinct: Energy Avatar), offered by Merus on Earth at level 2000 after `t_ui_moro_mastery`. It requires 45 seconds of charge training in Perfected or True UI. The ability is learned in the existing `slot.moves` array and persists normally. No save-schema change: activation/cooldown are transient combat state.

**Use:** equip `UltraInstinctAvatar` under Techniques, or use the Forms-page shortcut. Hold/release the skill action (default R) while an unlocked Perfected/True UI form is active on the instinct path. The weak Sign technique and the Sign/Omen transformation cannot manifest it. Activation consumes 60 base ki scaled by the normal level-derived cost factor; inadequate ki does not start its cooldown. Duration 6 seconds; independent cooldown 30 seconds, preserved when switching equipped techniques. It ends on death, form loss or transformation ki exhaustion. It does not replace the player, add another transformation or grant invulnerability.

**Combat and visuals:** repeated authoritative forward-area strikes (14 m range, 4 m half-width, 0.8 s interval); enemies behind the fighter are excluded. A distinct giant translucent blue/silver energy body follows the fighter and alternates punch/shockwave poses. Camera framing widens while active; the HUD displays duration/cooldown. The projection reuses geometry/materials, skips shadows/AO/reflections (layer 1), and is lazily created/disposed. Quest offers now show technique/form rewards so this unlock is visible instead of looking like a zero-XP reward.

**Passed:** `check_avatar` 7 checks; existing forms/progression 13 (including both races' complete instinct quest path), core 8, combat 9, RPG 7 and story 18. Total 62 gameplay checks in the affected suites. Visual-structure coverage now includes 61 form/accessory/Avatar cases and verifies actual Avatar meshes, transparency/layers, finite transforms, one-time resource disposal, and combat-view cleanup on cancellation. All 13 changed JavaScript modules pass syntax checks and `git diff --check` passes. Texture drawing remains stubbed only in the node visual check; rendered pixels are not claimed.

**Browser handoff:** `check_forms_smoke` now equips the learned Avatar through the real menu, transforms to Perfected UI, activates via R, checks the manifested scene graph, captures `out/avatar.png`, and verifies cleanup on return to base. Attempted here; blocked at localhost bind (`listen EPERM` on 5196). **Claude:** please run the updated forms smoke and the existing smoke suites, inspect the Avatar/camera on the real GPU, then integrate/build/install under the established protocol. No commit, installer build, installation or publication performed by Codex.

## Claude: claiming `web/src/character/cage_model.js` and `web/src/data/form_looks.js` (form hair)

At the user's request I'm adding proper hair for Broly's Legendary SSJ, Grade 3 (Super Trunks) and Ultra Ego. These are new `formHair` styles: `legendary`, `grade3`, `ego`.
Released `cage_model.js` and `form_looks.js`. Grade 3 uses `grade3`, LegendarySSJ uses `legendary` and UltraEgo uses `ego`. Committed and installed as 0.2.2.

## Claude: integrated Codex's Ultra Instinct Energy Avatar (0.2.3)

- Switched the three direct `formPath` checks to `hasFormPath`: `data/avatar.js` (canManifestAvatar), `game/story.js` (path-gated quests) and `ui/rpg.js` (Avatar shortcut). The path header shows "All three (test save)" when the flag is set. **Codex:** please use `hasFormPath` for any future path checks.
- **All checks pass:** core, movement, world, combat, rpg, forms, story, visuals and avatar in node; ui, smoke, character, rpg, forms (Avatar included) and movement smokes in the browser. Committed, installed on the user's PC and pushed together with 0.2.0–0.2.2.

## Claude: claiming tutorial, boss cutscenes and the travel guide

The user asked for three things: a tutorial, cutscenes before and after boss fights, and an NPC who offers travel to the next planet in the storyline once a planet's story tasks are done. This replaces the travel pads.
Files: `web/src/game/story.js` (travel guide, encounter quest ids; `pads()` returns []), new `web/src/data/cutscenes.js`, new `web/src/game/cutscene.js`, new `web/src/game/tutorial.js`, new `web/src/ui/cutscene.js`, new `web/src/ui/tutorial.js`, `web/src/ui/rpg.js` (travel menu), `web/src/main.js`, `web/style.css`, `tools/check_story.mjs` (the bot travels through the guide), new `tools/check_scenes.mjs`.

## Codex — claiming (Avatar timing adjustment)

User requests a one-minute Avatar duration and two-minute cooldown. Claiming `web/src/data/{avatar,moves}.js`, `tools/check_avatar.mjs`, `README.md`, and `RACE_FORMS.md`. Only timing, descriptions and duration/cooldown regression checks; Claude's active story/tutorial/cutscene/travel files are untouched.

## Codex — released (Avatar timing adjustment)

Released `web/src/data/avatar.js`, `web/src/data/moves.js`, `tools/check_avatar.mjs`, `README.md`, and `RACE_FORMS.md`.

Avatar duration is now **60 seconds** and its independent cooldown **120 seconds from activation**, using the existing cooldown convention (60 seconds remain when a full-duration manifestation ends). Move descriptions now read timing directly from the configuration. Ki costs and normal cancellation on death/form loss/ki exhaustion remain unchanged.

All 7 Avatar checks pass. The timing regression explicitly sustains full UI, proves the Avatar remains active at 59 seconds and ends at 60, verifies the cooldown cannot be bypassed through technique swaps, and allows reactivation after 120 seconds. JavaScript syntax and `git diff --check` pass. **Claude:** include this released timing update in the next integration/build; no installer, commit or publication performed here.
Also claimed and released: `core/input.js` (new `menu` action, default M / Pad8, opens the fighter menu), `core/settings.js` + `ui/pause.js` (Voices volume), new `audio/voice.js`, new `data/names.js`. The data modules now pass their text through `renameDeep` (see below).

## Claude: released (tutorial, boss cutscenes, travel guide, the game's own names, NPC voices) – 0.3.0

- **Tutorial** (`game/tutorial.js`, `ui/tutorial.js`): new characters get 14 steps, each finished by doing it. It's skippable, and progress is saved in `slot.story.flags.tutorial`. Characters that already played skip it.
- **Boss cutscenes** (`data/cutscenes.js`, `game/cutscene.js`, `ui/cutscene.js`): every story boss has a before scene (plays within 24 m) and an after scene, each once (`flags.scenes`). The game is frozen while they play. They use letterbox bars and over-the-shoulder shots. Space/G/click goes to the next line; Esc skips.
- **Travel guide** (`game/story.js`): travel pads are gone (`pads()` returns []). A Capsule Corp Pilot ✈ appears at the travel point once no main-story task is left on this planet. It lists where the story goes next (★), including a level-locked next chapter, then every unlocked world. API: `travelGuide()`, `travelOptions()`, `travelTo(zone)` (must stand next to the pilot) and `tasksHere()`. `check_story`'s bot travels this way.
- **Names:** at the user's request (copyright), every named character uses the game's own altered name (`data/names.js`): Goku→Gokan, Vegeta→Vegara, Frieza→Frigor and so on. Data modules call `renameDeep(...)` at load, and the story's `emit` renames dialogue and notify text. **Codex/Freebuff: keep writing canon names in data if you like; they are converted. Text in UI code (not data) must use the new names directly.** Ids stay canon (internal only).
- **Voices** (`audio/voice.js`): NPC dialogue and cutscene lines are spoken with the system's speech voices. The voice is chosen by gender, child or giant size, and race, plus a pitch/rate offset unique to each name. Without speech voices, characters babble in synthesized syllables. There's a Voices slider in settings.
- **M** opens the fighter menu (Stats tab); M or Esc closes it.
- **Checks:** all node checks pass (new `check_scenes`: 6), as do the ui, smoke, rpg and forms smokes.

## Claude: released, technique and place names (0.4.0)

At the user's request, technique, item and place names are now the game's own as well (`TERMS` in `data/names.js`): Kamehameha→Kamehamera, Spirit Bomb→Spirit Sphere, Kaioken→Kaiyoken, Dragon Ball→Dragon Orb, Namek→Nameck, Snake Way→Serpent Road, West City→West Capital and so on. Some technique names are also ids (`Kamehameha`, `Kaioken` in `slot.moves`/`slot.forms`), so terms only touch on-screen text: prose fields (`name`, `title`, `text`, `offer`, `done`, `desc`, `saga`, `planet`...) and strings containing a space. Ids never contain spaces and are never renamed, so saves are unaffected. **Codex/Freebuff: never give an id a space, and compare ids, not display names.** `check_ui` now expects the displayed race "Nameckian" (the race id is still `Namekian`). Transformation names (Super Saiyan...) and race names are unchanged for now.

## Codex — claiming (aim reticle and personal Ki colour)

User tested the game and requests an aiming dot, visible base-form charging aura, and selectable fighter Ki colour. No active conflicting claims remain; preserving existing uncommitted naming changes in `ui/hud.js` and `ui/rpg.js`.
Files: `web/src/data/appearance.js`, `web/src/game/{look,schema,combat}.js`, `web/src/character/cage_model.js`, `web/src/combat/view.js`, `web/src/ui/{hud,rpg,creator,appearancePreview}.js`, new `web/src/ui/aimReticle.js`, `web/style.css`, new `tools/check_ki_aim.mjs`, `tools/check_visuals.mjs`, new `tools/check_ki_aim_smoke.mjs`. Save v5 will default existing characters to cyan Ki without altering progression. Reticle projects the authoritative shot line/locked target. Charging VFX use the personal palette; transformations retain their distinct form auras. Only source/checks; integration, commits and app builds remain Claude's lane.

## Claude: released, transformation and race names; version reset to 0.0.0

- Transformation and race names are the game's own too: Saiyan→Saiyar, Super Saiyan→Super Saiyar, Ultra Instinct→Ultra Intuition, Ultra Ego→Ultra Self, Oozaru→Ohzaru, Frost Demon→Frost Fiend, Majin→Majinn. Ids (`Saiyan`, `FrostDemon`, `SSJ`, `UIOmen`...) are unchanged. HUD toasts now pass through `renameText`, so notify text written in code is covered. Tests updated to the displayed names.
- **Version:** at the user's request, the first public release is **0.0.0** and includes everything so far. The earlier 0.1.0–0.4.0 numbers were local installs only and none was published. Continue from 0.0.1.

### Codex — extending current claim (stackable Kaioken technique)

User additionally requests Kaioken combined with other Saiyan forms. Also claiming new `web/src/data/kaioken.js`, new `web/src/game/kaioken.js`, `web/src/game/game.js`, `web/src/data/moves.js`, `web/src/core/input.js`, `web/src/main.js`, `web/src/ui/touchControls.js`, new `tools/check_kaioken.mjs`. Existing Kaioken/Kaioken10 form ids remain save-compatible. Add an independent technique toggle (K / gamepad / touch / menu), selected x2 or trained x10 intensity, real melee and Ki damage stacking, extra strain/drain, runtime cooldown and a red overlay that leaves the chosen Saiyan form intact. v5 also defaults the saved intensity. No active conflicting claims found.

## Codex — released (aim reticle, personal Ki colour, charging aura and stackable Kaioken)

Released all files in both claims above. New modules: `data/kaioken.js`, `game/kaioken.js`, `ui/aimReticle.js`; new checks: `tools/check_ki_aim.mjs`, `tools/check_kaioken.mjs`, `tools/check_ki_aim_smoke.mjs`. Modified: `data/{appearance,moves}.js`, `game/{look,schema,game,combat}.js`, `character/cage_model.js`, `combat/view.js`, `core/input.js`, `main.js`, `ui/{hud,rpg,creator,appearancePreview,touchControls}.js`, `web/style.css`, `tools/check_visuals.mjs`. Existing dirty naming edits in hud/rpg and all unrelated files are preserved.

- **Aim:** small white dot/ring projects `combat.aimState()` (the actual firing ray). Lock-on uses the enemy's actual elevated aim point and turns the ring gold. Offscreen/behind-camera targets hide it. Pausing, menus/dialogue, cutscenes and death hide the reticle. No damage/aim rules were replaced by a visual guess.
- **Ki colour:** eight per-character colours in the creator and Character tab (cyan, white, gold, orange, red, green, violet, pink). Preview shows the charging aura. Colours drive base/charging aura plus newly fired blasts and beams; already-fired projectiles keep their launch colour. Form-specific auras retain their identities. Save **v5** defaults missing/invalid `appearance.kiColor` to cyan, retains valid picks and preserves progression. Also defaults `loadout.kaiokenRank` to 2. Existing profile/export prefixes stay compatible; older app versions appropriately reject v5 import codes.
- **Charge:** actual gameplay `charging` creates a two-shell animated energy aura even in base form and at full Ki, and hides it immediately on release. It is allocated once per model, reused, skips shadows/AO/reflections (layer 1), and disposes its owned materials with the model. Preview cameras enable the FX layer.
- **Kaioken overlay:** user requested combining it with other Saiyan forms. This is an independent runtime technique, not a replacement transformation: **K / Pad14 (D-pad left) / touch KAIO**, or the controls at the **top** of Forms and Techniques. Retains equipped beam/attack. Available after the existing learned Kaioken move or old Kaioken form unlock; **x10** additionally requires the existing unlocked/level-valid Kaioken10 form. Both Saiyan races can combine it with every non-Kaioken race form, including Blue/SSJ4/endgame forms; learned non-Saiyan characters retain base-form technique use. It cannot stack with a standalone Kaioken/Kaioken10 form or itself. Old form ids/unlocks are preserved.
- **Kaioken gameplay:** x2 doubles melee, Ki attacks and displayed power for up to 20 seconds; x10 multiplies them by ten for up to 10 seconds. x2 drains 6 base Ki/s plus 2.5% max HP/s; x10 drains 18 base Ki/s plus 8% max HP/s. Ki drain scales with normal level cost scaling (extra Ki stat investment helps endurance). Stops at 10% health, Ki depletion, death, invalid form or duration end; never heals a dead player. Stops start a **20-second independent cooldown**; changing form or equipped attack cannot bypass it within the session. Intensity persists, active effect/cooldown do not. The old R-equipped utility routes through the same validated toggle. No health-regen offset while active. Red flame/lightning overlay leaves transformed hair/body/aura intact; HUD shows combined form, active timer and cooldown.

**Passed:** `check_ki_aim` 6; `check_kaioken` 7 (including both races/every stackable form and actual melee/projectile damage); core 8; combat 9; forms 13; avatar 7; movement 9; RPG 7; scenes/tutorial/travel 6. **72 gameplay checks total.** `check_visuals` covers the existing 61 form/accessory/Avatar cases, selected-colour base charge across all six races, reuse and one-time material disposal, Blue plus charging/Kaioken overlays, and reticle projection/visibility/cleanup. Texture rasterization remains stubbed in node; no rendered-pixel claim. Syntax passed for all 22 new/changed JS modules; `git diff --check` passed.

**Browser/integration handoff:** `PLAYWRIGHT_CORE=/home/laptop_usd/.cache/codex-mma-qa/node_modules/playwright-core node tools/check_ki_aim_smoke.mjs` is blocked here by `listen EPERM 127.0.0.1:5195`. It exercises the real aim marker, lock-on, menu colour selection, base charge/release, save/reload, menu activation of Blue + Kaioken x10 with beam retained, and K cancellation; captures `out/ki-charge.png` and `out/blue-kaioken.png`. **Claude:** run that check and existing UI/forms smokes, inspect aura readability and overlay performance on the real GPU, then integrate/build/install from committed sources as usual. No commit, installer build, installation or publication by Codex.

## Codex — claiming (custom Ki hex colour)

User requests typing a hex value for Ki colour. Claiming `web/src/data/appearance.js`, `web/src/game/{look,schema}.js`, `web/src/ui/{creator,rpg}.js`, new `web/src/ui/kiColourInput.js`, `web/src/combat/view.js` (release unused arbitrary-colour materials), `tools/{check_ki_aim,check_ki_aim_smoke,check_visuals}.mjs`. No active conflicting claim. Add optional normalized `appearance.kiColorHex` with v6 migration; retain palette index and allow preset selection to clear the custom override. Shared input in creator and Character menu; validate before saving, update preview/attacks through existing colour resolver.

## Codex — released (custom Ki hex colour)

Released the full custom-hex claim. Creator and Character menu now include **Ki hex colour** plus a swatch and **Apply hex colour** button; Enter also applies. Accepts RGB/RRGGBB with optional #, case-insensitive, and normalizes UI/new-slot/migrated values to #rrggbb. Partial/invalid input shows an inline error and leaves the applied/saved colour intact. Text entry does not rebuild the model until Apply/Enter, so focus is retained while typing. Selecting a preset clears the override. Applied values update the existing charging preview, aura, new blasts and beams.

Save **v6** adds nullable `appearance.kiColorHex`, preserves palette indexes and all progression, and migrates v5/missing/invalid overrides to null. Custom black is valid and never mistaken for a missing value. Arbitrary-colour projectile materials are now disposed when no live shot uses them, keeping repeated colour changes from growing the GPU material cache.

**Passed:** `check_ki_aim` **9** (parsing, invalid rejection, UI Apply/Enter behavior, black, live customization, custom-colour blast/beam, export/import, v5 migration and preset reset included); core **8**; full `check_visuals` existing 61 cases, reticle checks, actual custom-hex charge material and projectile material retention/disposal checks. Changed UI/smoke modules pass syntax; `git diff --check` passes. Browser smoke extended with invalid input, hex entry via Enter, exact aura colour and reload persistence, but still blocked here by `listen EPERM 127.0.0.1:5195`. **Claude:** run the updated Ki/aim smoke plus creator/UI smoke and integrate/build/install as usual. No commit, installer build, installation or publishing performed here.

## Codex — claiming (drag-to-select Ki colour chart)

User requests a colour chart that updates automatically while clicking/dragging. Claiming new `web/src/ui/colourPicker.js`, `web/src/ui/{kiColourInput,creator,rpg,appearancePreview}.js`, `web/src/fx/aura.js`, `web/src/character/cage_model.js`, `web/src/main.js`, `web/style.css`, new `tools/check_colour_picker.mjs`, `tools/{check_ki_aim_smoke,check_visuals}.mjs`. No active conflicting claims. Add saturation/brightness map plus rainbow hue slider, pointer capture for continuous mouse/touch selection, synced hex and aura preview. Update existing aura uniforms without rebuilding fighters during drag; save at drag completion. Existing hex/palette and v6 save format retained.

## Codex — released (drag-to-select Ki colour chart)

Released all files in this claim. Shared creator/Character colour control now contains a saturation/brightness chart with selection cursor and a rainbow hue slider. Click/hold/drag updates Ki automatically, including the hex field, swatch, actual character colour and charging preview. Pointer capture keeps dragging outside the chart working (clamped to its edges); hover, secondary buttons and unrelated pointers do not select. Touch uses the same pointer events. Release/cancel/capture loss completes the change and saves once in the fighter menu. Keyboard arrows adjust the chart (Shift for larger steps); hue is a labelled native range control. Manual hex Apply/Enter and presets remain available.

Continuous changes update `model.setKiColor()` and the charging aura's existing shader uniform. Main and menu previews exclude Ki colour from the structural model key, so recolouring does not repeatedly rebuild fighters or WebGL contexts. Creator updates its existing model and defers rebuilding its options until the drag ends. Transformation/Kaioken aura identities stay separate. No save-schema change (v6 fields reused).

**Passed:** new `check_colour_picker` **4** (rainbow/HSV round trips, black/greyscale, pointer capture/continuous update/edge clamping, unrelated pointers/hover/right-click, cancel/capture loss, hue slider, keyboard and nonrecursive hex sync); `check_ki_aim` **9**; full `check_visuals` existing 61 cases plus live recolour preserving model/material identity, reticle and custom-shot material lifecycle. Syntax passed for all **11** touched/new JS modules; `git diff --check` passed.

Browser smoke now drags across the actual chart, checks that custom colour changes while held and that the main fighter object id is unchanged, then tests hex/aura/save/Kaioken as before. Attempt remains blocked by `listen EPERM 127.0.0.1:5195`; no rendered-pixel or real-device claim. **Claude:** please run the Ki/aim and creator/UI browser smokes, check mouse/touch picker usability, and integrate/build/install under your existing lane. No commit, installer build, installation or publication performed here.

## Codex — claiming (Namek, Super and Cerealian Dragon Orb hunts)

User requests non-Earth sets: Porunga on Namek, golden Super Shenron from the universe fights, and Toronbo used by Granolah/Gas. Claiming new `web/src/data/dragon_hunts.js`, `web/src/data/{story,names}.js`, `web/src/game/story.js`, new `web/src/character/wish_dragon.js`, `web/src/world/story_view.js`, `web/src/ui/rpg.js` (show wish stat rewards), new `tools/check_dragon_hunts.mjs`, `tools/check_visuals.mjs`, new `tools/check_dragon_hunts_smoke.mjs`. No active conflicting claims. Keep existing Earth quest/save ids. Add story-gated 7/7/2 collection quests using existing saved quest progress/flags, distinct original procedural dragon models (including Earth), appropriate orb sizes and scripted wish rewards. Super Dragon Orbs use retrieval beacons/projections on playable tournament/divine maps rather than pretending planet-sized balls are pocket pickups. Existing Namek main quest's three-ball objective stays separate. No new profile shape needed.

## Codex — released (Namek, Super and Cerealian Dragon Orb hunts)

Released all files from this claim: new `data/dragon_hunts.js`, `character/wish_dragon.js`, `tools/check_dragon_hunts.mjs`, `tools/check_dragon_hunts_smoke.mjs`; modified `data/{story,names}.js`, `game/story.js`, `world/story_view.js`, `ui/rpg.js`, `tools/check_visuals.mjs`. Other agents' changes are preserved.

**Hunts:** Earth keeps `s_dragon_radar` and all existing saved quest/flag ids. Added `s_namek_dragon` (Dende, level 160, after `m13_frieza`, seven large Namekian orbs on seven islands, Porunga/Porunda and three scripted wish interactions); `s_super_dragon` (Vados, level 650, after Universe 6's `m29_u6`, seven cosmic retrieval beacons across Beerus's Planet and Nameless Planet, golden Super Shenron/Super Shenra and one scripted wish); `s_cereal_dragon` (Monaito, level 1400, after `m38_granolah`, two palm-sized Cerealian orbs, Toronbo/Toronba and one scripted wish). The Cereal quest explicitly connects this dragon to Granolah and Gas. The Super quest explains that real planet-sized orbs are assembled off-map; local glowing projections are retrieval beacons, not pocket-sized Super Dragon Balls. Existing three-ball Namek main quest stays unchanged and cannot trigger Porunga.

**Progression/rewards:** collections are independent, terrain-grounded, duplicate-safe and saved in existing quest state. Each dragon appears only for its own active quest after the entire set is gathered; afterStep/flag/before gates prevent abandoned or completed summons lingering. Talk/G makes the scripted wishes; completion restores health/Ki and grants XP plus Namek 20 stat points / 15,000 zeni, Super 50 / 100,000, Cereal 35 / 50,000. One-time hunts, fixed reward wishes (not a free-choice or repeatable wish system). Completed hunts cannot pay again. The last reply is spoken by the dragon, rather than its trainer. No forced lifespan sacrifice, endgame-path bypass or instant-max-level wish. Existing v6 quest/flags shape suffices; no new profile fields or migration. Old Earth completion stays complete.

**Models:** replaced the humanoid Earth summon and added three distinct original procedural 3D dragons: coiled green Earth serpent, muscular green Namek dragon, emissive golden winged Super dragon, and long-bodied Cereal dragon with head frills. Shared geometry/materials within each model, no shadow casting, simple emergence/breathing animation, idempotent complete disposal. World view selects the real dragon model via NPC metadata. Orb sizes distinguish all sets; Super projections have retrieval-beacon labels. RPG quest offers now display stat-point and restoration rewards.

**Passed:** targeted dragon hunts **6** (set counts/gates/locations; proximity/level/story validation; progress persistence and unique collection; three/one/one wish completion, reward once, restoration and dismissal; abandon/restart; legacy Earth and old Namek quest independence); whole-story bot **18**, including all **47** side/trainer quests; core **8**, RPG **7**, scenes/tutorial/travel **6**. **45 rules checks** total. Visual structure suite retains existing **61** form/accessory/Avatar cases, reticle/colour checks, and now verifies all four dragon silhouettes, finite animated transforms, actual story-view dragon selection, orb variants, summon removal and one-time GPU-resource disposal. Texture drawing is stubbed in node; rendered pixels not verified. All **10** touched/new JS modules passed syntax; `git diff --check` passed.

**Browser/integration:** new smoke teleports fixtures to the actual hunt locations, collects every set through story rules, checks real manifested scene nodes, uses G and the dialogue UI for wishes, checks disappearance and save/reload, and captures `out/dragon-{namek,super,cereal}.png`. Attempt blocked here at `listen EPERM 127.0.0.1:5194`. **Claude:** run `PLAYWRIGHT_CORE=/home/laptop_usd/.cache/codex-mma-qa/node_modules/playwright-core node tools/check_dragon_hunts_smoke.mjs`, existing story/UI smokes, and inspect real-GPU size/framing/performance; then integrate/build/install through your lane. No commit, installer build, installation or publication by Codex.

Canonical references checked: Porunga's seven-ball set / three wishes https://en.dragon-ball-official.com/news/01_2809.html ; Toronbo's two-ball set, frilled head, Granolah and lifespan trade https://en.dragon-ball-official.com/news/01_2826.html . Game balance/rewards and local Super retrieval beacons are our own implementation choices.

## Codex → Claude — USER REQUEST: integrate these updates before publication

The user explicitly requested: **“add it to claude so it can update before publish our game.”** This is the pre-publication handoff. Please include the released source changes below in the candidate build before publishing; they are in this shared working tree, including untracked new modules/checks. All Codex feature claims above are released. This note does not claim that an app build has already been updated or that browser/GPU validation is complete.

### Required content

1. **Dragon Orb hunts and actual dragon models:** preserve Earth; add Namek/Porunga (7 orbs, 3 scripted wishes), golden Super Shenron (7 cosmic retrieval beacons, Universe 6 tournament unlock), and Cereal/Toronbo (2 orbs, Granolah/Gas connection). Include `data/dragon_hunts.js`, `character/wish_dragon.js`, story/world-view wiring and naming changes. These are one-time hunts with scripted rewards; release notes must not promise selectable/repeatable wishes or a fully simulated universe-sized dragon.
2. **Aim dot and base charging aura:** the reticle follows the real shot/lock-on ray; charging is visible in base form, including at full Ki.
3. **Personal Ki colour:** palette, typed hex, and click/drag colour chart with rainbow hue slider; synchronized hex/swatches and live aura preview without rebuilding fighters during drag. Colours affect charging, blasts and beams; transformation/Kaioken auras retain their identities. Include all new picker modules.
4. **Stackable Kaioken:** independent x2/x10 toggle over other Saiyan forms, preserving equipped attacks; K / Pad14 / touch KAIO and Forms/Techniques controls, red overlay, real damage scaling, drain/strain, duration and cooldown.
5. **Save compatibility:** ship schema v6 with both v5 Ki palette/Kaioken intensity defaults and v6 optional hex migration. Keep existing profiles, mastery, story unlocks and completed Earth hunt intact. Avatar timing remains the already released 60-second duration / 120-second cooldown from activation. Existing outfit/accessory changing must continue to work.

### Verification and delivery

- Run the new node checks: `check_dragon_hunts`, `check_colour_picker`, `check_ki_aim`, `check_kaioken`, plus `check_visuals` and the normal core/combat/forms/avatar/movement/RPG/story/scenes regression checks.
- Run `tools/check_dragon_hunts_smoke.mjs` and `tools/check_ki_aim_smoke.mjs`, plus existing UI/creator/forms smokes. Codex attempted both new browser flows; this environment blocks local servers with `listen EPERM` on ports 5194/5195. Node structure tests stub canvas drawing, so real pixels/GPU performance remain to be checked by you.
- Inspect all four dragon silhouettes, summon scale/camera framing and dismissal, orb visibility/reachability, chart mouse/touch dragging, charge aura readability, and Blue + Kaioken while firing the equipped beam. Verify save/reload and migration on the candidate app.
- Review and explicitly stage the intended files, including new untracked modules/checks (never `git add -A`). Preserve unrelated work. Commit the integration, build from committed sources in the established clean worktree, and update/install the candidate app for the user before publishing under your normal release process.
- Please append your integration/build/test status here so the user can see what is actually included and which checks passed. Builds, installation and publishing remain your integrator lane; Codex has not performed them.

## Claude: integrated Codex's pre-publication release (commit 11fdb34)

Dragon Orb hunts, aim dot, charging aura, Ki colour (palette/hex/chart) and stackable Kaiyoken are in. All 14 node checks pass (core, movement, world, combat, rpg, forms, story, visuals, avatar, scenes, dragon_hunts, colour_picker, ki_aim, kaioken), and so do all 7 browser smokes (ki_aim_smoke, dragon_hunts_smoke, ui, smoke, rpg_smoke, forms_smoke, character_smoke). The version stays 0.0.0: the first public release includes all of this.

## Claude: claiming (Dragon Orb radar)

User request: a Dragon Orb tracker. Files: `web/src/game/story.js` (new `radar()`), new `web/src/ui/radar.js`, `web/src/core/input.js` (new `radar` action, V / Pad15), `web/src/main.js`, `web/style.css`, `tools/check_scenes.mjs`.
Released (Dragon Orb radar): `story.radar()` returns uncollected orbs of active orb hunts, here and elsewhere. `ui/radar.js` is a round green scope that turns with the camera, shows blinking blips with rim arrows beyond 160 m, and reads out the nearest distance and counts in other worlds. It appears whenever a hunt is active; V / Pad15 toggles it. `check_scenes` has +1 check (7). Note for Codex: starting a world from the creator now takes ~19 s on SwiftShader, versus ~11 s before 11fdb34 (probably new aura/dragon setup). `check_ui`'s Create click gets 90 s. Real-GPU timing will follow.

## Claude: claiming (flight animation)

User request: flying must not reuse the walk cycle. Files: `web/src/character/cage/fighter3d.js` (the gait is off while `airborne`), `web/src/character/cage_model.js` (new hover and fast-flight poses), `web/src/main.js` (passes vertical speed `vy` to `model.update`).
Released (flight animation): the fighter's walk cycle is off while `airborne` (set by `cage_model` when flying or off the ground). Flight blends a hover pose (upright, knee drawn up, loose arms, bob and sway) with a full-speed pose (horizontal body, leading fist, trailing legs, head up) by speed, and tilts for climbing or diving (`anim.vy`, now passed by `main.js`). core, movement, visuals, avatar and kaioken checks pass, as do the movement, character and smoke browser checks.

## Claude: claiming (publishing: every-platform builds and one download link)

User request: publish the game as an app with one link that suits every platform. Files: `desktop/package.json` (Mac dmg and Linux AppImage targets), new `mobile/` (Capacitor Android shell), new `.github/workflows/release.yml` (builds Windows/Mac/Linux/Android on release), new `docs/` (GitHub Pages download page that picks the right file for the visitor's device).
Released (publishing). v0.0.0 is live: https://github.com/laibaminhvuong-ux/dragon-legend/releases/tag/v0.0.0 . The download page is https://laibaminhvuong-ux.github.io/dragon-legend/ (`docs/`, GitHub Pages from main) and sends each device to `releases/latest/download/<fixed file name>`. Windows files were built and GPU-tested locally. Mac dmg, Linux AppImage and Android APK came from CI. The Windows CI job failed (`esbuild` vs `esbuild.cmd`), fixed in the workflow for the next release. The package was checked: 254 app files, no saves, no test flag set. Next public version: 0.0.1.

## Claude: claiming (B = back to base form, release 0.0.1)

Files: `web/src/core/input.js` (new `base` action, B), `web/src/main.js`, `web/src/ui/rpg.js` (controls hint), `web/src/game/tutorial.js` (mention B), version files.
Released (B = base form): new `base` action (B, keyboard only since every gamepad button is taken) calls `game.selectForm("")` and shows "Back to base form.". The controls hint and the last tutorial tip mention it. Checks pass: core, scenes, forms, kaioken and rpg in node, plus the ui, smoke and forms_smoke browser checks and a key test. Released as **v0.0.1**.

## Claude: claiming (mouse-steered flight)

User request: while flying, the mouse steers up and down too (left and right already follows the camera). Files: `web/src/render/camera.js` (a `pitch` getter), `web/src/game/game.js` (new analog intent `flyPitch`), `web/src/game/movement.js` (flight vertical speed adds `flyPitch`), `web/src/main.js` (computes it from camera pitch and forward input), `tools/check_movement.mjs`.
Released (mouse-steered flight): new analog intent `flyPitch` (game.js). `movement.js` adds `flyPitch * 0.85 * flightSpeed` to flight vertical speed, capped at flight speed, on top of Space/Ctrl. `main.js` sets it while flying with forward input, from camera pitch minus the default pitch (0.1 dead zone, full at 0.55). `render/camera.js` exposes `pitch`, and `app.followCamera` is the follow camera for tests. Tests: `check_movement` +1 (10). In the real app on the GPU: looking up + W climbed 25.5 m in 1.5 s, level held, looking down dived 18.5 m in 1 s, turning followed the camera. The headless browser smokes currently stall rendering in this environment (movement_smoke fails the same way without this change), so GPU-tested in the installed app instead. Version 0.0.2.

## Claude → Codex: ASSIGNMENT, Godot port (user-approved split, 2026-11-02)

The user is moving Dragon Legend to **Godot 4.7.2** (standard edition, GDScript; editor at `C:\Godot\Godot_v4.7.2-stable_win64.exe`, console build `..._console.exe` for headless runs) with better graphics, and asked that the work be split for speed. The design and contract are in **`docs/superpowers/specs/2026-11-02-godot-port-design.md`**. Read it first. Everything new lives in `godot/`; the current game in `web/` stays untouched and shippable.

**Codex owns the game's "brain": data, rules, tests (no graphics).** In order:
1. **Stage 2:** `tools/export_godot_data.mjs` (JS data → `godot/data/*.json` after load, i.e. with installed endgame/RPG/hunt content and the game's own names); `rules/zone.gd` (port of game/zones.js + noise.js + placement.js, with `height_at` matching JS sample values exactly); `rules/schema.gd` (new_slot, normalize, v1–v6 migration, **import of current `DL1:` save codes**); `rules/progression.gd`. Plus headless tests and `tools/godot_test.sh`.
2. **Stage 3:** movement, ki, collision, combat (+ avatar, Kaiyoken), forms, mastery, ported from game/*.js with today's checks ported to GDScript.
3. **Stage 4:** `rules/story.gd` (quests, travel pilot, radar, Dragon Orb hunts, shop/items), `rules/cutscene_rules.gd`, `rules/tutorial_rules.gd`, with the whole-story bot (check_story) and check_scenes ported.

**Wait for Claude's Stage 1 release note** (project skeleton, autoloads, the `Data` loader and Events bus) before writing code inside `godot/`. The export tool (`tools/export_godot_data.mjs`) and test runner script can start right away. Claim files as usual, release with validation notes. Codex does not edit `godot/{core,world,characters,fx,ui,scenes}`.

**Claude owns the "body":** Stage 1 foundation (next), then worlds (23, new graphics), characters/animation/forms/VFX, wiring rules into scenes, camera, cutscenes and voices, HUD and menus, builds and releases.

## Claude: claiming (Godot Stage 1: foundation)

Files: new `godot/project.godot`, `godot/core/{data,events,save_store,clock}.gd`, `godot/scenes/main.tscn` + `main.gd`, `godot/icon.png`, `.gitignore` (Godot cache dirs).

## Codex — claiming (Godot exporter and headless test runner)

User explicitly says to start the assigned port. Claiming new `tools/export_godot_data.mjs`, `tools/godot_test.sh`, `tools/check_godot_export.mjs`. Stage 1 is still claimed, not released, so I will not write inside `godot/` until Claude releases it. Exporter validation will use temporary output directories meanwhile. Tables will be one JSON file per Data-loader property (e.g. quests.json, zones.json); namespace tables (stats, appearance, rpg) retain their JS export keys. Manifest includes hashes and source provenance; parity fixtures cover every zone and v1–v6 DL1 save migration/progression. Functions are deliberately excluded. **Claude:** please release Stage 1 when ready and confirm any loader API beyond the design contract so Stage 2 rules can proceed.

## Codex — released (Godot exporter and headless test runner; foundation handoff)

Released `tools/export_godot_data.mjs`, `tools/godot_test.sh`, `tools/check_godot_export.mjs`. No files were written inside `godot/`: Stage 1 remains claimed/not released and its directory does not exist yet. The current web/desktop/mobile sources are untouched.

**Exporter ready for the loader:** `node tools/export_godot_data.mjs` writes **36 JSON tables + manifest.json** to `godot/data/` once the foundation is released. `--out DIR` supports temporary outputs, `--check` rejects missing/stale generated content, `--no-parity` omits test fixtures. All game tables are evaluated JS exports, including installed endgame/RPG/dragon content and converted display names. Table filenames are the intended `Data` property names: quests, npcs, characters, links, start_zones, forms, mastery_evolutions, mastery_tuning, moves, move_order, races, race_order, outfits, outfit_order, accessories, zones, zone_order, stats, combat, movement, camera, cutscenes, form_looks, dragon_hunts, dragon_looks, orb_looks, kaioken, avatar, rpg, appearance, names, character, music, tutorial_steps, schema, parity. Namespace objects such as `stats`, `rpg`, `appearance` keep their original constant keys (e.g. `stats.MAX_LEVEL`, `rpg.ZONE_LEVELS`, `appearance.KI_COLORS`); single-table modules export the table directly. `zones` contains ZONE_DEFS (not function-bearing runtime zones). `cutscenes` is BOSS_SCENES. Tutorial text functions are rendered with `{jump}` / `{base}` etc placeholders; completion predicates must be ported as rules, not serialized. All other functions are explicitly excluded; nested non-JSON/nonfinite values fail export rather than silently corrupting it. Manifest stores table SHA-256, byte counts and source hashes; exports are deterministic.

**Parity fixtures:** every one of the **23** world recipes has height/normal/surface/dirt/forest samples (random, edges, spawn, landmarks and special Snake Way points), seeds, spawn/travel/kill metadata, free-position examples, prop counts/first samples and nearby-collider queries. Includes all **2000** XP thresholds, over **500** race/level/form derived-stat cases, and UTF-8/base64 **DL1** profiles for each of v1–v6 with expected JS migration outputs preserving collected orbs. Fixtures are about 1.3 MiB, generated, never hand-edited. Temporary validated output is `/tmp/dragon-legend-godot-data`.

**Runner:** `tools/godot_test.sh` uses native `godot`/`godot4`, explicit `GODOT_BIN`, or the installed WSL Windows console executable. Quotes project paths, translates paths with wslpath for Windows Godot, performs headless editor import before `res://tests/run_all.gd`, propagates failures and supports alternate project/script plus `--check-data`. It fails clearly if foundation/test entry is absent. No installer or graphical game launch.

**Passed:** `node tools/check_godot_export.mjs` **5** checks: content completeness/names, manifest file/source hashes, all-world/save/progression fixtures, deterministic regeneration/stale rejection, and runner arguments/failure propagation using an explicit stub engine. `bash -n tools/godot_test.sh`, `node --check tools/export_godot_data.mjs`, and `git diff --check` pass. **Real Godot tests have not run.** Found `/mnt/c/Godot/Godot_v4.7.2-stable_win64_console.exe`, but `--version` fails here with `WSL UtilBindVsockAnyPort: socket failed 1`; no native Godot is on PATH. This is a sandbox/WSL interop limitation, not evidence the installed Godot executable is faulty.

**Claude:** the exporter is ready to run when Stage 1 is released. Please expose these tables in Data (or provide its exact accessor API), release the foundation, and note the headless test entry contract. Next Codex work is Stage 2 `rules/zone.gd`, `schema.gd`, `progression.gd` and tests, followed by movement/combat and story. Waiting on the explicit Stage 1 barrier in your assignment; I will not edit your core/scenes or fabricate a competing foundation. Please run the real Godot runner in your unrestricted Windows/WSL environment when the rules land. No commits/builds/publication by Codex.

## Claude: released (Godot Stage 1: foundation), Codex can start inside `godot/`

The Godot project is in `godot/` (Godot 4.7.2, Forward+, typed GDScript with `inference_on_variant` as an error). **Codex now owns `godot/rules/`, `godot/data/`, `godot/tests/` and `tools/godot_test.sh`.** My bootstrap `tools/godot_test.sh` is committed; replace it with yours when you release (both run `res://tests/run_all.gd`).

**Autoloads (godot/core/, Claude's):**
- `Data`: `load_dir(path)`, called with `res://data` at start. Every `<name>.json` becomes the property of that name: `quests`, `npcs` (Arrays) and `characters`, `links`, `forms`, `mastery_evolutions`, `moves`, `races`, `outfits`, `accessories`, `zones`, `stats`, `combat`, `movement`, `camera`, `cutscenes`, `form_looks`, `dragon_hunts`, `kaioken`, `avatar`, `rpg`, `appearance`. `table(name)` reads any table, `errors: Array[String]` lists unreadable files (warning, never fatal). Other file names are reachable through `table()`.
- `Events`: signals `notify(text)`, `dialogue(d)`, `quest_accepted(id, title)`, `quest_completed(id, title)`, `quest_progress(id, objective)`, `travel(zone)`, `enemy_defeated(d)`, `levelup(level, gained)`, `stats(hud)`. **`emit_named("questAccepted", {id, title})` takes the JS event names and payloads**, so ported `emit(...)` calls stay one-liners.
- `SaveStore`: `path` (default `user://profile.json`), `list_slots()`, `load_slot(i)`, `save_slot(i, slot)`, `create_slot(i, look)`, `delete_slot(i)`, with 3 slots and atomic writes. A corrupt file is kept as `.bad`. **When `res://rules/schema.gd` exists it is used: `normalize(slot)` on load, `new_slot(look)` on create**, so give schema.gd those two methods.
- `Clock`: `STEP` (1/60), `MAX_STEPS` (5), `advance(frame_dt) -> int` (steps to run now; leftover dropped after a hitch) and `alpha`.
- `Controls`: input actions with the JS default keys: `move_forward/back/left/right`, `jump`, `melee`, `block`, `dash`, `flight`, `ascend`, `descend`, `charge`, `ki_blast`, `beam`, `transform`, `lock_on`, `interact`, `menu`, `radar`, `base`, `kaioken`, `pause`.

**Tests:** `tools/godot_test.sh [filter]` (filter = substring of `file::test`). Test files are `godot/tests/**/test_*.gd` and `extends TestCase` (`eq`, `ok`, `near`; failures are recorded, not thrown). **A test that hits any engine/script error fails** (the runner counts errors with a Logger), and warnings are allowed. Use fresh `load("res://...").new()` instances in tests, since autoloads aren't ready in `-s` runs. Free any Node you create. The default binary is a Linux Godot 4.7.2 in `~/.cache/godot/` (WSL-native, fast), with the Windows console exe as fallback, or set `$GODOT`.

**Validated:** 17 headless tests pass (runner self-tests, Data 4, Events 3, SaveStore 4, Clock 4, Controls 1). The real Windows Godot launches the project with `-- --smoke` ("smoke ok", no errors).

## Codex — claiming (Godot Stage 2: data, zones, saves and progression)

Stage 1 release and user instruction received. Claiming generated `godot/data/*.json`; new `godot/rules/{tables,noise,zone,schema,progression}.gd`; new `godot/tests/rules/test_{zone,schema,progression}.gd`; `tools/{export_godot_data,godot_test.sh,check_godot_export}.mjs` as applicable (runner is .sh). Will preserve foundation/core/scenes and existing TestCase/runner. Export schema/keys stay identical to JS; constructors accept an optional Data-like loader, and table helper supports fresh headless instances without autoload initialization. Runner will honor GODOT/GODOT_BIN, prefer the native cached Godot, and retain substring test filters. **Claude integration note:** SaveStore currently writes profile version 1 and calls per-slot normalize without passing profile version; please use schema.migrate(profile) / schema version when integrating legacy-profile loading to avoid accidentally rescaling already-v6 levels. I will test schema/new_slot/import directly and will not edit your core files.
**Stage 1 review fixes (Codex, please note):**
- **Runner:** a test file that doesn't parse or doesn't `extends TestCase` is now a FAIL with the reason (it used to hang the run), and a watchdog exits 2 if a script error aborts the run. `tests/fixtures/` is skipped by the normal suite. `tools/check_runner.sh` proves the runner fails broken files.
- **`Data`** only fills the 22 named tables in `Data.TABLES` (an allow-list, so a file like `script.json` can't overwrite the autoload). Any other file is reachable through `Data.table(name)`. **A table with the wrong JSON shape** (e.g. `quests.json` not an Array) is left empty and reported in `Data.errors`. If you export extra tables you want typed (`zone_order`, `start_zones`...), tell me and I'll add properties.
- **`SaveStore`** keeps a corrupt file's exact bytes as `.bad` (read-only if that fails), recovers an interrupted save from `.tmp`, and rolls memory back when a write fails.
- **Spec:** the Events bullet now matches the code (`emit_named`, `levelup(level, gained)`, `stats(hud)`).

### Codex — Stage 2 API available (final validation running)

Generated data and rule modules now exist. For Claude's view work: `load("res://rules/zone.gd").new(zone_id, Data)` (Data argument optional). `height_at`, `normal_at` (Vector3), `surface_at`, `dirt_at`, `forest_at`, `place` (x/z Dictionary), `free_position` (Vector3); metadata `id/name/planet/saga/size/spawn/gravity/kill_y/water/mesas/ground/biome/landmarks/travel_point/def/seed`; `props()` is a cached RefCounted object with `trees/rocks/bushes/stones` arrays of JS-shaped Dictionaries and `near(x,z,radius)`. Doubles are preserved for procedural coordinates and normals via `normal_data`; convert prop positions to Vector3 in views. All 23 worlds' height/surface samples and seeded prop/collision data already match JS; final combined suite is running.

`RuleSchema.new(Data)` offers `new_profile`, `new_slot(look, optional_now_ms)`, `normalize(slot)`, `migrate(profile)`, `import_code(DL1_string) -> {ok, profile}` or `{ok:false,error}`, `export_code(profile)`, `default_look`, `validate_look`, `outfit_allowed`, `normalize_ki_hex`. **normalize(slot) assumes current schema and never rescales levels; migrate(profile) reads the profile version and scales v1–v3 exactly once.** Player/save/derived-stat Dictionary keys stay JS camelCase, method names are snake_case. `RuleProgression` exposes the JS progression API in snake_case. Rule constructors work both with fresh injected Data Nodes and without initialized autoloads, via a cached read-only table helper. Core/scenes remain yours and untouched.

## Codex — released (Godot Stage 2: data, zone parity, DL1 saves and progression)

**Stage 2 is complete and released for integration.** Files: generated `godot/data/` (**36 tables + manifest**); new `godot/rules/{tables,noise,zone,schema,progression}.gd` and generated `.uid` files; `godot/tests/rules/test_{zone,schema,progression}.gd` and their `.uid` files; `tools/export_godot_data.mjs`, `tools/check_godot_export.mjs`, updated `tools/godot_test.sh`. The current web/desktop/mobile game and Claude's Godot core/scenes/TestCase/test runner files were not edited.

**Data:** evaluated current JS content, 41 main quests, all races/forms/moves/outfits, 23 zone recipes, all dragon hunts, renamed display text, tunings, music/character metadata and tutorial text templates. Manifest checks source/table hashes; `--check` verifies generated files have not drifted. `parity.json` contains synthetic fixtures, not user saves: **600** terrain points across all **23** worlds, prop counts/first samples and nearby collision queries, authored safe placements, **549** race/level/form derived-stat cases, all **2000** XP thresholds, and **six** real-format DL1 save codes with expected JS migration results (v1–v6).

**Zones:** complete JS terrain/noise/prop-placement port, including Mulberry32 unsigned arithmetic and Float32 gradient rounding, fractal hills/mountains/mesas, ocean islands/lakes, landmark flattening/craters, Snake Way, planetoid, intact/broken platforms and void edges. Height/normal/surface/dirt/forest parity passes (height/normal tolerance **1e-9**, dirt/forest **1e-10**); prop counts and sampled transforms/collider queries match JS across every world. Props build lazily and memoize; safe NPC placement ports the same radius/angle search. `normal_at`/`free_position` return Vector3 (normal/position conversion uses normal Godot vector precision), while procedural samples/props/spawn/place data retain double Dictionary coordinates. Detailed API is immediately above this release.

**Schema:** v6 `new_slot`, per-slot `normalize`, profile-level `migrate`, default appearance and validation, all prior save migrations and unlock reconciliation; legacy Saiyan ids/mastery/collected orbs/custom hex/test-path flags are retained. v1–v3 level/XP/stat-point expansion happens **only in migrate(profile)** and never repeats. `import_code` validates DL1 prefix/base64/UTF-8/JSON/profile and rejects future versions; returns `{ok:true, profile}` or `{ok:false,error}`. Unicode codes round-trip. `export_code` provides the same transferable DL1 format. Instance normalization is compatible with the existing SaveStore.new_slot/normalize hook and is tested through that real core store. `new_slot` expects a validated look, matching the JS schema contract; `validate_look` is available to the creator/save-store integration.

**Progression:** level-2000 XP curve, race bonuses, form availability/multipliers, stat derivation, XP gain/cap/stat points and validated stat spending. Function names snake_case; saved/derived Dictionary field names stay camelCase, as in JS. Rule constructors take an optional Data-like loader; fresh headless instances work without autoload initialization and injected fresh Data is explicitly tested.

**Validation:** `tools/godot_test.sh --check-data` on native **Godot 4.7.2.stable.official.ed1daf0bf** finished with **31 passed, 0 failed** (**17 foundation + 14 Stage 2**). Includes every terrain/prop/placement comparison, 549 derivations, 2000 thresholds, v1–v6 import/migration/idempotence, corrupted/future/Unicode codes, normalization and real SaveStore hook. Exporter/runner node checks **5 passed**; generated-data freshness passed; shell/JS syntax and `git diff --check` pass. Full native log: `/tmp/dragon-stage2-final.log`. The editor import prints sandbox TCP-binding diagnostics outside the test cases; the headless suite completes successfully and its Logger records no rule/test errors. Earlier test alias/initialization mistakes were corrected before this final run. No GPU/graphics claim and no commit/build/publication by Codex.

**Runner integration:** supports existing `tools/godot_test.sh [filter]`, both `GODOT` and `GODOT_BIN`, cached native Linux Godot preferred over the Windows fallback, quoted WSL paths, alternate project/script and optional `--check-data`. Editor import registers the new classes; suite errors propagate through the shell exit code.

**Claude:** Stage 2 is ready for your Stage 5 world/view work. Please review the SaveStore integration note in the claim: it currently writes profile version **1**, whereas these are v6-shaped Godot slots. Update profile metadata to SCHEMA_VERSION when integrating save-code import/export; legacy JS profile migration must use the actual incoming profile version, while routine per-slot `normalize` must not scale modern levels. Core save I/O remains your lane. Stage 3 movement/combat/forms/mastery and Stage 4 story are not part of this Stage 2 release and are next under the approved split.

## Claude: claiming (Godot Stage 5: worlds)

Plan: `docs/superpowers/plans/2026-11-02-godot-stage5-worlds.md`. Files: new `godot/world/**`, `godot/assets/**`, `godot/scenes/world_preview.*`, `godot/tests/world/**`, `tools/fetch_assets.sh`, `tools/world_shots.sh`. Views read Codex's `RuleZone` only (`height_at`, `surface_at`, `props()`, `landmarks`, `water`...). I won't touch `rules/`, `data/` or Codex's tests.

## Claude: integrated Codex's Godot Stage 2 (commit 6943efc), claiming `godot/core/save_store.gd`

48 headless tests pass with `--check-data`, plus the runner check and the 5 exporter checks. Fixing the SaveStore version note: files get `version = RuleSchema.SCHEMA_VERSION` (6), and an older file goes through `migrate(profile)` once on load.

## Codex — claiming (Godot Stages 3–4: complete gameplay brain)

User directs completion of all remaining Codex work without routine permission questions. Claiming new `godot/rules/{runtime,ki,movement,collision,forms,mastery,kaioken,combat,game,story,cutscene_rules,tutorial_rules}.gd`, generated UIDs, new `godot/tests/rules/test_{movement,combat,forms,kaioken,avatar,story,scenes,dragon_hunts,gameplay_parity}.gd`, fixture/export updates in `tools/{export_godot_data,check_godot_export}.mjs` and generated `godot/data/*.json`. Preserve Claude's active core/save-store/world/assets/scenes work. Will release a stable game/movement/combat API as soon as Stage 3 passes while continuing Stage 4 to completion. Positions/velocities are Vector3; persisted slot/derived state keys remain JS camelCase; intents and rule methods use snake_case per contract. Runtime links use weak references to prevent Game/Combat/Story ownership cycles. No web-game edits, installer builds or publication.
Released `godot/core/save_store.gd` (schema version + one-time migration), committed 4ed1259.

## Claude: released (Godot Stage 5: worlds)

All 23 worlds render in Godot from `RuleZone`. Entry point: `WorldView.build(zone_id, quality) -> Node3D` (meta "zone", "grass"). Set `grass.target` to the camera or player node.
- **Terrain:** heights exactly from `height_at`, a splat of CC0 Poly Haven ground scans, rock on cliffs, polished tiles on stone worlds, Serpent Road as a curved road ribbon, void left open, trimesh collision from the drawn triangles.
- **Grids are baked** into `godot/world/baked/` (medium + high, keyed by a hash of the world's recipe + `GRID_VERSION`), so worlds load in ~5 s. **Codex: if you change a zone recipe in data/rules, re-run `godot --headless --path godot -s res://tools_bake_terrain.gd`.** Stale bakes are ignored automatically, just slower until rebaked.
- **Atmosphere:** sky per biome, sun with shadows, haze, clouds, cloud seas under floating worlds. Water with depth colour, waves and foam. Wind grass streamed around the target. Trees (broadleaf, pine, palm, ajisa, crystal), CC0 scanned rocks, shrubs and dead trees. All 34 landmark types.
- **Performance on the user's GTX 1650 Ti:** 48–60 fps on medium in every world (SSAO is high-only). Quality presets are low, medium (default) and high.
- **Tests:** 14 world tests. `tools/world_shots.sh` renders every world on the GPU. Codex's in-progress `rules/test_movement.gd` currently fails (`dash` ki 88.13 vs 88), which is not part of any release.

## Codex — Stage 3 API ready; Stage 4 final validation underway

Movement/combat/form/Kaioken/Avatar focused tests now pass (21 behavioral tests, plus JS movement trace parity). `RuleGame.new(index, slot, Events)` owns `player`, `entities`, `zone`, `combat`, `kaioken`; call `update(1.0/60, snake_case_intents)`. Positions/velocities and attack event coordinates are Vector3; save positions remain Dictionaries. `combat.aim_state()`, `snapshot()`, `avatar_state()`, `available_techniques()`, `set_technique(id)` are available. Kaioken has `ranks/select/toggle/stop/snapshot`; form and customization commands follow the spec. Runtime timers never persist. Children reference Game/Story weakly.

**Claude integration requirement:** core Events currently maps only the foundation/story events. Please add passthrough Dictionary signals/mapping for JS event names **attack, damage, beam, avatarStrike** (snake_case signal `avatar_strike`). Combat emits them for your VFX/views; I have preserved core ownership. Full Stage 4 story API now exists; retain the Story instance alongside Game, run `story.update(dt,intents)` after Game, and listen to `travel` to save/recreate both in the requested world. `RuleCutsceneRules.new(slot)` provides `before_for(encounters, player.pos)` and `after_for(enemy, name)` with persisted once-only flags; `RuleTutorialRules.new(slot)` provides active/index/step/total, text(labels), look/note/update/skip/restart. Final whole-suite validation and formal release will follow.

## Claude: claiming (Godot Stage 6: characters)

Plan: `docs/superpowers/plans/2026-11-02-godot-stage6-characters.md`. Files: new `godot/characters/**`, `godot/fx/**`, `godot/assets/characters/**`, `godot/tests/characters/**`, `godot/tools_char_shot.*`. Body: CC0 Quaternius Universal Animation Library humanoid (53-bone rig, 46 animations). Model API = the JS model contract (`create`, `update(dt, anim)`, `set_form`, ...).

## Codex — released (Godot Stages 3–4: complete gameplay rules)

**All remaining Codex stages are complete and released for Claude integration.** New rule files: `godot/rules/{runtime,ki,movement,collision,forms,mastery,kaioken,combat,game,story,cutscene_rules,tutorial_rules}.gd` and their UIDs. New tests: `godot/tests/rules/test_{movement,combat,forms,kaioken,avatar,story,scenes,dragon_hunts,gameplay_parity}.gd`, shared helpers `game_case.gd` / `story_case.gd` and UIDs. Exporter/checker updates plus generated `narrative.json`, `parity.json`, `manifest.json` are released too. Narrative table contains evaluated/renamed talk replies, ambient lines, item labels and interaction tuning; use `Data.table("narrative")`. **37 generated tables + manifest**, now including JS-oracle movement and damage fixtures. No zone recipes or terrain rules changed, so existing terrain bakes remain valid.

**Stage 3:** fixed-step movement, flight/pitch/charge/dash/jump/gravity/prop and cliff collision; all combat techniques, projectiles, beams, combos, guard/shield/UI dodge/Ultra Ego, enemy AI, lock-on/aim, kills/rewards and respawn; race form validation and customization/equipment commands; mastery evolution (shared Saiyan/Half-Saiyan grades/full power, ape chain and Rage); exclusive level-2000 paths; independent Kaiyoken overlay on Saiyan forms and rank/strain/cooldown handling; Avatar's 60-second duration and independent 120-second activation cooldown. The earlier dash failure mentioned in Claude's Stage 5 note is **fixed**: a port typo decremented dash time twice; timing and cost now match the JS oracle.

**Stage 4:** complete quest state machine, reward/unlock reconciliation, NPC visibility/markers/dialogue/validated acceptance, training/collect/defeat/reach/talk/travel/level objectives, shops/consumables, tracker/journal/waypoints, pilot travel validation, radar and Earth/Namek/Super/Cereal orb hunts with saved collection and summoning/wishes; void rescue; persisted once-only boss scene rules and all 14 action-driven tutorial steps. Tests walk all **41 main quests** and **47 side/trainer quests** using actual pilot travel, validate all races' form quests and Saiyan/Half-Saiyan **beast/instinct/ego** branches, mastery prerequisites, required-form Avatar training, real Combat→Story kill credit, duplicate-reward prevention and save persistence. Bot tests accelerate training time and deliver kill-credit unit events for campaign traversal; a separate test verifies a real combat death advances the objective exactly once.

**Integration API:** prior API note remains accurate. Keep strong references to Game and Story in play scene; their children use weak references. Run `game.update(dt,intents)` then `story.update(dt,intents)` at 1/60. Read camelCase player/save/snapshot Dictionary fields; methods and intents are snake_case. `story.interact(true)` requests a choice dialogue; `interact()` directly chooses the priority offer. Travel emits an event rather than replacing the session; save `game.to_save()`, set destination/reset position and construct new Game/Story. Scene director `before_for` takes Vector3 player position. Tutorial `text(labels)` uses exported camelCase binding placeholders (`kiBlast`, `lockOn`); tutorial intents are snake_case. Rules are RefCounted, with no rendering Nodes.

**Remaining Claude-owned wiring:** add Events mappings/signals for `attack`, `damage`, `beam`, `avatarStrike` (`avatar_strike` signal); keep their Dictionary payloads/Vector3 coordinates. Implement/render play scenes, character/VFX/UI/voices and platform releases under Stages 6–8. No changes were made to Claude-owned core/world/characters/fx/ui/scenes/assets, or the existing web/desktop/mobile game. No commits, installers, publication or GPU validation by Codex.

**Final validation:** native Godot **4.7.2.stable.official.ed1daf0bf**, `tools/godot_test.sh --check-data`: **86 passed, 0 failed**, exit **0**; **48 rule tests** including 34 new Stage 3/4/parity tests plus foundation/world coverage. Full log `/tmp/dragon-godot-final.log`. `node tools/check_godot_export.mjs`: **5 passed**, log `/tmp/dragon-export-final.log`. JS original `node tools/check_movement.mjs` (10) and `node tools/check_story.mjs` (18) passed as reference checks; node/shell syntax and `git diff --check` pass. Editor import still prints sandbox TCP bind diagnostics outside test cases; no rule/test script errors and no failing cases. Export freshness includes unchanged terrain/progression/save fixtures plus six movement traces and six damage/guard cases evaluated from JS. All files in this Codex claim are now released.
