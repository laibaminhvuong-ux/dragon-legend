# Dev: plays Codex's animation showcase and saves a screenshot mid-way through each of its 8 stages.
#   godot --path godot -s res://tools_showcase_shots.gd -- --out=C:/path/prefix
extends SceneTree

func _initialize() -> void:
	var out := "user://showcase"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var scene: Node = load("res://scenes/animation_showcase.tscn").instantiate()
	root.add_child(scene)
	_run(out)

func _run(out: String) -> void:
	var frames := 0
	var t0 := Time.get_ticks_msec()
	for stage in 8:
		await create_timer(2.2 if stage == 0 else 4.0).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [out, stage + 1])
		print("stage %d fps %d" % [stage + 1, Engine.get_frames_per_second()])
	quit()
