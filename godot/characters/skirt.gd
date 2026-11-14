class_name Skirt
extends RefCounted
# Dress skirts (outfits Dress / LongDress, or outfitParts skirt on any outfit): ONE closed skirt skinned to the hips
# and both thighs (GPU skinning on the fighter's own skeleton). Each vertex follows the thigh on its side for part of
# the thigh's motion, more towards the hem; round the front and back centre the two thighs share it, so in a stride
# the front and back stretch between the legs instead of opening a slit (task C, 2026-11-13: the earlier two rigid
# halves swung apart and showed a gap at the side or front). The waistband follows the hips only.
# Built round the fighter's real hip joints (HeroBody bodies differ from the mannequin); meshes are cached per joint
# height and length. Nothing runs per frame.

const COLS := 32   # round the body (front centre = column 0)
const ROWS := 8
const FOLLOW_FRONT := 0.85  # share of the thighs' motion the hem follows at the front centre ...
const FOLLOW_BACK := 0.9    # ... at the back (a leg stretched back poked out behind long hems)
const FOLLOW_SIDE := 0.95   # ... and over each leg (a raised knee lifts the skirt instead of coming through it)
const SHARE := 0.42         # sin(angle) over which the hem passes from one thigh to the other round the centre lines
const BONES := ["DEF-hips", "DEF-thigh.L", "DEF-thigh.R"]   # skin bind order (L is the +X side)

## Adds the skirt for an outfit's parts ({skirt: colour, skirtLen: metres below the hip joint, about 0.42 knee,
## 0.66 mid-shin, 0.84 ankle}). The skirt goes into f.skirt.
static func dress(f: Fighter, parts: Dictionary) -> void:
	if not parts.has("skirt"):
		return
	var length := clampf(float(parts.get("skirtLen", 0.42)), 0.15, 0.9)
	var skin := Skin.new()
	for b: String in BONES:
		var i := f.skeleton.find_bone(b)
		if i < 0:
			return
		skin.add_named_bind(b, f.skeleton.get_bone_global_rest(i).affine_inverse())
	var jl := f.skeleton.get_bone_global_rest(f.skeleton.find_bone("DEF-thigh.L")).origin
	var jr := f.skeleton.get_bone_global_rest(f.skeleton.find_bone("DEF-thigh.R")).origin
	var jy := (jl.y + jr.y) * 0.5   # the body's own hip joints (model space, rest)
	var key := "skirt_skinned_%.3f_%.2f" % [jy, length]
	if not Parts._meshes.has(key):
		Parts._meshes[key] = build_mesh(jy, length)
	var mi := MeshInstance3D.new()
	mi.name = "Skirt"
	mi.mesh = Parts._meshes[key]
	mi.material_override = Parts.material(Parts.hx(parts.skirt), 0.75, 0.0, true)
	mi.skin = skin
	mi.skeleton = NodePath("..")   # skinned in the skeleton's own space (a new MeshInstance3D has no skeleton path)
	f.skeleton.add_child(mi)
	f.skirt.append(mi)

## The thighs' weights for a skirt vertex at angle `a` round the body (0 = front centre, +PI/2 = the +X / left leg)
## and `t` down the skirt (0 = waist, 1 = hem): [hips, thigh.L, thigh.R], summing to 1.
static func weights(a: float, t: float) -> Vector3:
	var c := cos(a)
	var follow := lerpf(FOLLOW_FRONT, FOLLOW_BACK, clampf(-c, 0.0, 1.0))
	follow = lerpf(follow, FOLLOW_SIDE, absf(sin(a)))
	var k := follow * smoothstep(0.0, 0.35, t)   # the waistband stays on the hips; below the hip joints the thighs lead
	var left := smoothstep(-SHARE, SHARE, sin(a))
	return Vector3(1.0 - k, k * left, k * (1.0 - left))

## The skirt in model space: waist above the hip joints, widest at the hips, then an A-line flare to the hem.
static func build_mesh(jy: float, length: float) -> ArrayMesh:
	var prof := [[0.045, 0.17, 0.122], [-0.03, 0.248, 0.158], [-length, 0.225 + 0.12 * length, 0.16 + 0.08 * length]]   # (a little roomier at the hips than the old halves: the thighs swell as they swing)
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var idx := PackedInt32Array()
	var bones := PackedInt32Array(); var wts := PackedFloat32Array()
	for r in ROWS + 1:
		var t := float(r) / ROWS
		var a0: Array = prof[0] if t < 0.2 else prof[1]
		var b0: Array = prof[1] if t < 0.2 else prof[2]
		var k := t / 0.2 if t < 0.2 else (t - 0.2) / 0.8
		var y := jy + lerpf(float(a0[0]), float(b0[0]), k)
		var rx := lerpf(float(a0[1]), float(b0[1]), k)
		var rz := lerpf(float(a0[2]), float(b0[2]), k)
		for c in COLS + 1:   # the last column repeats the first (closed at the front centre)
			var a := TAU * float(c) / COLS
			verts.append(Vector3(sin(a) * rx, y, -0.035 + cos(a) * rz))
			norms.append(Vector3(sin(a) * rz, 0.0, cos(a) * rx).normalized())
			var w := weights(a, t)
			bones.append_array([0, 1, 2, 0])
			wts.append_array([w.x, w.y, w.z, 0.0])
	for r in ROWS:
		for c in COLS:
			var p := r * (COLS + 1) + c
			var q := p + COLS + 1
			idx.append_array([p, p + 1, q, p + 1, q + 1, q])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_BONES] = bones; arr[Mesh.ARRAY_WEIGHTS] = wts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

## Every skirt vertex where the GPU draws it for the skeleton's current pose (linear blend skinning; tests, tools).
static func posed(f: Fighter, mi: MeshInstance3D) -> PackedVector3Array:
	var a := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var m: Array[Transform3D] = []
	for b in BONES.size():
		m.append(global_pose(f.skeleton, f.skeleton.find_bone(BONES[b])) * mi.skin.get_bind_pose(b))
	var out := PackedVector3Array()
	out.resize(v.size())
	for i in v.size():
		out[i] = (m[0] * v[i]) * w[i * 4] + (m[1] * v[i]) * w[i * 4 + 1] + (m[2] * v[i]) * w[i * 4 + 2]
	return out

## A bone's model-space pose from the local poses up its chain (also outside the scene tree, where the skeleton's
## cached global poses are not refreshed).
static func global_pose(sk: Skeleton3D, bone: int) -> Transform3D:
	var t := Transform3D.IDENTITY
	while bone >= 0:
		t = sk.get_bone_pose(bone) * t
		bone = sk.get_bone_parent(bone)
	return t
