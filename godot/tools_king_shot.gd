extends Node3D
# Dev: King Yemmo seated in the check-in hall. godot --path godot res://tools_king_shot.tscn -- --shot=C:/x.png --cam=x,y,z --look=x,y,z
func _ready() -> void:
	var args := {"shot": "", "cam": "6,5,-4", "look": "0,5,10"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.6, 0.7, 0.9)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-50, 30, 0); add_child(sun)
	var zone := RuleZone.new("snake_way")
	var l: Dictionary = {}
	for m: Dictionary in zone.landmarks:
		if str(m.type) == "checkinhall":
			l = m.duplicate()
	var king: Dictionary = {}
	for n: Dictionary in RuleTables.table("npcs"):
		if n.id == "king_yemma":
			king = n
	var c: Dictionary = RuleTables.table("characters")[king.who]
	l.x = 0.0; l.z = 0.0
	var g := WorldLandmarks.build_one(zone, l)
	add_child(g)
	var lk: Dictionary = (c.look as Dictionary).duplicate(); lk.faceSeed = "king_yemma"
	var model := Fighter.create(lk)
	model.scale = Vector3.ONE * float(c.scale)
	model.position = Vector3(0, float(king.y), 8.5)
	model.rotation.y = float(king.rot)
	add_child(model)
	model.call("update", 0.1, {"sitting": true})
	var cam := Camera3D.new(); cam.fov = 60; cam.far = 500; add_child(cam)
	var p: PackedStringArray = str(args.cam).split(",")
	cam.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var q: PackedStringArray = str(args.look).split(",")
	cam.look_at(Vector3(float(q[0]), float(q[1]), float(q[2])))
	cam.make_current()
	for i in 40:
		model.call("update", 0.05, {"sitting": true})
		await get_tree().process_frame
	if args.shot != "":
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
