# Dev: converts chosen clips of Quaternius's Universal Animation Library Pro (CC0; art/quaternius/ual_pro, outside the
# game folder; its own 65-bone UE-style rig) onto our DEF- rig and saves them as the "pro" animation library
# (res://assets/characters/ual/pro.res). Each bone's world-space motion is kept and re-based onto our bone's rest
# orientation; the hips' travel is scaled by hip height. Only rotations + hips/root positions, like the base library.
#   godot --headless --path godot -s res://tools_bake_anims.gd
extends SceneTree

const CLIPS := ["Hit_Stomach", "Hit_Shoulder_L", "Hit_Shoulder_R", "Death02", "Kick", "Dodge_Left", "Dodge_Right",
	"Celebration", "BackFlip", "Idle_Tired_Loop", "Idle_LookAround_Loop", "PunchKick_Enter", "PunchKick_Exit",
	"Spell_Double_Enter", "Spell_Double_Idle_Loop", "Spell_Double_Shoot_Loop", "Spell_Double_Exit", "Jog_Bwd_Loop",
	"Jog_Left_Loop", "Jog_Right_Loop", "Sprint_Enter", "Sprint_Exit", "Roll", "Turn90_L", "Turn90_R", "Crying",
	"GroundSit_Idle_Loop", "Climb_Idle_Loop"]
const FPS := 30.0

func _initialize() -> void:
	var src_path := ProjectSettings.globalize_path("res://").path_join("../art/quaternius/ual_pro/Unreal-Godot/UAL1.glb")
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	if doc.append_from_file(src_path, st) != OK:
		push_error("missing " + src_path); quit(); return
	var src: Node = doc.generate_scene(st)
	var sn: Skeleton3D = src.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
	var ours_scene: Node = (load("res://assets/characters/ual/AnimationLibrary_Godot_Standard.gltf") as PackedScene).instantiate()
	var so: Skeleton3D = ours_scene.find_children("*", "Skeleton3D", true, false)[0]
	var our_ap: AnimationPlayer = ours_scene.find_children("*", "AnimationPlayer", true, false)[0]
	var prefix := str(our_ap.get_animation("Idle").track_get_path(0)).get_slice(":", 0)
	# our bone -> their bone (skip fingertip/ball leaves: they fold onto the last joint, which the real joint drives)
	var map := HeroBody.bone_map()
	var theirs := {}
	for k: String in map:
		if not k.contains("leaf") and sn.find_bone(k) >= 0:
			theirs[map[k]] = sn.find_bone(k)
	# rest offsets: our global rest rotation = their global rest rotation * C
	var C := {}
	for i in so.get_bone_count():
		var n := so.get_bone_name(i)
		if theirs.has(n):
			C[i] = sn.get_bone_global_rest(theirs[n]).basis.get_rotation_quaternion().inverse() * so.get_bone_global_rest(i).basis.get_rotation_quaternion()
	var their_hips: int = theirs["DEF-hips"]
	var our_hips := so.find_bone("DEF-hips")
	var hip_scale := so.get_bone_global_rest(our_hips).origin.y / sn.get_bone_global_rest(their_hips).origin.y
	var lib := AnimationLibrary.new()
	for clip: String in CLIPS:
		if not ap.has_animation(clip):
			print("skip ", clip); continue
		var a := ap.get_animation(clip)
		var out := Animation.new()
		out.length = a.length
		out.loop_mode = Animation.LOOP_LINEAR if clip.ends_with("_Loop") else Animation.LOOP_NONE
		var rot_track := {}
		for i in so.get_bone_count():
			if C.has(i):
				var t := out.add_track(Animation.TYPE_ROTATION_3D)
				out.track_set_path(t, prefix + ":" + so.get_bone_name(i))
				rot_track[i] = t
		var hip_t := out.add_track(Animation.TYPE_POSITION_3D)
		out.track_set_path(hip_t, prefix + ":DEF-hips")
		var frames := maxi(2, ceili(a.length * FPS) + 1)
		for f in frames:
			var time := minf(a.length, float(f) / FPS)
			var tg := _pose(sn, a, time)
			var our_global := {}
			for i in so.get_bone_count():
				var parent := so.get_bone_parent(i)
				var pg: Quaternion = our_global[parent] if parent >= 0 else Quaternion.IDENTITY
				var g: Quaternion
				if C.has(i):
					g = (tg[theirs[so.get_bone_name(i)]] as Transform3D).basis.get_rotation_quaternion() * (C[i] as Quaternion)
					out.rotation_track_insert_key(rot_track[i], time, (pg.inverse() * g).normalized())
				else:
					g = pg * so.get_bone_rest(i).basis.get_rotation_quaternion()
				our_global[i] = g
			var travel := (tg[their_hips] as Transform3D).origin - sn.get_bone_global_rest(their_hips).origin
			var to_parent := so.get_bone_global_rest(so.get_bone_parent(our_hips)).basis.inverse()   # hips key in root space
			out.position_track_insert_key(hip_t, time, so.get_bone_rest(our_hips).origin + to_parent * (travel * hip_scale))
		lib.add_animation(clip, out)
		print("baked ", clip, " ", snappedf(a.length, 0.01), " s")
	ResourceSaver.save(lib, "res://assets/characters/ual/pro.res")
	src.free(); ours_scene.free()
	quit()

## Their skeleton's global bone transforms at `time` (tracks sampled directly and chained parent-to-child here:
## an off-tree Skeleton3D doesn't refresh its global poses).
func _pose(sk: Skeleton3D, a: Animation, time: float) -> Array:
	var local: Array = []
	for i in sk.get_bone_count():
		local.append(sk.get_bone_rest(i))
	var rot := {}; var pos := {}
	for t in a.get_track_count():
		var bone := sk.find_bone(str(a.track_get_path(t)).get_slice(":", 1))
		if bone < 0:
			continue
		match a.track_get_type(t):
			Animation.TYPE_ROTATION_3D: rot[bone] = a.rotation_track_interpolate(t, time)
			Animation.TYPE_POSITION_3D: pos[bone] = a.position_track_interpolate(t, time)
	var out: Array = []
	out.resize(sk.get_bone_count())
	for i in sk.get_bone_count():
		var l: Transform3D = local[i]
		if rot.has(i): l.basis = Basis(rot[i] as Quaternion)
		if pos.has(i): l.origin = pos[i]
		var parent := sk.get_bone_parent(i)
		out[i] = l if parent < 0 else (out[parent] as Transform3D) * l
	return out
