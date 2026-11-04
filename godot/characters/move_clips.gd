class_name MoveClips
extends RefCounted
# Fight flow (2026-11-04): turns compact key-pose tables into real Godot Animations for the fighter rig, so every
# move has proper wind-up, strike, follow-through and recovery with eased, interpolated motion (and blends in the
# AnimationTree like any imported clip). Offsets are Euler angles (radians) in each bone's own local frame, applied on
# top of a base pose sampled from an existing clip (normally "Idle"). A bone missing from a key returns to the base
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

## Each mapped bone's local rotation at the start of `clip` (falls back to the skeleton's rest pose).
static func base_pose(player: AnimationPlayer, skeleton: Skeleton3D, clip: String) -> Dictionary:
	var out := {}
	var a: Animation = player.get_animation(clip) if player != null and player.has_animation(clip) else null
	for short: String in BONES:
		var bone: String = BONES[short]
		var i := skeleton.find_bone(bone)
		if i < 0:
			continue
		var q := skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
		if a != null:
			var t := _track(a, bone, Animation.TYPE_ROTATION_3D)
			if t >= 0:
				q = a.rotation_track_interpolate(t, 0.0)
		out[bone] = q
	out["_prefix"] = _prefix(a) if a != null else "Rig/Skeleton3D"
	return out

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
static func build(skeleton: Skeleton3D, base: Dictionary, keys: Array, length: float, loop := false) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var prefix := str(base.get("_prefix", "Rig/Skeleton3D"))
	var sorted := keys.duplicate()
	sorted.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.t) < float(y.t))
	for short: String in BONES:
		var bone: String = BONES[short]
		if not base.has(bone) or skeleton.find_bone(bone) < 0:
			continue
		var rest: Quaternion = base[bone]
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("%s:%s" % [prefix, bone]))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
		var poses: Array[Quaternion] = []
		for k: Dictionary in sorted:
			var off: Vector3 = k.get(short, Vector3.ZERO)
			poses.append(rest * Quaternion.from_euler(off))
		for i in sorted.size():
			var t0 := float(sorted[i].t)
			if i == sorted.size() - 1:
				a.rotation_track_insert_key(t, minf(t0, length), poses[i])
				break
			var t1 := float(sorted[i + 1].t)
			var kind := str(sorted[i + 1].get("ease", "inout"))
			for s in STEPS:
				var x := float(s) / STEPS
				a.rotation_track_insert_key(t, t0 + (t1 - t0) * x, poses[i].slerp(poses[i + 1], _ease(kind, x)))
	var curve := PackedVector2Array()
	for k: Dictionary in sorted:
		curve.append(Vector2(float(k.t), float(k.get("lunge", 0.0))))
	a.set_meta("lunge_curve", curve)
	return a

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
