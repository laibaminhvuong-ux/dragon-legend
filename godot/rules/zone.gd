class_name RuleZone
extends RefCounted
# Pure deterministic terrain/placement. Dictionaries preserve JS double coordinates; view positions are Vector3.
const Tables = preload("res://rules/tables.gd")
const NoiseRules = preload("res://rules/noise.gd")
const VOID := -400.0
var id: String
var name: String
var planet: String
var saga: String
var size: float
var seed: int
var spawn: Dictionary
var gravity: float
var kill_y: Variant
var water: Variant = null
var mesas: Array
var ground: String
var biome: Dictionary
var landmarks: Array = []
var travel_point: Variant = null
var def: Dictionary
var _terrain: Dictionary
var _hills: Variant
var _flat_spawn: float
var _tp_base: float = 0.0
var _noise: Array = []
var _props: RefCounted

func _init(zone_id: String = "earth_plains", data: Object = null) -> void:
	var definitions: Dictionary = Tables.table("zones", data)
	id = zone_id if definitions.has(zone_id) else "earth_plains"
	def = definitions[id]
	_terrain = def.terrain
	var hash_value: int = 7
	for i in id.length():
		hash_value = (hash_value * 31 + id.unicode_at(i)) & 0xffffffff
	seed = 11 if id == "earth_plains" else (hash_value & 0xffff) + 100
	for i in 7:
		_noise.append(NoiseRules.new(seed + i))
	name = def.name
	planet = def.planet
	saga = def.saga
	size = _terrain.size
	_hills = null if _terrain.get("hills") is bool and not _terrain.hills else {"amp":17,"scale":230}
	if _hills != null and _terrain.get("hills") is Dictionary:
		_hills.merge(_terrain.hills, true)
	_flat_spawn = _terrain.get("flatSpawn", 28)
	mesas = _terrain.get("mesas", [])
	if _terrain.has("lake"):
		water = _terrain.lake.duplicate()
		water.ocean = false
	elif _terrain.has("ocean"):
		water = {"x":0,"z":0,"radius":size * 4,"level":_terrain.ocean.level,"ocean":true}
	ground = _terrain.get("ground", "grass")
	biome = def.biome
	gravity = _terrain.get("gravity", 1.0)
	kill_y = _terrain.get("killY")
	for source: Dictionary in def.get("landmarks", []):
		var landmark: Dictionary = {"scale":1,"rot":0}
		landmark.merge(source, true)
		landmark = _on_road(landmark)
		landmark.base = raw_height(landmark.x, landmark.z)
		landmarks.append(landmark)
	spawn = _on_road(_terrain.spawn)
	if def.get("travelPoint") != null:
		travel_point = _on_road(def.travelPoint)
		_tp_base = raw_height(travel_point.x, travel_point.z)
		travel_point.y = height_at(travel_point.x, travel_point.z)

# ---- planet-map API (open world): a single area is a map with one region, itself (RulePlanet overrides) ----
func has_region(zone_id: String) -> bool:
	return zone_id == id

func region_ids() -> Array:
	return [id]

func region_at(_x: float, _z: float) -> String:
	return id

func place_in(_zone_id: String, x: float, z: float) -> Dictionary:
	return place(x, z)

func region_spawn(_zone_id: String) -> Dictionary:
	return spawn

func region_travel_point(_zone_id: String) -> Variant:
	return travel_point

## Inside a planet map an area's border mountains are dropped (the countryside continues instead).
func open_edges() -> void:
	_terrain = _terrain.duplicate(true)
	_terrain.erase("edge")

func path_centre(z: float) -> float:
	var p: Dictionary = _terrain.path
	return sin(z / p.wave) * p.amp + sin(z / (p.wave * 0.37)) * p.amp * 0.18

func _on_road(point: Dictionary) -> Dictionary:
	var result: Dictionary = point.duplicate()
	if _terrain.has("path"):
		result.x += path_centre(result.z)
	return result

