class_name RulePlanet
extends RuleZone
# One seamless map per planet (open world, docs/superpowers/specs/2026-11-03-open-world-design.md).
# The planet's areas ("regions") keep their own RuleZone recipes, placed at their spot on the map; between them is
# countryside with its own hills, a sea and mountains at the map's edge. A RulePlanet answers every question a
# RuleZone does, in planet coordinates, so the game, story and views take either.

var regions: Dictionary = {}     # zone id -> {"zone": RuleZone, "x", "z", "radius", "blend"}
var start_region: String
var _pdef: Dictionary
var _base: Dictionary
var _sea: Dictionary
var _rnoise: Array = []

## The world to load for a save's area: its planet's map when the area is on one, else the area itself.
static func open(zone_id: String, data: Object = null) -> RuleZone:
	var pid := planet_of(zone_id, data)
	return RulePlanet.new(pid, zone_id, data) if pid != "" else RuleZone.new(zone_id, data)

static func planet_of(zone_id: String, data: Object = null) -> String:
	var t: Variant = Tables.table("planets", data)
	var planets: Dictionary = t if t is Dictionary else {}
	for pid: String in planets:
		for r: Dictionary in planets[pid].regions:
			if r.zone == zone_id:
				return pid
	return ""

func _init(planet_id: String, start: String = "", data: Object = null) -> void:
	var p: Dictionary = Tables.table("planets", data)[planet_id]
	var first: String = start if _region_in(p, start) else str(p.start)
	super(first, data)
	_pdef = p
	start_region = first
	id = planet_id
	name = p.name
	planet = p.name
	size = float(p.size)
	seed = int(p.seed)
	_noise.clear()
	for i in 7:
		_noise.append(NoiseRules.new(seed + i))
	_base = p.base
	_sea = p.get("sea", {})
	mesas = []
	ground = "grass"
	kill_y = null
	water = {"x": 0, "z": 0, "radius": size * 4, "level": float(_sea.get("level", 0)), "ocean": true}
	_hills = null
	_flat_spawn = 0
	for r: Dictionary in p.regions:
		var z := RuleZone.new(str(r.zone), data)
		z.open_edges()
		regions[str(r.zone)] = {"zone": z, "x": float(r.x), "z": float(r.z), "radius": float(r.radius), "blend": float(r.get("blend", 90))}
	biome = (regions[str(p.biome)].zone as RuleZone).biome.duplicate(true) if regions.has(str(p.get("biome", ""))) else biome
	biome.merge(p.get("props", {}), true)
	def = {"name": name, "planet": name, "saga": "", "biome": biome, "terrain": {"size": size, "planet": planet_id, "regions": p.regions, "base": _base, "sea": _sea}, "landmarks": []}
	_terrain = def.terrain
	var s: Dictionary = regions[first].zone.spawn
	spawn = to_planet(first, s)
	var tp: Variant = regions[first].zone.travel_point
	travel_point = null
	if tp != null:
		travel_point = to_planet(first, tp)
		travel_point.y = height_at(travel_point.x, travel_point.z)
	landmarks = []
	for rid: String in regions:
		for l: Dictionary in (regions[rid].zone as RuleZone).landmarks:
			var m: Dictionary = l.duplicate(true)
			m.x = float(l.x) + regions[rid].x
			m.z = float(l.z) + regions[rid].z
			m.region = rid
			landmarks.append(m)
	_props = null

static func _region_in(p: Dictionary, zone_id: String) -> bool:
	for r: Dictionary in p.regions:
		if r.zone == zone_id:
			return true
	return false

# ------------------------------------------------------------------------------------------------- regions
func has_region(zone_id: String) -> bool:
	return regions.has(zone_id)

func region_ids() -> Array:
	return regions.keys()

func to_planet(zone_id: String, local: Dictionary) -> Dictionary:
	var r: Dictionary = regions[zone_id]
	var out: Dictionary = local.duplicate()
	out.x = float(local.x) + r.x
	out.z = float(local.z) + r.z
	return out

## Where an authored point of an area (NPC, quest step, pickup) is on the planet.
func place_in(zone_id: String, x: float, z: float) -> Dictionary:
	if not regions.has(zone_id):
		return {"x": x, "z": z}
	var local: Dictionary = (regions[zone_id].zone as RuleZone).place(x, z)
	return to_planet(zone_id, local)

func region_spawn(zone_id: String) -> Dictionary:
	return to_planet(zone_id, regions[zone_id].zone.spawn) if regions.has(zone_id) else spawn

