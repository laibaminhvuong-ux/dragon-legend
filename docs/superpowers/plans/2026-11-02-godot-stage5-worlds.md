# Godot Stage 5: Worlds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (the user chose Native execution for this port) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** All 23 worlds render in Godot from Codex's `RuleZone` (exact JS heights, surfaces and props), looking clearly better than the web game: photo-scanned ground textures, dense wind-blown grass, proper water, sky, fog and shadows, and every landmark.

**Architecture:** `world/world_view.gd` builds a world Node3D from `RuleZone.new(zone_id, Data)`. Its builders are split by job: terrain (chunked mesh + splat shader + collision), atmosphere (sky, sun, fog, per-biome tints), water, vegetation (grass MultiMesh, trees/rocks/bushes from `zone.props()`) and landmarks (one builder per type). `scenes/world_preview.tscn` loads any world with a free camera and can save a screenshot, which is how every world is checked on the real GPU.

**Tech Stack:** Godot 4.7.2 Forward+, GDScript, spatial shaders; CC0 assets from Poly Haven (textures, models).

**Spec:** `docs/superpowers/specs/2026-11-02-godot-port-design.md` (Graphics direction, Stage 5)

## Global Constraints

- Heights, surfaces, props and landmark positions come only from `RuleZone` (Codex). Views never recompute terrain.
- Coordinates are as in the spec: metres, +Z forward at yaw 0, models face +Z.
- Assets are CC0 only, downloaded by `tools/fetch_assets.sh` into `godot/assets/`, and listed in `godot/assets/LICENSES.md`.
- Target 60 fps on a GTX 1650 Ti at 1080p on the "high" preset.
- Claude's folders only: `godot/world/`, `godot/fx/`, `godot/scenes/`, `godot/assets/`, plus view tests in `godot/tests/world/`.

## Review Focus

- **Worlds with special terrain:** Serpent Road (a narrow path over a void), King Kae's planetoid, the floating Lookout, the Null Realm void. They render without holes or skirts hanging in the sky, and the camera can't see under the world. Pinned in Task 2 (terrain skips void cells) and Task 6 (screenshot of every world).
- **Water worlds** (Kama House ocean, Nameck lakes): the water is level with `zone.water.level` and there's no z-fighting where it meets the shore. Pinned in Task 3.
- **Performance:** grass density and draw distance must hold 60 fps. Grass is chunked with distance fade, and a quality preset scales density. Pinned in Task 4 (fps printed per preview).
- **Missing assets** (offline machine, fetch not run): the world still renders with flat-colour fallbacks instead of crashing. Pinned in Task 1.
- **Collision matches visuals:** the player stands on the drawn ground. The collision shape is built from the same height samples. Pinned in Task 2 (test).

---

### Task 1: CC0 asset fetch with fallbacks
**Files:** create `tools/fetch_assets.sh`, `godot/assets/LICENSES.md`, `godot/world/materials.gd`, `godot/tests/world/test_materials.gd`
**Produces:** `Materials.ground(kind: String) -> Dictionary` (`albedo`, `normal`, `rough` Texture2D or null) for `grass`, `dirt`, `rock`, `sand`, `snow`, `forest`, `white`. `Materials.has_textures() -> bool`.
- [ ] Test: with no `godot/assets/textures`, `ground("grass")` returns null textures and doesn't crash. With fixtures present, it returns Texture2D.
- [ ] Fetch script: Poly Haven 1k diffuse, normal (GL) and roughness for aerial_grass_rock (grass), brown_mud_leaves_01 (forest), dry_ground_01 (dirt), rocky_terrain_02 (rock), coast_sand_01 (sand) and snow_02 (snow). It writes LICENSES.md.
- [ ] Run, then commit.

