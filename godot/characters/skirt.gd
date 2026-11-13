class_name Skirt
extends RefCounted
# Dress skirts (outfits Dress / LongDress, or outfitParts skirt on any outfit): two halves hung from the hips at the
# hip joints. Each frame a half swings forward/back with its own thigh (most of the swing, not the sideways spread of
# the stance), so the hem follows the legs when walking or kicking instead of the legs cutting through a rigid tube;
# standing, the halves close into one A-line skirt. Built round the fighter's real hip joints (HeroBody bodies differ
# from the mannequin); meshes are cached per joint position and length. No allocations per frame.

const COLS := 14   # round half the body, front centre to back centre (plus the overlap)
const ROWS := 8
const FOLLOW := 0.45   # how much of the thigh's forward/back swing a half follows
const FOLLOW_BACK := 0.8   # a leg stretched back in a stride takes its half further (it poked out behind long hems)
const FOLLOW_SIDE := 0.75   # ...and of its sideways spread
const OVERLAP := 0.45   # radians each half reaches past the front/back centre line (no slit at rest or in a stride)

## Adds the skirt for an outfit's parts ({skirt: colour, skirtLen: metres below the hip joint, about 0.42 knee,
## 0.66 mid-shin, 0.84 ankle}). The halves go into f.skirt (Skirt.update swings them).
static func dress(f: Fighter, parts: Dictionary) -> void:
	if not parts.has("skirt"):
		return
	var length := clampf(float(parts.get("skirtLen", 0.42)), 0.15, 0.9)
	var mat := Parts.material(Parts.hx(parts.skirt), 0.75, 0.0, true)
	var hips := f.skeleton.find_bone("DEF-hips")
	if hips < 0:
		return
	for s: int in [1, -1]:
		var thigh := f.skeleton.find_bone("DEF-thigh." + ("L" if s > 0 else "R"))
		if thigh < 0:
			continue
		var joint := f.skeleton.get_bone_global_rest(thigh).origin   # the body's own hip joint (model space, rest)
		var shift: Vector3 = f._joint_shift.get("DEF-hips", Vector3.ZERO)
		var key := "skirt%d_%.3f_%.3f_%.2f" % [s, absf(joint.x), joint.z, length]
		var mesh := Parts._mesh(key, func(g: Geo) -> void: _half(g, s, absf(joint.x), joint.z, length))
		# add_piece adds the hips' joint shift to the frame: hand it the mannequin-space point so it lands on our joint
		var mi := f.add_piece("DEF-hips", Transform3D(Basis.IDENTITY, joint - shift), mesh, mat)
		# the halves swing about the waist at the body's centre line, so the waistband stays put and the hem opens out
		f.skirt.append([mi, mi.transform, thigh, hips, Vector3(-s * absf(joint.x), 0.045, -0.035 - joint.z)])

## Swings each half with its thigh (call once per frame after the animation is posed).
static func update(f: Fighter) -> void:
	for h: Array in f.skirt:
		var mi: MeshInstance3D = h[0]
		var thigh: int = h[2]
		var hips: int = h[3]
		var hr := f.skeleton.get_bone_global_rest(hips).basis
		var posed := f.skeleton.get_bone_global_pose(hips).basis.inverse() * f.skeleton.get_bone_global_pose(thigh).basis
		var rest := hr.inverse() * f.skeleton.get_bone_global_rest(thigh).basis
		var a := angles(hr, posed, rest)
		var base: Transform3D = h[1]
		var pivot: Vector3 = h[4]
		var rot := Basis(Vector3.BACK, a.y * FOLLOW_SIDE) * Basis(Vector3.RIGHT, -a.x * (FOLLOW if a.x > 0.0 else FOLLOW_BACK))
		mi.transform = base * Transform3D(rot, pivot - rot * pivot)

## The thigh's swing relative to the hips (radians): x = forward/back (+ = forward), y = sideways (+ = towards +X).
## `hr` is the hips' rest basis, `posed` / `rest` the thigh's basis in the hips' frame now and at rest.
static func angles(hr: Basis, posed: Basis, rest: Basis) -> Vector2:
	var d := hr * (posed * rest.inverse()) * hr.inverse() * Vector3.DOWN   # where the rest-pose "down" leg points now
	return Vector2(atan2(d.z, -d.y), atan2(d.x, -d.y))

## One half (side s: +1 = +X) in joint-local space: waist above the joint, widest at the hips, then an A-line flare.
static func _half(g: Geo, s: int, jx: float, jz: float, length: float) -> void:
	var cz := -0.035 - jz   # the body's front/back centre at hip height, relative to the joint
	# profile rows: [y relative to the joint, half width, half depth]
	var prof := [[0.045, 0.165, 0.118], [-0.03, 0.232, 0.142], [-length, 0.215 + 0.12 * length, 0.15 + 0.08 * length]]
	var pts := PackedVector3Array()
	for r in ROWS + 1:
		var t := float(r) / ROWS
		var a: Array
		var b: Array
		var k: float
		if t < 0.2:   # waist to hips
			a = prof[0]; b = prof[1]; k = t / 0.2
		else:
			a = prof[1]; b = prof[2]; k = (t - 0.2) / 0.8
		var y := lerpf(float(a[0]), float(b[0]), k)
		var rx := lerpf(float(a[1]), float(b[1]), k)
		var rz := lerpf(float(a[2]), float(b[2]), k)
		for c in COLS + 1:
			var th := lerpf(-OVERLAP, PI + OVERLAP, float(c) / COLS)   # 0 = front centre, PI = back centre
			var inset := 1.0 - 0.025 * clampf(maxf(-th, th - PI) / 0.1, 0.0, 1.0)   # the overlap tucks under the other half (no z-fighting)
			pts.append(Vector3(-s * jx + s * sin(th) * rx * inset, y, cz + cos(th) * rz * inset))
	g.grid(pts, COLS, ROWS)
