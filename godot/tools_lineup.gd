# Dev (presentation rebuild): renders the body-shape lineup as contact sheets, same camera and height for everyone.
#   godot --path godot -s res://tools_lineup.gd -- --out=C:/path/prefix
# Writes <prefix>_races_neutral.png, _races_silhouette.png, _named_neutral.png, _named_silhouette.png,
# _races_side.png (neutral grey material: shape only, no colours or outfits).
extends SceneTree

const W := 2400
const H := 1150
const RACES := ["Saiyan", "HalfSaiyan", "Human", "Namekian", "FrostDemon", "Majin"]
const RACE_HAIR := {"Saiyan": "Spiky", "HalfSaiyan": "Wild", "Human": "Short", "Namekian": "None", "FrostDemon": "None", "Majin": "None"}
const NAMED := [
	["goku", "gokan"], ["vegeta", "vegara"], ["piccolo", "piccor"], ["nappa", "nappo"], ["krillin", "krilan"],
	["roshi", "roshu"], ["frieza", "frigor"], ["recoome", "recume"], ["android_16", "cyborg16"], ["king_cold", "kold"],
	["fat_buu", "boo_fat"], ["kid_buu", "boo_kid"],
]
const NAMED2 := [
	["broly", "brolo"], ["jiren", "jiran"], ["toppo", "toppa"], ["dodoria", "dodorra"], ["cell", "cel"], ["hit", "hitto"],
	["beerus", "beeros"], ["mr_satan", "sadan"], ["bulma", ""], ["android_18", "cyborg_slim"], ["videl", ""], ["gamma1", "gama"],
]

var vp: SubViewport
var stage: Node3D
var cam: Camera3D
var light: DirectionalLight3D
var env: WorldEnvironment
var neutral := StandardMaterial3D.new()
var black := StandardMaterial3D.new()

func _initialize() -> void:
	var out := "user://lineup"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	neutral.albedo_color = Color(0.72, 0.72, 0.74)
	neutral.roughness = 0.75
	black.albedo_color = Color.BLACK
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.56, 0.6)
	vp.add_child(env)
	light = DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.5, 0)
	light.shadow_enabled = true
	vp.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.4, 0)
	fill.light_energy = 0.4
	vp.add_child(fill)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	_run(out)

func _look(race: String) -> Dictionary:
	return {"race": race, "skin": 0, "face": "Calm", "hair": RACE_HAIR[race], "hairColor": 0, "build": "Average", "outfit": "TurtleGi", "outfitTint": 0}

func _row(entries: Array, spacing: float) -> void:
	if stage != null:
		stage.free()
	stage = Node3D.new()
	vp.add_child(stage)
	var n := entries.size()
	var total := 0.0
	for e: Array in entries:
		total += spacing * maxf(1.0, float(e[2]) * 0.85)
	var x := -total / 2.0
	for i in n:
		var e: Array = entries[i]
		var f := Fighter.create(e[1])
		var w := spacing * maxf(1.0, float(e[2]) * 0.85)
		f.position = Vector3(x + w / 2.0, 0, 0)
		x += w
		f.scale = Vector3.ONE * float(e[2])
		stage.add_child(f)
		var label := Label3D.new()
		label.text = e[0]
		label.font_size = 40
		label.pixel_size = 0.004
		label.position = f.position + Vector3(0, -0.14, 0.3)
		label.modulate = Color(0.1, 0.1, 0.12)
		label.outline_size = 0
		stage.add_child(label)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(total + 4, 6)
	floor.mesh = pm
	floor.position.y = -0.002
	stage.add_child(floor)
	var tallest := 1.0
	for e: Array in entries:
		tallest = maxf(tallest, float(e[2]))
	cam.size = 2.45 * tallest
	for l: Label3D in stage.find_children("*", "Label3D", true, false):
		l.pixel_size = 0.004 * sqrt(tallest)
		l.position.y = -0.14 * sqrt(tallest)
	vp.size = Vector2i(roundi(H * (total + 0.3) / cam.size), H)
	cam.position = Vector3(0, cam.size * 0.5 - 0.3 * tallest, 8)
	cam.rotation = Vector3.ZERO

