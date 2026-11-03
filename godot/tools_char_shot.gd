extends Node3D
# Character preview: loads the mannequin, plays an animation, saves a screenshot.
#   godot --path godot res://tools_char_shot.tscn -- --anim=Idle_Loop --shot=C:/x.png
func _ready() -> void:
	var args := {"anim": "Idle", "shot": "", "t": "0.6", "cam": "0,1.3,5.6", "look": "0,0.95,0"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.35, 0.45, 0.6)
	env.environment.ambient_light_color = Color(0.6, 0.65, 0.7); env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); sun.shadow_enabled = true; add_child(sun)
	var looks: Array = [
		{"race": "Saiyan", "outfit": "TurtleGi", "build": "Muscular", "hair": "Spiky"},
		{"race": "Saiyan", "outfit": "SaiyanArmor", "build": "Average", "hair": "Swept"},
		{"race": "Namekian", "outfit": "NamekRobe", "build": "Tall", "outfitTint": 2},
		{"race": "Human", "outfit": "CapsuleCorp", "build": "Slim", "outfitTint": 4},
		{"race": "FrostDemon", "outfit": "FrostArmor", "build": "Short"},
		{"race": "Majin", "outfit": "MajinVest", "build": "Muscular"},
	]
	var scene: Node3D = Node3D.new()
	add_child(scene)
	var aps: Array = []
	for i in looks.size():
		var f: Node3D = load("res://characters/fighter.gd").create(looks[i])
		f.position = Vector3((i - 2.5) * 1.1, 0, 0)
		scene.add_child(f)
		aps.append(f.anim_player)
	var ap: AnimationPlayer = aps[0]
	for p: AnimationPlayer in aps:
		p.play(args.anim)
		p.seek(float(args.t), true)
		p.pause()
	var aabb := AABB()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge(mi.global_transform * mi.get_aabb())
	print("aabb ", aabb)
	var cp: PackedFloat64Array = str(args.cam).split_floats(","); var lp: PackedFloat64Array = str(args.look).split_floats(",")
	var cam := Camera3D.new(); cam.position = Vector3(cp[0], cp[1], cp[2]); add_child(cam); cam.look_at(Vector3(lp[0], lp[1], lp[2])); cam.make_current()
	if args.shot != "":
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
