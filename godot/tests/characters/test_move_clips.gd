extends TestCase
# Fight flow (2026-11-04): code-authored move clips built from key poses.

func _rig() -> Array:
	var scene: Node = (load("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf") as PackedScene).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	return [scene, sk, ap]

func _rot_track(a: Animation, bone: String) -> int:
	for t in a.get_track_count():
		if a.track_get_type(t) == Animation.TYPE_ROTATION_3D and str(a.track_get_path(t)).ends_with(":" + bone):
			return t
	return -1

func test_clip_has_tracks_and_length() -> void:
	var r := _rig()
	var base := MoveClips.base_pose(r[2], r[1], "Idle")
	ok(base.has("DEF-hips") and base.has("DEF-upper_arm.R"), "base pose sampled from Idle")
	var a := MoveClips.build(r[1], base, [{"t": 0.0}, {"t": 0.2, "armR": Vector3(-1.5, 0, 0)}, {"t": 0.5}], 0.5)
	near(a.length, 0.5, 1e-6, "length")
	var t := _rot_track(a, "DEF-upper_arm.R")
	ok(t >= 0, "arm track keyed")
	near(a.track_get_key_time(t, a.track_get_key_count(t) - 1), 0.5, 1e-4, "last key at the end")
	ok(_rot_track(a, "DEF-hips") >= 0, "every mapped bone has a track (holds the base pose)")
	(r[0] as Node).free()

func test_keys_without_bone_keep_base() -> void:
	var r := _rig()
	var base := MoveClips.base_pose(r[2], r[1], "Idle")
	var a := MoveClips.build(r[1], base, [{"t": 0.0, "armR": Vector3(-1.0, 0, 0)}, {"t": 0.25}, {"t": 0.5, "armR": Vector3(-1.0, 0, 0)}], 0.5)
	var t := _rot_track(a, "DEF-upper_arm.R")
	var mid: Quaternion = a.rotation_track_interpolate(t, 0.25)
	ok(mid.angle_to(base["DEF-upper_arm.R"]) < 0.05, "an unkeyed bone in a key returns to the base pose, not identity")
	ok(mid.angle_to(Quaternion.IDENTITY) > 0.01 or (base["DEF-upper_arm.R"] as Quaternion).angle_to(Quaternion.IDENTITY) < 0.01, "not snapped to identity")
	(r[0] as Node).free()

func test_unknown_bone_name_is_ignored() -> void:
	var r := _rig()
	var a := MoveClips.build(r[1], MoveClips.base_pose(r[2], r[1], "Idle"), [{"t": 0.0, "tail": Vector3.ONE}, {"t": 0.3}], 0.3)
	ok(a != null and a.get_track_count() > 0, "builds")
	(r[0] as Node).free()

func test_lunge_curve_metadata() -> void:
	var r := _rig()
	var a := MoveClips.build(r[1], MoveClips.base_pose(r[2], r[1], "Idle"), [{"t": 0.0}, {"t": 0.2, "lunge": 0.6}, {"t": 0.4}], 0.4)
	var c: PackedVector2Array = a.get_meta("lunge_curve")
	ok(c.size() == 3, "one point per key")
	near(MoveClips.lunge_at(a, 0.2), 0.6, 1e-4, "peak lunge")
	near(MoveClips.lunge_at(a, 0.4), 0.0, 1e-4, "back to zero by default")
	(r[0] as Node).free()