func _paint(mat: Material, bg: Color) -> void:
	env.environment.background_color = bg
	for mi: MeshInstance3D in stage.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent() == stage:   # the floor
			mi.visible = bg != Color.WHITE
			mi.material_override = neutral
			continue
		if mat == null:   # real colours: put the fighter's own materials back
			if mi.has_meta("own"):
				mi.material_override = mi.get_meta("own")
			continue
		if not mi.has_meta("own"):
			mi.set_meta("own", mi.material_override)
		mi.material_override = mat
		for s in mi.get_surface_override_material_count():
			mi.set_surface_override_material(s, null)
	for l: Label3D in stage.find_children("*", "Label3D", true, false):
		l.modulate = Color(0.1, 0.1, 0.12)
	light.visible = true

func _settle() -> void:
	for f: Fighter in stage.find_children("*", "Fighter", true, false):
		for i in 30:
			f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true})
	for i in 6:
		await process_frame

func _shot(path: String) -> void:
	for i in 4:
		await process_frame
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)

func _turn(yaw: float) -> void:
	for f: Fighter in stage.find_children("*", "Fighter", true, false):
		f.rotation.y = yaw

## Every skill pose, held (gathering) and released, as a grid; seen from a three-quarter angle.
func _poses(out: String) -> void:
	var ids: Array = SkillPoses.all().keys()
	ids.sort()
	for which: String in ["hold", "release"]:
		if stage != null:
			stage.free()
		stage = Node3D.new()
		vp.add_child(stage)
		var cols := 9
		var rows := ceili(ids.size() / float(cols))
		for i in ids.size():
			var f := Fighter.create(_look("Saiyan"))
			f.position = Vector3((i % cols - (cols - 1) / 2.0) * 1.35, -(i / cols) * 2.5, 0)
			f.rotation.y = 0.65
			stage.add_child(f)
			var label := Label3D.new()
			label.text = ids[i]
			label.font_size = 30
			label.pixel_size = 0.004
			label.modulate = Color(0.1, 0.1, 0.12)
			label.position = f.position + Vector3(0, -0.15, 0.6)
			stage.add_child(label)
		cam.size = rows * 2.5 + 0.2
		vp.size = Vector2i(roundi(H * 1.6 * (cols * 1.35 + 0.3) / cam.size), roundi(H * 1.6))
		cam.position = Vector3(0, -(rows - 1) * 2.5 / 2.0 + 0.95, 8)
		var serial := 1
		for f: Fighter in stage.find_children("*", "Fighter", true, false):
			var id: String = ids[stage.find_children("*", "Fighter", true, false).find(f)]
			for k in 24:
				var a := {"speed": 0.0, "onGround": true}
				if which == "hold":
					a.skillHoldPose = id; a.skillHold = 1.0
				elif k >= 12:
					a.skillReleasePose = id; a.attackSerial = serial; a.attackKind = "beam"
				f.update(1.0 / 30.0, a)
			serial += 1
		_paint(neutral, Color(0.86, 0.87, 0.9))
		await _shot("%s_poses_%s.png" % [out, which])

## Close-up faces of the six races in their real colours (front and three-quarter rows).
func _faces(out: String) -> void:
	stage = Node3D.new()
	vp.add_child(stage)
	env.environment.background_color = Color(0.3, 0.33, 0.4)
	var i := 0
	for row in 2:
		for r: String in RACES:
			var l := _look(r)
			l.face = ["Calm", "Fierce", "Smirk", "Determined", "Cold", "Calm"][i % 6]
			var f := Fighter.create(l)
			f.position = Vector3((i % 6 - 2.5) * 0.42, -row * 0.62, 0)
			f.position.z = row * 3.0
			f.rotation.y = 0.0 if row == 0 else 0.7
			stage.add_child(f)
			i += 1
	for f: Fighter in stage.find_children("*", "Fighter", true, false):
		for k in 20:
			f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true})
	cam.size = 1.0
	vp.size = Vector2i(2600, roundi(2600 * 1.0 / (6 * 0.42 + 0.1)))
	cam.position = Vector3(0, 1.72 - 0.3, 8)
	await _shot(out + "_faces.png")

