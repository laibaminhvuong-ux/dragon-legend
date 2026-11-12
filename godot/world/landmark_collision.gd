class_name LandmarkCollision
extends RefCounted
# Solid landmark buildings (user report after 0.0.8: "you walk straight through the new buildings").
#
# The game does not move fighters with Godot physics: RuleCollision.resolve pushes every player, NPC and enemy out
# of the zone's 2D colliders (zone.props(): circles {x, z, radius, top} and oriented boxes {x, z, rot, hw, hd, top},
# each solid from below the ground up to `top`). Until now a landmark only had the one `collide` circle from the
# zone data, so most walls, towers and wings had no collision and big circles blocked the wrong areas.
#
# Here the colliders come from the building's real pieces (recorded by MeshMerge before it merges them, or the
# loose MeshInstance3D pieces of the legacy builders): every structural piece standing on the ground becomes a
# circle (upright cylinders, domes, spheres) or an oriented box, and the pieces resting on them (roofs, upper
# floors, domes, tower tops) raise their top. Gaps between pieces (doorways, arches, gates) stay open.
# Never solid: decoration (pieces under ~1.5 m, posts and poles under 0.6 m across, thin fences/signs/rails,
# unshaded / transparent / glow / water / cloud materials, the builder's no_shadow and `no_collision` materials,
# pieces marked meta "no_collision", animated "spin" pieces, toruses, planes, labels) and walkable surfaces (floors,
# paths and steps under 0.8 m, wide platforms and rings under 2 m: rules have no "stand on a landmark" height, so
# making them solid would push fighters off the arena).
# The zone's spawn, travel point, doors, NPCs and quest spots are kept clear: a collider covering one is dropped
# (or, for a point high above the ground, cut down below it). The old `collide` circle is removed when the geometry
# gave the landmark colliders, kept otherwise. A StaticBody3D with the same shapes is added for Godot-side queries.

const MIN_SIZE := 1.5      # pieces whose world box is smaller than this in every direction are props
const POST := 0.6          # thinner than this in both horizontal directions: lamp posts, poles, flag poles
const THIN := 0.25         # thinner than this in one direction and lower than LOW_WALL: fences, rails, signs
const LOW_WALL := 2.5
const WALK_TOP := 0.8      # tops lower than this are floors, paths, steps: walked over
const PLATFORM_TOP := 2.0  # wide pieces lower than this are rings, stages, plinths: stood on
const PLATFORM_MIN := 3.0
const GROUNDED := 2.5      # a piece starting higher than this rests on others (or floats)
const CLEAR := 0.8         # protected points keep this much room (fighter radius 0.35 + margin)

static var _sphere_aabbs: Dictionary = {}
static var _lock := Mutex.new()

## One piece as MeshMerge sees it, before it is merged away: transform relative to the landmark, mesh-space box.
static func piece(mi: MeshInstance3D, root: Node3D) -> Dictionary:
	var m: Material = mi.material_override
	if m == null and mi.mesh is PrimitiveMesh:
		m = (mi.mesh as PrimitiveMesh).material
	elif m == null and mi.mesh.get_surface_count() > 0:
		m = mi.mesh.surface_get_material(0)
	return {"xf": MeshMerge._relative(mi, root), "aabb": local_aabb(mi.mesh), "mat": m,
		"round": mi.mesh is CylinderMesh or mi.mesh is SphereMesh or mi.mesh is CapsuleMesh, "skip": _opted_out(mi, root)}

static func _opted_out(n: Node, root: Node) -> bool:
	var c := n
	while c != null and c != root:
		if c.has_meta("no_collision"):
			return true
		c = c.get_parent()
	return false

