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