## The eight combo strikes caught mid-motion (side-ish view).
func _strikes(out: String) -> void:
	var strikes := ["jab", "cross", "hook", "uppercut", "palm_strike", "knee", "spin_kick", "axe_kick"]
	_row(strikes.map(func(k: String) -> Array: return [k, _look("Saiyan"), 1.0]), 1.3)
	var i := 0
	for f: Fighter in stage.find_children("*", "Fighter", true, false):
		f.rotation.y = 0.9
		f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true})
		var frames: int = {"spin_kick": 7, "axe_kick": 6, "knee": 4}.get(strikes[i], 5)
		for k in frames:
			f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true, "attackSerial": 9, "attackKind": strikes[i], "finisher": true})
		i += 1
	_paint(neutral, Color(0.86, 0.87, 0.9))
	await _shot(out + "_strikes.png")

## Every fighting style's moves frozen at their contact frame (rows = styles; stance, combo 1-4, dash, finisher).
func _styles(out: String) -> void:
	stage = Node3D.new()
	vp.add_child(stage)
	var slots := ["stance", "combo1", "combo2", "combo3", "combo4", "dash", "finisher"]
	var r := 0
	for style: String in FightStyles.IDS:
		var c := 0
		for slot: String in slots:
			var id := "%s_%s" % [style, slot]
			var f := Fighter.create(_look("Saiyan"))
			f.position = Vector3((c - 3) * 1.5, -r * 2.4, 0)
			f.rotation.y = 0.9
			stage.add_child(f)
			f.anim.tree.active = false
			if not f.anim_player.has_animation_library("moves"):
				f.anim_player.add_animation_library("moves", FightStyles.library(f))
			var mv: Dictionary = FightStyles.moves(style)[id]
			f.anim_player.play("moves/" + id)
			f.anim_player.seek(float(mv.contact) if slot != "stance" else 0.5, true)
			f.anim_player.pause()
			f.position.x += MoveClips.lunge_at(f.anim_player.get_animation("moves/" + id), float(mv.contact)) * 0.0
			var label := Label3D.new()
			label.text = id
			label.font_size = 30
			label.pixel_size = 0.004
			label.modulate = Color(0.1, 0.1, 0.12)
			label.position = f.position + Vector3(0, -0.15, 0.8)
			stage.add_child(label)
			c += 1
		r += 1
	cam.size = 4 * 2.4 + 0.2
	vp.size = Vector2i(roundi(H * 1.6 * (7 * 1.5 + 0.3) / cam.size), roundi(H * 1.6))
	cam.position = Vector3(0, -1.5 * 2.4 + 0.95, 8)
	_paint(neutral, Color(0.86, 0.87, 0.9))
	await _shot(out + "_styles.png")

## A real-time recording: the four styles side by side in their guard, then the full 4-hit combo and finisher,
## chained as fast as a player would press (frames saved as <prefix>_flow_0000.png ... for ffmpeg).
func _flow(out: String) -> void:
	stage = Node3D.new()
	vp.add_child(stage)
	var fs: Array[Fighter] = []
	for i in 4:
		var f := Fighter.create(_look(["Saiyan", "Human", "HalfSaiyan", "Namekian"][i]))
		f.position = Vector3((i - 1.5) * 1.9, 0, 0)
		f.rotation.y = 1.2
		stage.add_child(f)
		fs.append(f)
		var label := Label3D.new()
		label.text = FightStyles.NAMES[FightStyles.IDS[i]]
		label.font_size = 40; label.pixel_size = 0.004; label.modulate = Color(0.1, 0.1, 0.12)
		label.position = f.position + Vector3(0, -0.2, 0.9)
		stage.add_child(label)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(14, 8); floor.mesh = pm; stage.add_child(floor)
	env.environment.background_color = Color(0.86, 0.87, 0.9)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 40
	cam.position = Vector3(0, 1.05, 9.0)
	cam.rotation = Vector3(-0.02, 0, 0)
	vp.size = Vector2i(1600, 640)
	# script: 0.8 s guard, then hits every ~0.42 s (step 1-4, finisher), then guard again
	var schedule := [0.8, 1.2, 1.62, 2.1, 2.62, 3.5]
	var dt := 1.0 / 30.0
	var t := 0.0
	var frame := 0
	while t < 4.6:
		var serial := 0
		for s in schedule.size():
			if t >= schedule[s]:
				serial = s + 1
		for i in 4:
			var style: String = FightStyles.IDS[i]
			var a := {"speed": 0.0, "onGround": true, "inCombat": true, "style": style}
			if serial > 0 and serial <= 5:
				a.attackSerial = serial
				a.attackKind = "jab"
				a.comboStep = serial
				a.move = "%s_finisher" % style if serial == 5 else ""
			fs[i].update(dt, a)
		await process_frame
		await process_frame
		vp.get_texture().get_image().save_png("%s_flow_%04d.png" % [out, frame])
		frame += 1
		t += dt
	print("saved %d flow frames" % frame)

