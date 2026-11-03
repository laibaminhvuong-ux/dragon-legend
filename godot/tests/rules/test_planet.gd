extends TestCase
# Open world: Earth is one map; its areas keep their own ground at their spot (spec 2026-11-03-open-world-design).
static var _earth: RulePlanet

func _planet() -> RulePlanet:
	if _earth == null:
		_earth = RulePlanet.open("earth_plains") as RulePlanet
	return _earth

func test_areas_open_on_their_planet() -> void:
	ok(RulePlanet.open("west_city") is RulePlanet, "West Capital is on Earth's map")
	eq(RulePlanet.planet_of("west_city"), "earth")
	eq(RulePlanet.planet_of("namek"), "nameck", "Nameck has its own planet map")
	ok(not (RulePlanet.open("snake_way") is RulePlanet), "Serpent Road is still its own area")
	eq(RulePlanet.planet_of("lookout"), "", "the Lookout stays separate (in the sky)")
	var e := _planet()
	eq(e.id, "earth")
	ok(e.has_region("cell_games") and e.has_region("amber_city"))
	ok(not e.has_region("namek"), "Nameck is not on Earth")

func test_each_area_keeps_its_own_ground_at_its_spot() -> void:
	var e := _planet()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for rid: String in e.region_ids():
		var r: Dictionary = e.regions[rid]
		var z: RuleZone = r.zone
		eq(e.region_at(r.x, r.z), rid, rid + " centre")
		for i in 6:
			var a := rng.randf() * TAU
			var d := rng.randf() * float(r.radius) * 0.9
			var lx := cos(a) * d
			var lz := sin(a) * d
			near(e.height_at(r.x + lx, r.z + lz), z.height_at(lx, lz) + float(r.lift), 0.001, "%s at %.0f,%.0f" % [rid, lx, lz])
		if not z.def.terrain.has("ocean"):
			ok(e.height_at(r.x, r.z) > 0.5, rid + " centre above the sea")

func test_spawn_and_authored_points_land_on_the_map() -> void:
	var e := _planet()
	var s: Dictionary = e.region_spawn("west_city")
	var r: Dictionary = e.regions.west_city
	near(float(s.x), float(r.zone.spawn.x) + float(r.x), 0.0001)
	var p := e.place_in("west_city", 10, 20)
	near(float(p.x), float(r.x) + 10.0, 0.0001)
	near(float(p.z), float(r.z) + 20.0, 0.0001)
	near(float(e.spawn.x), float(e.regions.earth_plains.zone.spawn.x), 0.0001, "starts in the plains")
	eq(e.region_at(e.spawn.x, e.spawn.z), "earth_plains")

func test_you_can_cross_between_neighbours_without_falling_out() -> void:
	var e := _planet()
	var pairs := [["earth_plains", "west_city"], ["earth_plains", "pepper_village"], ["earth_plains", "amber_city"],
		["earth_plains", "gero_lab"], ["gizard_wasteland", "broly_glacier"], ["amber_city", "cell_games"], ["cell_games", "harbor_town"], ["harbor_town", "kame_island"]]
	for pr: Array in pairs:
		var a: Dictionary = e.regions[pr[0]]
		var b: Dictionary = e.regions[pr[1]]
		for i in 41:
			var t := i / 40.0
			var x: float = lerpf(a.x, b.x, t)
			var z: float = lerpf(a.z, b.z, t)
			var h := e.height_at(x, z)
			ok(h > -20.0 and h < 400.0, "%s→%s at %.0f,%.0f: %.1f" % [pr[0], pr[1], x, z, h])

func test_countryside_has_sea_in_the_south_and_ground_types() -> void:
	var e := _planet()
	eq(e.region_at(-900, -1500), "")
	eq(e.surface_at(-900, -1500), "water", "southern sea")
	ok(e.height_at(-300, 250) > 0.0, "land between the plains and the village")
	ok(e.surface_at(-300, 250) in ["grass", "dirt", "rock"])

func test_areas_do_not_crowd_each_other() -> void:
	var e := _planet()
	var ids: Array = e.region_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Dictionary = e.regions[ids[i]]
			var b: Dictionary = e.regions[ids[j]]
			var d := Vector2(float(a.x) - float(b.x), float(a.z) - float(b.z)).length()
			ok(d >= float(a.radius) + float(b.radius) + maxf(float(a.blend), float(b.blend)), "%s and %s are %.0f m apart" % [ids[i], ids[j], d])
	for rid: String in ids:
		var r: Dictionary = e.regions[rid]
		ok(absf(float(r.x)) + float(r.radius) <= e.size / 2.0 and absf(float(r.z)) + float(r.radius) <= e.size / 2.0, rid + " inside the map")

func test_land_areas_never_flood_and_keep_their_lakes() -> void:
	var e := _planet()
	for rid: String in ["earth_plains", "amber_city", "pepper_village", "west_city", "gero_lab", "cell_games"]:
		var r: Dictionary = e.regions[rid]
		for i in 40:
			var a := float(i) / 40.0 * TAU
			for d in [0.0, 0.4, 0.8]:
				var x: float = float(r.x) + cos(a) * float(r.radius) * d
				var z: float = float(r.z) + sin(a) * float(r.radius) * d
				var s := e.surface_at(x, z)
				ok(s != "water" or (r.zone as RuleZone).water != null, "%s flooded at %.0f,%.0f" % [rid, x, z])
	var lakes := e.lakes()
	ok(lakes.size() >= 1, "the plains lake is kept")
	var plains: Dictionary = e.regions.earth_plains
	near(float(lakes.filter(func(l: Dictionary) -> bool: return absf(float(l.x) - float(plains.x) - float(plains.zone.water.x)) < 0.01)[0].level), float(plains.zone.water.level) + float(plains.lift), 0.0001)

func test_every_planet_map_is_sound() -> void:
	var planets: Dictionary = RuleTables.table("planets")
	eq(planets.size(), 9, "Earth and eight more planet maps")
	for pid: String in planets:
		var e := RulePlanet.new(pid)
		var ids: Array = e.region_ids()
		for i in ids.size():
			var a: Dictionary = e.regions[ids[i]]
			ok(absf(float(a.x)) + float(a.radius) <= e.size / 2.0 and absf(float(a.z)) + float(a.radius) <= e.size / 2.0, "%s/%s inside the map" % [pid, ids[i]])
			eq(e.region_at(a.x, a.z), ids[i], "%s/%s centre" % [pid, ids[i]])
			near(e.height_at(a.x, a.z), (a.zone as RuleZone).height_at(0, 0) + float(a.lift), 0.001, "%s/%s keeps its ground" % [pid, ids[i]])
			var sp := e.region_spawn(ids[i])
			ok(e.height_at(sp.x, sp.z) > -20.0, "%s/%s spawn on the ground" % [pid, ids[i]])
			for j in range(i + 1, ids.size()):
				var b: Dictionary = e.regions[ids[j]]
				var d := Vector2(float(a.x) - float(b.x), float(a.z) - float(b.z)).length()
				ok(d >= float(a.radius) + float(b.radius) + maxf(float(a.blend), float(b.blend)), "%s: %s and %s are %.0f m apart" % [pid, ids[i], ids[j], d])
		var start: Dictionary = e.regions[e.start_region]
		for rid: String in ids:   # you can always get from the start area to every other one (walking, or flying low over sea)
			var r: Dictionary = e.regions[rid]
			for k in 21:
				var t := k / 20.0
				ok(e.height_at(lerpf(start.x, r.x, t), lerpf(start.z, r.z, t)) > -20.0, "%s: path to %s" % [pid, rid])
