extends SceneTree
# Dev-only GPU preview of the batch-B4 alien landmark builders (world/landmarks_alien.gd). Not a test case
# (no test_ prefix, the runner skips it). Builds ONE landmark on a flat ground disc under a simple sky, takes a few
# screenshots and prints its draw-call / node cost.
#   DL_PREVIEW_LANDMARK=<type>|all  godot --path godot -s res://tests/preview_alien_landmarks.gd -- --out=C:/dir
# (or pass --type=<type>). Windows Godot from WSL: --out takes a Windows path.

# Type "trees" lays out the batch-B4 tree kinds of world/props.gd in a row (3 variants each).
const GROUND := {"namekdome": 0x3a7ad0, "namekvillage": 0x3a7ad0, "elderspire": 0x3a7ad0, "tyrantship": 0x3a7ad0,
	"heetersship": 0xc08a52, "cerealhut": 0xc08a52, "yardratvillage": 0x8a7ab8, "floatcups": 0xb83a5a,
	"vampacrater": 0xc8b040, "trees": 0x6a8a4a}
const TREE_KINDS := ["ajisa", "ajisa_tall", "purple_spire", "mushroom", "cypress", "giant"]

func _initialize() -> void:
	var out := "user://b4map"
	var want := OS.get_environment("DL_PREVIEW_LANDMARK")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--type="):
			want = a.substr(7)
	var types: Array[String] = []
	if want == "" or want == "all":
		types = LandmarksAlien.TYPES.duplicate()
	else:
		for t in want.split(","):
			types.append(t.strip_edges())
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_run(types, out)

func _env() -> Node3D:
	var n := Node3D.new()
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.18, 0.42, 0.85); sm.sky_horizon_color = Color(0.62, 0.78, 0.95)
	sm.ground_horizon_color = Color(0.62, 0.78, 0.95); sm.ground_bottom_color = Color(0.3, 0.35, 0.4)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	n.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 0.6, 0.0)
	sun.light_energy = 1.25; sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	n.add_child(sun)
	return n

func _run(types: Array[String], out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	for t in types:
		var scene := _env()
		root.add_child(scene)
		var ground := MeshInstance3D.new()
		var pm := CylinderMesh.new(); pm.top_radius = 140; pm.bottom_radius = 140; pm.height = 0.2
		ground.mesh = pm; ground.position.y = -0.11
		var gm := StandardMaterial3D.new(); gm.albedo_color = Color.hex((int(GROUND.get(t, 0x6a8a4a)) << 8) | 0xff); gm.roughness = 0.95
		ground.material_override = gm
		scene.add_child(ground)
		var g := Node3D.new()
		g.name = t
		var l := {"type": t, "x": 0, "z": 0}
		var t0 := Time.get_ticks_usec()
		if t == "trees":
			for ki in TREE_KINDS.size():
				for v in 3:
					var tm := MeshInstance3D.new()
					tm.mesh = WorldProps.tree_mesh(TREE_KINDS[ki], v)
					var giant: bool = TREE_KINDS[ki] == "giant"
					tm.position = Vector3(55.0, 0, (v - 1) * 34.0) if giant else Vector3((ki - 2.5) * 12.0, 0, (v - 1) * 9.0)
					g.add_child(tm)
		else:
			LandmarksAlien.build(t, g, null, l)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		scene.add_child(g)
		var meshes := g.find_children("*", "MeshInstance3D", true, false)
		var aabb := AABB()
		var first := true
		var verts := 0
		for m: Node in meshes:
			var mi := m as MeshInstance3D
			var bb := mi.transform * mi.get_aabb()
			aabb = bb if first else aabb.merge(bb)
			first = false
			for s in mi.mesh.get_surface_count():
				verts += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		print("%s: %d draw meshes, %d nodes, %d verts, build %.1f ms, size %s" % [t, meshes.size(), g.get_child_count(), verts, ms, str(aabb.size)])
		var cam := Camera3D.new()
		cam.far = 3000.0
		scene.add_child(cam)
		cam.make_current()
		var c := aabb.get_center()
		var r := maxf(maxf(aabb.size.x, aabb.size.z), aabb.size.y) * 0.5
		var views: Array = [[Vector3(0.75, 0.42, 1.0), c, 1.7], [Vector3(-1.0, 0.75, -0.55), c, 1.8], [Vector3(0.15, 0.12, 1.0), c - Vector3(0, c.y * 0.4, 0), 1.6]]
		if t == "korrinspire":
			var top := Vector3(0, 405, 0)
			views = [[Vector3(0.6, -0.35, 1.0), top, 45.0], [Vector3(0.8, 0.25, 1.0), Vector3(0, 6, 0), 50.0], [Vector3(1.0, 0.05, 0.6), Vector3(0, 200, 0), 500.0]]
		if t == "trees":
			views = [[Vector3(0.3, 0.25, 1.0), Vector3(-6, 4, 0), 42.0], [Vector3(0.6, 0.3, 1.0), Vector3(55, 14, 0), 75.0], [Vector3(-0.2, 0.1, 1.0), Vector3(-6, 4, 0), 30.0]]
		if t == "budokaihall":   # its front faces the ring (-z)
			for v: Array in views:
				v[0] = (v[0] as Vector3) * Vector3(1, 1, -1)
		for i in views.size():
			var v: Array = views[i]
			var dir: Vector3 = (v[0] as Vector3).normalized()
			var tgt: Vector3 = v[1]
			var dist: float = float(v[2]) * (r if t != "korrinspire" and t != "trees" else 1.0)
			cam.look_at_from_position(tgt + dir * dist, tgt, Vector3.UP)
			for f in 20:
				await process_frame
			await create_timer(0.6).timeout
			var img := root.get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%d.png" % [out, t, i + 1])
		scene.queue_free()
		await process_frame
	quit()
