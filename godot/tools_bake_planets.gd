# Usage: godot --headless --path godot -s res://tools_bake_planets.gd [-- --only=earth,nameck]   (minutes per planet)
# Bakes each planet map's terrain grids (low/medium/high) and props into res://world/baked; up-to-date files are kept.
extends SceneTree

func _init() -> void:
	var only: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
	for pid: String in RuleTables.table("planets"):
		if not only.is_empty() and pid not in only:
			continue
		var e := RulePlanet.new(pid)
		var t := Time.get_ticks_msec()
		var props_path := "res://world/baked/%s.props" % e.props_key()
		if not FileAccess.file_exists(props_path):
			e.save_props(RuleZone.PropSet.new(e), props_path)
			print(pid, " props ", (Time.get_ticks_msec() - t) / 1000.0, " s")
		for q in ["low", "medium", "high"]:
			var path := "res://world/baked/%s.grid" % WorldTerrain.cache_key(e, q)
			if FileAccess.file_exists(path):
				continue
			t = Time.get_ticks_msec()
			WorldTerrain.save_grid(WorldTerrain.sample_grid(e, q), path)
			print(pid, " ", q, " ", (Time.get_ticks_msec() - t) / 1000.0, " s")
	quit()