### Task 2: Terrain mesh, splat shader and collision
**Files:** create `godot/world/terrain.gd`, `godot/world/shaders/terrain.gdshader`, `godot/tests/world/test_terrain.gd`
**Produces:** `Terrain.build(zone: RuleZone, quality: String) -> Node3D` with `MeshInstance3D` chunks (64 m, 1 m cells near spawn, 2 m elsewhere, on "high") and a `StaticBody3D` + `HeightMapShape3D`. Vertex colour encodes splat weights (grass, dirt, rock, sand/snow) from `zone.surface_at`/`dirt_at`/`forest_at`. Cells whose height is below `zone.kill_y` (void) are left out.
- [ ] Test: for 50 random points inside the world, the mesh vertex nearest to (x, z) has y == `zone.height_at(x, z)` within 1e-4, and the collision shape's height at a grid point equals the mesh. For `snake_way`, no triangle touches a vertex below `kill_y`.
- [ ] Shader: triplanar on steep slopes, height-blended splat of the 5 ground textures, a macro-variation noise to break tiling, and a flat-colour fallback when textures are missing.
- [ ] Commit.

### Task 3: Atmosphere and water
**Files:** create `godot/world/atmosphere.gd`, `godot/world/water.gd`, `godot/world/shaders/water.gdshader`
**Produces:** `Atmosphere.build(zone) -> Node` (WorldEnvironment with a sky from `biome.sky`: physical sky by elevation/azimuth, or a gradient sky; sun DirectionalLight3D with cascaded shadows; volumetric or height fog from `biome.fog`; ACES tonemap, glow, SSAO, SSIL on "high"). `Water.build(zone) -> Node3D` (a plane or disc at `zone.water.level` with a depth-coloured, normal-mapped, reflective shader, plus a foam edge from the depth difference).
- [ ] Test (headless): Kama House water's global y == `zone.water.level`. A zone without water builds nothing.
- [ ] Commit.

### Task 4: Vegetation
**Files:** create `godot/world/grass.gd`, `godot/world/shaders/grass.gdshader`, `godot/world/props.gd`
**Produces:** `Grass.build(zone, quality) -> Node3D` (MultiMesh blades per 32 m chunk on grass and forest surfaces, with density by preset, wind sway, distance fade and colour from `biome.tints`). `Props.build(zone) -> Node3D` (trees, rocks, bushes and stones from `zone.props()` as MultiMeshes, using CC0 models when fetched and procedural meshes otherwise).
- [ ] Test (headless): prop instance counts equal `zone.props()` array sizes. No grass instance sits on a rock, sand or snow cell.
- [ ] Preview fps on earth_plains printed ≥ 60 on the GPU (if lower, reduce the "high" density and record a ledger ruling).
- [ ] Commit.

### Task 5: Landmarks
**Files:** create `godot/world/landmarks.gd` (one `_build_<type>(l: Dictionary) -> Node3D` per type, ported from `web/src/world/landmarks.js` with better materials) and `godot/tests/world/test_landmarks.gd`
**Produces:** `Landmarks.build(zone) -> Node3D`, placing every `zone.landmarks` entry at (x, base, z) with `rot` and `scale`, and a collision cylinder where `collide` is set.
- [ ] Test: every one of the 33 types in `zones.json` has a builder (no "unknown landmark" fallback used), and each landmark node is at its rule position.
- [ ] Commit.

### Task 6: World assembly, preview and the all-worlds pass
**Files:** create `godot/world/world_view.gd`, `godot/scenes/world_preview.tscn` + `.gd`, `tools/world_shots.sh`
**Produces:** `WorldView.build(zone_id: String, quality := "high") -> Node3D`. The preview takes `-- --zone=<id> --shot=<png> [--cam=x,y,z,yaw,pitch]`, prints `fps <n>` and quits after the shot.
- [ ] `tools/world_shots.sh` runs the Windows (GPU) editor build for every zone and collects 23 screenshots plus fps.
- [ ] Review every screenshot for holes, floating props, wrong water or missing landmarks. Fix, then commit.
