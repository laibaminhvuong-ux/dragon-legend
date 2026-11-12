extends TestCase
# Solid landmark buildings (LandmarkCollision): every builder of the four 0.0.8 group files and the legacy
# landmarks.gd gets colliders from its real pieces, a probe from outside towards the building hits them, walking
# into the walls with the game's own RuleCollision stops, and no arrival / door / NPC / quest point is inside.

## Types that are not buildings (holes, floating or flat things, scenery parts made of decoration): no colliders needed.
const NOT_SOLID := ["crater", "interior", "kaiband", "beerusisle", "serpentcoils", "kaiorb", "cupstand", "toparena"]
## Arenas, plazas and villages: open in the middle by design (you fight / walk there), probed at their biggest piece.
const OPEN := ["budokai", "cellring", "u6arena", "budokaihall", "lookout", "lookoutpalace", "nexus",
	"serpenthead", "bloodpool", "yardratvillage", "floatcups", "vampacrater"]
## Builders that need placement data no zone gives them (kaiplanet: King Kae's orb, replaced by kaiorb).
const SKIP := ["kaiplanet"]

## A real placement of every landmark type (its zone and data), else a bare one on the plains.
func _placements() -> Dictionary:
	var out := {}
	var zones: Dictionary = RuleTables.table("zones")
	for zid: String in zones:
		for l: Dictionary in zones[zid].get("landmarks", []):
			var t := str(l.get("type", ""))
			if t != "town" and not out.has(t):
				out[t] = zid
	var types: Array = WorldLandmarks.BUILDERS.duplicate()
	for gr: Variant in WorldLandmarks._groups():
		types.append_array(gr.TYPES)
	var all := {}
	for t: String in types:
		if t != "town" and t not in SKIP:
			all[t] = out.get(t, "")
	return all

func _built(t: String, zid: String) -> Array:
	var zone := RuleZone.new(zid if zid != "" else "earth_plains")
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == t:
			l = m
			break
	if l.is_empty():
		l = {"type": t, "x": 0.0, "z": 0.0, "scale": 1, "rot": 0}
	var t0 := Time.get_ticks_usec()
	var g := WorldLandmarks.build_one(zone, l)
	var t1 := Time.get_ticks_usec()
	var cs := LandmarkCollision.colliders(g)
	var t2 := Time.get_ticks_usec()
	return [zone, l, g, cs, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0]

func _biggest_centre(cs: Array) -> Vector2:
	var best := Vector2.ZERO
	var area := -1.0
	for c: Dictionary in cs:
		var a: float = PI * pow(float(c.radius), 2) if not c.has("hw") else 4.0 * float(c.hw) * float(c.hd)
		if a > area:
			area = a; best = Vector2(float(c.x), float(c.z))
	return best

## Does the 2D segment a -> b (fighter radius 0.35) touch any collider?
func _hits(cs: Array, a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / 0.25))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		for c: Dictionary in cs:
			if LandmarkCollision.inside(c, p.x, p.y, 0.35):
				return true
	return false

func test_every_landmark_type_is_solid_from_outside() -> void:
	var slow: Array = []
	for t: String in _placements():
		var zid: String = _placements()[t]
		var r := _built(t, zid)
		var g: Node3D = r[2]
		var cs: Array = r[3]
		var tops := 0.0
		for c: Dictionary in cs:
			tops = maxf(tops, float(c.top) - g.position.y)
		print("  %-14s %-18s colliders %3d  top %5.1f m  build %6.1f ms  collision %5.1f ms" % [t, zid, cs.size(), tops, r[4], r[5]])
		if float(r[5]) > 50.0:
			slow.append("%s %.0f ms" % [t, r[5]])
		if t in NOT_SOLID:
			g.free()
			continue
		ok(not cs.is_empty(), t + " has colliders")
		var centre := Vector2(g.position.x, g.position.z)
		if t in OPEN:
			centre = _biggest_centre(cs)
		var hit := 0
		for k in 8:
			var d := Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0))
			if _hits(cs, centre + d * 120.0, centre):
				hit += 1
		ok(hit >= 6, "%s: %d of 8 probes from outside hit the building" % [t, hit])
		g.free()
	ok(slow.is_empty(), "collision under 50 ms per landmark: %s" % ", ".join(PackedStringArray(slow)))

