class_name CreatureBodies
extends RefCounted
# Cast batch B6 (2026-11-10): gear for Namekians, demons, animals and the two non-humanoid NPCs. All are look.costume
# ids (Parts.gear passes every id on here; several can be worn at once, see the field list at the top of outfits.gd).
#   headwear:  namek_turban (white; set antenna false so the antennae stay tucked in), pilaf_hat, ninja_hood
#              (bandanas, scarves and skin spots come from B5 look.hat / neckwear and B4 look.skinPattern)
#   animal heads (pieces over the humanoid head; approximations, the head shape itself stays):
#              pig_head (snout + floppy ears), cat_head (muzzle, nose, whiskers, cat ears), dog_head (muzzle, nose),
#              monkey_head (pale muzzle, round ears), big_mustache (Toppa: white moustache + brows),
#              plant_head (Saibling: veins over the skull)
#   demons:    bat_wings (skin-coloured membrane wings), demon_crest (fin over the skull), oni_horns (two short forehead horns)
#   props:     prop_cane (right hand), prop_staff (long, right hand), prop_katana (on the back), prop_turtle_shell,
#              suspenders
#   bodies:    battle_walker (pink mech round the hidden body), oracle_fish (fish in a bowl on a stand; static)
# Head pieces are in Hair.HEAD_SPACE (head centre about (0, 0.06, 0), radius about 0.105, +Z is the face; eyes at
# y 0.04, nose y 0, mouth y -0.03); body pieces in model rest space (T-pose, arms along ±X, hands at x ±0.8, y 1.44).

const IDS := ["namek_turban", "pilaf_hat", "ninja_hood", "pig_head", "cat_head", "dog_head", "monkey_head",
	"big_mustache", "plant_head", "bat_wings", "demon_crest", "oni_horns", "prop_cane", "prop_staff",
	"prop_katana", "prop_turtle_shell", "suspenders", "battle_walker", "oracle_fish"]
const HEAD_C := Vector3(0, 0.06, 0)

static func _m(key: String, build: Callable) -> ArrayMesh:
	return Parts._mesh("b6_" + key, build)

static func _mat(hex: int, rough := 0.6, metal := 0.0, two := false) -> StandardMaterial3D:
	return Parts.material(Parts.hx(hex), rough, metal, two)

static func _skin(f: Fighter, bone: String, frame: Transform3D, mesh: Mesh, shade: float, two := false) -> MeshInstance3D:
	var mi := f.add_piece(bone, frame, mesh, Parts.material(f.skin * shade, 0.55, 0.0, two))
	f.add_skin_piece(mi, shade)
	return mi

static func _pts(a: Array) -> PackedVector3Array:
	return PackedVector3Array(a)

## A double-sided fan of triangles from root through tips (wing membranes).
static func _fan(g: Geo, root: Vector3, tips: Array) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var v := PackedVector3Array([root])
	for t: Vector3 in tips:
		v.append(t)
	var first: Vector3 = tips[0]
	var last: Vector3 = tips[tips.size() - 1]
	var n := (first - root).cross(last - root).normalized()
	var nn := PackedVector3Array()
	for k in v.size():
		nn.append(n)
	var idx := PackedInt32Array()
	for k in range(1, v.size() - 1):
		idx.append_array([0, k, k + 1])
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_NORMAL] = nn; arr[Mesh.ARRAY_INDEX] = idx
	g.add_arrays(arr)

## Hides the humanoid (body and every piece added so far) for a creature body drawn instead of it.
static func _hide_humanoid(f: Fighter) -> void:
	for mi: MeshInstance3D in f.find_children("*", "MeshInstance3D", true, false):
		mi.visible = false
	f.set_meta("creature", true)

