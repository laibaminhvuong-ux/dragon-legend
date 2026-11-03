# Usage: godot --headless --path godot -s res://tools_bake_planets.gd   (minutes per planet)
extends SceneTree
# Bakes Earth's planet map: terrain grids (low/medium/high) and props into res://world/baked.
func _init() -> void:
	var e: RulePlanet = RulePlanet.new("earth")
	var t := Time.get_ticks_msec()
	var p: RefCounted = PropSetHolder.make(e)
	e.save_props(p, "res://world/baked/%s.props" % e.props_key())
	print("props ", (Time.get_ticks_msec() - t) / 1000.0, " s")
	for q in ["low", "medium", "high"]:
		t = Time.get_ticks_msec()
		var g := WorldTerrain.sample_grid(e, q)
		WorldTerrain.save_grid(g, "res://world/baked/%s.grid" % WorldTerrain.cache_key(e, q))
		print(q, " ", (Time.get_ticks_msec() - t) / 1000.0, " s")
	quit()
class PropSetHolder:
	static func make(e: RulePlanet) -> RefCounted:
		return RuleZone.PropSet.new(e)
