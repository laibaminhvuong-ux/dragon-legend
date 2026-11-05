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
	# a shared sea for Earth-like and ocean worlds; all-land worlds only have their areas' lakes
	water = {"x": 0, "z": 0, "radius": size * 4, "level": float(_sea.get("level", 0)), "ocean": true} if (_sea.has("southFrom") or not _sea.get("bays", []).is_empty() or p.base.get("islands", false)) else null
	_hills = null
	_flat_spawn = 0
	for r: Dictionary in p.regions:
		var z := RuleZone.new(str(r.zone), data)
		z.open_edges()
		# land areas sit `lift` m up so their low ground stays above the shared sea; island areas keep sea level 0
		var lift: float = 0.0 if z.def.terrain.has("ocean") else float(p.base.get("lift", 0))
		regions[str(r.zone)] = {"zone": z, "x": float(r.x), "z": float(r.z), "radius": float(r.radius), "blend": float(r.get("blend", 90)), "lift": lift}
	biome = (regions[str(p.biome)].zone as RuleZone).biome.duplicate(true) if regions.has(str(p.get("biome", ""))) else biome
	biome.merge(p.get("props", {}), true)
	def = {"name": name, "planet": name, "saga": "", "biome": biome, "terrain": {"size": size, "planet": planet_id, "regions": p.regions, "base": _base, "sea": _sea}, "landmarks": []}
	var recipes := {}
	for rid: String in regions:
		recipes[rid] = (regions[rid].zone as RuleZone).def
	def.terrain.recipes = "%08x" % (hash(JSON.stringify(recipes, "", true)) & 0xffffffff)   # terrain caches follow area changes
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
	landmarks.append_array(hamlets(planet_id))
	_props = null

# ------------------------------------------------------------------------------------------------- countryside
## Hamlets and farmsteads scattered over the countryside (user request 2026-11-04: "the open world is big but
## there aren't any details"). Same every time (planet seed); only on fairly flat dry land away from the areas and
## from each other. Each is an ordinary town landmark (solid, enterable buildings; RuleTown layouts).
const HAMLET_STYLES := {"earth": ["village", "village", "village", "snowvillage"], "nameck": ["domevillage"], "new_nameck": ["domevillage"],
	"yardran": ["domevillage", "village"], "grain": ["village", "village", "domevillage"], "beeros": ["garden"],
	"future_earth": ["ruins", "ruins", "village"], "kae_world": ["garden"], "nameless": ["ruins"]}
const HAMLET_NAMES := ["Willow", "Stonebrook", "Red Barn", "Cedar", "Hilltop", "Mossy Creek", "Old Mill", "Sunfield", "Pine Ridge",
	"Clearwater", "Fox Hollow", "Briar", "Long Meadow", "Amberleaf", "Windy Knoll", "Tall Oak", "Riverbend", "Copperfield",
	"Misty Vale", "Lark", "Ember", "Golden Rye", "Quiet Pond", "Thornbury", "Bluebell", "Ashgrove", "Kestrel", "Highfield"]
const HAMLET_KINDS := ["Hamlet", "Farmstead", "Village", "Homestead", "Crossing"]

func hamlets(planet_id: String) -> Array:
	var out: Array = []
	var styles: Array = HAMLET_STYLES.get(planet_id, ["village"])
	var r := NoiseRules.Random32.new(seed * 131 + 977)
	var want := clampi(int(size * size / 300000.0), 4, 40)
	var half := size * 0.5 - 140.0
	for attempt in want * 90:
		if out.size() >= want:
			break
		var x := (r.next_float() * 2.0 - 1.0) * half
		var z := (r.next_float() * 2.0 - 1.0) * half
		var radius := 42.0 + r.next_float() * 30.0
		var far := true
		for rid: String in regions:
			var g: Dictionary = regions[rid]
			if Vector2(x - float(g.x), z - float(g.z)).length() < float(g.radius) + float(g.blend) + radius + 40.0:
				far = false
				break
		for h: Dictionary in out:
			if Vector2(x - float(h.x), z - float(h.z)).length() < float(h.radius) + radius + 140.0:
				far = false
				break
		if not far:
			continue
		var h0 := height_at(x, z)
		var lo := INF; var hi := -INF
		var dry := true
		for k in 9:
			var a := float(k) / 8.0 * TAU
			var px := x + cos(a) * radius * (0.0 if k == 8 else 0.8); var pz := z + sin(a) * radius * (0.0 if k == 8 else 0.8)
			var hh := height_at(px, pz)
			lo = minf(lo, hh); hi = maxf(hi, hh)
			if water is Dictionary and hh < float(water.level) + 1.5:
				dry = false
		if not dry or hi - lo > radius * 0.14 or not is_finite(h0):
			continue
		var style: String = styles[floori(r.next_float() * styles.size())]
		if planet_id == "earth" and z > float(_base.get("northFrom", 1e9)):
			style = "snowvillage"
		var nm := "%s %s" % [HAMLET_NAMES[floori(r.next_float() * HAMLET_NAMES.size())], HAMLET_KINDS[floori(r.next_float() * HAMLET_KINDS.size())]]
		out.append({"type": "town", "name": nm, "x": x, "z": z, "style": style, "radius": radius, "seed": int(r.next_float() * 100000.0) + 1,
			"rot": r.next_float() * TAU, "hamlet": true})
	return out

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
	if out.get("y") != null and (out.y is float or out.y is int):
		out.y = float(out.y) + float(r.lift)
	return out