func place(x: float, z: float) -> Dictionary:
	return {"x":x + path_centre(z) if _terrain.has("path") else x,"z":z}

func mesa_height(m: Dictionary, x: float, z: float) -> float:
	var d: float = _distance(x - m.x, z - m.z)
	if d > m.r * 1.6:
		return 0.0
	var dw: float = d + _noise[2].fbm(x / 28, z / 28, 3) * m.r * 0.24 + _noise[1].fbm(x / 7, z / 7, 3) * m.r * 0.06
	var s: float = NoiseRules.smooth_step(m.r, m.r * 0.82, dw)
	var t: float = s * 6
	var steps: float = (floor(t) + NoiseRules.smooth_step(0.25, 0.75, t - floor(t))) / 6
	var skirt: float = NoiseRules.smooth_step(m.r * 1.55, m.r, dw) * 0.16
	var top: float = _noise[1].fbm(x / 18, z / 18, 2) * minf(1.1, m.r * 0.08) if s > 0.999 else 0.0
	return m.h * maxf(steps, skirt * (1 - s) + steps) + top

static func _distance(x: float, z: float) -> float:
	return sqrt(x*x + z*z)

func raw_height(x: float, z: float) -> float:
	if _terrain.has("path"):
		var p: Dictionary = _terrain.path
		if _terrain.has("plaza"):
			# Godot addition: a flat round floor on the road's line (King Yemmo's Check-In Station)
			var pz: Dictionary = _terrain.plaza
			if _distance(x - path_centre(pz.z) - float(pz.get("x",0)), z - pz.z) <= pz.radius:
				return float(pz.height)
		if z < p.from - 6 or z > p.to + 6:
			return VOID
		var slope: float = (path_centre(z + 1) - path_centre(z - 1)) / 2
		var d: float = absf(x - path_centre(z)) / sqrt(1 + slope*slope)
		if d > p.width:
			return VOID
		return 0.35 * cos((d / p.width) * PI * 0.5) + sin(z * 0.05) * 0.4
	if _terrain.has("planetoid"):
		var radius: float = _terrain.planetoid.radius
		var d: float = _distance(x,z)
		return VOID if d >= radius else sqrt(radius*radius - d*d) - radius + _noise[1].fbm(x/9,z/9,2) * 0.25
	if _terrain.has("platform"):
		var p: Dictionary = _terrain.platform
		var edge: float = p.radius * (0.92 + _noise[2].fbm(x/25,z/25,3) * 0.12) if p.get("broken",false) else p.radius
		return VOID if _distance(x,z) > edge else float(p.height)
	var h: float = 0.0
	if _hills != null:
		h = _noise[0].fbm(x/_hills.scale,z/_hills.scale,5) * _hills.amp + _noise[1].fbm(x/42,z/42,3) * 1.8 * minf(1,_hills.amp/10.0)
	if _flat_spawn > 0:
		h *= NoiseRules.smooth_step(_flat_spawn,_flat_spawn+67,_distance(x-_terrain.spawn.x,z-_terrain.spawn.z))
	if _terrain.has("ocean"):
		var land: float = -14.0
		for island: Dictionary in _terrain.get("islands",[]):
			var d: float = _distance(x-island.x,z-island.z)
			if d > island.r * 1.5:
				continue
			var dw: float = d + _noise[6].fbm(x/30,z/30,3) * island.r * 0.25
			var k: float = NoiseRules.smooth_step(island.r*1.15,island.r*0.55,dw)
			land = maxf(land,NoiseRules.mix_value(-14,island.h+maxf(0,h*0.5),k))
		h = land
	if _terrain.has("lake"):
		var w: Dictionary = _terrain.lake
		var dl: float = _distance(x-w.x,z-w.z)
		if dl < w.radius*2.2:
			h = NoiseRules.mix_value(h,1.6,NoiseRules.smooth_step(w.radius*2.2,w.radius*1.15,dl))
			var dw: float = dl + _noise[6].fbm(x/24,z/24,3) * w.radius * 0.22
			h -= 2.9 * NoiseRules.smooth_step(w.radius*1.05,w.radius*0.3,dw)
	for m: Dictionary in mesas:
		h += mesa_height(m,x,z)
	if _terrain.get("edge") == "mountains":
		var e: float = maxf(absf(x),absf(z)) / (size/2)
		if e > 0.78:
			var wx: float = x + _noise[2].fbm(x/420,z/420,3)*140
			var wz: float = z + _noise[2].fbm(x/420+7.3,z/420+3.1,3)*140
			var r1: float = _noise[3].ridged(wx/560,wz/560,4)
			var foothills: float = NoiseRules.smooth_step(0.78,1.1,e) * (12+r1*80+_noise[1].fbm(x/60,z/60,3)*6)
			var ranges: float = NoiseRules.smooth_step(1,3.4,e) * (45+r1*r1*330+_noise[0].fbm(x/300,z/300,4)*40)
			h += foothills + ranges
	return h

