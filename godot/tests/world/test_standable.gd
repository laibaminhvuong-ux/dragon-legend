extends TestCase
# Stand-on surfaces (RuleZone.add_surface, filled by LandmarkCollision): rings, stages and stairs can be climbed,
# and no fighter walking at any landmark ends up inside one (user report: "I can still walk through the buildings").

## Walks like the game: step along `dir`, stand on ground_at (reach = current height), then RuleCollision.resolve.
func _walk(zone: RuleZone, e: Dictionary, dir: Vector3, steps: int, speed := 0.15) -> void:
	for i in steps:
		var prev: Vector3 = e.pos
		var p: Vector3 = e.pos + dir * speed
		p.y = zone.ground_at(p.x, p.z, prev.y)
		e.pos = p
		RuleCollision.resolve(e, zone, prev)

func _fighter(zone: RuleZone, x: float, z: float) -> Dictionary:
	return {"pos": Vector3(x, zone.height_at(x, z), z), "vel": Vector3.ZERO, "flying": false, "onGround": true}

## Is the fighter inside something it should not be in (a surface above its feet, or a solid collider)?
func _buried(zone: RuleZone, p: Vector3) -> String:
	var top := zone.ground_at(p.x, p.z)
	if top - p.y > 0.7 and top - zone.height_at(p.x, p.z) > 0.3:
		return "inside a platform %.2f m above the feet" % (top - p.y)
	for c: Dictionary in zone.props().near(p.x, p.z, 0.1):
		if p.y < float(c.top) - 0.05 and LandmarkCollision.depth(c, p.x, p.z) > 0.25:
			return "inside a solid (top %.1f)" % float(c.top)
	return ""

func test_the_tournament_ring_can_be_climbed() -> void:
	var zone := RuleZone.new("tournament_island")
	var root := WorldLandmarks.build(zone)
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "budokaihall":
			l = m
	ok(not l.is_empty(), "tournament island has the hall")
	if l.is_empty():
		root.free()
		return
	var cx := float(l.x); var cz := float(l.z)
	var heights: Array = []
	for side in 4:   # walk in at the middle of each side (the stairs), the ring is a 40 m square 1.6 m up
		var a := side * PI * 0.5
		var dir := Vector3(sin(a), 0, cos(a))
		var e := _fighter(zone, cx + dir.x * 30.0, cz + dir.z * 30.0)
		_walk(zone, e, -dir, 260)
		heights.append(snappedf(e.pos.y - zone.height_at(e.pos.x, e.pos.z), 0.01))
		ok(e.pos.y > zone.height_at(e.pos.x, e.pos.z) + 1.4, "side %d: climbed onto the ring (y over the ground: %.2f m)" % [side, e.pos.y - zone.height_at(e.pos.x, e.pos.z)])
	# the ring's flank, away from the stairs, is a wall: you stop at its foot
	var e2 := _fighter(zone, cx + 14.0 + 0.0, cz + 30.0)
	_walk(zone, e2, Vector3(0, 0, -1), 260)
	ok(e2.pos.y < zone.height_at(e2.pos.x, e2.pos.z) + 0.7, "the side wall of the ring stops a fighter on foot (ended %.1f m up, z %.1f)" % [e2.pos.y - zone.height_at(e2.pos.x, e2.pos.z), e2.pos.z])
	# on top you can walk right across, and step off the edge down again
	var top := _fighter(zone, cx, cz)
	top.pos.y = zone.ground_at(cx, cz, 99.0)
	_walk(zone, top, Vector3(1, 0, 0), 200)
	ok(absf(float(top.pos.y) - zone.ground_at(top.pos.x, top.pos.z, top.pos.y)) < 0.05, "standing on the ring top after crossing it")
	# an NPC on the ring stands on it
	var f := zone.free_position({"x": cx + 3.0, "z": cz + 3.0})
	ok(f.y > zone.height_at(f.x, f.z) + 1.4, "a point on the ring is placed on its top (%.2f)" % f.y)
	root.free()

func test_the_cell_ring_can_be_climbed() -> void:
	var zone := RuleZone.new("cell_games")
	var root := WorldLandmarks.build(zone)
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "cellring":
			l = m
	if l.is_empty():
		root.free()
		return
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		var dir := Vector3(sin(a), 0, cos(a))
		var e := _fighter(zone, float(l.x) + dir.x * 45.0, float(l.z) + dir.z * 45.0)
		_walk(zone, e, -dir, 300)
		var rise: float = e.pos.y - zone.height_at(e.pos.x, e.pos.z)
		ok(rise > 0.9, "cell ring from side %d: climbed on (%.2f m up)" % [k, rise])
	root.free()

func test_nobody_walks_into_a_landmark() -> void:
	var group_types: Array = []
	for gr: Variant in WorldLandmarks._groups():
		group_types.append_array(gr.TYPES)
	var zones: Dictionary = RuleTables.table("zones")
	var checked := 0
	for zid: String in zones:
		var uses := false
		for l: Dictionary in zones[zid].get("landmarks", []):
			uses = uses or str(l.get("type", "")) in group_types
		if not uses or str(zones[zid].get("terrain", {}).get("planet", "")) != "":
			continue
		var zone := RuleZone.new(zid)
		var root := WorldLandmarks.build(zone)
		for g in root.get_children():
			if not g.has_meta("landmark"):
				continue
			var l: Dictionary = g.get_meta("landmark")
			var reach := 30.0 * float(l.get("scale", 1.0)) + float(l.get("flatten", l.get("collide", 10.0)))
			for k in 8:
				var a := k * PI / 4.0 + 0.2
				var dir := Vector3(sin(a), 0, cos(a))
				var e := _fighter(zone, float(l.x) + dir.x * reach, float(l.z) + dir.z * reach)
				var bad := ""
				if _buried(zone, e.pos) != "":
					continue   # the start itself is inside a bigger neighbour (arena slab, wall): not an approach
				for i in int(reach / 0.2):
					_walk(zone, e, -dir, 1, 0.2)
					bad = _buried(zone, e.pos)
					if bad != "":   # a concave corner can need a second push (the game resolves again next frame)
						_walk(zone, e, -dir, 1, 0.0)
						bad = _buried(zone, e.pos)
					if bad != "":
						break
				checked += 1
				ok(bad == "", "%s / %s from %d°: walking in ends %s" % [zid, l.type, k * 45, bad])
		root.free()
	ok(checked > 20, "walked into %d landmark approaches" % checked)
