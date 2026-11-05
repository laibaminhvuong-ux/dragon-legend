class_name WorldView
extends RefCounted
# One complete world from Codex's RuleZone: terrain, atmosphere, water (vegetation and landmarks join in later tasks).
# The returned node carries the zone as meta "zone".

## Maps at least this big (planets) stream their terrain around the camera instead of building it all.
const STREAM_SIZE := 1200.0
static var force_stream := false   # dev: --stream=1 in the world preview

static func build(zone_id: String, quality := "high") -> Node3D:
	return build_zone(RulePlanet.open(zone_id), quality)

## Builds the world for an already loaded map (an area or a planet).
static func build_zone(zone: RuleZone, quality := "high") -> Node3D:
	var root := Node3D.new()
	root.name = "World_" + zone.id
	root.set_meta("zone", zone)
	root.add_child(load("res://world/atmosphere.gd").build(zone, quality))
	var terrain: Node3D
	if force_stream or float(zone.size) >= STREAM_SIZE or zone is RulePlanet:
		terrain = TerrainStream.create(zone, WorldTerrain.grid_for(zone, quality))
		(terrain as TerrainStream).update_around(Vector3(zone.spawn.x, 0, zone.spawn.z), true)
		root.set_meta("stream", terrain)
	else:
		terrain = load("res://world/terrain.gd").build(zone, quality)
	root.add_child(terrain)
	var grass: Node3D = load("res://world/grass.gd").create(terrain, zone, quality)
	root.add_child(grass)
	root.set_meta("grass", grass)
	root.add_child(load("res://world/props.gd").build(zone, quality))
	var marks: Node3D = load("res://world/landmarks.gd").build(zone)
	root.add_child(marks)
	if marks.has_meta("towns"):
		root.set_meta("towns", marks.get_meta("towns"))   # towns stream in like chunks; play feeds it the player position
	var water: Node3D = load("res://world/water.gd").build(zone)
	if water != null:
		root.add_child(water)
	if zone is RulePlanet:
		for lake: Dictionary in (zone as RulePlanet).lakes():
			root.add_child(WorldWater.build_body(zone, lake))
	return root