## The mesh's box in its own space, without building primitive meshes (null = never solid).
static func local_aabb(mesh: Mesh) -> Variant:
	if mesh is BoxMesh:
		var sz := (mesh as BoxMesh).size
		return AABB(-sz * 0.5, sz)
	if mesh is PrismMesh:
		var sz := (mesh as PrismMesh).size
		return AABB(-sz * 0.5, sz)
	if mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		var r := maxf(c.top_radius, c.bottom_radius)
		return AABB(Vector3(-r, -c.height * 0.5, -r), Vector3(r * 2.0, c.height, r * 2.0))
	if mesh is CapsuleMesh:
		var cp := mesh as CapsuleMesh
		return AABB(Vector3(-cp.radius, -cp.height * 0.5, -cp.radius), Vector3(cp.radius * 2.0, cp.height, cp.radius * 2.0))
	if mesh is SphereMesh:
		var sp := mesh as SphereMesh
		if sp.radius <= 0.0:
			return null
		var key := "%.2f:%s" % [snappedf(sp.height / sp.radius, 0.01), sp.is_hemisphere]
		_lock.lock()
		var hit: Variant = _sphere_aabbs.get(key)
		_lock.unlock()
		if hit == null:   # the unit shape MeshMerge caches anyway (a hemisphere's extent depends on Godot's mesher)
			var verts: PackedVector3Array = MeshMerge._shape(mesh, 0)[0][0]
			var box := AABB(verts[0], Vector3.ZERO) if not verts.is_empty() else AABB()
			for v in verts:
				box = box.expand(v)
			hit = box
			_lock.lock()
			_sphere_aabbs[key] = box
			_lock.unlock()
		var u: AABB = hit
		return AABB(u.position * sp.radius, u.size * sp.radius)
	if mesh is TorusMesh or mesh is PlaneMesh or mesh is QuadMesh or mesh is TextMesh or mesh is PrimitiveMesh:
		return null   # rings, flat cards, text: decoration
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	return mesh.get_aabb()

static func _decor(m: Material, extra: Array) -> bool:
	if m == null:
		return false
	if m in extra:
		return true
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		return b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
			or b.albedo_color.a < 0.99
	if m is ShaderMaterial:
		var sh := (m as ShaderMaterial).shader
		return sh != null and ("unshaded" in sh.code or "blend_add" in sh.code or "ALPHA" in sh.code)
	return false

## Every piece of a built landmark: recorded by MeshMerge, else the loose (legacy, unmerged) static meshes.
static func pieces_of(g: Node3D) -> Array:
	if g.has_meta("pieces"):
		return g.get_meta("pieces")
	var out: Array = []
	for n in g.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh != null and not MeshMerge._moving(mi, g):
			out.append(piece(mi, g))
	return out

## Rule colliders (world space; the landmark node `g` sits directly under the world origin) for one landmark.
static func colliders(g: Node3D) -> Array:
	var gx := g.transform
	var base := g.position.y
	var yaw := g.rotation.y
	var extra: Array = g.get_meta("no_collision_mats", [])
	var solid: Array = []    # [collider, Rect2 footprint]
	var resting: Array = []  # [bottom, top, Rect2]
	for p: Dictionary in pieces_of(g):
		if p.skip or p.aabb == null or _decor(p.mat, extra):
			continue
		var aabb: AABB = p.aabb
		var full: Transform3D = gx * (p.xf as Transform3D)
		var lo := Vector3(INF, INF, INF); var hi := -lo
		for i in 8:
			var w := full * aabb.get_endpoint(i)
			lo = lo.min(w); hi = hi.max(w)
		var size := hi - lo
		if maxf(size.x, maxf(size.y, size.z)) < MIN_SIZE or hi.y - base < WALK_TOP:
			continue
		var rect := Rect2(lo.x, lo.z, size.x, size.z)
		if lo.y - base > GROUNDED:
			resting.append([lo.y, hi.y, rect])
			continue
		var c := _shape2d(full, aabb, bool(p.round), yaw)
		var w2: float; var d2: float
		if c.has("radius"):
			w2 = float(c.radius) * 2.0; d2 = w2
		else:
			w2 = float(c.hw) * 2.0; d2 = float(c.hd) * 2.0
		if maxf(w2, d2) < POST or (minf(w2, d2) < THIN and size.y < LOW_WALL):
			continue
		if hi.y - base < PLATFORM_TOP and minf(w2, d2) > PLATFORM_MIN:
			continue
		c.top = hi.y
		c.landmark = true
		for part: Dictionary in _split(c):
			solid.append([part, rect])
	# roofs, upper floors and tower tops raise the top of what they rest on (never widen it: no invisible walls
	# under eaves and porches); pieces resting on nothing solid (floating rings, signs, clouds) are left out
	resting.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for r: Array in resting:
		for s: Array in solid:
			if float(s[0].top) >= float(r[0]) - 1.0 and (s[1] as Rect2).grow(0.05).intersects(r[2]):
				s[0].top = maxf(float(s[0].top), float(r[1]))
	var out: Array = []
	for s: Array in solid:
		out.append(s[0])
	return out

