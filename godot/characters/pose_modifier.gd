class_name PoseModifier
extends SkeletonModifier3D
# Procedural poses layered on top of the animation (port of the JS model's flight/power-up/dash/block code):
#  hover    upright, one knee drawn up, arms loose and a little out, a gentle bob and sway
#  flying   body nearly horizontal, one fist punched ahead, the other arm swept back, legs trailing, head up;
#           climbing tilts the body up, diving tips it down
#  charge   crouched, fists clenched at the sides, chest out, head back a little, a fine shake
#  dash     hard forward lean;  block  forearms crossed in front of the face;  kick  a front kick (one-shot)
# Rotations are given as in the JS model (x = pitch, z = roll; +x tips a hanging limb backwards) and applied in
# the frame of the parent body part, so a knee bends with its thigh however the body is tilted.

var fly := 0.0
var fast := 0.0
var climb := 0.0
var charge := 0.0
var dash := 0.0
var dash_side := 0.0
var dash_back := 0.0
var block := 0.0
var kick := 0.0
var style: Dictionary = MotionStyle.for_form("")
var lean := 0.0
var brake := 0.0
var landing := 0.0
var takeoff := 0.0
var surge_weight := 0.0
var cast := 0.0
var aim_pitch := 0.0
var strike := 0.0
var strike_kind := ""
var heavy_hit := 0.0
var hit_side := 0.0
var t := 0.0
var _ids: Dictionary = {}

func _bone(n: String) -> int:
	if not _ids.has(n):
		_ids[n] = get_skeleton().find_bone(n)
	return _ids[n]

