extends TestCase
# Water sits exactly at the rules' water level; worlds without water get none.

func test_kame_island_water_level() -> void:
	var zone: RefCounted = load("res://rules/zone.gd").new("kame_island")
	var w: Node3D = load("res://world/water.gd").build(zone)
	ok(w != null, "Kama House has water")
	near(w.position.y, float(zone.water.level), 1e-6, "water level")
	w.free()

func test_no_water_world() -> void:
	var zone: RefCounted = load("res://rules/zone.gd").new("htc")
	eq(load("res://world/water.gd").build(zone), null, "the Time Room has no water")