## Both Great Apes (normal, golden) in key frames of their clips, in real colours.
func _ape(out: String) -> void:
	stage = Node3D.new()
	vp.add_child(stage)
	env.environment.background_color = Color(0.55, 0.62, 0.72)
	var shots := [["idle", 0.6], ["walk", 0.2], ["roar", 0.8], ["swipe", 0.42], ["grab_slam", 0.78], ["mouth_blast", 0.55], ["stomp", 0.38]]
	var r := 0
	for golden in [false, true]:
		var c := 0
		for sh: Array in shots:
			var g := GreatApe.create(golden)
			g.position = Vector3((c - 3) * 2.2, -r * 2.6, 0)
			g.rotation.y = 0.55
			stage.add_child(g)
			g.update(1.6, {})
			g.play(sh[0], 0.0)
			g.update(float(sh[1]), {})
			var label := Label3D.new()
			label.text = ("golden " if golden else "") + str(sh[0])
			label.font_size = 34; label.pixel_size = 0.004; label.modulate = Color(0.08, 0.08, 0.1)
			label.position = g.position + Vector3(0, -0.15, 1.2)
			stage.add_child(label)
			c += 1
		r += 1
	cam.size = 2 * 2.6 + 0.3
	vp.size = Vector2i(roundi(1150 * 1.6 * (7 * 2.2 + 0.4) / cam.size), roundi(1150 * 1.6))
	cam.position = Vector3(0, -1.3 + 1.0, 8)
	await _shot(out + "_ape.png")

## Both Great Apes performing their moves in real time (frames <prefix>_apeflow_0000.png ...).
func _apeflow(out: String) -> void:
	stage = Node3D.new()
	vp.add_child(stage)
	var apes: Array[GreatApe] = []
	for i in 2:
		var g := GreatApe.create(i == 1)
		g.position = Vector3((i - 0.5) * 4.2, 0, 0)
		g.rotation.y = 0.45 if i == 0 else -0.45
		stage.add_child(g)
		apes.append(g)
	var floor := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 20); floor.mesh = pm; stage.add_child(floor)
	env.environment.background_color = Color(0.55, 0.62, 0.72)
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 45
	cam.position = Vector3(0, 2.3, 9.5)
	cam.rotation = Vector3(-0.08, 0, 0)
	vp.size = Vector2i(1600, 800)
	# script: transform-in, idle, walk on the spot, swipe, swipe, grab-slam, stomp, mouth blast, roar, chest pound
	var plan := [[0.0, {}], [1.6, {"speed": 3.5}], [3.4, {"attackSerial": 1, "attackKind": "jab"}], [4.3, {"attackSerial": 2, "attackKind": "jab"}],
		[5.2, {"attackSerial": 3, "attackKind": "jab"}], [6.7, {"attackSerial": 4, "attackKind": "leg kick"}], [7.9, {"attackSerial": 5, "attackKind": "beam"}],
		[9.3, {"charging": true}], [10.9, {}]]
	var dt := 1.0 / 30.0
	var t := 0.0
	var frame := 0
	while t < 12.0:
		var a := {}
		for step: Array in plan:
			if t >= float(step[0]):
				a = (step[1] as Dictionary).duplicate()
		if not a.has("attackSerial") and t >= 3.4:
			a.attackSerial = 5 if t >= 7.9 else (4 if t >= 6.7 else (3 if t >= 5.2 else (2 if t >= 4.3 else 1)))
		for g in apes:
			g.update(dt, a)
		await process_frame
		await process_frame
		vp.get_texture().get_image().save_png("%s_apeflow_%04d.png" % [out, frame])
		frame += 1
		t += dt
	print("saved %d ape frames" % frame)

