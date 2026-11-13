extends TestCase
# World leftovers (task 4, 2026-11-13): tall stand-on platforms get stairs or are walls on purpose, Beeros's temple
# door tier has stairs, the Capsule / Ginger dome houses can be entered, the dome windows are curved, no grass on
# Grandpa Gohin's stepping stones, no invisible walls in front of landmark doors, quest points reachable.

const RISER := 0.6   # a proper stair riser

func _walk(zone: RuleZone, e: Dictionary, dir: Vector3, steps: int, speed := 0.15) -> float:
	var best := INF
	for i in steps:
		var prev: Vector3 = e.pos
		var p: Vector3 = e.pos + dir * speed
		p.y = zone.ground_at(p.x, p.z, prev.y)
		e.pos = p
		RuleCollision.resolve(e, zone, prev)
		if e.has("target"):
			best = minf(best, Vector2(e.pos.x - float(e.target.x), e.pos.z - float(e.target.z)).length())
	return best

func _fighter(zone: RuleZone, x: float, z: float) -> Dictionary:
	return {"pos": Vector3(x, zone.ground_at(x, z, zone.height_at(x, z)), z), "vel": Vector3.ZERO, "flying": false, "onGround": true}

func _landmark(zone: RuleZone, type: String) -> Dictionary:
	for m: Dictionary in zone.landmarks:
		if str(m.type) == type:
			return m
	return {}

func _node(root: Node3D, type: String) -> Node3D:
	for g in root.get_children():
		if g.has_meta("landmark") and str(g.get_meta("landmark").type) == type:
			return g
	return null

# ------------------------------------------------------------------------------- surface reachability (as tools audit)
func _surfaces(zone: RuleZone) -> Array:
	var seen := {}
	var out: Array = []
	for key: Vector2i in zone._surface_grid:
		for s: Dictionary in zone._surface_grid[key]:
			var k := "%.3f,%.3f,%.3f" % [float(s.x), float(s.z), float(s.top)]
			if not seen.has(k):
				seen[k] = true
				out.append(s)
	return out

func _ring(s: Dictionary) -> Array:
	var pts: Array = []
	if s.has("radius"):
		var r := float(s.radius) + 0.3
		var n := maxi(12, int(TAU * r))
		for i in n:
			pts.append(Vector2(float(s.x) + sin(TAU * i / n) * r, float(s.z) + cos(TAU * i / n) * r))
		return pts
	var rr := float(s.rot)
	var ax := Vector2(cos(rr), -sin(rr)); var az := Vector2(sin(rr), cos(rr))
	var c := Vector2(float(s.x), float(s.z))
	for side in 4:
		var along: Vector2 = ax if side < 2 else az
		var across: Vector2 = az if side < 2 else ax
		var ha: float = (float(s.hw) if side < 2 else float(s.hd)) + 0.3
		var hc: float = (float(s.hd) if side < 2 else float(s.hw)) + 0.3
		var sg := 1.0 if side % 2 == 0 else -1.0
		var n := maxi(2, int(ha * 2.0))
		for i in n + 1:
			pts.append(c + along * (-ha + 2.0 * ha * i / n) + across * hc * sg)
	return pts

## Indices of the surfaces a fighter can reach from the ground by steps of at most `riser`.
func _reachable(zone: RuleZone, list: Array, riser: float) -> Dictionary:
	var got := {}
	var changed := true
	while changed:
		changed = false
		for i in list.size():
			if got.has(i):
				continue
			var s: Dictionary = list[i]
			for p: Vector2 in _ring(s):
				var bases: Array = []
				var h := zone.height_at(p.x, p.y)
				var blocked := false
				for c: Dictionary in zone.props().near(p.x, p.y, 0.1):
					if float(c.top) > h + 0.6 and LandmarkCollision.depth(c, p.x, p.y) > 0.0:
						blocked = true
				if not blocked:
					bases.append(h)
				for j: int in got:
					if LandmarkCollision.depth(list[j], p.x, p.y) > -0.05:
						bases.append(float(list[j].top))
				if bases.any(func(b: float) -> bool: return float(s.top) - b <= riser):
					got[i] = true
					changed = true
					break
	return got

func _size(s: Dictionary) -> float:
	return float(s.radius) * 2.0 if s.has("radius") else maxf(float(s.hw), float(s.hd)) * 2.0

