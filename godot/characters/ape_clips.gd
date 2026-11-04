class_name ApeClips
extends RefCounted
# The Great Ape's animations (2026-11-04 rebuild), written as key poses on ApeBody's skeleton and baked into
# eased Animations. Bone rests have identity rotations, so offsets are model-axis Euler angles: x - swings a hanging
# limb forward, z + swings a left limb out (- for right), y twists. "hips_y" moves the whole body up/down; "contact"
# marks the impact time of strikes (ground shake + dust).

const PATH := "ApeRig/Skeleton3D:"
const STEPS := 4

static var _lib: AnimationLibrary
static var _data: Dictionary = {}

static func _sym(arm: Vector3, fore: Vector3, extra := {}) -> Dictionary:
	var d := {"arm.L": arm, "arm.R": Vector3(arm.x, -arm.y, -arm.z), "forearm.L": fore, "forearm.R": Vector3(fore.x, -fore.y, -fore.z)}
	d.merge(extra, true)
	return d

## name -> {"length", "loop", "contact", "keys": [[t, ease, pose], ...]}
static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	var V := func(x: float, y := 0.0, z := 0.0) -> Vector3: return Vector3(x, y, z)
	# the resting stance: hunched forward, knees bent, arms hanging forward with the knuckles low
	var stand := _sym(V.call(-0.15, 0, 0.12), V.call(-0.25), {"spine2": V.call(0.12), "chest": V.call(0.12), "neck": V.call(-0.2),
		"head": V.call(-0.08), "thigh.L": V.call(-0.25, 0, 0.06), "thigh.R": V.call(-0.25, 0, -0.06), "shin.L": V.call(0.4), "shin.R": V.call(0.4),
		"foot.L": V.call(-0.15), "foot.R": V.call(-0.15), "tail1": V.call(0.2), "tail2": V.call(0.1, 0.2), "tail3": V.call(0.0, 0.2), "hips_y": -0.05})
	var with := func(extra: Dictionary) -> Dictionary:
		var d := stand.duplicate()
		for k: String in extra:
			d[k] = (d.get(k, Vector3.ZERO) if k != "hips_y" else d.get(k, 0.0)) + extra[k]
		return d
	var stepL: Dictionary = with.call({"thigh.L": V.call(-0.55), "shin.L": V.call(0.5), "thigh.R": V.call(0.35), "shin.R": V.call(0.15),
		"arm.L": V.call(0.4), "arm.R": V.call(-0.55), "forearm.R": V.call(-0.2), "chest": V.call(0.0, 0.14), "spine1": V.call(0, -0.08, 0.05),
		"head": V.call(0, -0.1), "tail2": V.call(0, -0.25), "hips_y": -0.02})
	var stepR: Dictionary = with.call({"thigh.R": V.call(-0.55), "shin.R": V.call(0.5), "thigh.L": V.call(0.35), "shin.L": V.call(0.15),
		"arm.R": V.call(0.4), "arm.L": V.call(-0.55), "forearm.L": V.call(-0.2), "chest": V.call(0.0, -0.14), "spine1": V.call(0, 0.08, -0.05),
		"head": V.call(0, 0.1), "tail2": V.call(0, 0.25), "hips_y": -0.02})
	var passing: Dictionary = with.call({"hips_y": 0.05, "shin.L": V.call(0.2), "shin.R": V.call(0.2)})
	var roar: Dictionary = with.call({"chest": V.call(-0.45), "spine2": V.call(-0.2), "neck": V.call(-0.35), "head": V.call(-0.45), "jaw": V.call(0.55),
		"arm.L": V.call(-0.5, 0, 0.95), "arm.R": V.call(-0.5, 0, -0.95), "forearm.L": V.call(-0.9), "forearm.R": V.call(-0.9),
		"tail2": V.call(-0.4), "tail3": V.call(-0.4), "hips_y": 0.06})
	_data = {
		"idle": {"length": 2.4, "loop": true, "contact": -1.0, "keys": [[0.0, "inout", stand],
			[1.2, "inout", with.call({"chest": V.call(-0.05), "spine2": V.call(-0.03), "head": V.call(0.04), "arm.L": V.call(0.05, 0, 0.03),
				"arm.R": V.call(0.05, 0, -0.03), "tail3": V.call(0.0, -0.3), "tail4": V.call(0.0, -0.3), "hips_y": 0.015})], [2.4, "inout", stand]]},
		"walk": {"length": 1.1, "loop": true, "contact": -1.0, "keys": [[0.0, "inout", stepL], [0.275, "inout", passing], [0.55, "inout", stepR],
			[0.825, "inout", passing], [1.1, "inout", stepL]]},
		"roar": {"length": 1.6, "loop": true, "contact": -1.0, "keys": [[0.0, "inout", roar],
			[0.8, "inout", with.call({"chest": V.call(-0.5, 0.05), "spine2": V.call(-0.22), "neck": V.call(-0.4), "head": V.call(-0.5, 0.1),
				"jaw": V.call(0.65), "arm.L": V.call(-0.55, 0, 1.0), "arm.R": V.call(-0.55, 0, -1.0), "forearm.L": V.call(-1.0),
				"forearm.R": V.call(-1.0), "tail2": V.call(-0.45), "tail3": V.call(-0.5), "hips_y": 0.07})], [1.6, "inout", roar]]},
		"chest_pound": {"length": 1.5, "loop": false, "contact": 0.35, "keys": [[0.0, "inout", stand],
			[0.2, "out", with.call({"chest": V.call(-0.35), "head": V.call(-0.35), "jaw": V.call(0.35), "arm.L": V.call(-1.6, 0, 0.6),
				"forearm.L": V.call(-1.2), "arm.R": V.call(-0.6, 0, -0.4)})],
			[0.35, "in", with.call({"chest": V.call(-0.3), "head": V.call(-0.3), "jaw": V.call(0.35), "arm.L": V.call(-1.1, 0, -0.25),
				"forearm.L": V.call(-1.7), "arm.R": V.call(-1.6, 0, -0.6), "forearm.R": V.call(-1.2)})],
			[0.55, "in", with.call({"chest": V.call(-0.3), "head": V.call(-0.3), "jaw": V.call(0.4), "arm.R": V.call(-1.1, 0, 0.25),
				"forearm.R": V.call(-1.7), "arm.L": V.call(-1.6, 0, 0.6), "forearm.L": V.call(-1.2)})],
			[0.75, "in", with.call({"chest": V.call(-0.3), "head": V.call(-0.3), "jaw": V.call(0.4), "arm.L": V.call(-1.1, 0, -0.25),
				"forearm.L": V.call(-1.7), "arm.R": V.call(-1.6, 0, -0.6), "forearm.R": V.call(-1.2)})],
			[0.95, "in", with.call({"chest": V.call(-0.3), "head": V.call(-0.3), "jaw": V.call(0.4), "arm.R": V.call(-1.1, 0, 0.25),
				"forearm.R": V.call(-1.7), "arm.L": V.call(-1.6, 0, 0.6), "forearm.L": V.call(-1.2)})],
			[1.5, "inout", stand]]},
		"stomp": {"length": 1.1, "loop": false, "contact": 0.55, "keys": [[0.0, "inout", stand],
			[0.38, "out", with.call({"thigh.R": V.call(-1.3, 0, -0.15), "shin.R": V.call(1.1), "spine1": V.call(-0.1, 0, 0.12), "chest": V.call(-0.15),
				"arm.L": V.call(0, 0, 0.6), "arm.R": V.call(-0.3, 0, -0.5), "head": V.call(-0.15), "hips_y": 0.08})],
			[0.55, "in", with.call({"thigh.R": V.call(-0.35, 0, -0.1), "shin.R": V.call(0.3), "spine1": V.call(0.15), "chest": V.call(0.25),
				"thigh.L": V.call(-0.3), "shin.L": V.call(0.6), "arm.L": V.call(0.2, 0, 0.5), "arm.R": V.call(0.2, 0, -0.5), "hips_y": -0.12})],
			[1.1, "inout", stand]]},
		"swipe": {"length": 0.95, "loop": false, "contact": 0.42, "keys": [[0.0, "inout", stand],
			[0.28, "out", with.call({"arm.R": V.call(0.5, 0, -1.1), "forearm.R": V.call(-0.4), "chest": V.call(0, -0.45), "spine1": V.call(0, -0.2),
				"head": V.call(0, 0.25), "arm.L": V.call(-0.6, 0, 0.3)})],
			[0.42, "in", with.call({"arm.R": V.call(-1.35, 0, 0.55), "forearm.R": V.call(-0.15), "chest": V.call(0.2, 0.5), "spine1": V.call(0.1, 0.25),
				"head": V.call(0, -0.2), "arm.L": V.call(0.3, 0, 0.5), "thigh.R": V.call(-0.4), "shin.R": V.call(0.5)})],
			[0.55, "out", with.call({"arm.R": V.call(-1.25, 0, 0.75), "forearm.R": V.call(-0.15), "chest": V.call(0.22, 0.55), "spine1": V.call(0.1, 0.27),
				"head": V.call(0, -0.2), "arm.L": V.call(0.3, 0, 0.5)})],
			[0.95, "inout", stand]]},
		"grab_slam": {"length": 1.4, "loop": false, "contact": 0.78, "keys": [[0.0, "inout", stand],
			[0.45, "out", _merge(with.call({"chest": V.call(-0.35), "spine2": V.call(-0.15), "head": V.call(-0.3), "jaw": V.call(0.3), "hips_y": 0.08}),
				_sym(V.call(-2.7, 0, 0.3), V.call(-0.4)))],
			[0.78, "in", _merge(with.call({"chest": V.call(0.6), "spine2": V.call(0.25), "spine1": V.call(0.15), "head": V.call(0.15),
				"thigh.L": V.call(-0.5), "thigh.R": V.call(-0.5), "shin.L": V.call(0.8), "shin.R": V.call(0.8), "hips_y": -0.16}), _sym(V.call(-0.7, 0, -0.15), V.call(-0.1)))],
			[1.0, "out", _merge(with.call({"chest": V.call(0.62), "spine2": V.call(0.26), "spine1": V.call(0.15), "thigh.L": V.call(-0.5),
				"thigh.R": V.call(-0.5), "shin.L": V.call(0.8), "shin.R": V.call(0.8), "hips_y": -0.16}), _sym(V.call(-0.65, 0, -0.15), V.call(-0.1)))],
			[1.4, "inout", stand]]},
		"mouth_blast": {"length": 1.3, "loop": false, "contact": 0.55, "keys": [[0.0, "inout", stand],
			[0.4, "out", with.call({"chest": V.call(-0.4), "neck": V.call(-0.3), "head": V.call(-0.45), "jaw": V.call(0.25),
				"arm.L": V.call(0.4, 0, 0.6), "arm.R": V.call(0.4, 0, -0.6), "forearm.L": V.call(-0.8), "forearm.R": V.call(-0.8), "hips_y": 0.04})],
			[0.55, "in", with.call({"chest": V.call(0.3), "neck": V.call(0.2), "head": V.call(0.25), "jaw": V.call(0.75),
				"arm.L": V.call(0.5, 0, 0.7), "arm.R": V.call(0.5, 0, -0.7), "thigh.L": V.call(-0.35), "shin.L": V.call(0.4), "hips_y": -0.04})],
			[0.95, "inout", with.call({"chest": V.call(0.25), "neck": V.call(0.15), "head": V.call(0.2), "jaw": V.call(0.7),
				"arm.L": V.call(0.45, 0, 0.65), "arm.R": V.call(0.45, 0, -0.65), "hips_y": -0.03})],
			[1.3, "inout", stand]]},
		"hurt": {"length": 0.65, "loop": false, "contact": -1.0, "keys": [[0.0, "inout", stand],
			[0.12, "out", with.call({"chest": V.call(-0.45, 0.15), "head": V.call(-0.5, 0.2), "jaw": V.call(0.35), "arm.L": V.call(-0.7, 0, 0.8),
				"arm.R": V.call(-0.5, 0, -0.9), "spine1": V.call(-0.15), "hips_y": 0.03})], [0.65, "inout", stand]]},
		"transform_in": {"length": 1.5, "loop": false, "contact": 0.9, "keys": [
			[0.0, "inout", with.call({"thigh.L": V.call(-0.9), "thigh.R": V.call(-0.9), "shin.L": V.call(1.5), "shin.R": V.call(1.5), "chest": V.call(0.6),
				"spine2": V.call(0.3), "head": V.call(0.3), "arm.L": V.call(-0.4, 0, -0.2), "arm.R": V.call(-0.4, 0, 0.2), "hips_y": -0.32})],
			[0.9, "out", roar], [1.5, "inout", stand]]},
	}
	return _data