## Twelve fighters with the SAME look and different face seeds, close up (the faces must all differ).
func _faces2(out: String) -> void:
	stage = Node3D.new()
	vp.add_child(stage)
	env.environment.background_color = Color(0.3, 0.33, 0.4)
	for i in 12:
		var l := _look(["Human", "Saiyan", "Namekian"][i / 6 if i < 12 else 0] if false else "Human")
		l.hair = "None" if i % 3 == 0 else "Short"
		l.faceSeed = "trainee_%d" % i
		var f := Fighter.create(l)
		f.position = Vector3((i % 6 - 2.5) * 0.36, -(i / 6) * 0.5, (i / 6) * 3.0)
		stage.add_child(f)
		for k in 10:
			f.update(1.0 / 30.0, {"speed": 0.0, "onGround": true})
	cam.size = 0.95
	vp.size = Vector2i(2600, roundi(2600 * 0.95 / (6 * 0.36 + 0.06)))
	cam.position = Vector3(0, 1.72 - 0.24, 8)
	await _shot(out + "_faces2.png")

func _run(out: String) -> void:
	await process_frame
	if "--faces2" in OS.get_cmdline_user_args():
		await _faces2(out)
		quit()
		return
	if "--apeflow" in OS.get_cmdline_user_args():
		await _apeflow(out)
		quit()
		return
	if "--ape" in OS.get_cmdline_user_args():
		await _ape(out)
		quit()
		return
	if "--flow" in OS.get_cmdline_user_args():
		await _flow(out)
		quit()
		return
	if "--styles" in OS.get_cmdline_user_args():
		await _styles(out)
		quit()
		return
	if "--strikes" in OS.get_cmdline_user_args():
		await _strikes(out)
		quit()
		return
	if "--faces" in OS.get_cmdline_user_args():
		await _faces(out)
		quit()
		return
	if "--poses" in OS.get_cmdline_user_args():
		await _poses(out)
		quit()
		return
	var races: Array = []
	for r: String in RACES:
		races.append([r, _look(r), 1.0])
	_row(races, 1.15)
	await _settle()
	_paint(neutral, Color(0.86, 0.87, 0.9)); await _shot(out + "_races_neutral.png")
	_paint(black, Color.WHITE); await _shot(out + "_races_silhouette.png")
	_turn(PI / 2); await _settle()
	_paint(neutral, Color(0.86, 0.87, 0.9)); await _shot(out + "_races_side.png")
	var chars: Dictionary = root.get_node("Data").characters if root.has_node("Data") else {}
	var named: Array = []
	for pair: Array in (NAMED2 if "--more" in OS.get_cmdline_user_args() else NAMED):
		var c: Dictionary = chars.get(pair[0], {})
		var l: Dictionary = c.get("look", _look("Human")).duplicate()
		l["physique"] = pair[1]
		var s: Variant = c.get("scale")
		named.append([str(c.get("name", pair[0])), l, float(s) if s != null and float(s) < 2.0 else 1.0])
	_row(named, 0.95)
	await _settle()
	_paint(neutral, Color(0.86, 0.87, 0.9)); await _shot(out + "_named_neutral.png")
	_paint(black, Color.WHITE); await _shot(out + "_named_silhouette.png")
	_paint(null, Color(0.3, 0.33, 0.4)); await _shot(out + "_named_dressed.png")
	quit()
