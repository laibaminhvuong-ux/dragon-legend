class_name WorldView
extends RefCounted
# One complete world from Codex's RuleZone: terrain, atmosphere, water (vegetation and landmarks join in later tasks).
# The returned node carries the zone as meta "zone".

static func build(zone_id: String, quality := "high") -> Node3D:
	var zone: RefCounted = load("res://rules/zone.gd").new(zone_id)
	var root := Node3D.new()
	root.name = "World_" + zone_id
	root.set_meta("zone", zone)
	root.add_child(load("res://world/atmosphere.gd").build(zone, quality))
	var terrain: Node3D = load("res://world/terrain.gd").build(zone, quality)
	root.add_child(terrain)
	var grass: Node3D = load("res://world/grass.gd").create(terrain, zone, quality)
	root.add_child(grass)
	root.set_meta("grass", grass)
	root.add_child(load("res://world/props.gd").build(zone, quality))
	var water: Node3D = load("res://world/water.gd").build(zone)
	if water != null:
		root.add_child(water)
	return root