# ------------------------------------------------------------------------------------------------------------ tests
## Every stand-on surface wider than 6 m can be walked onto (the game climbs SURFACE_STEP); the ones task 4 gave stairs
## take proper 0.6 m risers.
func test_wide_platforms_can_be_walked_onto() -> void:
	for zid: String in ["west_city", "beerus_planet", "future_earth", "nameless_planet", "snake_way", "cell_games", "tournament_island"]:
		var zone := RuleZone.new(zid)
		var root := WorldLandmarks.build(zone)
		var list := _surfaces(zone)
		var game := _reachable(zone, list, RuleZone.SURFACE_STEP)
		var stairs := _reachable(zone, list, RISER)
		for i in list.size():
			var s: Dictionary = list[i]
			if _size(s) <= 6.0:
				continue
			var over: float = float(s.top) - zone.height_at(float(s.x), float(s.z))
			ok(game.has(i), "%s: the %.0f m platform at (%.0f, %.0f), %.2f m up, can be walked onto" % [zid, _size(s), float(s.x), float(s.z), over])
			if over > RuleZone.SURFACE_STEP:
				ok(stairs.has(i), "%s: the %.2f m tall platform at (%.0f, %.0f) has stairs (risers <= %.1f m)" % [zid, over, float(s.x), float(s.z), RISER])
		root.free()

## Beeros's temple: up the front stairs to the 2 m terrace and on up to the door on the 4 m tier.
func test_beeros_temple_door_tier_has_stairs() -> void:
	var zone := RuleZone.new("beerus_planet")
	var root := WorldLandmarks.build(zone)
	var g := _node(root, "beeruscastle")
	ok(g != null, "the temple is built")
	if g == null:
		root.free()
		return
	var e := _fighter(zone, g.position.x, g.position.z + 30.0)
	_walk(zone, e, Vector3(0, 0, -1), 200)
	ok(absf(e.pos.y - (g.position.y + 4.0)) < 0.1, "walked up to the 4 m tier (%.2f m up)" % (e.pos.y - g.position.y))
	ok(e.pos.z - g.position.z < 10.0, "and on to the door at the tower's foot (its gold base ring is at 9.25 m) (z %.1f from the centre)" % (e.pos.z - g.position.z))
	root.free()

## King Yemmo's dais (1.55 m) has steps on its right side.
func test_check_in_dais_has_steps() -> void:
	var zone := RuleZone.new("snake_way")
	var root := WorldLandmarks.build(zone)
	var g := _node(root, "checkinhall")
	var e := _fighter(zone, g.position.x + 14.0, g.position.z + 10.5)
	_walk(zone, e, Vector3(-1, 0, 0), 100)
	ok(e.pos.y > g.position.y + 1.4, "walked up onto the dais (%.2f m up)" % (e.pos.y - g.position.y))
	root.free()

## The Capsule dome homes: a door each (interior_home), reached by walking straight at it; the drum is a wall.
func test_capsule_homes_can_be_entered() -> void:
	var zone := RuleZone.new("west_city")
	var root := WorldLandmarks.build(zone)
	var doors := zone.doors().filter(func(d: Dictionary) -> bool: return str(d.name) == "Dome home")
	eq(doors.size(), 6, "six Dome home doors")
	for d: Dictionary in doors:
		eq(str(d.interior), "interior_home", "a dome home opens to a home interior")
	for l: Dictionary in zone.landmarks:
		if str(l.type) == "capsulehouse":
			var top := zone.surface_top(float(l.x), float(l.z) + 3.0)
			ok(top == -INF, "no stand-on ledge on the house at (%.0f, %.0f)" % [float(l.x), float(l.z)])
			ok(not zone.props().near(float(l.x), float(l.z), 0.1).is_empty(), "the house is solid")
	root.free()