## Walk (RuleCollision, as the game does every step) from outside straight at the biggest wall: it stops there.
func test_walking_into_the_walls_stops() -> void:
	for pair: Array in [["west_city", "capsulehq"], ["kame_island", "kamecottage"], ["korrin_tower", "korrinspire"],
			["pilav_castle", "pilavpalace"], ["snake_way", "checkinhall"]]:
		var zone := RulePlanet.open(pair[0])   # the map the game loads (Earth areas are regions of the planet)
		var root := WorldLandmarks.build(zone)
		var g: Node3D = null
		for c in root.get_children():
			if c.has_meta("landmark") and str(c.get_meta("landmark").type) == pair[1]:
				g = c
		ok(g != null, "%s builds %s" % pair)
		if g == null:
			root.free()
			continue
		var cs: Array = g.get_meta("colliders")
		var big: Dictionary = {}
		var area := 0.0
		for c: Dictionary in cs:
			var a: float = PI * pow(float(c.radius), 2) if not c.has("hw") else 4.0 * float(c.hw) * float(c.hd)
			if a > area:
				area = a; big = c
		ok(not big.is_empty(), "%s has a wall to walk into" % pair[1])
		for k in 4:
			var target := Vector3(float(big.x), 0, float(big.z))
			var dir := Vector3(cos(k * TAU / 4.0 + 0.3), 0, sin(k * TAU / 4.0 + 0.3))
			var start := target + dir * 90.0
			var e := {"pos": Vector3(start.x, zone.height_at(start.x, start.z), start.z), "vel": Vector3.ZERO, "flying": false, "onGround": true}
			for i in 900:
				var prev: Vector3 = e.pos
				var p: Vector3 = e.pos - dir * 0.15
				p.y = zone.height_at(p.x, p.z)
				e.pos = p
				RuleCollision.resolve(e, zone, prev)
			ok(not LandmarkCollision.inside(big, e.pos.x, e.pos.z, 0.3), "%s: walking in from side %d stops at the wall (ended %.1f, %.1f)" % [pair[1], k, e.pos.x, e.pos.z])
		root.free()

## Every zone with a 0.0.8 builder: arrivals, doors, NPCs and quest spots are outside the colliders, the buildings
## kept their colliders, and the old `collide` circle is gone where the pieces gave better ones.
func test_zone_points_are_not_inside_collision() -> void:
	var group_types: Array = []
	for gr: Variant in WorldLandmarks._groups():
		group_types.append_array(gr.TYPES)
	var zones: Dictionary = RuleTables.table("zones")
	for zid: String in zones:
		var swapped := false
		for l: Dictionary in zones[zid].get("landmarks", []):
			swapped = swapped or str(l.get("type", "")) in group_types
		if not swapped:
			continue
		var zone := RuleZone.new(zid)
		var root := WorldLandmarks.build(zone)
		var points := LandmarkCollision.protected_points(zone)
		for g in root.get_children():
			if not g.has_meta("colliders"):
				continue
			var l: Dictionary = g.get_meta("landmark")
			var cs: Array = g.get_meta("colliders")
			if int(g.get_meta("carved", 0)) > 0:
				print("  %s %s: %d collider(s) cleared for spawn/door/NPC/quest points" % [zid, l.type, g.get_meta("carved")])
			for pt: Dictionary in points:
				var p: Vector3 = pt.p
				for c: Dictionary in cs:
					if not LandmarkCollision.blocks(c, pt):
						continue
					if pt.kind == "npc":   # deep inside a building: the NPC stands at its free position instead
						var f := zone.free_position({"x": p.x, "z": p.z})
						ok(not LandmarkCollision.inside(c, f.x, f.z, 0.3), "%s: NPC at %.1f,%.1f moved out of %s (to %.1f,%.1f)" % [zid, p.x, p.z, l.type, f.x, f.z])
					else:
						ok(false, "%s: %s point %.1f,%.1f is blocked by %s" % [zid, pt.kind, p.x, p.z, l.type])
			if cs.is_empty() or l.get("collide") == null:
				continue
			var r := float(l.collide) * float(l.get("scale", 1.0))
			for c: Dictionary in zone.props().near(float(l.x), float(l.z), 0.1):
				ok(c.has("hw") or c.get("landmark", false) or not is_equal_approx(float(c.radius), r) or not is_equal_approx(float(c.x), float(l.x)),
					"%s: %s's old collide circle replaced" % [zid, l.type])
			var body := root.get_node_or_null("Collision_" + g.name)
			ok(body != null and body.get_child_count() == cs.size(), "%s: %s has a StaticBody3D with its shapes" % [zid, l.type])
		root.free()
