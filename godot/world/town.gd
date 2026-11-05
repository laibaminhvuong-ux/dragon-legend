class_name WorldTown
extends RefCounted
# Draws an open-world town from its rules layout (RuleTown.layout): roads, buildings and street furniture, in the
# style of the world (round domed houses and towers in the city, gabled farm houses, log cabins, a harbour).
# Buildings of one kind share meshes and materials.

static var _mats: Dictionary = {}

const CUTAWAY := preload("res://world/shaders/cutaway.gdshader")
static var _cut_mats: Dictionary = {}

## The shader global the cutaway material reads (registered once; play sets it every frame).
static var _globals_ready := false
static func ensure_globals() -> void:
	if _globals_ready:
		return
	_globals_ready = true
	RenderingServer.global_shader_parameter_add(&"inside_building", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)

## Walls/roofs of walk-in buildings: solid, ordinary materials (user request 2026-11-04: walls stay visible inside;
## the camera stops at walls instead, FollowCamera).
static func _cut(color: int, rough := 0.75) -> Material:
	return _mat(color, {"rough": rough})

## Four walls with a doorway in the front (+z) wall, a floor and simple furniture (RuleTown.WALL / DOOR match).
static func _hollow(n: Node3D, w: float, d: float, h: float, wall: Material, floor_color: int, furnish := true) -> void:
	var t := RuleTown.WALL
	var dw := RuleTown.DOOR
	var dh := 2.3
	_box(n, Vector3(w, h, t), wall, Vector3(0, h * 0.5, -d * 0.5 + t * 0.5))
	_box(n, Vector3(t, h, d), wall, Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0))
	_box(n, Vector3(t, h, d), wall, Vector3(w * 0.5 - t * 0.5, h * 0.5, 0))
	var side := (w - dw) * 0.5
	_box(n, Vector3(side, h, t), wall, Vector3(-dw * 0.5 - side * 0.5, h * 0.5, d * 0.5 - t * 0.5))
	_box(n, Vector3(side, h, t), wall, Vector3(dw * 0.5 + side * 0.5, h * 0.5, d * 0.5 - t * 0.5))
	if h > dh:
		_box(n, Vector3(dw, h - dh, t), wall, Vector3(0, dh + (h - dh) * 0.5, d * 0.5 - t * 0.5))
	_box(n, Vector3(w - t * 2.0, 0.1, d - t * 2.0), _mat(floor_color, {"rough": 0.8}), Vector3(0, 0.05, 0))
	_box(n, Vector3(w - t * 2.0, 0.12, d - t * 2.0), _mat(0xeae4d6, {"rough": 0.9}), Vector3(0, h - 0.06, 0))   # ceiling
	var lamp := OmniLight3D.new()   # a warm light inside so rooms aren't pitch dark under the ceiling
	lamp.light_color = Color(1.0, 0.88, 0.7); lamp.light_energy = 0.9; lamp.omni_range = maxf(w, d) * 0.8
	lamp.distance_fade_enabled = true   # only lit when you're near (hundreds of houses otherwise light every frame)
	lamp.distance_fade_begin = 22.0; lamp.distance_fade_length = 6.0
	lamp.position = Vector3(0, h - 0.6, 0)
	n.add_child(lamp)
	if furnish and w > 4.0 and d > 4.0:
		var wood := _mat(0x7a5232, {"rough": 0.8})
		_box(n, Vector3(1.4, 0.08, 0.9), wood, Vector3(-w * 0.18, 0.75, -d * 0.12))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(n, Vector3(0.08, 0.72, 0.08), wood, Vector3(-w * 0.18 + sx * 0.6, 0.36, -d * 0.12 + sz * 0.35))
		_box(n, Vector3(1.2, 0.45, 2.0), wood, Vector3(w * 0.5 - t - 0.75, 0.22, -d * 0.5 + t + 1.1))
		_box(n, Vector3(1.1, 0.15, 1.9), _mat(0xf0eee6), Vector3(w * 0.5 - t - 0.75, 0.52, -d * 0.5 + t + 1.1))
		_box(n, Vector3(0.6, 1.8, 1.4), wood, Vector3(-w * 0.5 + t + 0.35, 0.9, d * 0.18))