## Rotates a bone by `euler` (JS-style x/y/z) expressed in `frame`; returns the bone's new frame.
func _turn(sk: Skeleton3D, bone: String, euler: Vector3, frame: Basis) -> Basis:
	var i := _bone(bone)
	if i < 0 or euler.is_zero_approx():
		return frame
	var q := frame * Basis.from_euler(euler) * frame.inverse()
	var g := sk.get_bone_global_pose(i)
	var parent := sk.get_bone_parent(i)
	var pg := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(i, (pg.inverse() * (q * g.basis)).get_rotation_quaternion())
	return frame * Basis.from_euler(euler)

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var k := fly; var hov := 1.0 - fast
	var bob := sin(t * 2.2); var sway := sin(t * 1.3)
	var body := Vector3.ZERO; var chest := Vector3.ZERO; var neck := Vector3.ZERO; var drop := 0.0
	var thigh: Dictionary[String, Vector3] = {"L": Vector3.ZERO, "R": Vector3.ZERO}; var shin: Dictionary[String, Vector3] = {"L": Vector3.ZERO, "R": Vector3.ZERO}
	var arm: Dictionary[String, Vector3] = {"L": Vector3.ZERO, "R": Vector3.ZERO}; var fore: Dictionary[String, Vector3] = {"L": Vector3.ZERO, "R": Vector3.ZERO}
	if k > 0.01:
		var up := maxf(0.0, climb)
		body.x += (fast * (1.3 - 0.75 * up) + maxf(0.0, -climb) * 0.5 * hov - up * 0.25 * hov) * k
		body.z += sway * 0.04 * hov * k
		drop -= bob * 0.035 * hov * k
		chest.x -= 0.18 * fast * k
		neck.x -= (0.95 * fast + 0.1 * hov) * k
		thigh.R += Vector3((-0.75 * hov + 0.08 * fast) * k, 0, -0.04 * hov * k); shin.R.x += (1.25 * hov + 0.12 * fast) * k
		thigh.L += Vector3((0.12 * hov + 0.16 * fast + bob * 0.04 * hov) * k, 0, 0.06 * hov * k); shin.L.x += (0.4 * hov + 0.08 * fast) * k
		var loose := hov * (1.0 - up)
		for s in ["L", "R"]:
			var sx := 1.0 if s == "L" else -1.0
			arm[s].z += sx * (0.28 + bob * 0.03) * loose * k
			fore[s].x -= 0.35 * loose * k
		var lead := maxf(fast, up)
		arm.R.x += (-2.75 - 0.5 * up) * lead * k; fore.R.x += 0.15 * lead * k
		arm.L.x += 0.45 * lead * k; arm.L.z += 0.12 * lead * k; fore.L.x -= 0.15 * lead * k
	if charge > 0.01:
		var c := charge; var shake := sin(t * 40.0) * 0.01
		drop += 0.1 * c
		for s in ["L", "R"]:
			var sx := 1.0 if s == "L" else -1.0
			thigh[s] += Vector3(-0.45 * c, 0, sx * 0.25 * c); shin[s].x += 0.8 * c
			arm[s] += Vector3(0.25 * c, 0, sx * 0.45 * c); fore[s].x -= 1.1 * c
		chest.x -= 0.25 * c + shake; neck.x -= 0.15 * c
	if dash > 0.01:
		body.x += 0.55 * dash; arm.L.x += 0.6 * dash; arm.R.x += 0.6 * dash
	if block > 0.01:
		var b := block
		arm.L += Vector3(-1.3 * b, 0, -0.35 * b); fore.L.x -= 1.6 * b
		arm.R += Vector3(-1.3 * b, 0, 0.35 * b); fore.R.x -= 1.6 * b
	if kick > 0.01:
		var kk := kick
		body.x -= 0.22 * kk
		thigh.R.x -= 1.55 * kk; shin.R.x += 0.15 * kk
		arm.L.x -= 0.4 * kk; arm.R.x += 0.5 * kk
	# Whole-body follow-through and recovery on top of authored clips.
	body.z -= lean
	body.x -= brake
	var weight: float = style.get("weight",1.0)
	var calm: float = style.get("calm",0.0)
	chest.x += float(style.get("stance",0))* (1.0-charge)
	arm.L.z += 0.08*calm; arm.R.z -= 0.08*calm
	var crouch := landing*weight + takeoff*0.15
	drop += crouch*0.14
	for side in ["L","R"]:
		thigh[side].x -= crouch*0.35
		shin[side].x += crouch*0.65
	# A controlled UI rise versus an explosive heavy-form power surge.
	var surge := surge_weight*(1.0-calm*0.65)
	chest.x -= surge*0.2
	for side in ["L","R"]:
		arm[side].x += surge*0.35
		fore[side].x -= surge*0.45
	# Beam wind-up: cupped hands drawn back, then both palms thrust forward.
	var release := maxf(0.0,strike) if strike_kind in ["beam","ultimate","avatar"] else 0.0
	var casting := maxf(cast,release)
	if casting>0.01:
		body.y += cast*0.28
		for side in ["L","R"]:
			var sx := 1.0 if side=="L" else -1.0
			arm[side].x -= casting*(1.45+aim_pitch)
			arm[side].z -= sx*casting*0.22
			fore[side].x -= cast*1.1*(1.0-release)
		chest.x += release*0.12
	elif strike_kind=="utility":
		arm.L.z += maxf(0,strike)*0.65
		arm.R.z -= maxf(0,strike)*0.65
		chest.x -= maxf(0,strike)*0.12
	elif strike_kind=="ki":
		arm.R.x -= maxf(0,strike)*(0.8+aim_pitch)
	elif strike_kind in ["jab","cross","hook"]:
		var twist := strike*(0.12 if strike_kind=="jab" else 0.28)
		chest.y += twist*(-1 if strike_kind=="jab" else 1)
		body.y -= twist*0.35
		neck.y -= twist*0.3
	body.x -= heavy_hit*0.18
	chest.z += hit_side*heavy_hit*0.2
	chest.x -= heavy_hit*0.22
	if dash>0.01:
		body.z += (lean-dash_side*0.3)*dash
		body.x += dash_back*0.7*dash
	# apply, parents first
	var hips := _bone("DEF-hips")
	if drop != 0.0 and hips >= 0:
		sk.set_bone_pose_position(hips, sk.get_bone_pose_position(hips) - Vector3(0, drop, 0))
	var f_body := _turn(sk, "DEF-hips", body, Basis.IDENTITY)
	var f_chest := _turn(sk, "DEF-spine.003", chest, f_body)
	_turn(sk, "DEF-neck", neck, f_chest)
	for s in ["L", "R"]:
		var f_arm := _turn(sk, "DEF-upper_arm." + s, arm[s], f_chest)
		_turn(sk, "DEF-forearm." + s, fore[s], f_arm)
		var f_thigh := _turn(sk, "DEF-thigh." + s, thigh[s], f_body)
		_turn(sk, "DEF-shin." + s, shin[s], f_thigh)
