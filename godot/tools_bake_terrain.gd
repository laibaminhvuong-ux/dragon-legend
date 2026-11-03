extends SceneTree
# Bakes every world's terrain grid (medium + high) into res://world/baked/ so worlds load fast on first visit.
#   godot --headless --path godot -s res://tools_bake_terrain.gd [-- zone_id ...]
func _init() -> void:
	var T: GDScript = load("res://world/terrain.gd")
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = JSON.parse_string(FileAccess.get_file_as_string("res://data/zones.json")).keys()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(T.BAKED_DIR))
	for f in DirAccess.get_files_at(T.BAKED_DIR):
		if f.ends_with(".grid"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(T.BAKED_DIR.path_join(f)))
	for id: String in ids:
		if id == "test":
			continue
		var zone: RefCounted = load("res://rules/zone.gd").new(id)
		for q in ["medium", "high"]:
			var t := Time.get_ticks_msec()
			var g: Dictionary = T.sample_grid(zone, q)
			T.save_grid(g, "%s/%s.grid" % [T.BAKED_DIR, g.key])
			print("%s %s %d ms" % [id, q, Time.get_ticks_msec() - t])
	quit()
