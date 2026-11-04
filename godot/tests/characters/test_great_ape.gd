extends TestCase
# New Great Ape (2026-11-04): one skinned body on its own skeleton, with its own clips, for both forms.

const CLIPS := ["idle", "walk", "roar", "chest_pound", "stomp", "swipe", "grab_slam", "mouth_blast", "hurt", "transform_in"]

func test_builds_both_forms_as_one_skinned_body() -> void:
	var colours: Array[Color] = []
	for golden in [false, true]:
		var b := ApeBody.build(golden)
		var sk: Skeleton3D = b.skeleton
		var mi: MeshInstance3D = b.mesh
		ok(sk.get_bone_count() >= 26, "full skeleton (%d bones)" % sk.get_bone_count())
		for n: String in ["hips", "chest", "head", "jaw", "arm.L", "forearm.R", "hand.L", "thigh.R", "foot.L", "tail4"]:
			ok(sk.find_bone(n) >= 0, "bone %s" % n)
		ok(mi.skin != null, "skinned")
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var bad := 0
		for v in w.size() / 4:
			var sum := w[v * 4] + w[v * 4 + 1] + w[v * 4 + 2] + w[v * 4 + 3]
			if absf(sum - 1.0) > 0.01: bad += 1
		eq(bad, 0, "every vertex fully weighted")
		ok((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 2000, "a detailed body")
		colours.append(b.fur)
		(b.root as Node).free()
	ok(colours[0] != colours[1], "golden fur differs")

func test_every_clip_exists_and_plays() -> void:
	var g := GreatApe.create(false)
	for c: String in CLIPS:
		ok(g.player.has_animation("ape/" + c), "clip %s" % c)
	for c: String in CLIPS:
		g.play(c)
		g.update(0.1, {})
	g.free()

func test_anim_mapping() -> void:
	var g := GreatApe.create(false)
	g.update(1.5, {})   # past the transform-in
	g.update(0.1, {"speed": 4.0})
	eq(g.current, "walk", "moving → walk")
	g.update(0.1, {"speed": 0.0, "charging": true})
	eq(g.current, "roar", "charging → roar")
	g.update(0.1, {"speed": 0.0, "attackSerial": 1, "attackKind": "beam"})
	eq(g.current, "mouth_blast", "beams → mouth blast")
	g.update(1.5, {"speed": 0.0, "attackSerial": 2, "attackKind": "leg kick"})
	eq(g.current, "stomp", "kicks → stomp")
	g.update(1.5, {"speed": 0.0, "attackSerial": 3, "attackKind": "jab"})
	ok(g.current in ["swipe", "grab_slam"], "punches → swipe or grab-slam")
	g.update(1.5, {"speed": 0.0, "hurt": true, "reactionSerial": 4})
	eq(g.current, "hurt", "hurt reaction")
	g.free()
