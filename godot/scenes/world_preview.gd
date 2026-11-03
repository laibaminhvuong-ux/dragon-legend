extends Node3D
# World preview: builds one world and shows it with a camera, for checking every world on the real GPU.
#   godot --path godot res://scenes/world_preview.tscn -- --zone=namek [--quality=high] [--shot=C:/x.png] [--cam=x,y,z,yaw,pitch]
# With --shot it waits for the scene to settle, prints "fps <n> build <s>", saves the screenshot and quits.

func _ready() -> void:
	var args := {"zone": "earth_plains", "quality": "high", "shot": "", "cam": "", "focus": "", "off": ""}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var t0 := Time.get_ticks_msec()
	var world: Node3D = load("res://world/world_view.gd").build(args.zone, args.quality)
	add_child(world)
	# --off=grass,props,landmarks,ssao,shadows,fog : switch parts off to measure what they cost
	for part in String(args.off).split(",", false):
		match part:
			"grass", "props", "landmarks":
				for c in world.find_children("*", "", false, false):
					if c.name.to_lower().begins_with(part.substr(0, 4)):
						c.queue_free()
			"ssao", "fog", "shadows":
				var we: WorldEnvironment = world.find_children("*", "WorldEnvironment", true, false)[0]
				if part == "ssao": we.environment.ssao_enabled = false; we.environment.ssil_enabled = false
				if part == "fog": we.environment.volumetric_fog_enabled = false
				if part == "shadows":
					for sun in world.find_children("*", "DirectionalLight3D", true, false): sun.shadow_enabled = false
	var build_s := (Time.get_ticks_msec() - t0) / 1000.0
	var zone: RefCounted = world.get_meta("zone")
	var cam := Camera3D.new()
	cam.fov = 70
	cam.far = 4000
	add_child(cam)
	if args.focus != "" and int(args.focus) < zone.landmarks.size():
		var l: Dictionary = zone.landmarks[int(args.focus)]
		var r := 22.0 * float(l.get("scale", 1.0)) + 18.0
		var ly: float = zone.height_at(l.x, l.z)
		cam.position = Vector3(float(l.x) + r * 0.7, ly + r * 0.45, float(l.z) + r * 0.7)
		cam.look_at(Vector3(l.x, ly + 4.0, l.z))
	elif args.cam != "":
		var c: PackedStringArray = args.cam.split(",")
		cam.position = Vector3(float(c[0]), float(c[1]), float(c[2]))
		cam.rotation = Vector3(deg_to_rad(float(c[4])), deg_to_rad(float(c[3])), 0)
	else:
		var s: Dictionary = zone.spawn
		var y: float = zone.height_at(s.x, s.z)
		cam.position = Vector3(s.x, y + 6.0, s.z - 14.0)
		cam.look_at(Vector3(s.x, y + 2.0, s.z + 30.0))
	cam.make_current()
	var grass: Node = world.get_meta("grass") if world.has_meta("grass") else null
	if grass != null:
		grass.target = cam
		grass.update_around(cam.global_position)
		print("grass clumps %d" % grass.instance_count())
	if args.shot != "":
		await get_tree().create_timer(4.0).timeout
		print("fps %d build %.1f" % [Engine.get_frames_per_second(), build_s])
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
