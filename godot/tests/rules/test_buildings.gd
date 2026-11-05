extends TestCase
# Solid and enterable buildings (user request, 2026-11-04; Claude's claimed rules files).

func _town() -> Dictionary:
	return {"type": "town", "style": "village", "seed": 23, "radius": 120.0, "x": 0.0, "z": 0.0, "rot": 0.0, "name": "Test Village"}

func _house(l: Dictionary) -> Dictionary:
	for b: Dictionary in RuleTown.layout(l).buildings:
		if b.kind == "house":
			return b
	return {}

func _walk(zone: RefCounted, from: Vector3, to: Vector3) -> Vector3:
	var e := {"pos": from, "vel": Vector3.ZERO, "flying": false, "onGround": true}
	for i in 200:
		var prev: Vector3 = e.pos
		e.pos = (e.pos as Vector3).move_toward(Vector3(to.x, from.y, to.z), 0.1)
		RuleCollision.resolve(e, zone, prev)
	return e.pos

class FlatZone extends RefCounted:
	var landmarks: Array
	var _p: RefCounted
	var def := {}
	func _init(ls: Array) -> void:
		landmarks = ls
	func height_at(_x: float, _z: float) -> float: return 0.0
	func normal_at(_x: float, _z: float) -> Vector3: return Vector3.UP
	func ceiling() -> float: return INF
	func props() -> RefCounted:
		if _p == null:
			var ps: RefCounted = RuleZone.PropSet.new(self, {"trees": [], "rocks": [], "bushes": [], "stones": []})
			_p = ps
		return _p

func test_house_walls_block_but_the_doorway_lets_you_in() -> void:
	var l := _town()
	var b := _house(l)
	ok(not b.is_empty(), "village has houses")
	var z := FlatZone.new([l])
	var r := float(b.rot)
	var at := func(lx: float, lz: float) -> Vector3: return Vector3(float(b.x) + lx * cos(r) + lz * sin(r), 0, float(b.z) - lx * sin(r) + lz * cos(r))
	# walking at the back wall from outside stops at the wall
	var stopped := _walk(z, at.call(0.0, -float(b.d) * 0.5 - 4.0), at.call(0.0, 0.0))
	ok(RuleTown.inside(l, stopped.x, stopped.z).is_empty(), "the back wall is solid")
	# walking through the doorway on the front ends up inside
	var entered := _walk(z, at.call(0.0, float(b.d) * 0.5 + 4.0), at.call(0.0, 0.0))
	ok(not RuleTown.inside(l, entered.x, entered.z).is_empty(), "the doorway lets you walk in")

func test_big_buildings_are_solid_and_have_doors() -> void:
	var l := {"type": "town", "style": "city", "seed": 11, "radius": 210.0, "x": 0.0, "z": 0.0, "rot": 0.0, "name": "Amber City"}
	var z := FlatZone.new([l])
	var tower: Dictionary = {}
	for b: Dictionary in RuleTown.layout(l).buildings:
		if b.kind in ["tower", "office"]:
			tower = b
			break
	var end := _walk(z, Vector3(float(tower.x) + 40.0, 0, float(tower.z)), Vector3(float(tower.x), 0, float(tower.z)))
	ok(Vector2(end.x - float(tower.x), end.z - float(tower.z)).length() > float(tower.w) * 0.3, "you can't walk into a tower")
	var doors := RuleTown.doors(l)
	ok(doors.size() > 0 and str(doors[0].interior).begins_with("interior_"), "towers have doors to an interior")

