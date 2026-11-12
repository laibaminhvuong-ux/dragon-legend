extends SceneTree
# Dev-only GPU preview of the batch-B3 divine landmark builders (world/landmarks_divine.gd). Not a test case
# (no test_ prefix, the runner skips it). Builds ONE landmark on a flat ground disc under a simple sky, takes a few
# screenshots and prints its draw-call / node cost.
#   DL_PREVIEW_LANDMARK=<type>|all  godot --path godot -s res://tests/preview_divine_landmarks.gd -- --out=C:/dir
# (or pass --type=<type>). Windows Godot from WSL: --out takes a Windows path.
#   ... -- --zone=<id> --out=C:/dir : builds that real world with the B3 data requests applied IN MEMORY
#   (art/reference/map_data_requests_divine.md; data files untouched) and shoots it from a few cameras.

# ground disc colour per type; floating builders (absent here) get no ground
const GROUND := {"godtree": 0x4f9a52, "beeruscastle": 0x4f9a52, "zenopalace": 0xf2e8c8, "u6arena": 0xb84a5a,
	"cupstand": 0xb84a5a, "shieldbox": 0xb84a5a, "needlepeak": 0x5a2a2a, "bloodpool": 0x5a2a2a, "checkinhall": 0xf3cf5c}
const FLOATING := ["kaiorb", "kaiband", "beerusisle", "toparena", "serpentcoils", "serpenthead"]

func _initialize() -> void:
	var out := "user://b3map"
	var want := OS.get_environment("DL_PREVIEW_LANDMARK")
	var zone_id := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--type="):
			want = a.substr(7)
		elif a.begins_with("--zone="):
			zone_id = a.substr(7)
	if zone_id != "":
		DisplayServer.window_set_size(Vector2i(1280, 720))
		_zone_run(zone_id, out)
		return
	var types: Array[String] = []
	if want == "" or want == "all":
		types = LandmarksDivine.TYPES.duplicate()
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
	sm.sky_top_color = Color(0.82, 0.38, 0.78); sm.sky_horizon_color = Color(0.98, 0.78, 0.55)
	sm.ground_horizon_color = Color(0.98, 0.78, 0.55); sm.ground_bottom_color = Color(0.3, 0.35, 0.4)
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
		if not t in FLOATING:
			scene.add_child(ground)
		else:
			ground.free()
		var g := Node3D.new()
		g.name = t
		var l := {"type": t, "x": 0, "z": 0, "alt": 0}
		var t0 := Time.get_ticks_usec()
		LandmarksDivine.build(t, g, null, l)
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
		if t == "checkinhall":
			views.append([Vector3(0.0, 0.25, -1.0), Vector3(0, 6, 0), 0.45])
		for i in views.size():
			var v: Array = views[i]
			var dir: Vector3 = (v[0] as Vector3).normalized()
			var tgt: Vector3 = v[1]
			var dist: float = float(v[2]) * r
			cam.look_at_from_position(tgt + dir * dist, tgt, Vector3.UP)
			for f in 20:
				await process_frame
			await create_timer(0.6).timeout
			var img := root.get_viewport().get_texture().get_image()
			img.save_png("%s/%s_%d.png" % [out, t, i + 1])
		scene.queue_free()
		await process_frame
	quit()


# --- whole-world preview with the B3 data requests applied in memory -------------------------------------------------
static func _swap(z: Dictionary, old: String, new: String, extra := {}) -> void:
	for l: Dictionary in z.landmarks:
		if str(l.type) == old:
			l.type = new
			l.merge(extra, true)