static var _mat_lock := Mutex.new()   # towns build on a worker thread (TownStream)
static func _mat(color: int, o := {}) -> StandardMaterial3D:
	var key := "%x:%s" % [color, str(o)]
	_mat_lock.lock()
	if _mats.has(key):
		var hit: StandardMaterial3D = _mats[key]
		_mat_lock.unlock()
		return hit
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((color << 8) | 0xff)
	m.roughness = float(o.get("rough", 0.65))
	m.metallic = float(o.get("metal", 0.0))
	if o.has("emissive"):
		m.emission_enabled = true
		m.emission = Color.hex((int(o.emissive) << 8) | 0xff)
		m.emission_energy_multiplier = float(o.get("glow", 1.0))
	_mats[key] = m
	_mat_lock.unlock()
	return m

static func build(g: Node3D, zone: RefCounted, l: Dictionary) -> void:
	var lay: Dictionary = RuleTown.layout(l)
	var style := str(l.get("style", "village"))
	var base_y: float = g.position.y
	var road_mat := _mat(0x3a3c42 if style == "city" else 0x8a7354, {"rough": 0.9})
	for rd: Dictionary in lay.roads:
		_road(g, zone, l, base_y, rd, road_mat)
	for e: Dictionary in lay.extras:
		_extra(g, zone, l, base_y, e, style)
	for b: Dictionary in lay.buildings:
		var n := Node3D.new()
		n.position = Vector3(b.x, _ground(zone, l, b.x, b.z) - base_y, b.z)
		n.rotation.y = float(b.rot)
		g.add_child(n)
		_foundation(n, zone, l, b)
		match str(b.kind):
			"tower": _tower(n, b)
			"office": _office(n, b)
			"dome": _dome_house(n, b)
			"cabin": _cabin(n, b)
			"windmill": _windmill(n, b)
			"lighthouse": _lighthouse(n, b)
			"ruin": _ruin(n, b)
			"shrine": _shrine(n, b)
			_: _house(n, b)
	# one mesh per material for the whole town (thousands of pieces -> a few draw calls), faded out far away
	var holder := Node3D.new()
	holder.name = "TownMeshes"
	for c in g.get_children():
		if not (c is Light3D):
			g.remove_child(c)
			holder.add_child(c)
	g.add_child(holder)
	MeshMerge.merge(holder, 2600.0)

## A stone footing from the building's floor down to the lowest ground under its footprint, so buildings on a
## slope stand on the ground instead of floating (user report, 2026-11-04).
static func _foundation(n: Node3D, zone: RefCounted, l: Dictionary, b: Dictionary) -> void:
	if str(b.kind) in ["field", "plaza", "pier", "boat", "bonfire", "fountain", "lamp"]:
		return
	var w := float(b.w); var d := float(b.d)
	if str(b.kind) == "lighthouse": w = 4.8; d = 4.8
	if str(b.kind) == "windmill": w = 6.0; d = 6.0
	var r := float(b.rot)
	var low := INF
	for cx in [-0.5, 0.0, 0.5]:
		for cz in [-0.5, 0.0, 0.5]:
			var lx: float = float(b.x) + float(cx) * w * cos(r) + float(cz) * d * sin(r)
			var lz: float = float(b.z) - float(cx) * w * sin(r) + float(cz) * d * cos(r)
			low = minf(low, _ground(zone, l, lx, lz))
	var drop := _ground(zone, l, float(b.x), float(b.z)) - low + 0.6
	var hh := drop + 0.2   # top at +0.02: a low step round the building (RuleTown.surface_at matches)
	_box(n, Vector3(w + 0.3, hh, d + 0.3), _mat(0x8f8a80, {"rough": 0.95}), Vector3(0, 0.02 - hh * 0.5, 0))

## Ground height under a town-local point (towns are flattened, but the edges follow the land).
static func _ground(zone: RefCounted, l: Dictionary, x: float, z: float) -> float:
	return RuleTown.ground(zone, l, x, z)

