class_name MoveClips
extends RefCounted
# Fight flow (2026-11-04): turns compact key-pose tables into real Godot Animations for the fighter rig, so every
# move has proper wind-up, strike, follow-through and recovery with eased, interpolated motion (and blends in the
# AnimationTree like any imported clip). Offsets are Euler angles (radians) in the body-part frames of ORDER (the
# PoseModifier convention), applied on top of a base pose sampled from an existing clip (normally "Idle"). A bone missing from a key returns to the base
# pose at that key. Keys may carry "lunge" (metres the body travels forward); it is stored as clip metadata for the
# Fighter to apply as visual root motion.

const BONES := {
	"hips": "DEF-hips", "spine": "DEF-spine.001", "spine2": "DEF-spine.002", "chest": "DEF-spine.003", "neck": "DEF-neck",
	"head": "DEF-head", "shoulderL": "DEF-shoulder.L", "shoulderR": "DEF-shoulder.R",
	"armL": "DEF-upper_arm.L", "armR": "DEF-upper_arm.R", "foreL": "DEF-forearm.L", "foreR": "DEF-forearm.R",
	"handL": "DEF-hand.L", "handR": "DEF-hand.R", "thighL": "DEF-thigh.L", "thighR": "DEF-thigh.R",
	"shinL": "DEF-shin.L", "shinR": "DEF-shin.R", "footL": "DEF-foot.L", "footR": "DEF-foot.R",
}
const STEPS := 4   # baked sub-keys per segment, so the easing survives linear interpolation

## Every bone's local rotation at the start of `clip` (falls back to the skeleton's rest pose).
static func base_pose(player: AnimationPlayer, skeleton: Skeleton3D, clip: String) -> Dictionary:
	var out := {}
	var a: Animation = player.get_animation(clip) if player != null and player.has_animation(clip) else null
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		var q := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		if a != null:
			var t := _track(a, bone, Animation.TYPE_ROTATION_3D)
			if t >= 0:
				q = a.rotation_track_interpolate(t, 0.0)
		out[bone] = q
	out["_prefix"] = _prefix(a) if a != null else "Rig/Skeleton3D"
	return out

# offset frames, parents first (same convention as PoseModifier): [short, frame-from short ("" = model frame)]
const ORDER := [["hips", ""], ["spine", "hips"], ["chest", "hips"], ["neck", "chest"], ["head", "neck"],
	["shoulderL", "chest"], ["shoulderR", "chest"], ["armL", "chest"], ["armR", "chest"], ["foreL", "armL"], ["foreR", "armR"],
	["handL", "foreL"], ["handR", "foreR"], ["thighL", "hips"], ["thighR", "hips"], ["shinL", "thighL"], ["shinR", "thighR"],
	["footL", "shinL"], ["footR", "shinR"]]

## The local rotations for one key pose: each offset is an Euler rotation expressed in the frame of the body part
## named in ORDER (so +x tips a hanging limb backwards, -1.5 on an arm lifts it straight ahead, as in PoseModifier).
static func pose(skeleton: Skeleton3D, base: Dictionary, key: Dictionary) -> Dictionary:
	var local := {}
	for i in skeleton.get_bone_count():
		local[i] = base.get(skeleton.get_bone_name(i), Quaternion.IDENTITY)
	var frames := {"": Basis.IDENTITY}
	for entry: Array in ORDER:
		var short: String = entry[0]
		var bone: String = BONES[short]
		var i := skeleton.find_bone(bone)
		var parent_frame: Basis = frames.get(entry[1], Basis.IDENTITY)
		var off: Vector3 = key.get(short, Vector3.ZERO)
		frames[short] = parent_frame * Basis.from_euler(off)
		if i < 0 or off.is_zero_approx():
			continue
		var g := _global(skeleton, local, i)
		var p := skeleton.get_bone_parent(i)
		var pg := _global(skeleton, local, p) if p >= 0 else Basis.IDENTITY
		var turn := parent_frame * Basis.from_euler(off) * parent_frame.inverse()
		local[i] = (pg.inverse() * (turn * g)).get_rotation_quaternion()
	var out := {}
	for i: int in local:
		out[skeleton.get_bone_name(i)] = local[i]
	return out

