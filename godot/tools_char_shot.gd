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
	var sets := {
		"base": [
			{"race": "Saiyan", "outfit": "TurtleGi", "build": "Muscular", "hair": "Spiky", "face": "Determined"},
			{"race": "Saiyan", "outfit": "SaiyanArmor", "build": "Average", "hair": "Swept", "face": "Fierce"},
			{"race": "Namekian", "outfit": "NamekRobe", "build": "Tall", "outfitTint": 2, "face": "Calm"},
			{"race": "Human", "outfit": "CapsuleCorp", "build": "Slim", "outfitTint": 4, "hair": "Bowl", "hairColor": 2, "face": "Smirk"},
			{"race": "FrostDemon", "outfit": "FrostArmor", "build": "Short", "face": "Cold"},
			{"race": "Majin", "outfit": "MajinVest", "build": "Muscular", "face": "Smirk"},
		],
		"hair": [
			{"race": "Human", "hair": "Spiky"}, {"race": "Human", "hair": "Wild"}, {"race": "Human", "hair": "Swept"},
			{"race": "Human", "hair": "LongSpiky"}, {"race": "Human", "hair": "Short", "hairColor": 1}, {"race": "Human", "hair": "Ponytail", "hairColor": 2, "female": true},
		],
		"faces": [
			{"race": "Human", "hair": "Short", "face": "Calm"}, {"race": "Human", "hair": "Short", "face": "Fierce"}, {"race": "Human", "hair": "Short", "face": "Smirk"},
			{"race": "Human", "hair": "Short", "face": "Determined"}, {"race": "Human", "hair": "Short", "face": "Cold"}, {"race": "Namekian", "face": "Fierce"},
		],
	}
	sets["outfits"] = []
	for o: String in Outfits.ALL:
		sets.outfits.append({"race": "Human", "hair": "Short", "outfit": o, "outfitTint": Outfits.ALL.find(o) % 7})
	sets["raceforms"] = []
	for rf: Array in [["Namekian", ""], ["Namekian", "NamekFusion"], ["Namekian", "Giant"], ["FrostDemon", ""], ["FrostDemon", "FinalForm"], ["FrostDemon", "Golden"], ["FrostDemon", "Black"],
			["Majin", ""], ["Majin", "SuperMajin"], ["Majin", "KidForm"], ["Majin", "PureMajin"], ["Human", "PotentialUnleashed"], ["Saiyan", "SSJGod"], ["Saiyan", "UIPerfected"]]:
		sets.raceforms.append({"race": rf[0], "hair": "Spiky", "outfit": "TurtleGi", "face": "Fierce", "form": rf[1]})
	var looks: Array = sets.get(args.get("set", "base"), sets.base)
	var states: PackedStringArray = str(args.get("states", "")).split(",", false)
	var STATE := {
		"idle": {}, "run": {"speed": 6.0}, "sprint": {"speed": 11.0}, "hover": {"flying": true, "onGround": false},
		"flyfast": {"flying": true, "onGround": false, "speed": 14.0}, "climb": {"flying": true, "onGround": false, "speed": 3.0, "vy": 10.0},
		"dive": {"flying": true, "onGround": false, "speed": 3.0, "vy": -10.0}, "charge": {"charging": true}, "block": {"blocking": true},
		"dash": {"dashing": true, "speed": 8.0}, "jump": {"onGround": false, "vy": 4.0}, "talk": {"talking": true}, "sit": {"sitting": true}, "dead": {"dead": true},
		"jab": {"attackSerial": 1, "attackKind": "jab", "_t": 0.25}, "cross": {"attackSerial": 1, "attackKind": "cross", "_t": 0.35},
		"kick": {"attackSerial": 1, "attackKind": "leg kick", "_t": 0.2}, "ki": {"attackSerial": 1, "attackKind": "ki", "_t": 0.25},
	}
	if not states.is_empty():
		looks = []
		for st in states:
			looks.append({"race": "Saiyan", "hair": "Spiky", "outfit": "TurtleGi", "face": "Fierce", "state": st})
	var crowd := int(args.get("crowd", "0"))
	if crowd > 0:
		looks = []
		var races := ["Saiyan", "Human", "Namekian", "FrostDemon", "Majin", "HalfSaiyan"]
		var hairs := ["Spiky", "Wild", "Swept", "Short", "Bowl", "Ponytail"]
		for i in crowd:
			looks.append({"race": races[i % 6], "hair": hairs[(i * 5) % 6], "outfit": Outfits.ALL[(i * 7) % Outfits.ALL.size()], "outfitTint": i % 7, "skin": i % 3, "face": ["Calm", "Fierce", "Smirk"][i % 3]})
	var forms: PackedStringArray = str(args.get("forms", "")).split(",", false)
	if not forms.is_empty():
		looks = []
		for fm in forms:
			looks.append({"race": args.get("race", "Saiyan"), "hair": args.get("hair", "Spiky"), "outfit": "TurtleGi", "face": "Fierce", "form": fm})
	var scene: Node3D = Node3D.new()
	add_child(scene)
	var aps: Array = []
	for i in looks.size():
		var f: Node3D = load("res://characters/fighter.gd").create(looks[i])
		if looks[i].get("form", "") != "": f.set_form(looks[i].form)
		var cols := 7 if looks.size() > 6 else looks.size()
		f.position = Vector3((i % cols - (cols - 1) / 2.0) * 1.1, 0, -int(i / cols) * 1.9) if crowd == 0 else Vector3((i % 5 - 2) * 1.6, 0, -int(i / 5) * 1.8)
		scene.add_child(f)
		aps.append(f.anim_player)
	var fighters := scene.get_children()
	print("built ", fighters.size(), " at ", Time.get_ticks_msec())
	for i in fighters.size():
		var st: Dictionary = STATE.get(looks[i].get("state", "idle"), {})
		var settle := 1.5
		for k in int(settle * 60):
			fighters[i].update(1.0 / 60.0, {})
		var run_t := float(st.get("_t", 1.5))
		var a := st.duplicate(); a.erase("_t")
		for k in int(run_t * 60):
			fighters[i].update(1.0 / 60.0, a)
	var aabb := AABB()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge(mi.global_transform * mi.get_aabb())
	print("aabb ", aabb)
	var cp: PackedFloat64Array = str(args.cam).split_floats(","); var lp: PackedFloat64Array = str(args.look).split_floats(",")
	var cam := Camera3D.new(); cam.position = Vector3(cp[0], cp[1], cp[2]); add_child(cam); cam.look_at(Vector3(lp[0], lp[1], lp[2])); cam.make_current()
	print("settled at ", Time.get_ticks_msec())
	if crowd > 0:
		var frames := 0
		var t0 := Time.get_ticks_msec()
		var crowd_states := [{"speed": 6.0}, {"flying": true, "onGround": false, "speed": 12.0}, {"charging": true}, {}, {"speed": 2.0, "talking": true}]
		while Time.get_ticks_msec() - t0 < 4000:
			var dt := get_process_delta_time()
			for i in fighters.size():
				fighters[i].update(dt, crowd_states[i % crowd_states.size()])
			await get_tree().process_frame
			frames += 1
		print("crowd %d fps %.1f" % [crowd, frames / 4.0])
	if args.shot != "":
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(args.shot)
		get_tree().quit()
