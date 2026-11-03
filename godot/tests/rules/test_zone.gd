extends TestCase
const Zone = preload("res://rules/zone.gd")
const NoiseRules = preload("res://rules/noise.gd")
const Tables = preload("res://rules/tables.gd")

func test_all_world_heights_normals_surfaces_match_js() -> void:
	var worlds: Dictionary = Tables.table("parity").zones
	for id: String in worlds:
		if _godot_only(id):
			continue
		var zone := Zone.new(id)
		var fixture: Dictionary = worlds[id]
		eq(zone.seed,int(fixture.seed),id)
		near(zone.spawn.x,fixture.spawn.x,1e-10,id+" spawn")
		near(zone.spawn.z,fixture.spawn.z,1e-10,id+" spawn")
		for row: Dictionary in fixture.samples:
			var location: String = "%s at %.4f,%.4f" % [id,row.x,row.z]
			ok(is_finite(zone.height_at(row.x,row.z)),location+" finite height")
			near(zone.height_at(row.x,row.z),row.height,1e-9,location)
			var normal: Dictionary = zone.normal_data(row.x,row.z)
			for axis: String in ["x","y","z"]:
				near(normal[axis],row.normal[axis],1e-9,location+axis)
			eq(zone.surface_at(row.x,row.z),row.surface,location+" surface")
			near(zone.dirt_at(row.x,row.z),row.dirt,1e-10,location+" dirt")
			near(zone.forest_at(row.x,row.z),row.forest,1e-10,location+" forest")
	eq(worlds.size(),23)

func test_seeded_props_and_collision_queries_match_js() -> void:
	for id: String in Tables.table("parity").zones:
		if _godot_only(id):
			continue
		var zone := Zone.new(id)
		var fixture: Dictionary = Tables.table("parity").zones[id]
		var props: RefCounted = zone.props()
		ok(props == zone.props(),"memoized")
		for kind: String in ["trees","rocks","bushes","stones"]:
			var values: Array = props.get(kind)
			eq(values.size(),int(fixture.props[kind].count),id+" "+kind)
			for i in mini(3,values.size()):
				var expected: Dictionary = fixture.props[kind].first[i]
				for key: String in expected:
					near(float(values[i][key]),float(expected[key]),1e-8,id+" "+kind+" "+key)
		for query: Dictionary in fixture.near:
			var found: Array = props.near(query.x,query.z,query.radius)
			eq(found.size(),query.expected.size(),id+" nearby collision count")
			for i in mini(found.size(),query.expected.size()):
				for key: String in ["x","z","radius","top"]:
					near(found[i][key],query.expected[i][key],1e-8,id+" collider "+key)

func test_authored_placements_and_void_road_boundaries() -> void:
	for id: String in Tables.table("parity").zones:
		if _godot_only(id):
			continue
		var zone := Zone.new(id)
		for row: Dictionary in Tables.table("parity").zones[id].placements:
			var point: Vector3 = zone.free_position(row.input)
			for axis: String in ["x","y","z"]:
				near(point[axis],row.expected[axis],0.00003,id+" free placement "+axis)
	var road := Zone.new("snake_way")
	var at: Dictionary = road.place(0,200)
	ok(road.height_at(at.x,200)>-1)
	eq(road.surface_at(at.x+1000,200),"void")
	var alias := Zone.new("test")
	eq(alias.id,"earth_plains")

func test_rng_is_deterministic_and_noise_can_tile() -> void:
	var a := NoiseRules.Random32.new(4242)
	var b := NoiseRules.Random32.new(4242)
	for i in 100:
		var value: float = a.next_float()
		near(value,b.next_float(),0.0)
		ok(value>=0 and value<1)
	var noise := NoiseRules.new(73,16)
	near(noise.noise2(-3.25,7.75),noise.noise2(12.75,23.75),1e-15)

## Zones changed by tools/godot_additions.mjs no longer match the classic JS game; test_godot_additions covers them.
func _godot_only(id: String) -> bool:
	return id in Tables.table("godot_additions").get("zones", [])
