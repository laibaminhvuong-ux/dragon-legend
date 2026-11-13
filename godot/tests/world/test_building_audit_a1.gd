extends TestCase
# Building audit (2026-11-12, agent 1 zones): regressions for the bugs found there.

func _walk(zone: RuleZone, e: Dictionary, dir: Vector3, steps: int, speed := 0.15) -> void:
	for i in steps:
		var prev: Vector3 = e.pos
		var p: Vector3 = e.pos + dir * speed
		p.y = zone.ground_at(p.x, p.z, prev.y)
		e.pos = p
		RuleCollision.resolve(e, zone, prev)

func _fighter(zone: RuleZone, x: float, z: float) -> Dictionary:
	return {"pos": Vector3(x, zone.height_at(x, z), z), "vel": Vector3.ZERO, "flying": false, "onGround": true}

## The pilot's landing pad keeps the town's flattened ground (it dug a pit into island towns: harbor_town -12 m).
func test_travel_pads_do_not_dig_into_towns() -> void:
	var zones: Dictionary = RuleTables.table("zones")
	for zid: String in zones:
		var z := RuleZone.new(zid)
		if z.travel_point == null:
			continue
		var tp: Dictionary = z.travel_point
		var keep: Variant = z.travel_point
		z.travel_point = null
		var without := z.height_at(tp.x, tp.z)
		z.travel_point = keep
		ok(absf(z.height_at(tp.x, tp.z) - without) < 0.05, "%s: the pad sits on the ground there (%.2f vs %.2f)" % [zid, z.height_at(tp.x, tp.z), without])
		if z.water is Dictionary and z.water.get("ocean", false):
			ok(float(tp.y) > float(z.water.level) + 0.5, "%s: the pad is above the sea (%.2f)" % [zid, tp.y])

## Pilav's palace: the grand stair (0.57 m risers) is walked up to the terrace, the tier walls still stop you.
func test_pilav_stair_climbs_to_the_terrace() -> void:
	var zone := RulePlanet.open("pilav_castle")
	var root := WorldLandmarks.build(zone)
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "pilavpalace":
			l = m
	ok(not l.is_empty(), "pilav_castle has the palace")
	if l.is_empty():
		root.free()
		return
	var front := Vector3(sin(float(l.rot)), 0, cos(float(l.rot)))   # local +z: the stair side
	var e := _fighter(zone, float(l.x) + front.x * 52.0, float(l.z) + front.z * 52.0)
	_walk(zone, e, -front, 400)
	ok(e.pos.y - float(l.base) > 16.5, "walked up the stair onto the terrace (%.2f m up)" % (e.pos.y - float(l.base)))
	var side := _fighter(zone, float(l.x) + front.x * 52.0 + front.z * 20.0, float(l.z) + front.z * 52.0 - front.x * 20.0)
	_walk(zone, side, -front, 400)
	ok(side.pos.y - float(l.base) < 0.7, "beside the stair the terrace wall stops you (%.2f m up)" % (side.pos.y - float(l.base)))
	root.free()

## Babido's ship mound: walked up to the hatch collar (it was one solid 24 m circle: an invisible wall at its rim).
func test_babidi_mound_is_walked_up() -> void:
	var zone := RulePlanet.open("babidi_ship")
	var root := WorldLandmarks.build(zone)
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "babidihatch":
			l = m
	if l.is_empty():
		root.free()
		return
	for k in 4:
		var d := Vector3(sin(k * PI * 0.5 + 0.3), 0, cos(k * PI * 0.5 + 0.3))
		var e := _fighter(zone, float(l.x) + d.x * 34.0, float(l.z) + d.z * 34.0)
		_walk(zone, e, -d, 300)
		var r := Vector2(e.pos.x - float(l.x), e.pos.z - float(l.z)).length()
		ok(r < 9.0 and e.pos.y - float(l.base) > 2.3, "side %d: up the mound to the hatch (r %.1f, %.2f m up)" % [k, r, e.pos.y - float(l.base)])
	root.free()

## The Grand Elder's house fits its pillar top and he stands outside it, on the pillar.
func test_elder_house_fits_the_pillar() -> void:
	var zone := RulePlanet.open("namek")
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "elderspire":
			l = m
	var s := float(l.get("houseScale", 2.5))
	for p: Vector2 in [Vector2(0, 4.7), Vector2(0, -4.7), Vector2(3.4, 0), Vector2(-3.4, 0)]:   # the dome's rim (3.6 x 4.86 m local)
		var h := zone.height_at(float(l.x) + p.x * s, float(l.z) + p.y * s)
		ok(absf(h - float(l.base)) < 1.2, "the house rim at %s stands on the pillar top (%.1f vs %.1f)" % [p * s, h, l.base])
	for n: Dictionary in RuleTables.table("npcs"):
		if n.id == "guru":
			var pos := zone.free_position(zone.place_in("namek", float(n.x), float(n.z)))
			ok(pos.y > float(l.base) - 1.0, "the Grand Elder is up on the pillar (%.1f)" % pos.y)
			ok(Vector2(pos.x - float(l.x), pos.z - float(l.z)).length() > 3.6 * s * 1.3, "and outside his house")

## Nobody of these maps stands in the sea.
func test_npcs_are_on_dry_land() -> void:
	for zid: String in ["kame_island", "namek"]:
		var zone := RulePlanet.open(zid)
		for n: Dictionary in RuleTables.table("npcs"):
			if str(n.get("zone", "")) != zid or n.get("y") != null:
				continue
			var p: Dictionary = zone.place_in(zid, float(n.x), float(n.z))
			ok(zone.height_at(p.x, p.z) > 0.5, "%s / %s stands on land (%.1f)" % [zid, n.id, zone.height_at(p.x, p.z)])
