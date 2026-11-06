# Dev: bakes the Universal Base Characters bodies (art/quaternius/ubc_bodies, outside the game folder) into small
# game files for HeroBody: <kind>.res (mesh + skin weights) and <kind>.json (joints, skin bind bones).
#   godot --headless --path godot -s res://tools_bake_bodies.gd
extends SceneTree

func _initialize() -> void:
	var src := ProjectSettings.globalize_path("res://").path_join("../art/quaternius/ubc_bodies/")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HeroBody.DIR))
	for kind: String in HeroBody.KINDS:
		var d := HeroBody.extract(src + HeroBody.SOURCES[kind])
		ResourceSaver.save(d.mesh, HeroBody.DIR + kind + ".res")
		var f := FileAccess.open(HeroBody.DIR + kind + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify({"joints": d.joints, "binds": d.binds, "eyes": d.eyes}))
		f.close()
		print("baked ", kind)
	quit()
