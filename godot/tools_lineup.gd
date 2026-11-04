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

func _run(out: String) -> void:
	await process_frame
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