## PropSet.near finds colliders by their centre's 16 m cell within radius + 26 m: big boxes are cut into tiles
## no wider than MAX_HALF each way, and every box carries its bounding `radius` (near() reads it).
const MAX_HALF := 10.0
static func _split(c: Dictionary) -> Array:
	if not c.has("hw") and float(c.radius) <= 24.0:
		return [c]
	if not c.has("hw"):   # a huge round piece: the square of the same area, tiled
		c = c.duplicate()
		c.rot = 0.0; c.hw = float(c.radius) * 0.886; c.hd = c.hw
	var nx := int(ceil(float(c.hw) / MAX_HALF)); var nz := int(ceil(float(c.hd) / MAX_HALF))
	var hw := float(c.hw) / nx; var hd := float(c.hd) / nz
	var r: float = c.rot
	var ax := Vector2(cos(r), -sin(r)); var az := Vector2(sin(r), cos(r))   # the box's local x / z axes in world x,z
	var out: Array = []
	for i in nx:
		for k in nz:
			var o := ax * (-float(c.hw) + hw * (2 * i + 1)) + az * (-float(c.hd) + hd * (2 * k + 1))
			var t := c.duplicate()
			t.x = float(c.x) + o.x; t.z = float(c.z) + o.y
			t.hw = hw; t.hd = hd
			t.radius = Vector2(hw, hd).length()
			out.append(t)
	return out

## A circle for upright round pieces, an oriented box for upright boxes, else the box around it in the landmark's frame.
static func _shape2d(full: Transform3D, aabb: AABB, round: bool, yaw: float) -> Dictionary:
	var ctr := full * aabb.get_center()
	var bx := full.basis.x; var by := full.basis.y; var bz := full.basis.z
	if absf(by.normalized().y) > 0.985:
		var sx := Vector2(bx.x, bx.z).length(); var sz := Vector2(bz.x, bz.z).length()
		if round and absf(sx - sz) <= 0.05 * maxf(sx, sz):
			return {"x": ctr.x, "z": ctr.z, "radius": aabb.size.x * 0.5 * sx}
		return {"x": ctr.x, "z": ctr.z, "rot": atan2(-bx.z, bx.x), "hw": aabb.size.x * 0.5 * sx, "hd": aabb.size.z * 0.5 * sz}
	var cs := cos(yaw); var sn := sin(yaw)
	var lo := Vector2(INF, INF); var hi := -lo
	for i in 8:
		var w := full * aabb.get_endpoint(i)
		var l := Vector2(w.x * cs - w.z * sn, w.x * sn + w.z * cs)
		lo = lo.min(l); hi = hi.max(l)
	var m := (lo + hi) * 0.5
	return {"x": m.x * cs + m.y * sn, "z": -m.x * sn + m.y * cs, "rot": yaw, "hw": (hi.x - lo.x) * 0.5, "hd": (hi.y - lo.y) * 0.5}

## Is (x, z) within `margin` of the collider's footprint (RuleCollision's frame)?
static func inside(c: Dictionary, x: float, z: float, margin := 0.0) -> bool:
	return depth(c, x, z) > -margin

## How far (x, z) is inside the collider's footprint (negative: that far outside, roughly).
static func depth(c: Dictionary, x: float, z: float) -> float:
	var dx: float = x - float(c.x); var dz: float = z - float(c.z)
	if not c.has("hw"):
		return float(c.radius) - sqrt(dx * dx + dz * dz)
	var r: float = c.rot
	var lx := dx * cos(r) - dz * sin(r)
	var lz := dx * sin(r) + dz * cos(r)
	return minf(float(c.hw) - absf(lx), float(c.hd) - absf(lz))