func height_at(x: float, z: float) -> float:
	var h: float = raw_height(x,z)
	if h <= VOID:
		return h
	for l: Dictionary in landmarks:
		var d: float = _distance(x-l.x,z-l.z)
		if l.get("flatten",0) and d < l.flatten*1.7:
			h = NoiseRules.mix_value(h,l.base,NoiseRules.smooth_step(l.flatten*1.7,l.flatten,d))
		if l.get("dig") and d < l.dig.radius*1.3:
			var r: float = l.dig.radius
			h += -l.dig.depth*NoiseRules.smooth_step(r,0,d) + NoiseRules.smooth_step(r*1.3,r,d)*NoiseRules.smooth_step(r*0.7,r,d)*l.dig.depth*0.35
	if travel_point != null and not _terrain.has("platform") and not _terrain.has("path") and not _terrain.has("planetoid"):
		var d: float = _distance(x-travel_point.x,z-travel_point.z)
		if d < 22:
			h = NoiseRules.mix_value(h,_tp_base,NoiseRules.smooth_step(22,12,d))
	return h

func normal_data(x: float, z: float) -> Dictionary:
	var nx: float = height_at(x-0.6,z) - height_at(x+0.6,z)
	var nz: float = height_at(x,z-0.6) - height_at(x,z+0.6)
	var length: float = sqrt(nx*nx + 1.2*1.2 + nz*nz)
	return {"x":nx/length,"y":1.2/length,"z":nz/length}

func normal_at(x: float, z: float) -> Vector3:
	var n: Dictionary = normal_data(x,z)
	return Vector3(n.x,n.y,n.z)

func dirt_at(x: float, z: float) -> float:
	if ground == "dirt":
		return 0.75+0.25*NoiseRules.smooth_step(-0.3,0.3,_noise[4].fbm(x/55,z/55,4))
	return NoiseRules.smooth_step(0.04,0.32,_noise[4].fbm(x/55,z/55,4))

func forest_at(x: float, z: float) -> float:
	return _noise[5].fbm(x/95,z/95,3)

func surface_at(x: float, z: float) -> String:
	var h: float = height_at(x,z)
	if h <= VOID+1:
		return "void"
	if water != null:
		var nearby: bool = water.ocean or _distance(x-water.x,z-water.z) < water.radius*1.5
		if nearby and h < water.level-0.02:
			return "water"
		if nearby and h < water.level+0.7:
			return "sand"
	if ground in ["white","stone"]:
		return ground
	var n: Dictionary = normal_data(x,z)
	if ground == "snow" or (h > biome.get("snowLine",135)+_noise[1].fbm(x/40,z/40,2)*20 and n.y > 0.6):
		return "rock" if n.y < 0.78 else "snow"
	if n.y < 0.78:
		return "rock"
	if ground == "sand":
		return "sand"
	return "dirt" if dirt_at(x,z) > 0.55 else "grass"