func region_travel_point(zone_id: String) -> Variant:
	if not regions.has(zone_id) or regions[zone_id].zone.travel_point == null:
		return null
	var tp: Dictionary = to_planet(zone_id, regions[zone_id].zone.travel_point)
	tp.y = height_at(tp.x, tp.z)
	return tp

## The area at a point: the region with the most weight there, or "" in the countryside.
func region_at(x: float, z: float) -> String:
	var best := ""
	var best_w := 0.5
	for rid: String in regions:
		var w := _weight(regions[rid], x, z)
		if w > best_w:
			best = rid
			best_w = w
	return best

func place(x: float, z: float) -> Dictionary:
	return {"x": x, "z": z}

func _weight(r: Dictionary, x: float, z: float) -> float:
	var d := RuleZone._distance(x - r.x, z - r.z)
	return NoiseRules.smooth_step(r.radius + r.blend, r.radius, d)

# ------------------------------------------------------------------------------------------------- ground
func base_height(x: float, z: float) -> float:
	var h: float = 6.0 + (_noise[0].fbm(x / float(_base.get("scale", 260)), z / float(_base.get("scale", 260)), 5) * 0.5 + 0.5) * float(_base.get("amp", 14))
	h += _noise[1].fbm(x / 60, z / 60, 3) * 1.6
	# mountains along the map's land edges and in the north
	var half := size / 2.0
	var e := maxf(absf(x), z) / half
	if e > 0.8:
		var r1: float = _noise[3].ridged(x / 520, z / 520, 4)
		h += NoiseRules.smooth_step(0.8, 1.05, e) * (25 + r1 * r1 * 260)
	var north: float = NoiseRules.smooth_step(float(_base.get("northFrom", 600)), float(_base.get("northTo", 1300)), z)
	if north > 0:
		h += north * (_noise[3].ridged(x / 380, z / 380, 4) * 70)
	# the sea: south of the coast line, and round the listed bays
	var sea: float = NoiseRules.smooth_step(float(_sea.get("southFrom", -900)), float(_sea.get("southTo", -1060)), z + _noise[6].fbm(x / 300, z / 300, 3) * 60)
	for b: Dictionary in _sea.get("bays", []):
		var d: float = RuleZone._distance(x - float(b.x), z - float(b.z)) + _noise[6].fbm(x / 140, z / 140, 3) * float(b.r) * 0.2
		sea = maxf(sea, NoiseRules.smooth_step(float(b.r), float(b.r) * 0.75, d))
	return NoiseRules.mix_value(h, -14.0, sea)

func raw_height(x: float, z: float) -> float:
	return height_at(x, z)

func height_at(x: float, z: float) -> float:
	var acc := 0.0
	var total := 0.0
	for rid: String in regions:
		var r: Dictionary = regions[rid]
		var w := _weight(r, x, z)
		if w <= 0.0:
			continue
		acc += w * (r.zone as RuleZone).height_at(x - r.x, z - r.z)
		total += w
	if total >= 1.0:
		return acc / total
	return base_height(x, z) * (1.0 - total) + acc

func _main_region(x: float, z: float) -> Dictionary:
	var best: Dictionary = {}
	var best_w := 0.5
	for rid: String in regions:
		var w := _weight(regions[rid], x, z)
		if w > best_w:
			best = regions[rid]
			best_w = w
	return best

func dirt_at(x: float, z: float) -> float:
	var r := _main_region(x, z)
	return (r.zone as RuleZone).dirt_at(x - r.x, z - r.z) if not r.is_empty() else super(x, z)

func forest_at(x: float, z: float) -> float:
	var r := _main_region(x, z)
	return (r.zone as RuleZone).forest_at(x - r.x, z - r.z) if not r.is_empty() else super(x, z)

func surface_at(x: float, z: float) -> String:
	var r := _main_region(x, z)
	if not r.is_empty():
		var s: String = (r.zone as RuleZone).surface_at(x - r.x, z - r.z)
		if s != "void":
			return s
	var h: float = height_at(x, z)
	if h < float(water.level) - 0.02:
		return "water"
	if h < float(water.level) + 0.7:
		return "sand"
	var n: Dictionary = normal_data(x, z)
	if h > 120.0 + _noise[1].fbm(x / 40, z / 40, 2) * 20 and n.y > 0.6:
		return "rock" if n.y < 0.78 else "snow"
	if n.y < 0.78:
		return "rock"
	return "dirt" if dirt_at(x, z) > 0.55 else "grass"