## Points that must stay reachable: {p: Vector3 (y = NAN on the ground), kind, slack}. A point is reachable
## when a fighter can get within `slack` of it (quest areas have a radius; arrivals and doors must be free).
## NPCs deep inside a building are moved out by zone.free_position (as with the old `collide` circle).
static func protected_points(zone: RuleZone) -> Array:
	var out: Array = []
	var add := func(p: Variant, kind: String, slack := 0.0, y: Variant = null) -> void:
		if p is Dictionary and p.get("x") != null and p.get("z") != null:
			out.append({"p": Vector3(float(p.x), NAN if y == null else float(y), float(p.z)), "kind": kind, "slack": slack})
	add.call(zone.spawn, "spawn")
	add.call(zone.travel_point, "travel")
	if zone is RulePlanet:
		var planet := zone as RulePlanet
		for rid: String in planet.regions:
			var rz: RuleZone = planet.regions[rid].zone
			add.call(planet.to_planet(rid, rz.spawn), "spawn")
			if rz.travel_point != null:
				add.call(planet.to_planet(rid, rz.travel_point), "travel")
	for d: Dictionary in zone.doors():
		add.call(d, "door")
	for n: Dictionary in RuleTables.table("npcs"):
		var nz := str(n.get("zone", ""))
		if zone.has_region(nz):
			var y: Variant = null
			if n.get("y") != null:
				y = float(n.y) + (zone.lift_of(nz) if zone.has_method("lift_of") else 0.0)
			add.call(zone.place_in(nz, float(n.x), float(n.z)), "npc", 0.0, y)
	for q: Dictionary in RuleTables.table("quests"):
		for s: Dictionary in q.get("steps", []):
			var sz := str(s.get("zone", ""))
			if s.get("x") != null and zone.has_region(sz) and str(s.get("type", "")) != "defeat":   # foes are pushed out
				add.call(zone.place_in(sz, float(s.x), float(s.get("z", 0))), "quest", maxf(float(s.get("r", 2.0)) - 1.0, 0.0))
			for sp: Dictionary in s.get("spots", []):
				var pz := str(sp.get("zone", sz))
				if zone.has_region(pz):
					add.call(zone.place_in(pz, float(sp.x), float(sp.z)), "pickup", 1.0)
	return out

## Is the point blocked by this collider (a fighter can't get within its slack)?
static func blocks(c: Dictionary, pt: Dictionary) -> bool:
	var p: Vector3 = pt.p
	return depth(c, p.x, p.z) + CLEAR > float(pt.slack) and (is_nan(p.y) or p.y <= float(c.top))

## Drops (or, under a high point, cuts down) the colliders that block a protected point. Returns how many.
static func carve(cs: Array, points: Array, base: float) -> int:
	var n := 0
	for pt: Dictionary in points:
		var p: Vector3 = pt.p
		for c: Dictionary in cs.duplicate():
			if not blocks(c, pt):
				continue
			if pt.kind == "npc" and depth(c, p.x, p.z) > 2.5:
				continue   # well inside: free_position stands the NPC outside
			n += 1
			if not is_nan(p.y) and p.y > base + GROUNDED:
				c.top = minf(float(c.top), p.y - 0.05)
			elif not _trim(c, p, float(pt.slack)):
				cs.erase(c)
	return n

## Pulls the collider's nearest side back so the point is clear (most of the wall stays). False: too little is
## left, drop it.
static func _trim(c: Dictionary, p: Vector3, slack: float) -> bool:
	var keep := slack - CLEAR - 0.02   # the depth the point may still have
	var dx: float = p.x - float(c.x); var dz: float = p.z - float(c.z)
	if not c.has("hw"):
		var nr := sqrt(dx * dx + dz * dz) + keep
		if nr < float(c.radius) * 0.6 or nr < 0.3:
			return false
		c.radius = nr
		return true
	var r: float = c.rot
	var lx := dx * cos(r) - dz * sin(r)
	var lz := dx * sin(r) + dz * cos(r)
	var on_x := float(c.hw) - absf(lx) < float(c.hd) - absf(lz)
	var half: float = c.hw if on_x else c.hd
	var l := absf(lx if on_x else lz)
	var s := signf(lx if on_x else lz) if (lx if on_x else lz) != 0.0 else 1.0
	var edge := l + keep               # the side facing the point moves to here (the far side stays at -half)
	var nh := (half + edge) * 0.5
	if nh < 0.3:
		return false
	var shift := (edge - half) * 0.5 * s   # along the trimmed local axis
	var axis := Vector2(cos(r), -sin(r)) if on_x else Vector2(sin(r), cos(r))
	c.x = float(c.x) + axis.x * shift; c.z = float(c.z) + axis.y * shift
	if on_x:
		c.hw = nh
	else:
		c.hd = nh
	c.radius = Vector2(float(c.hw), float(c.hd)).length()
	return true

