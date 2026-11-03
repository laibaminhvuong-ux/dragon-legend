extends TestCase
# Stage 6 Task 1: every vertex of the mannequin lands in a body region, every outfit colours every region, and
# a fighter builds for every race x outfit x build without errors.

func _mannequin() -> MeshInstance3D:
	var scene: Node = (load("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf") as PackedScene).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	mi.get_parent().remove_child(mi)
	scene.free()
	return mi

func test_every_vertex_has_a_region() -> void:
	var mi := _mannequin()
	var mesh := BodyRegions.dressed_mesh(mi)
	var seen := {}
	var total := 0
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var rest: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		eq(rest.size(), verts.size() * 4, "surface %d keeps a rest position per vertex" % s)
		ok(not (arr[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty(), "surface %d is still skinned" % s)
		for v in verts.size():
			var r := BodyRegions.region(Vector3(rest[v * 4], rest[v * 4 + 1], rest[v * 4 + 2]))
			ok(r >= 0 and r < BodyRegions.COUNT, "vertex region in range")
			seen[r] = int(seen.get(r, 0)) + 1
			total += 1
	for r in [BodyRegions.SKIN, BodyRegions.TOP, BodyRegions.PANTS, BodyRegions.BOOTS, BodyRegions.BELT, BodyRegions.WRIST,
			BodyRegions.SLEEVE, BodyRegions.FOREARM, BodyRegions.HANDS, BodyRegions.UNDERSHIRT, BodyRegions.PLATE, BodyRegions.UPPER_ARM]:
		ok(int(seen.get(r, 0)) > 10, "region %d covers part of the body (%d verts)" % [r, int(seen.get(r, 0))])
	ok(total > 3000, "whole mannequin checked (%d verts)" % total)
	mi.free()

func test_dressed_mesh_is_shared() -> void:
	var a := _mannequin()
	var b := _mannequin()
	ok(BodyRegions.dressed_mesh(a) == BodyRegions.dressed_mesh(b), "one dressed mesh for every fighter")
	a.free(); b.free()

func test_every_outfit_paints_every_region() -> void:
	for o: String in Outfits.ALL:
		var c := BodyRegions.colours(Outfits.parts(o, 0xe86a1a), Color(0.9, 0.75, 0.6))
		eq(c.size(), BodyRegions.COUNT, "%s has a colour per region" % o)
		for col in c:
			ok(col.a > 0.99, "%s colours are opaque" % o)

func test_fighter_builds_for_every_race_outfit_build() -> void:
	var races: Dictionary = Fighter.Tables().races
	var builds: Array = Fighter.Tables().appearance.BUILDS
	ok(races.size() >= 6, "races loaded")
	var n := 0
	for race: String in races:
		for o: String in Outfits.ALL:
			var b: Dictionary = builds[n % builds.size()]
			var f := Fighter.create({"race": race, "outfit": o, "build": b.id, "skin": n % 3, "outfitTint": n % 5})
			ok(f.anim_player.current_animation == "Idle", "%s/%s idles" % [race, o])
			near(f.body.scale.y, float(b.height), 1e-6, "%s build height" % b.id)
			f.free()
			n += 1