func lift_of(zone_id: String) -> float:
	return float(regions[zone_id].lift) if regions.has(zone_id) else 0.0

## The areas' own lakes, at their spot and lifted with their ground.
func lakes() -> Array:
	var out: Array = []
	for rid: String in regions:
		var r: Dictionary = regions[rid]
		var w: Variant = (r.zone as RuleZone).water
		if w is Dictionary and not w.get("ocean", false):
			var lake: Dictionary = w.duplicate()
			lake.x = float(w.x) + float(r.x)
			lake.z = float(w.z) + float(r.z)
			lake.level = float(w.level) + float(r.lift)
			out.append(lake)
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
## The countryside between areas. Kinds: land with an optional southern sea and bays (Earth), all-land worlds walled
## by mountains (sea {} empty), and ocean worlds of scattered islands (base.islands).
func base_height(x: float, z: float) -> float:
	var h: float = float(_base.get("lift", 0)) + 2.0 + (_noise[0].fbm(x / float(_base.get("scale", 260)), z / float(_base.get("scale", 260)), 5) * 0.5 + 0.5) * float(_base.get("amp", 14))
	h += _noise[1].fbm(x / 60, z / 60, 3) * 1.6
	var half := size / 2.0
	var south_sea: bool = _sea.has("southFrom")
	if not _base.get("islands", false):   # mountains along the map's land edges (not where a sea is)
		var e := maxf(absf(x), z if south_sea else absf(z)) / half
		if e > 0.8:
			var r1: float = _noise[3].ridged(x / 520, z / 520, 4)
			h += NoiseRules.smooth_step(0.8, 1.05, e) * (25 + r1 * r1 * 260)
	if _base.has("northFrom"):
		var north: float = NoiseRules.smooth_step(float(_base.northFrom), float(_base.get("northTo", 1300)), z)
		if north > 0:
			h += north * (_noise[3].ridged(x / 380, z / 380, 4) * 70)
	var sea := 0.0
	if _base.get("islands", false):   # an ocean world: islands where the noise rises, sea everywhere else
		sea = NoiseRules.smooth_step(0.05, -0.12, _noise[2].fbm(x / 230, z / 230, 4))
	if south_sea:
		sea = maxf(sea, NoiseRules.smooth_step(float(_sea.southFrom), float(_sea.get("southTo", float(_sea.southFrom) - 160)), z + _noise[6].fbm(x / 300, z / 300, 3) * 60))
	for bay: Dictionary in _sea.get("bays", []):
		var d: float = RuleZone._distance(x - float(bay.x), z - float(bay.z)) + _noise[6].fbm(x / 140, z / 140, 3) * float(bay.r) * 0.2
		sea = maxf(sea, NoiseRules.smooth_step(float(bay.r), float(bay.r) * 0.75, d))
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
		acc += w * ((r.zone as RuleZone).height_at(x - r.x, z - r.z) + float(r.lift))
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
	if water != null and h < float(water.level) - 0.02:
		return "water"
	if water != null and h < float(water.level) + 0.7:
		return "sand"
	var n: Dictionary = normal_data(x, z)
	if h > 120.0 + _noise[1].fbm(x / 40, z / 40, 2) * 20 and n.y > 0.6:
		return "rock" if n.y < 0.78 else "snow"
	if n.y < 0.78:
		return "rock"
	return "dirt" if dirt_at(x, z) > 0.55 else "grass"

# ------------------------------------------------------------------------------------------------- props
## Bump when prop placement changes: saved props are then ignored.
const PROPS_VERSION := 1
const BAKED_PROPS := "res://world/baked"
static var props_cache_dir := "user://cache/props"

## Trees, rocks, bushes and stones for the whole map. Placing them takes seconds, so the result is saved once
## (shipped in world/baked, else this PC's cache) and read back after that.
func props() -> RefCounted:
	if _props != null:
		return _props
	var key := props_key()
	for path in ["%s/%s.props" % [BAKED_PROPS, key], "%s/%s.props" % [props_cache_dir, key]]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
			if f != null:
				var saved: Variant = f.get_var()
				f.close()
				if saved is Dictionary and saved.get("key") == key:
					_props = PropSet.new(self, saved)
					return _props
	_props = PropSet.new(self)
	save_props(_props, "%s/%s.props" % [props_cache_dir, key])
	return _props

func save_props(p: RefCounted, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f != null:
		f.store_var({"key": props_key(), "trees": p.trees, "rocks": p.rocks, "bushes": p.bushes, "stones": p.stones})
		f.close()

## The planet's recipe, every area's recipe and the prop version: any change makes new props.
func props_key() -> String:
	var recipes := {}
	for rid: String in regions:
		recipes[rid] = (regions[rid].zone as RuleZone).def
	return "%s_props_%08x" % [id, hash(JSON.stringify(_pdef, "", true) + JSON.stringify(recipes, "", true) + str(PROPS_VERSION)) & 0xffffffff]