## Every landmark door (LANDMARK_INTERIORS) can be walked up to: no invisible wall short of DOOR_RANGE, and walking on
## stops at the building.
func test_landmark_doors_have_no_invisible_wall() -> void:
	var checked := 0
	for zid: String in RuleTables.table("zones"):
		var uses := false
		for l: Dictionary in RuleTables.table("zones")[zid].get("landmarks", []):
			uses = uses or RuleZone.LANDMARK_INTERIORS.has(str(l.get("type", "")))
		if not uses:
			continue
		var zone := RuleZone.new(zid)
		var root := WorldLandmarks.build(zone)
		var town_doors := {}
		for l: Dictionary in zone.landmarks:
			if str(l.type) == "town":
				for td: Dictionary in RuleTown.doors(l):
					town_doors["%.2f,%.2f" % [float(td.x), float(td.z)]] = true
		for d: Dictionary in zone.doors():
			if d.get("exit", false) or town_doors.has("%.2f,%.2f" % [float(d.x), float(d.z)]):
				continue
			var out := Vector3(sin(float(d.yaw)), 0, cos(float(d.yaw)))
			var e := _fighter(zone, float(d.x) + out.x * 5.0, float(d.z) + out.z * 5.0)
			e.target = d
			var best := _walk(zone, e, -out, 70)
			checked += 1
			ok(best < RuleStory.DOOR_RANGE, "%s / %s: walking at the door gets within %.1f m of it (best %.2f m)" % [zid, d.name, RuleStory.DOOR_RANGE, best])
		root.free()
	ok(checked >= 10, "walked up to %d landmark doors" % checked)

## Quest spots, pickups and NPCs on a landmark's stand-on surface are on one you can walk onto.
func test_quest_points_on_platforms_are_reachable() -> void:
	var checked := 0
	for zid: String in RuleTables.table("zones"):
		if RuleTables.table("zones")[zid].get("landmarks", []).is_empty():
			continue
		var zone := RuleZone.new(zid)
		var root := WorldLandmarks.build(zone)
		var list := _surfaces(zone)
		var game: Variant = null
		for pt: Dictionary in LandmarkCollision.protected_points(zone):
			var p: Vector3 = pt.p
			if str(pt.kind) not in ["quest", "pickup", "npc"] or not is_nan(p.y):
				continue
			var top := zone.surface_top(p.x, p.z)
			if top - zone.height_at(p.x, p.z) < RuleZone.SURFACE_STEP:
				continue
			if game == null:
				game = _reachable(zone, list, RuleZone.SURFACE_STEP)
			var on := -1
			for i in list.size():
				if is_equal_approx(float(list[i].top), top) and LandmarkCollision.depth(list[i], p.x, p.z) > -0.05:
					on = i
			checked += 1
			ok(on >= 0 and (game as Dictionary).has(on), "%s: %s point (%.0f, %.0f) on a %.1f m platform you can walk onto" % [zid, pt.kind, p.x, p.z, top - zone.height_at(p.x, p.z)])
		root.free()
	ok(true, "checked %d raised points" % checked)

## The dome band windows lie on the squashed dome (they were flat 22 cm boxes standing off the curve).
func test_dome_windows_follow_the_dome() -> void:
	var g := Node3D.new()
	var b := LandmarksEarth.E.new(g, null, {"x": 0.0, "z": 0.0})
	var r := 6.0; var s := 0.8; var y0 := 1.6
	var mi := b.dome_panel(r, s, y0, 0.25, 0.7, 2.5, 0.8, StandardMaterial3D.new())
	var worst := 0.0
	for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		# distance off the ellipsoid x^2 + z^2 + ((y - y0) / s)^2 = r^2, roughly in metres
		var q := Vector3(v.x, (v.y - y0) / s, v.z)
		worst = maxf(worst, absf(q.length() - r))
	ok(worst < 0.08, "panel vertices within 8 cm of the dome (worst %.3f m)" % worst)
	ok(mi.has_meta("no_collision"), "the pane is not a collider")
	g.free()

## No grass on Grandpa Gohin's stepping stones.
func test_no_grass_on_the_hut_stepping_stones() -> void:
	var zone := RuleZone.new("mt_paozu")
	var l := _landmark(zone, "paozucabin")
	ok(not l.is_empty(), "the hut is on the map")
	var bare := WorldGrass.bare_spots(l)
	eq(bare.size(), 6, "six bare spots")
	var rot := float(l.get("rot", 0.0))
	for i in 6:   # the builder's stones: local (0, 5 + 1.6 i), r 0.7
		var lz := 5.0 + i * 1.6
		var w := Vector2(float(l.x) + lz * sin(rot), float(l.z) + lz * cos(rot))
		for k in 8:
			var p := w + Vector2(sin(k * PI / 4.0), cos(k * PI / 4.0)) * 0.7
			ok(WorldGrass._bare_at(bare, p.x, p.y), "stone %d edge %d is bare" % [i, k])