static func _global(skeleton: Skeleton3D, local: Dictionary, i: int) -> Basis:
	var b := Basis.IDENTITY
	while i >= 0:
		b = Basis(local[i] as Quaternion) * b
		i = skeleton.get_bone_parent(i)
	return b

static func _track(a: Animation, bone: String, type: int) -> int:
	for t in a.get_track_count():
		if a.track_get_type(t) == type and str(a.track_get_path(t)).ends_with(":" + bone):
			return t
	return -1

static func _prefix(a: Animation) -> String:
	for t in a.get_track_count():
		var p := str(a.track_get_path(t))
		if p.contains(":"):
			return p.split(":")[0]
	return "Rig/Skeleton3D"

static func _ease(kind: String, x: float) -> float:
	match kind:
		"in": return x * x
		"out": return 1.0 - (1.0 - x) * (1.0 - x)
		"linear": return x
	return x * x * (3.0 - 2.0 * x)   # inout (default)

## A clip from key poses: keys = [{"t": seconds, "ease": "in|out|inout|linear", <short bone>: Vector3, "lunge": m}, ...]
static func build(skeleton: Skeleton3D, base: Dictionary, keys: Array, length: float, loop := false, held := {}) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var prefix := str(base.get("_prefix", "Rig/Skeleton3D"))
	var sorted := keys.duplicate()
	sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.t) < float(y.t))
	var key_poses: Array[Dictionary] = []
	for k: Dictionary in sorted:
		key_poses.append(pose(skeleton, base, k))
	for short: String in BONES:
		var bone: String = BONES[short]
		if not base.has(bone) or skeleton.find_bone(bone) < 0:
			continue
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("%s:%s" % [prefix, bone]))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		for i in sorted.size():
			var q0: Quaternion = key_poses[i][bone]
			var t0 := float(sorted[i].t)
			if i == sorted.size() - 1:
				a.rotation_track_insert_key(t, minf(t0, length), q0)
				break
			var q1: Quaternion = key_poses[i + 1][bone]
			var t1 := float(sorted[i + 1].t)
			var kind := str(sorted[i + 1].get("ease", "inout"))
			for s in STEPS:
				var x := float(s) / STEPS
				a.rotation_track_insert_key(t, t0 + (t1 - t0) * x, q0.slerp(q1, _ease(kind, x)))
	# bones held still for the whole clip (e.g. fingers closed into fists): bone name -> local Quaternion
	for bone: String in held:
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("%s:%s" % [prefix, bone]))
		a.rotation_track_insert_key(t, 0.0, held[bone])
		a.rotation_track_insert_key(t, length, held[bone])
	var curve := PackedVector2Array()
	for k: Dictionary in sorted:
		curve.append(Vector2(float(k.t), float(k.get("lunge", 0.0))))
	a.set_meta("lunge_curve", curve)
	return a

## Finger and thumb rotations of `clip` at time t (e.g. the fists of a punch clip), for MoveClips.build's `held`.
static func hand_pose(player: AnimationPlayer, clip: String, t: float) -> Dictionary:
	var out := {}
	var a: Animation = player.get_animation(clip) if player.has_animation(clip) else null
	if a == null:
		return out
	for i in a.get_track_count():
		var p := str(a.track_get_path(i))
		if a.track_get_type(i) == Animation.TYPE_ROTATION_3D and (p.contains(":DEF-f_") or p.contains(":DEF-thumb")):
			out[p.split(":")[1]] = a.rotation_track_interpolate(i, t)
	return out

## Visual forward travel (metres) at time t of a clip built here (0 for clips without a lunge curve).
static func lunge_at(a: Animation, t: float) -> float:
	if a == null or not a.has_meta("lunge_curve"):
		return 0.0
	var c: PackedVector2Array = a.get_meta("lunge_curve")
	if c.is_empty():
		return 0.0
	if t <= c[0].x:
		return c[0].y
	for i in range(1, c.size()):
		if t <= c[i].x:
			var x := (t - c[i - 1].x) / maxf(1e-5, c[i].x - c[i - 1].x)
			return lerpf(c[i - 1].y, c[i].y, x * x * (3.0 - 2.0 * x))
	return c[-1].y
