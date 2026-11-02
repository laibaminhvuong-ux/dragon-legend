# Dragon Ball

A standalone 3D action RPG inspired by Dragon Ball, shipped as a **downloadable app** (Windows first, then Android, Mac and Linux). It is not a Roblox game. It has the same idea and systems as our earlier Roblox project (`~/dbz-project`), rebuilt as our own engine-free web game packaged as an app.

Three AI agents work in this one folder at the same time: **Claude Code**, **Codex** and **Freebuff**.

Status: brand new (started 2026-11-01). No code yet. The first step is for the user to confirm the tech setup below. The game design is carried over from the Roblox project, which the user has already confirmed.

## Tech setup (proposed, waiting for the user's confirmation)

We use the same pipeline as Cage Career 3D, which already ships as a Windows app:

- **Engine:** [Three.js](https://threejs.org) (version pinned and vendored in `web/vendor/`, no CDN at runtime) with plain ES modules. No game engine, no framework.
- **Bundling:** esbuild bundles `web/` into `dist/site/`.
- **Desktop app:** Electron in `desktop/`. It loads the bundled game from a custom `app://game/` protocol and forces the dedicated GPU. electron-builder makes `Dragon-Ball-Setup.exe` and a portable zip.
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
- **Name:** the user chose **"Dragon Ball"** as the app name. Note: "Dragon Ball" and the character/move names are trademarks of their owners. That's fine for a personal project, but the integrator raises it with the user before any public release or store listing.

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