static func _put(p: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	p.add_child(mi)
	return mi

static func _box(p: Node3D, size: Vector3, m: Material, pos: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return _put(p, b, m, pos, rot_y)

static func _cyl(p: Node3D, rt: float, rb: float, h: float, m: Material, pos: Vector3, seg := 20) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg
	return _put(p, c, m, pos)

static func _dome(p: Node3D, r: float, m: Material, pos: Vector3, flat := 1.0) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r; s.is_hemisphere = true; s.radial_segments = 24; s.rings = 8
	var mi := _put(p, s, m, pos)
	mi.scale = Vector3(1, flat, 1)
	return mi

static func _windows(p: Node3D, r: float, y0: float, rows: int, per: int, gap: float) -> void:
	var glass := _mat(0x9fd4ff, {"rough": 0.15, "metal": 0.3, "emissive": 0x2a4a66, "glow": 0.6})
	var win := BoxMesh.new(); win.size = Vector3(1.2, 1.4, 0.15)
	for row in rows:
		for i in per:
			var a := float(i) / per * TAU + row * 0.3
			var mi := _put(p, win, glass, Vector3(sin(a) * r, y0 + row * gap, cos(a) * r))
			mi.rotation.y = a

# --- city ---------------------------------------------------------------------------------------------
static func _tower(n: Node3D, b: Dictionary) -> void:
	var r := float(b.w) * 0.5
	var h := float(b.h)
	var wall := _mat(int(b.color), {"rough": 0.4})
	_cyl(n, r, r * 1.08, h, wall, Vector3(0, h * 0.5, 0), 24)
	_cyl(n, r * 1.12, r * 1.12, 0.6, _mat(0x8a96a8, {"metal": 0.5, "rough": 0.3}), Vector3(0, h * 0.62, 0), 24)
	_dome(n, r * 1.05, _mat(0x5a8ad0, {"rough": 0.3, "metal": 0.2}), Vector3(0, h, 0), 0.8)
	_cyl(n, 0.15, 0.15, 5, _mat(0xcccccc, {"metal": 0.8}), Vector3(0, h + r * 0.8 + 2.5, 0), 6)
	_windows(n, r * 1.01, 3.0, int(h / 4.5), 10, 4.5)

static func _office(n: Node3D, b: Dictionary) -> void:
	var w := float(b.w); var h := float(b.h)
	var wall := _mat(int(b.color), {"rough": 0.5})
	_box(n, Vector3(w, h, w * 0.8), wall, Vector3(0, h * 0.5, 0))
	_cyl(n, w * 0.42, w * 0.42, w * 0.8, wall, Vector3(0, h, 0), 20).rotation.x = PI / 2   # rounded top
	var glass := _mat(0x9fd4ff, {"rough": 0.15, "metal": 0.3, "emissive": 0x2a4a66, "glow": 0.5})
	for row in int(h / 4.0):
		_box(n, Vector3(w * 0.86, 1.4, 0.2), glass, Vector3(0, 2.5 + row * 4.0, w * 0.4 + 0.05))
		_box(n, Vector3(w * 0.86, 1.4, 0.2), glass, Vector3(0, 2.5 + row * 4.0, -w * 0.4 - 0.05))

static func _dome_house(n: Node3D, b: Dictionary) -> void:
	var r := float(b.w) * 0.5
	var wall := _cut(int(b.color), 0.45)
	var panels := 20
	for i in panels:
		var a := (float(i) + 0.5) / panels * TAU
		if absf(wrapf(a, -PI, PI)) < 0.2:   # the doorway faces +z
			continue
		var pw := TAU * r / panels + 0.05
		var p := _box(n, Vector3(pw, 3.4, 0.3), wall, Vector3(sin(a) * r, 1.7, cos(a) * r))
		p.rotation.y = a
	_box(n, Vector3(RuleTown.DOOR + 0.2, 1.0, 0.3), wall, Vector3(0, 2.9, r))
	_dome(n, r, wall, Vector3(0, 3.4, 0), 0.85)
	_cyl(n, r, r, 0.12, _mat(0xeae4d6, {"rough": 0.9}), Vector3(0, 3.35, 0), 24)   # ceiling under the dome
	_box(n, Vector3(r * 1.5, 0.1, r * 1.5), _mat(0xc8b890, {"rough": 0.8}), Vector3(0, 0.05, 0))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.88, 0.7); lamp.light_energy = 0.9; lamp.omni_range = r * 1.8
	lamp.distance_fade_enabled = true   # only lit when you're near (hundreds of houses otherwise light every frame)
	lamp.distance_fade_begin = 22.0; lamp.distance_fade_length = 6.0
	lamp.position = Vector3(0, 2.8, 0)
	n.add_child(lamp)
	var wood := _mat(0x7a5232, {"rough": 0.8})
	_cyl(n, 0.7, 0.7, 0.08, wood, Vector3(0, 0.75, -r * 0.2), 16)
	_cyl(n, 0.08, 0.08, 0.72, wood, Vector3(0, 0.36, -r * 0.2), 6)
	var glass := _mat(0x8cc8f0, {"rough": 0.1, "metal": 0.3})
	for a in [0.9, -0.9, PI]:
		_cyl(n, 0.6, 0.6, 0.25, glass, Vector3(sin(a) * r, 2.2, cos(a) * r), 12).rotation = Vector3(PI / 2, a, 0)
	_cyl(n, r * 0.18, r * 0.18, 0.4, _mat(0xd84a3a), Vector3(0, 3.4 + r * 0.85, 0), 12)

# --- villages -----------------------------------------------------------------------------------------
static func _house(n: Node3D, b: Dictionary) -> void:
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	_hollow(n, w, d, h, _cut(int(b.color), 0.8), 0x9a7a58)
	var roof := CylinderMesh.new(); roof.top_radius = 0.0; roof.bottom_radius = 1.0; roof.height = 1.0; roof.radial_segments = 4
	var mi := _put(n, roof, _cut(0xb0462e, 0.7), Vector3(0, h + d * 0.28, 0))
	mi.rotation.y = PI / 4
	mi.scale = Vector3(w * 0.78, d * 0.56, d * 0.78)
	_box(n, Vector3(1.1, 1.0, 0.15), _cut(0x9fd0f0, 0.1), Vector3(w * 0.32, h * 0.6, d * 0.5 + 0.05))

static func _cabin(n: Node3D, b: Dictionary) -> void:
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var logs := _mat(int(b.color), {"rough": 0.9})
	var cut_logs := _cut(int(b.color), 0.9)
	for i in int(h / 0.45):
		var y := 0.25 + i * 0.45
		if y < 2.4:   # the front row of logs leaves the doorway open
			var seg := (w + 0.6 - RuleTown.DOOR) * 0.5
			for sx in [-1.0, 1.0]:
				var lf := _cyl(n, 0.24, 0.24, seg, cut_logs, Vector3(sx * (RuleTown.DOOR * 0.5 + seg * 0.5), y, d * 0.5), 8); lf.rotation.z = PI / 2
		else:
			var lg := _cyl(n, 0.24, 0.24, w + 0.6, cut_logs, Vector3(0, y, d * 0.5), 8); lg.rotation.z = PI / 2
		var lg2 := _cyl(n, 0.24, 0.24, w + 0.6, cut_logs, Vector3(0, y, -d * 0.5), 8); lg2.rotation.z = PI / 2
	_hollow(n, w, d, h, cut_logs, 0x8a6a48)
	var roof := CylinderMesh.new(); roof.top_radius = 0.0; roof.bottom_radius = 1.0; roof.height = 1.0; roof.radial_segments = 4
	var mi := _put(n, roof, _cut(0xf4f7fb, 0.6), Vector3(0, h + d * 0.3, 0))
	mi.rotation.y = PI / 4
	mi.scale = Vector3(w * 0.8, d * 0.6, d * 0.8)
	_box(n, Vector3(0.8, 2.0, 0.8), _cut(0x6a6a6a, 0.9), Vector3(w * 0.3, h + d * 0.4, 0))
	_box(n, Vector3(0.9, 0.8, 0.15), _mat(0xffc870, {"emissive": 0xffa040, "glow": 0.8}), Vector3(-w * 0.28, h * 0.55, d * 0.5 + 0.25))

static func _windmill(n: Node3D, b: Dictionary) -> void:
	var h := float(b.h)
	_cyl(n, 1.8, 3.0, h, _mat(int(b.color), {"rough": 0.8}), Vector3(0, h * 0.5, 0), 12)
	var cap := CylinderMesh.new(); cap.top_radius = 0.0; cap.bottom_radius = 2.4; cap.height = 2.6; cap.radial_segments = 12
	_put(n, cap, _mat(0xb0462e), Vector3(0, h + 1.3, 0))
	var hub := Node3D.new(); hub.position = Vector3(0, h - 1.0, 2.2); n.add_child(hub)
	hub.set_meta("spin", 0.6)
	for i in 4:
		var blade := _box(hub, Vector3(1.2, 9.0, 0.15), _mat(0xe6dcc6, {"rough": 0.9}), Vector3(0, 0, 0))
		blade.rotation.z = i * PI / 2
		blade.position = Vector3(sin(i * PI / 2) * -4.5, cos(i * PI / 2) * 4.5, 0)

static func _lighthouse(n: Node3D, b: Dictionary) -> void:
	var h := float(b.h)
	for i in 4:
		_cyl(n, 2.2 - i * 0.25, 2.4 - i * 0.25, h / 4.0, _mat(0xf4f4f4 if i % 2 == 0 else 0xd8322a, {"rough": 0.5}), Vector3(0, h / 8.0 + i * h / 4.0, 0), 16)
	_cyl(n, 1.5, 1.5, 2.2, _mat(0xfff2b0, {"emissive": 0xffd060, "glow": 2.0}), Vector3(0, h + 1.1, 0), 12)
	var cap := CylinderMesh.new(); cap.top_radius = 0.0; cap.bottom_radius = 1.9; cap.height = 1.6; cap.radial_segments = 12
	_put(n, cap, _mat(0x2a2a2a), Vector3(0, h + 3.0, 0))

static func _ruin(n: Node3D, b: Dictionary) -> void:
	var w := float(b.w); var d := float(b.d); var h := float(b.h)
	var wall := _mat(int(b.color), {"rough": 0.95})
	_box(n, Vector3(w, h * 0.55, d), wall, Vector3(0, h * 0.275, 0))
	_box(n, Vector3(w * 0.55, h * 0.45, d * 0.6), wall, Vector3(-w * 0.2, h * 0.55 + h * 0.2, d * 0.15))   # broken upper floors
	var dark := _mat(0x2a2826, {"rough": 1.0})
	for row in int(h * 0.55 / 3.5):
		_box(n, Vector3(w * 0.8, 1.2, 0.2), dark, Vector3(0, 1.8 + row * 3.5, d * 0.5 + 0.05))

static func _shrine(n: Node3D, b: Dictionary) -> void:
	var w := float(b.w); var h := float(b.h)
	var stone := _mat(int(b.color), {"rough": 0.8})
	_box(n, Vector3(w, h * 0.25, w), stone, Vector3(0, h * 0.125, 0))
	var top := CylinderMesh.new(); top.top_radius = 0.0; top.bottom_radius = w * 0.62; top.height = h * 0.75; top.radial_segments = 4
	var mi := _put(n, top, stone, Vector3(0, h * 0.25 + h * 0.375, 0)); mi.rotation.y = PI / 4
	_cyl(n, w * 0.08, w * 0.08, 1.0, _mat(0x8f5ad8, {"emissive": 0x6a30c0, "glow": 1.4}), Vector3(0, h + 0.5, 0), 8)

# --- roads and extras -----------------------------------------------------------------------------------
static func _road(g: Node3D, zone: RefCounted, l: Dictionary, base_y: float, rd: Dictionary, m: Material) -> void:
	var a := Vector2(rd.x1, rd.z1); var b := Vector2(rd.x2, rd.z2)
	var length := a.distance_to(b)
	var steps := maxi(1, int(length / 8.0))
	for i in steps:   # short flat pieces so the road follows the ground
		var p0 := a.lerp(b, float(i) / steps); var p1 := a.lerp(b, float(i + 1) / steps)
		var mid := (p0 + p1) * 0.5
		var y := _ground(zone, l, mid.x, mid.y) - base_y + 0.06
		var piece := _box(g, Vector3(float(rd.w), 0.6, p0.distance_to(p1) + 0.4), m, Vector3(mid.x, y - 0.25, mid.y))
		piece.rotation.y = atan2(b.x - a.x, b.y - a.y)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _extra(g: Node3D, zone: RefCounted, l: Dictionary, base_y: float, e: Dictionary, style: String) -> void:
	var y := _ground(zone, l, float(e.x), float(e.z)) - base_y
	match str(e.kind):
		"plaza":
			_cyl(g, float(e.r), float(e.r), 0.2, _mat(0xd8d2c4, {"rough": 0.6}), Vector3(e.x, y + 0.1, e.z), 40)
		"fountain":
			_cyl(g, 6.0, 6.4, 1.0, _mat(0xcfc8b8), Vector3(e.x, y + 0.5, e.z), 28)
			_cyl(g, 5.5, 5.5, 0.2, _mat(0x5aa8e0, {"rough": 0.05, "metal": 0.2}), Vector3(e.x, y + 0.95, e.z), 28)
			_cyl(g, 0.6, 0.9, 3.5, _mat(0xcfc8b8), Vector3(e.x, y + 1.75, e.z), 12)
			_dome(g, 1.6, _mat(0x8fd0ff, {"rough": 0.05, "emissive": 0x2a6aa0, "glow": 0.5}), Vector3(e.x, y + 3.4, e.z), 0.6)
		"lamp":
			var pole := _mat(0x40444c, {"metal": 0.6, "rough": 0.4})
			_cyl(g, 0.12, 0.16, 5.0, pole, Vector3(e.x, y + 2.5, e.z), 8)
			var bulb := SphereMesh.new(); bulb.radius = 0.45; bulb.height = 0.9
			_put(g, bulb, _mat(0xfff0c8, {"emissive": 0xffd890, "glow": 1.5}), Vector3(e.x, y + 5.2, e.z))
		"field":
			var fm := _mat(0x8aa63a if int(e.w) % 2 == 0 else 0xc8b04a, {"rough": 1.0})
			var fr := float(e.rot)
			var nx := maxi(1, int(float(e.w) / 6.0)); var nz := maxi(1, int(float(e.d) / 6.0))
			for i in nx:
				for k in nz:   # tiles that each sit on the ground under them
					var lx := (float(i) + 0.5) / nx * float(e.w) - float(e.w) * 0.5
					var lz := (float(k) + 0.5) / nz * float(e.d) - float(e.d) * 0.5
					var tx := float(e.x) + lx * cos(fr) + lz * sin(fr)
					var tz := float(e.z) - lx * sin(fr) + lz * cos(fr)
					var ty := _ground(zone, l, tx, tz) - base_y
					var f := _box(g, Vector3(float(e.w) / nx + 0.05, 0.5, float(e.d) / nz + 0.05), fm, Vector3(tx, ty - 0.17, tz))
					f.rotation.y = fr
					f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"bonfire":
			_cyl(g, 1.2, 1.4, 0.5, _mat(0x4a3a2a), Vector3(e.x, y + 0.25, e.z), 10)
			var fire := CylinderMesh.new(); fire.top_radius = 0.0; fire.bottom_radius = 0.9; fire.height = 1.8
			_put(g, fire, _mat(0xffa030, {"emissive": 0xff7010, "glow": 2.5}), Vector3(e.x, y + 1.3, e.z))
			var light := OmniLight3D.new(); light.light_color = Color("#ffb060"); light.light_energy = 1.5; light.omni_range = 18
			light.position = Vector3(e.x, y + 2.5, e.z)
			g.add_child(light)
		"rubble":
			var rb := _box(g, Vector3.ONE * float(e.s), _mat(0x7a766e, {"rough": 1.0}), Vector3(e.x, y + float(e.s) * 0.3, e.z))
			rb.rotation = Vector3(float(e.s), float(e.x), float(e.z) * 0.1)
		"pier":
			var wood := _mat(0x8a6a44, {"rough": 0.9})
			var len := float(e.len)
			_box(g, Vector3(4.0, 0.3, len), wood, Vector3(e.x, 0.9 - base_y, float(e.z) - len * 0.5))
			for i in int(len / 6.0) + 1:
				for sx in [-1.8, 1.8]:
					_cyl(g, 0.22, 0.22, 4.0, wood, Vector3(float(e.x) + sx, -1.0 - base_y, float(e.z) - i * 6.0), 6)
		"boat":
			var hull := _box(g, Vector3(3.0, 1.2, 8.0), _mat(0xf4f4f4, {"rough": 0.4}), Vector3(e.x, 0.4 - base_y, e.z))
			hull.rotation.y = float(e.rot)
			var cabin := _box(g, Vector3(2.2, 1.4, 2.6), _mat(0x2a5aa8), Vector3(e.x, 1.6 - base_y, e.z))
			cabin.rotation.y = float(e.rot)