static func patch(id: String) -> void:
	var zones: Dictionary = RuleTables.table("zones")
	var z: Dictionary = zones[id]
	match id:
		"snake_way":
			z.terrain.path["serpent"] = true
			_swap(z, "checkin", "checkinhall")
			_swap(z, "kaiplanet", "kaiorb")
			z.landmarks = z.landmarks.filter(func(l: Dictionary) -> bool: return str(l.type) != "snakehead")
			z.landmarks.append({"type": "serpenthead", "name": "Serpent Road gate", "x": 38.0, "z": -392.0})
			z.landmarks.append({"type": "serpentcoils", "x": -110.0, "z": -260.0, "alt": 6.0})
			z.landmarks.append({"type": "serpentcoils", "x": 90.0, "z": 20.0, "alt": 4.0, "span": 180.0})
			z.landmarks.append({"type": "serpentcoils", "x": -120.0, "z": 260.0, "alt": 8.0, "loops": 2})
		"king_kai":
			z.landmarks.append({"type": "kaiband", "x": 0.0, "z": 0.0})
		"beerus_planet":
			z.terrain = {"size": 360, "spawn": {"x": 0, "z": -30}, "platform": {"radius": 110, "height": 0}, "killY": -80}
			z.landmarks = [{"type": "beerusisle", "x": 0.0, "z": 0.0},
				{"type": "beeruscastle", "name": "Beeros's temple", "x": 0.0, "z": 40.0, "collide": 10},
				{"type": "godtree", "name": "The great tree", "x": -45.0, "z": 60.0, "collide": 4}]
			z.biome.treeCount = 30
		"world_of_void":
			z.landmarks.append({"type": "toparena", "x": 0.0, "z": 0.0})
		"nameless_planet":
			_swap(z, "cellarena", "u6arena")
			z.landmarks = z.landmarks.filter(func(l: Dictionary) -> bool: return str(l.type) != "stands")
			z.landmarks.append({"type": "shieldbox", "name": "Gods' box", "x": 0.0, "z": 58.0, "rot": PI})
			var k := 0
			for p in [Vector2(-50, 40), Vector2(50, 40), Vector2(-62, -5), Vector2(62, -5), Vector2(-48, -50), Vector2(48, -50)]:
				z.landmarks.append({"type": "cupstand", "x": p.x, "z": p.y, "top": "seats" if k % 2 else "dome"})
				k += 1
			z.biome.tints = {"dirt": [1.25, 0.55, 0.62]}

const ZONE_CAMS := {
	"snake_way": [[Vector3(30, 14, -360), Vector3(42, 0, -300)], [Vector3(60, 8, -405), Vector3(36, 3, -392)],
		[Vector3(0, 60, -80), Vector3(40, -10, 40)], [Vector3(90, 30, -500), Vector3(30, 8, -447)]],
	"king_kai": [[Vector3(0, 8, -40), Vector3(0, 0, 10)], [Vector3(110, 10, 40), Vector3(0, -40, 0)]],
	"beerus_planet": [[Vector3(0, 12, -90), Vector3(0, 15, 40)], [Vector3(260, -40, -200), Vector3(0, -40, 0)]],
	"world_of_void": [[Vector3(0, 10, -90), Vector3(0, 0, 0)], [Vector3(230, -30, -160), Vector3(0, -40, 0)]],
	"nameless_planet": [[Vector3(0, 30, -90), Vector3(0, 0, 20)], [Vector3(30, 6, -20), Vector3(0, 6, 58)]],
}

func _zone_run(id: String, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	patch(id)
	var zone: RuleZone = RulePlanet.open(id)
	var world: Node3D = WorldView.build_zone(zone, "high")
	root.add_child(world)
	var cam := Camera3D.new()
	cam.fov = 70; cam.far = 4000
	root.add_child(cam)
	cam.make_current()
	var cams: Array = ZONE_CAMS.get(id, [[Vector3(0, 30, -90), Vector3.ZERO]])
	for i in cams.size():
		var c: Array = cams[i]
		var tgt: Vector3 = c[1]
		var gy: float = zone.height_at(tgt.x, tgt.z)
		var lift := Vector3(0, gy if gy > -100.0 else 0.0, 0)   # planet maps sit higher than 0
		cam.look_at_from_position(c[0] + lift, tgt + lift, Vector3.UP)
		for f in 40:
			await process_frame
		await create_timer(1.5).timeout
		root.get_viewport().get_texture().get_image().save_png("%s/zone_%s_%d.png" % [out, id, i + 1])
	quit()