## Collision for the landmarks just built: [[g, l], ...]. Injects the colliders into the zone's rule colliders
## (once per PropSet), replacing the old `collide` circle, and adds a StaticBody3D per landmark under `root`.
static func apply(zone: RuleZone, root: Node3D, built: Array) -> void:
	var props: RefCounted = zone.props()
	var fresh := not props.has_meta("landmark_collision")
	var points := protected_points(zone)
	for it: Array in built:
		var g: Node3D = it[0]
		var l: Dictionary = it[1]
		var cs := colliders(g)
		g.remove_meta("pieces")   # the recorded pieces are only needed here
		var near: Array = []
		var reach := 0.0
		for c: Dictionary in cs:
			reach = maxf(reach, Vector2(float(c.x) - g.position.x, float(c.z) - g.position.z).length() + float(c.get("radius", Vector2(c.get("hw", 0), c.get("hd", 0)).length())))
		for pt: Dictionary in points:
			if Vector2(pt.p.x - g.position.x, pt.p.z - g.position.z).length() < reach + CLEAR:
				near.append(pt)
		g.set_meta("carved", carve(cs, near, g.position.y))
		g.set_meta("colliders", cs)
		if cs.is_empty():
			if l.get("collide") != null:
				root.add_child(_legacy_body(zone, l))
			continue
		root.add_child(body(cs, g.position.y, g.name))
		if fresh:
			_drop_legacy(props, l)
			for c: Dictionary in cs:
				props._add(c)
	props.set_meta("landmark_collision", true)

## The old landmark circle (radius collide * scale, 12 m * scale tall), for landmarks whose pieces gave nothing.
static func _legacy_body(zone: RuleZone, l: Dictionary) -> StaticBody3D:
	var s := float(l.get("scale", 1.0))
	var c := {"x": float(l.x), "z": float(l.z), "radius": float(l.collide) * s, "top": zone.height_at(l.x, l.z) + 12.0 * s}
	return body([c], zone.height_at(l.x, l.z), "legacy")

static func _drop_legacy(props: RefCounted, l: Dictionary) -> void:
	if l.get("collide") == null:
		return
	var cell := Vector2i(floori(float(l.x) / 16.0), floori(float(l.z) / 16.0))
	var list: Array = props._grid.get(cell, [])
	var r := float(l.collide) * float(l.get("scale", 1.0))
	for c: Dictionary in list.duplicate():
		if not c.has("hw") and c.has("radius") and is_equal_approx(float(c.x), float(l.x)) and is_equal_approx(float(c.z), float(l.z)) \
				and is_equal_approx(float(c.radius), r):
			list.erase(c)

## The same shapes as a StaticBody3D (collision layer 1, as the terrain), from 2 m under the base to each top.
static func body(cs: Array, base: float, label: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Collision_" + label
	for c: Dictionary in cs:
		var h := maxf(float(c.top) - (base - 2.0), 0.5)
		var shape := CollisionShape3D.new()
		if c.has("hw"):
			var bs := BoxShape3D.new()
			bs.size = Vector3(float(c.hw) * 2.0, h, float(c.hd) * 2.0)
			shape.shape = bs
			shape.rotation.y = float(c.rot)
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = float(c.radius)
			cyl.height = h
			shape.shape = cyl
		shape.position = Vector3(float(c.x), float(c.top) - h * 0.5, float(c.z))
		b.add_child(shape)
	return b
