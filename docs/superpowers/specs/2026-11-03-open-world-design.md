# Open World: one map per planet

**Status:** approved direction (user, 2026-11-03: "One big map per planet"). Godot game only; the classic
`web/` game is unchanged.

## Goal

Each planet is one seamless map you can walk and fly across with no loading screens between its places.
The existing areas become *regions* on their planet's map, and there are new towns, cities and villages
with roads between them. The story keeps working unchanged: every quest, NPC and enemy still names its
area (`zone` id), and the planet map places that area's local coordinates at the region's spot.

## What players get

- **Earth:** about 3.2 km × 3.2 km. Ten areas become regions, joined by countryside, roads and a southern sea.
  - **New places:** Amber City (a big modern city of domed buildings and towers), Pepper Village (farms),
    Snowpeak Village (north, by the glacier) and Harbor Town (a port on the south-east coast).
  - **Still separate areas** (they can't sit on the ground map): Kamu's Lookout (in the sky) and the
    Hyperbolic Time Room. The Earth pilot and the travel guide still reach them.
- **Other planets** get bigger maps (1.6–2.4 km) with their current area plus new places:
  - **Nameck and New Nameck:** three villages.
  - **Yardran:** two hut villages.
  - **Grain:** a farm town and a market town.
  - **Beeros's Planet:** temple gardens.
  - **Future Earth:** a ruined city district.
  - **Sacred World of the Kae and the Nameless Planet:** one more site each.
- **Other World** (Serpent Road with the Check-In Station), **King Kae's Planet**, the **Null Realm** and
  **Babido's ship interior** stay as they are.
- **Travel and fast travel:** fly or walk anywhere on a planet. The pilot still offers instant travel to any
  unlocked region, and to other planets. Entering a region for the first time unlocks it ("Discovered:
  West Capital").
- **HUD and map:**
  - The HUD shows the region you're in.
  - A world map screen (default key `N`) shows the planet, its regions and towns, quest markers and you.
  - The radar keeps working.
- **Towns** have walking townsfolk, a shop and a few ambient lines. New side quests can be added later
  through the same data.

## Earth layout (planet metres, +z north)

| Region | Centre (x, z) | Radius |
|---|---|---|
| earth_plains (start) | 0, 0 | 300 |
| west_city | 1100, 150 | 260 |
| red_ribbon (north-east coast) | 1250, 1050 | 280 |
| gero_lab (northern mountains) | 0, 1150 | 280 |
| broly_glacier (north-west, snow) | -1100, 1150 | 300 |
| gizard_wasteland (west, mesas) | -1150, 100 | 300 |
| babidi_ship (south-west wastes) | -700, -650 | 260 |
| cell_games | 300, -900 | 260 |
| kame_island (south-east sea) | 1150, -1250 | 200 |
| papaya_island (south sea) | -150, -1350 | 260 |
| **Amber City** (new) | 650, -350 | 240 |
| **Pepper Village** (new) | -450, 450 | 150 |
| **Snowpeak Village** (new) | -650, 1350 | 140 |
| **Harbor Town** (new) | 750, -1050 | 160 |

Sea level 0 (every ocean recipe already uses 0). The ground falls away to the sea south of z ≈ -950,
around the island regions, and along the north-east coast at Red Ribbon.

## Contract

### Data: `planets.json` (from `tools/godot_additions.mjs`)
```
{ "earth": { "name": "Earth", "size": 3200, "seed": 7, "sea": 0, "biome": "<zone id whose sky/fog/tints the
  countryside uses>", "base": {"hills": {"amp", "scale"}, "coast": [{"x","z","r"}...]},
  "regions": [{"zone": "earth_plains", "x": 0, "z": 0, "radius": 300, "blend": 80}, ...],
  "roads": [{"from": "earth_plains", "to": "west_city", "width": 6}...],
  "towns": [{"id": "amber_city", "name": "Amber City", "kind": "city", "x", "z", "radius"}...] } }
```
New towns are ordinary zones in `zones.json` (`kind: "town"`, terrain recipe plus `town` landmarks), so
NPCs, shops and quests attach to them like any other area. `zone_order` keeps story order. Each region
zone gets `planet: "<planet id>"` in data.

### Rules (Codex): `rules/planet.gd` `RulePlanet`, the same surface as `RuleZone`
Everything that takes a `RuleZone` today accepts a `RulePlanet`:
- **Ground queries:** `height_at`, `normal_at`, `surface_at`, `dirt_at`, `forest_at`, `props()`,
  `free_position`, `kill_y` and `water` (`{level: 0, ocean: true}`).
- **Identity:** `id` is the planet id. `spawn` is the start region's spawn in planet space.
- **New for regions:**
  - `regions` (array of region dicts).
  - `region_at(x, z) -> String`: the region whose weight is highest there, or `""` in the countryside.
  - `has_region(zone_id) -> bool`.
  - `to_planet(zone_id, local: Dictionary) -> Dictionary` and `place_in(zone_id, x, z)`, which
    replace `zone.place` for authored points.
  - `region_def(zone_id) -> RuleZone`, the region's own recipe evaluated locally.
- **Height:** the countryside base terrain, blended with each region's own `RuleZone` height by
  `smoothstep(radius + blend, radius, distance)`. A region's `edge: "mountains"` walls are off inside a
  planet. Surface and props come from the region with the highest weight; the countryside has its own
  props.
- **Story, combat and tutorial** use `zone.has_region(step.zone)` instead of `step.zone == zone.id`, and
  `zone.place_in(...)` for coordinates. `RuleStory.travel_to(region)` on the same planet moves the player
  (no rebuild) and keeps the save. To another planet, it travels as today.
- **Saves:** `slot.zone` keeps the *region* id (so old saves and save codes still work), and
  `slot.position` is in planet space. The schema's migration converts old region-local positions once,
  bumping the save version to 7.
- **Discovery:** `slot.story.unlocked` gets a region when you first enter it (Events `notify`
  "Discovered: …").
- **Tests:**
  - Every Earth region's local height equals the planet height at its centre ±1 m.
  - Every quest step's position resolves on its planet.
  - The walk/fly path between neighbouring regions never crosses the void.
  - Old saves migrate exactly once.
  - The JS parity tests keep testing each region's own recipe.

### Views (Claude)
- **Big-map terrain:** `world/terrain.gd` streams 128 m chunks around the camera. LOD runs from 2 m cells
  (near) to 4 m to 8 m (far), meshes are built on a worker thread, and collision is a moving HeightMapShape
  around the player. A baked 2 m height/surface grid per planet (`world/baked/`) keeps loading under 10 s.
  The sea is one water plane at level 0. Grass streams as now; props are MultiMeshes per chunk.
- **Towns:** `world/town.gd` builds procedural cities and villages from a seed: domed round houses, towers,
  shops, plazas, street lamps, roads and fences, with collision boxes. Roads are flat ribbons draped on the
  terrain.
- **Integration:** the HUD region name; the world map screen; townsfolk (simple wandering NPCs with
  ambient lines); a region-discovered toast; and music by region.
- **Performance target:** 60 fps on the GTX 1650 Ti at "high", flying fast across Earth. A planet loads in
  under 10 s.

## Work split and order
1. **Codex:** `RulePlanet` + `planets.json` export + story/combat/save changes + tests (Phase 1).
2. **Claude, in parallel:** streaming LOD terrain, sea and props for big maps, tested first on a large
   single zone (`htc`, 900 m), then on the planet once Phase 1 lands; then the town builders, roads, the
   map screen and the HUD (Phase 2).
3. **Integration (Claude):** play scene on planets, travel, discovery, GPU checks of every planet, story-play
   through all 41 main quests (Phase 3).
4. **Other planets' layouts and towns** (data by Codex, builders by Claude) (Phase 4).

If Codex hasn't claimed Phase 1 by the time Phase 2's terrain streaming is done, Claude implements Phase 1
too (the user asked for the work to be finished, not to wait).

## Risks
- **Height blending at region borders** can make cliffs where a region's recipe is far above or below the
  countryside. Countryside heights near a region are pulled to that region's edge height. Tests sample the
  borders.
- **Ocean regions inside a land planet:** the countryside drops below sea level around them, so
  islands stay islands.
- **Performance of composite height queries:** gameplay uses exact rules heights (only the player and
  enemies are queried each step). Rendering and collision use the baked grid.