static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k: String in b:
		out[k] = (out.get(k, Vector3.ZERO) as Vector3) + (b[k] as Vector3)
	return out

static func _ease(kind: String, x: float) -> float:
	match kind:
		"in": return x * x
		"out": return 1.0 - (1.0 - x) * (1.0 - x)
	return x * x * (3.0 - 2.0 * x)

static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	var lib := AnimationLibrary.new()
	for clip: String in data():
		var d: Dictionary = data()[clip]
		var a := Animation.new()
		a.length = float(d.length)
		a.loop_mode = Animation.LOOP_LINEAR if d.loop else Animation.LOOP_NONE
		var keys: Array = d["keys"]
		for b: Array in ApeBody.BONES:
			var bone: String = b[0]
			var t := a.add_track(Animation.TYPE_ROTATION_3D)
			a.track_set_path(t, NodePath(PATH + bone))
			for i in keys.size():
				var q0 := Quaternion.from_euler((keys[i][2] as Dictionary).get(bone, Vector3.ZERO))
				if i == keys.size() - 1:
					a.rotation_track_insert_key(t, float(keys[i][0]), q0)
					break
				var q1 := Quaternion.from_euler((keys[i + 1][2] as Dictionary).get(bone, Vector3.ZERO))
				var t0 := float(keys[i][0]); var t1 := float(keys[i + 1][0])
				for s in STEPS:
					var x := float(s) / STEPS
					a.rotation_track_insert_key(t, t0 + (t1 - t0) * x, q0.slerp(q1, _ease(str(keys[i + 1][1]), x)))
		var hp := a.add_track(Animation.TYPE_POSITION_3D)
		a.track_set_path(hp, NodePath(PATH + "hips"))
		var hips_rest := ApeBody.pos("hips")
		for i in keys.size():
			a.position_track_insert_key(hp, float(keys[i][0]), hips_rest + Vector3(0, float((keys[i][2] as Dictionary).get("hips_y", 0.0)), 0))
		lib.add_animation(clip, a)
	_lib = lib
	return lib