func test_enter_and_leave_round_trip() -> void:
	var g := RuleGame.new()
	var door := {"x": g.player.pos.x + 1.0, "z": g.player.pos.z, "yaw": 0.0, "interior": "interior_home", "name": "Farmhouse"}
	eq(g.enter_building(door), "interior_home", "enter goes to the interior map")
	var saved := g.to_save()
	eq(str(saved.zone), "interior_home", "saved inside")
	var inside := RuleGame.new(0, saved.duplicate(true))
	eq(inside.zone.id, "interior_home", "the interior map loads")
	ok(inside.zone.doors().any(func(d: Dictionary) -> bool: return d.get("exit", false)), "it has an exit")
	ok(not inside.zone.props().near(0.0, -float(RuleInterior.dims("home").d) * 0.5, 1.0).is_empty(), "its walls are solid")
	var back: Variant = inside.leave_building()
	eq(str(back), str(door.get("zone", g.current_region())) if door.has("zone") else g.current_region(), "leaving goes back to where you came from")
	var out := inside.to_save()
	ok(out.position != null and absf(float(out.position.z) - float(door.z) - 1.6) < 0.01, "outside the same door")
	var again := RuleGame.new(0, out.duplicate(true))
	ok(Vector2(again.player.pos.x - float(door.x), again.player.pos.z - (float(door.z) + 1.6)).length() < 0.05, "standing outside the door")

func test_countryside_hamlets() -> void:
	var p := RulePlanet.new("earth")
	var hs: Array = p.landmarks.filter(func(l: Dictionary) -> bool: return l.get("hamlet", false))
	ok(hs.size() >= 20, "Earth's countryside has hamlets (%d)" % hs.size())
	for h: Dictionary in hs:
		ok(p.region_at(float(h.x), float(h.z)) == "", "%s is out in the countryside" % h.name)
		ok(not RuleTown.layout(h).buildings.is_empty(), "%s has buildings" % h.name)
	var again: Array = RulePlanet.new("earth").landmarks.filter(func(l: Dictionary) -> bool: return l.get("hamlet", false))
	eq(again.map(func(l: Dictionary) -> String: return l.name), hs.map(func(l: Dictionary) -> String: return l.name), "the same every time")
	var props: RefCounted = p.props()
	for h: Dictionary in hs.slice(0, 5):
		ok(props.trees.filter(func(t: Dictionary) -> bool: return Vector2(float(t.x) - float(h.x), float(t.z) - float(h.z)).length() < float(h.radius) * 0.9).is_empty(), "no trees inside %s" % h.name)

func test_you_stand_on_roads_and_floors() -> void:
	var l := _town()
	var z := FlatZone.new([l])
	var lay := RuleTown.layout(l)
	var rd: Dictionary = lay.roads[0]
	var mid := Vector2(rd.x1, rd.z1).lerp(Vector2(rd.x2, rd.z2), 0.3)
	near(RuleTown.surface_at(z, l, mid.x, mid.y), RuleTown.ROAD_TOP, 1e-4, "a road's top is above the ground")
	var b := _house(l)
	near(RuleTown.surface_at(z, l, float(b.x), float(b.z)), RuleTown.FLOOR_TOP, 1e-4, "inside a house you stand on its floor")
	eq(RuleTown.surface_at(z, l, 500.0, 500.0), -INF, "open ground: just the terrain")
	var g := RuleGame.new()
	var land: RefCounted = g.zone
	var t: Dictionary = {}
	for m: Dictionary in land.landmarks:
		if m.get("type") == "town":
			t = m
			break
	var r0: Dictionary = RuleTown.layout(t).roads[0]
	var p := Vector2(r0.x1, r0.z1).lerp(Vector2(r0.x2, r0.z2), 0.5)
	var rr := float(t.get("rot", 0.0))
	var wx := float(t.x) + p.x * cos(rr) + p.y * sin(rr); var wz := float(t.z) - p.x * sin(rr) + p.y * cos(rr)
	g.player.pos = Vector3(wx, land.height_at(wx, wz) + 1.0, wz)
	for i in 60:
		g.update(1.0 / 60.0, RuleGame.empty_intents())
	ok(float(g.player.pos.y) > land.height_at(wx, wz) + 0.05, "the player stands on the road, not in it")