func props() -> RefCounted:
	if _props == null:
		_props = PropSet.new(self)
	return _props

func free_position(point: Variant) -> Vector3:
	var px: float = point.x
	var pz: float = point.z
	var authored_y: bool = point is Vector3 or (point is Dictionary and point.get("y") != null and (point.y is int or point.y is float) and is_finite(float(point.y)))
	var half: float = size/2-1
	for radius: int in [0,2,4,8,12,20,32,64]:
		for i in 16:
			var x: float = px + sin(i*PI/8)*radius
			var z: float = pz + cos(i*PI/8)*radius
			if absf(x)>half or absf(z)>half:
				continue
			var y: float = point.y if authored_y else height_at(x,z)
			if y < -100 or (not authored_y and normal_data(x,z).y < 0.6):
				continue
			var blocked: bool = false
			for c: Dictionary in props().near(x,z,0.5):
				if y <= c.top and _distance(x-c.x,z-c.z) < c.radius+0.5:
					blocked = true
					break
			if not blocked:
				return Vector3(x,y,z)
	return Vector3(spawn.x,height_at(spawn.x,spawn.z),spawn.z)

class PropSet extends RefCounted:
	var trees: Array = []
	var rocks: Array = []
	var bushes: Array = []
	var stones: Array = []
	var _grid: Dictionary = {}

	static func _pick(r: RefCounted, half: float) -> Dictionary:
		return {"x":(r.next_float()*2-1)*half,"z":(r.next_float()*2-1)*half}

	static func _clear(zone: RefCounted, p: Dictionary, distance: float) -> bool:
		if RuleZone._distance(p.x-zone.spawn.x,p.z-zone.spawn.z) <= distance:
			return false
		if zone.travel_point != null and RuleZone._distance(p.x-zone.travel_point.x,p.z-zone.travel_point.z) < 16:
			return false
		for l: Dictionary in zone.landmarks:
			if RuleZone._distance(p.x-l.x,p.z-l.z) < float(l.get("flatten",l.get("collide",3)))*1.15+2:
				return false
		return true

	static func _lush(zone: RefCounted, surface: String) -> bool:
		return surface=="grass" or (zone.ground=="sand" and surface=="sand") or (zone.ground=="dirt" and surface=="dirt") or (zone.ground=="stone" and surface=="stone")

	func _init(zone: RefCounted) -> void:
		var b: Dictionary = zone.biome
		var r: RefCounted = NoiseRules.Random32.new(4242 if zone.id=="earth_plains" else zone.seed*7+1)
		var half: float = zone.size/2-12
		var count: int = 0 if b.get("trees")=="none" else int(b.get("treeCount",340))
		var spread: bool = count < 20
		for attempt in 20000:
			if trees.size() >= count:
				break
			var p: Dictionary = _pick(r,half)
			if not _clear(zone,p,8 if spread else 22):
				continue
			if not spread and zone.forest_at(p.x,p.z)<-0.02 and r.next_float()>0.06:
				continue
			if not _lush(zone,zone.surface_at(p.x,p.z)) or zone.normal_data(p.x,p.z).y<0.9:
				continue
			var crowded: bool = false
			for t: Dictionary in trees:
				if pow(t.x-p.x,2)+pow(t.z-p.z,2)<36:
					crowded = true
					break
			if crowded:
				continue
			var scale: float = 0.8+r.next_float()*0.65
			trees.append({"x":p.x,"y":zone.height_at(p.x,p.z),"z":p.z,"scale":scale,"rot":r.next_float()*PI*2,"variant":floori(r.next_float()*4)})
		for attempt in 20000:
			if rocks.size() >= int(b.get("rocks",230)):
				break
			var p: Dictionary = _pick(r,half)
			if not _clear(zone,p,16):
				continue
			var surface: String = zone.surface_at(p.x,p.z)
			if surface=="water" or (surface=="snow" and zone.ground!="snow") or surface=="void":
				continue
			var near_mesa: bool = false
			for m: Dictionary in zone.mesas:
				if absf(RuleZone._distance(p.x-m.x,p.z-m.z)-m.r*1.15)<m.r*0.35:
					near_mesa = true
					break
			if not near_mesa and surface!="rock" and r.next_float()>0.35:
				continue
			var scale: float = (0.7 if near_mesa else 0.35)+pow(r.next_float(),2)*(3.2 if near_mesa else 1.8)
			rocks.append({"x":p.x,"y":zone.height_at(p.x,p.z)-scale*0.25,"z":p.z,"scale":scale,"rx":r.next_float()*6.3,"ry":r.next_float()*6.3,"rz":r.next_float()*0.4,"variant":floori(r.next_float()*5)})
		for attempt in 20000:
			if bushes.size() >= int(b.get("bushes",520)):
				break
			var index: int = floori(r.next_float()*trees.size())
			var t: Variant = trees[index] if index < trees.size() else null
			var nearby: bool = r.next_float()<0.7
			var p: Dictionary = {"x":t.x+(r.next_float()*2-1)*9,"z":t.z+(r.next_float()*2-1)*9} if nearby and t!=null else _pick(r,half)
			if absf(p.x)>half or absf(p.z)>half or not _clear(zone,p,14) or not _lush(zone,zone.surface_at(p.x,p.z)):
				continue
			bushes.append({"x":p.x,"y":zone.height_at(p.x,p.z),"z":p.z,"scale":0.6+r.next_float()*0.9,"rot":r.next_float()*6.3})
		for attempt in 30000:
			if stones.size() >= int(b.get("stones",0 if zone.ground=="white" else 1400)):
				break
			var p: Dictionary = _pick(r,half)
			var surface: String = zone.surface_at(p.x,p.z)
			if surface in ["water","void","white"] or (surface=="grass" and r.next_float()>0.3):
				continue
			stones.append({"x":p.x,"y":zone.height_at(p.x,p.z)-0.03,"z":p.z,"scale":0.08+r.next_float()*0.25,"rx":r.next_float()*6.3,"ry":r.next_float()*6.3,"rz":r.next_float()*6.3,"variant":floori(r.next_float()*5)})
		for t: Dictionary in trees:
			_add({"x":t.x,"z":t.z,"radius":0.35*t.scale,"top":t.y+14*t.scale})
		for rock: Dictionary in rocks:
			if rock.scale>=0.6:
				_add({"x":rock.x,"z":rock.z,"radius":0.8*rock.scale,"top":rock.y+1.1*rock.scale})
		for l: Dictionary in zone.landmarks:
			if l.get("collide",0):
				_add({"x":l.x,"z":l.z,"radius":l.collide*l.scale,"top":zone.height_at(l.x,l.z)+12*l.scale})
			if l.get("type")=="town":   # every building in an open-world town is solid
				for c: Dictionary in RuleTown.colliders(l):
					_add({"x":c.x,"z":c.z,"radius":c.radius,"top":zone.height_at(c.x,c.z)+c.height})

	func _add(c: Dictionary) -> void:
		var cell := Vector2i(floori(c.x/16.0),floori(c.z/16.0))
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(c)

	func near(x: float, z: float, radius: float) -> Array:
		var out: Array = []
		var reach: float = radius+26
		for cx in range(floori((x-reach)/16),floori((x+reach)/16)+1):
			for cz in range(floori((z-reach)/16),floori((z+reach)/16)+1):
				for c: Dictionary in _grid.get(Vector2i(cx,cz),[]):
					if RuleZone._distance(c.x-x,c.z-z)<radius+c.radius:
						out.append(c)
		return out