## A piece that stands still on the fighter's root (it does not follow the animation).
static func _fixed(f: Fighter, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat
	f.add_child(mi)
	return mi

static func gear(f: Fighter, id: String) -> void:
	var H := Hair.HEAD_SPACE
	match id:
		# ---------------------------------------------------------------------------------------- headwear
		"namek_turban":   # Piccor's white turban over the tall Namekian skull: a wrapped band above the brows and a
			# tall rounded crown (the antennae stay tucked inside: set look.antenna false)
			f.add_piece("DEF-head", H, _m("namek_turban", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(0.98, 0.92, 1.12)), Vector3(0, 0.14, -0.012)), 0.1, 14, 20)
				g.torus(Transform3D(Basis.from_euler(Vector3(0.12, 0, 0)) * Basis.from_scale(Vector3(1.0, 1.0, 1.1)), Vector3(0, 0.09, -0.006)), 0.086, 0.018, 30, 8)), _mat(0xf4f2ee, 0.8))
		"pilaf_hat":   # Pilav: a black skull cap with a red band, a red pompom and a white badge with a red star
			f.add_piece("DEF-head", H, _m("pilaf_hat", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.06, 1.0, 1.1)), Vector3(0, 0.03, -0.006)), 0.118, PI * 0.36, PI * 0.42)), _mat(0x1c1c22, 0.7))
			f.add_piece("DEF-head", H, _m("pilaf_hat_red", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 0.168, -0.006)), 0.026, 8, 12)
				g.torus(Transform3D(Basis.from_euler(Vector3(0.1, 0, 0)), Vector3(0, 0.122, -0.004)), 0.072, 0.012, 24, 6)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.35)), Vector3(0, 0.098, 0.121)), 0.014, 6, 10)), _mat(0xd02030, 0.5))
			f.add_piece("DEF-head", H, _m("pilaf_badge", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2 - 0.35, 0, 0)), Vector3(0, 0.098, 0.115)), 0.026, 0.026, 0.006, 16)), _mat(0xf4f2ee, 0.5))
		"ninja_hood":   # Shoo: a purple hood over the head and neck with two pointed ears, the face left open
			var cloth := _mat(0x3a2a6e, 0.8, 0.0, true)
			f.add_piece("DEF-head", H, _m("ninja_hood", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_scale(Vector3(1.12, 1.18, 1.12)), Vector3(0, 0.035, -0.01)), 0.122, PI * 0.33, PI * 0.88)
				for s in [1, -1]:
					g.spike(Vector3(s * 0.06, 0.15, -0.02), 0.11, 0.05, Vector3(s * 0.3, 1, 0.05))), cloth)
		# ---------------------------------------------------------------------------------------- animal heads
		"pig_head":   # Ulong: a round pig snout with nostrils and floppy pig ears
			_skin(f, "DEF-head", H, _m("pig_snout", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)) * Basis.from_scale(Vector3(1.25, 1.0, 0.85)), Vector3(0, -0.006, 0.122)), 0.032, 0.036, 0.04, 18)
				for s in [1, -1]:
					g.spike(Vector3(s * 0.07, 0.13, 0.0), 0.075, 0.04, Vector3(s * 0.75, 0.55, 0.45), 0.3)), 1.04, true)
			f.add_piece("DEF-head", H, _m("pig_nostrils", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(0.7, 1.0, 0.4)), Vector3(s * 0.013, -0.006, 0.142)), 0.008, 6, 8)), _mat(0x5a2a30, 0.6))
		"cat_head":   # Puir, Korrin: puffed cheeks, a small nose, whiskers and cat ears
			Parts.gear(f, "cat_ears")
			_skin(f, "DEF-head", H, _m("cat_muzzle", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.2, 0.9, 0.8)), Vector3(s * 0.022, -0.022, 0.104)), 0.026, 8, 12)), 1.12)
			f.add_piece("DEF-head", H, _m("cat_nose", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.3, 0.9, 0.8)), Vector3(0, -0.002, 0.124)), 0.009, 6, 8)), _mat(0xd87a8a, 0.5))
			f.add_piece("DEF-head", H, _m("whiskers", func(g: Geo) -> void:
				for s in [1, -1]:
					for k in 3:
						var y := -0.014 - float(k) * 0.01
						g.tube(_pts([Vector3(s * 0.035, y, 0.118), Vector3(s * 0.075, y + 0.006 - float(k) * 0.008, 0.12), Vector3(s * 0.115, y + 0.008 - float(k) * 0.018, 0.11)]), 0.0022, 0.001, 6, 4)), _mat(0x2a2a2a, 0.6))
		"dog_head":   # Shoo: a cream dog muzzle with a big black nose
			f.add_piece("DEF-head", H, _m("dog_muzzle", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.2, 0.78, 0.9)), Vector3(0, -0.02, 0.1)), 0.045, 10, 14)), _mat(0xf2e4c4, 0.6))
			f.add_piece("DEF-head", H, _m("dog_nose", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.3, 1.0, 0.9)), Vector3(0, -0.006, 0.142)), 0.014, 8, 10)), _mat(0x141414, 0.3))
		"monkey_head":   # Bubbo: a pale muzzle and round ears (pair with look.faceRgb for the pale face)
			f.add_piece("DEF-head", H, _m("monkey_muzzle", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.25, 0.8, 0.7)), Vector3(0, -0.026, 0.1)), 0.036, 10, 14)), _mat(0xd8b48c, 0.65))
			_skin(f, "DEF-head", H, _m("monkey_ears", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.from_euler(Vector3(0, s * 0.3, 0)) * Basis.from_scale(Vector3(0.35, 1.0, 1.0)), Vector3(s * 0.11, 0.05, -0.005)), 0.035, 8, 12)), 1.0)
		"big_mustache":   # Toppa: a huge white moustache sweeping out past the cheeks and bushy white brows
			f.add_piece("DEF-head", H, _m("big_mustache", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_pts([Vector3(s * 0.004, -0.012, 0.122), Vector3(s * 0.05, -0.03, 0.11), Vector3(s * 0.1, -0.02, 0.075), Vector3(s * 0.15, 0.01, 0.04)]), 0.02, 0.005, 14, 8)
					g.sphere(Transform3D(Basis.from_euler(Vector3(0, 0, s * 0.25)) * Basis.from_scale(Vector3(1.8, 0.7, 0.8)), Vector3(s * 0.04, 0.075, 0.104)), 0.017, 8, 12)), _mat(0xf4f2ee, 0.8))
		"plant_head":   # the Saiblings: raised veins running over the skull from the brow to the back
			_skin(f, "DEF-head", H, _m("plant_veins", func(g: Geo) -> void:
				for k: float in [-0.055, -0.022, 0.022, 0.055]:
					var r := sqrt(0.108 * 0.108 - k * k)
					var pts: Array = []
					for t: float in [1.05, 0.6, 0.1, -0.5, -1.1]:
						pts.append(Vector3(k * (1.0 + 0.25 * cos(t)), 0.06 + r * cos(t), r * sin(t)))
					g.tube(_pts(pts), 0.007, 0.004, 18, 6)), 0.82)
		# ---------------------------------------------------------------------------------------- demons
		"bat_wings":   # Tamburin, Cymbel: membrane wings from the shoulder blades (bones + skin)
			_skin(f, "DEF-spine.003", Transform3D.IDENTITY, _m("bat_wing_skin", func(g: Geo) -> void:
				for s in [1, -1]:
					var root := Vector3(s * 0.07, 1.36, -0.14)
					var joint := Vector3(s * 0.36, 1.66, -0.3)
					_fan(g, root, [joint, Vector3(s * 0.66, 1.56, -0.33), Vector3(s * 0.6, 1.3, -0.31), Vector3(s * 0.48, 1.1, -0.27), Vector3(s * 0.28, 1.02, -0.22), Vector3(s * 0.1, 1.12, -0.16)])
				), 0.72, true)
			_skin(f, "DEF-spine.003", Transform3D.IDENTITY, _m("bat_wing_bones", func(g: Geo) -> void:
				for s in [1, -1]:
					var root := Vector3(s * 0.07, 1.36, -0.14)
					var joint := Vector3(s * 0.36, 1.66, -0.3)
					g.tube(_pts([root, Vector3(s * 0.2, 1.54, -0.22), joint]), 0.018, 0.012, 10, 8)
					for t: Vector3 in [Vector3(s * 0.66, 1.56, -0.33), Vector3(s * 0.6, 1.3, -0.31), Vector3(s * 0.48, 1.1, -0.27)]:
						g.tube(_pts([joint, (joint + t) * 0.5 + Vector3(0, 0.02, 0), t]), 0.01, 0.004, 10, 6)), 0.6)
		"demon_crest":   # a short fin ridge from the brow over the skull (Cymbel)
			_skin(f, "DEF-head", H, _m("demon_crest", func(g: Geo) -> void:
				for k in 5:
					var t := 0.7 - float(k) * 0.4
					var d := Vector3(0, cos(t), sin(t))
					g.spike(HEAD_C + d * 0.1, 0.06 - absf(float(k) - 1.5) * 0.008, 0.02, d + Vector3(0, 0, -0.4))), 0.85)
		"oni_horns":   # two short pale horns on the forehead (ogres, demons)
			f.add_piece("DEF-head", H, _m("oni_horns", func(g: Geo) -> void:
				for s in [1, -1]:
					g.spike(HEAD_C + Vector3(s * 0.045, 0.085, 0.045), 0.07, 0.02, Vector3(s * 0.3, 1, 0.2))), _mat(0xe8dcc0, 0.5))
		# ---------------------------------------------------------------------------------------- props
		"prop_cane", "prop_staff":   # a wooden cane (Kamu, Monaido) or a long staff (Korrin) in the right hand
			var top := -0.62 if id == "prop_cane" else -0.42
			f.add_piece("DEF-hand.R", Transform3D.IDENTITY, _m(id, func(g: Geo) -> void:
				var along := Basis.from_euler(Vector3(0, 0, PI / 2))
				var a := Vector3(top, 1.44, -0.02)
				var b := Vector3(-1.62, 1.44, -0.02)
				g.cylinder(Transform3D(along, (a + b) * 0.5), 0.016, 0.013, absf(b.x - a.x), 10)
				g.sphere(Transform3D(Basis.IDENTITY, a), 0.026, 8, 10)), _mat(0x8a5a2e, 0.75))
		"prop_katana":   # Shoo: a katana across the back, orange-wrapped hilt over the right shoulder
			var tilt := Basis.from_euler(Vector3(0, 0, -0.65))
			f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _m("katana_sheath", func(g: Geo) -> void:
				g.cylinder(Transform3D(tilt * Basis.from_scale(Vector3(1.0, 1.0, 0.55)), Vector3(0.03, 1.25, -0.17)), 0.022, 0.022, 0.75, 10)), _mat(0x1c1626, 0.5))
			f.add_piece("DEF-spine.003", Transform3D.IDENTITY, _m("katana_hilt", func(g: Geo) -> void:
				var up := tilt * Vector3.UP
				g.cylinder(Transform3D(tilt, Vector3(0.03, 1.25, -0.17) + up * 0.48), 0.018, 0.018, 0.2, 10)
				g.cylinder(Transform3D(tilt, Vector3(0.03, 1.25, -0.17) + up * 0.38), 0.04, 0.04, 0.012, 14)), _mat(0xe0782a, 0.6))
		"prop_turtle_shell":   # a green turtle shell on the back with a yellow rim
			f.add_piece("DEF-spine.003", Parts._fit(f, Vector3(0, 1.25, -0.12), Parts._sc(f, "shoulders"), Parts._sc(f, "chest")), _m("turtle_shell", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.2, 0.5)), Vector3(0, 1.22, -0.2)), 0.2, 12, 18)), _mat(0x3a8a3a, 0.5))
			f.add_piece("DEF-spine.003", Parts._fit(f, Vector3(0, 1.25, -0.12), Parts._sc(f, "shoulders"), Parts._sc(f, "chest")), _m("turtle_shell_rim", func(g: Geo) -> void:
				g.torus(Transform3D(Basis.from_euler(Vector3(PI / 2, 0, 0)) * Basis.from_scale(Vector3(1.0, 1.0, 1.2)), Vector3(0, 1.22, -0.17)), 0.2, 0.018, 30, 6)), _mat(0xe8c84a, 0.5))
		"suspenders":   # Ulong: two straps over the shoulders from the trousers
			f.add_piece("DEF-spine.003", Parts._fit(f, Vector3(0, 1.25, 0), Parts._sc(f, "shoulders"), Parts._sc(f, "chest") * 1.06), _m("suspenders", func(g: Geo) -> void:
				for s in [1, -1]:
					g.tube(_pts([Vector3(s * 0.075, 1.02, 0.128), Vector3(s * 0.088, 1.25, 0.14), Vector3(s * 0.1, 1.44, 0.085), Vector3(s * 0.1, 1.48, -0.04), Vector3(s * 0.08, 1.3, -0.135), Vector3(s * 0.065, 1.02, -0.125)]), 0.012, 0.012, 24, 6)), _mat(0x6a4a2a, 0.7))
		# ---------------------------------------------------------------------------------------- creature bodies
		"battle_walker":   # Pilav's Battle Walker: a pink egg-shaped cockpit with the pilot behind the glass, a head on
			# a hose neck, two thin thighs and big boot-like shins with flat feet (no arms)
			_hide_humanoid(f)
			var pink := _mat(0xe0606e, 0.35, 0.15)
			var grey := _mat(0x9a9aa4, 0.45, 0.6)
			f.add_piece("DEF-spine.001", Transform3D.IDENTITY, _m("walker_body", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.88, 0.95)), Vector3(0, 1.28, 0)), 0.42, 16, 24)
				for s in [1, -1]:
					g.spike(Vector3(s * 0.26, 1.56, -0.08), 0.32, 0.07, Vector3(s * 1.0, 0.35, -0.25))
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.33, 1.06, 0.0)), 0.13, 10, 14)), pink)
			f.add_piece("DEF-spine.001", Transform3D.IDENTITY, _m("walker_glass", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.45)), Vector3(0, 1.33, 0.36)), 0.15, 12, 16)), Parts._lens(0x9ad8f0))
			f.add_piece("DEF-spine.001", Transform3D.IDENTITY, _m("walker_pilot", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 1.32, 0.3)), 0.075, 10, 14)), _mat(0x7aaee0, 0.6))
			f.add_piece("DEF-spine.001", Transform3D.IDENTITY, _m("walker_hose", func(g: Geo) -> void:
				g.tube(_pts([Vector3(0, 1.58, -0.18), Vector3(0, 1.82, -0.24), Vector3(0, 1.98, -0.08), Vector3(0, 2.0, 0.05)]), 0.04, 0.035, 16, 8)
				for s in [1, -1]:
					g.tube(_pts([Vector3(s * 0.1, 1.0, 0.0), Vector3(s * 0.11, 0.92, 0.0)]), 0.05, 0.05, 4, 10)), grey)
			f.add_piece("DEF-spine.001", Transform3D.IDENTITY, _m("walker_head", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.9, 1.15)), Vector3(0, 2.04, 0.1)), 0.14, 12, 16)
				g.sphere(Transform3D(Basis.from_euler(Vector3(0.25, 0, 0)) * Basis.from_scale(Vector3(0.9, 0.3, 1.4)), Vector3(0, 1.95, 0.2)), 0.1, 8, 12)), pink)
			f.add_piece("DEF-spine.001", Transform3D.IDENTITY, _m("walker_eye", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.5)), Vector3(0.06, 2.07, 0.24)), 0.03, 8, 10)), _mat(0x24242a, 0.2, 0.4))
			for s in [1, -1]:
				var side := "L" if s > 0 else "R"
				f.add_piece("DEF-thigh." + side, Transform3D.IDENTITY, _m("walker_thigh%d" % s, func(g: Geo) -> void:
					g.tube(_pts([Vector3(s * 0.11, 0.92, 0.0), Vector3(s * 0.12, 0.52, 0.0)]), 0.045, 0.04, 6, 10)), grey)
				f.add_piece("DEF-shin." + side, Transform3D.IDENTITY, _m("walker_shin%d" % s, func(g: Geo) -> void:
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.12, 0.5, 0.0)), 0.07, 10, 12)
					g.cylinder(Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.25)), Vector3(s * 0.12, 0.27, 0.0)), 0.085, 0.13, 0.46, 18)), pink)
				f.add_piece("DEF-foot." + side, Transform3D.IDENTITY, _m("walker_foot%d" % s, func(g: Geo) -> void:
					g.sphere(Transform3D(Basis.from_scale(Vector3(1.1, 0.32, 2.0)), Vector3(s * 0.12, 0.04, 0.08)), 0.12, 10, 14)), pink)
		"oracle_fish":   # the Oracle Fish: a blue fish rising from a green-water glass bowl on a gold stand (stands still)
			_hide_humanoid(f)
			_fixed(f, _m("fish_stand", func(g: Geo) -> void:
				g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), 0.2, 0.24, 0.06, 20)
				g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), 0.05, 0.07, 0.8, 14)
				g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 0.88, 0)), 0.17, 0.06, 0.12, 20)
				g.torus(Transform3D(Basis.IDENTITY, Vector3(0, 1.46, 0)), 0.1, 0.014, 20, 6)), _mat(0xd8b040, 0.3, 0.7))
			_fixed(f, _m("fish_water", func(g: Geo) -> void:
				g.cap(Transform3D(Basis.from_euler(Vector3(PI, 0, 0)), Vector3(0, 1.17, 0)), 0.265, PI * 0.6, PI * 0.6, 12, 24)
				g.cylinder(Transform3D(Basis.IDENTITY, Vector3(0, 1.25, 0)), 0.255, 0.255, 0.003, 24)), Parts._lens(0x3ac88a))
			_fixed(f, _m("fish_bowl", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 1.17, 0)), 0.28, 16, 24)), Parts._lens(0xd8f0ff))
			_fixed(f, _m("fish_body", func(g: Geo) -> void:
				g.tube(_pts([Vector3(0, 0.98, -0.04), Vector3(0.03, 1.12, 0.0), Vector3(0, 1.3, 0.02), Vector3(0, 1.46, 0.0), Vector3(0, 1.56, 0.02)]), 0.035, 0.06, 20, 10)
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 1.15, 0.95)), Vector3(0, 1.6, 0.02)), 0.075, 12, 16)
				g.tube(_pts([Vector3(0, 1.66, -0.02), Vector3(0, 1.74, -0.04), Vector3(0.02, 1.78, 0.0), Vector3(0.04, 1.75, 0.02)]), 0.016, 0.006, 12, 6)
				g.spike(Vector3(0, 0.99, -0.04), 0.1, 0.04, Vector3(0, -1, -0.5))), _mat(0x3a6ae0, 0.4))
			_fixed(f, _m("fish_eyes", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.03, 1.63, 0.075)), 0.02, 8, 10)), _mat(0xf4f2ee, 0.3))
			_fixed(f, _m("fish_pupils", func(g: Geo) -> void:
				for s in [1, -1]:
					g.sphere(Transform3D(Basis.IDENTITY, Vector3(s * 0.03, 1.63, 0.092)), 0.007, 6, 8)), _mat(0x141414, 0.3))
			_fixed(f, _m("fish_lips", func(g: Geo) -> void:
				g.sphere(Transform3D(Basis.from_scale(Vector3(1.3, 0.75, 0.7)), Vector3(0, 1.575, 0.085)), 0.022, 8, 10)), _mat(0xe84a5a, 0.4))
