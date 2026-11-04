class_name ApeBody
extends RefCounted
# The Great Ape's body (2026-11-04 rebuild): its own Skeleton3D and ONE continuous skinned mesh, generated in code.
# Hunched barrel torso, heavy shoulder fur, long arms with big hands, digitigrade-ish legs, a muzzle with fangs, a heavy
# brow, glowing red eyes and a four-bone tail. Fur is a clumped displacement of the surface (vertex colour = fur or
# bare skin), so the silhouette reads as shaggy instead of smooth balls. Built at human size (feet at the origin,
# facing +Z); the fighter scales it up with the form. Bone rests have identity rotations, so clips rotate bones about
# the model axes (x pitches a limb forward/back, z swings it out).

# name, parent, model-space position
const BONES := [
	["hips", "", Vector3(0, 0.80, 0)], ["spine1", "hips", Vector3(0, 0.98, -0.02)], ["spine2", "spine1", Vector3(0, 1.16, -0.06)],
	["chest", "spine2", Vector3(0, 1.36, -0.05)], ["neck", "chest", Vector3(0, 1.58, 0.06)], ["head", "neck", Vector3(0, 1.72, 0.18)],
	["jaw", "head", Vector3(0, 1.62, 0.30)],
	["shoulder.L", "chest", Vector3(0.20, 1.50, -0.02)], ["arm.L", "shoulder.L", Vector3(0.46, 1.47, -0.02)],
	["forearm.L", "arm.L", Vector3(0.55, 1.06, 0.03)], ["hand.L", "forearm.L", Vector3(0.58, 0.66, 0.08)],
	["shoulder.R", "chest", Vector3(-0.20, 1.50, -0.02)], ["arm.R", "shoulder.R", Vector3(-0.46, 1.47, -0.02)],
	["forearm.R", "arm.R", Vector3(-0.55, 1.06, 0.03)], ["hand.R", "forearm.R", Vector3(-0.58, 0.66, 0.08)],
	["thigh.L", "hips", Vector3(0.21, 0.76, 0.0)], ["shin.L", "thigh.L", Vector3(0.23, 0.42, 0.07)], ["foot.L", "shin.L", Vector3(0.23, 0.09, 0.0)],
	["thigh.R", "hips", Vector3(-0.21, 0.76, 0.0)], ["shin.R", "thigh.R", Vector3(-0.23, 0.42, 0.07)], ["foot.R", "shin.R", Vector3(-0.23, 0.09, 0.0)],
	["tail1", "hips", Vector3(0, 0.82, -0.24)], ["tail2", "tail1", Vector3(0.05, 0.70, -0.52)], ["tail3", "tail2", Vector3(0.22, 0.78, -0.80)],
	["tail4", "tail3", Vector3(0.35, 1.05, -0.86)], ["tail_end", "tail4", Vector3(0.34, 1.30, -0.78)],
]

static var _cache: Dictionary = {}

const FUR := Color(0.36, 0.21, 0.13)
const GOLD := Color(0.78, 0.52, 0.12)
const SKIN := Color(0.55, 0.38, 0.27)
const GOLD_SKIN := Color(0.72, 0.52, 0.34)

static func pos(name: String) -> Vector3:
	for b: Array in BONES:
		if b[0] == name:
			return b[2]
	return Vector3.ZERO

## {"root": Node3D, "skeleton": Skeleton3D, "mesh": MeshInstance3D, "fur": Color}
static func build(golden: bool) -> Dictionary:
	var root := Node3D.new()
	root.name = "ApeRig"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	for b: Array in BONES:
		sk.add_bone(b[0])
	for b: Array in BONES:
		var i := sk.find_bone(b[0])
		var parent := sk.find_bone(b[1]) if b[1] != "" else -1
		sk.set_bone_parent(i, parent)
		var local: Vector3 = b[2] - (pos(b[1]) if b[1] != "" else Vector3.ZERO)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		sk.set_bone_pose_position(i, local)
	var fur := GOLD if golden else FUR
	var bare := GOLD_SKIN if golden else SKIN
	var mi := MeshInstance3D.new()
	mi.name = "ApeBody"
	if not _cache.has(golden):   # generated once per form; transforming again is instant
		_cache[golden] = _mesh(sk, fur, bare, golden)
	mi.mesh = _cache[golden]
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sk.create_skin_from_rest_transforms()
	return {"root": root, "skeleton": sk, "mesh": mi, "fur": fur}

# ------------------------------------------------------------------------------------------------ mesh
class Part:
	var xf: Transform3D
	var bones: PackedStringArray
	var kind: String   # "fur", "skin", "eye", "fang", "dark"
	var furry: float   # clump displacement (metres)
	var rings: int
	var segs: int
	func _init(t: Transform3D, b: PackedStringArray, k: String, f: float, r := 14, s := 20) -> void:
		xf = t; bones = b; kind = k; furry = f; rings = r; segs = s

static func _ell(c: Vector3, r: Vector3, bones: PackedStringArray, kind: String, furry := 0.0, rot := Vector3.ZERO, rings := 14, segs := 20) -> Part:
	return Part.new(Transform3D(Basis.from_euler(rot) * Basis.from_scale(r), c), bones, kind, furry, rings, segs)

## An ellipsoid stretched from a to b (a limb segment), radius r0 at a tapering to r1 at b (approximated by r avg).
static func _limb(a: Vector3, b: Vector3, r: float, depth: float, bones: PackedStringArray, kind: String, furry := 0.0) -> Part:
	var d := b - a
	var len := d.length()
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	var basis := Basis(side * r, up * (len * 0.5 + r * 0.5), fwd * depth)
	return Part.new(Transform3D(basis, (a + b) * 0.5), bones, kind, furry, 12, 18)

## A tapered fur tuft: an elongated ellipsoid from p pointing along dir.
static func _tuft(p: Vector3, dir: Vector3, length: float, bones: PackedStringArray) -> Part:
	var up := dir.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	return Part.new(Transform3D(Basis(side * 0.075, up * length * 0.7, fwd * 0.055), p + up * length * 0.35), bones, "fur", 0.0, 8, 10)

static func _parts() -> Array[Part]:
	var P := func(n: String) -> Vector3: return pos(n)
	var out: Array[Part] = []
	# torso: hips, belly, barrel chest, a heavy shoulder/back hump, bare chest and belly patches
	out.append(_ell(Vector3(0, 0.86, -0.02), Vector3(0.36, 0.22, 0.28), ["hips", "spine1"], "fur", 0.03))
	out.append(_ell(Vector3(0, 1.06, 0.0), Vector3(0.40, 0.30, 0.32), ["spine1", "spine2"], "fur", 0.03))
	out.append(_ell(Vector3(0, 1.34, -0.05), Vector3(0.50, 0.36, 0.36), ["spine2", "chest"], "fur", 0.04, Vector3.ZERO, 16, 24))
	out.append(_ell(Vector3(0, 1.46, -0.18), Vector3(0.46, 0.22, 0.28), ["chest", "neck"], "fur", 0.04, Vector3(0.35, 0, 0), 14, 22))
	out.append(_ell(Vector3(0, 1.22, 0.17), Vector3(0.33, 0.32, 0.18), ["chest", "spine2", "spine1"], "skin", 0.0, Vector3.ZERO, 14, 20))
	for s in [1.0, -1.0]:
		var L := "L" if s > 0 else "R"
		# shoulder fur mass and long arms
		out.append(_ell(Vector3(s * 0.36, 1.50, -0.05), Vector3(0.26, 0.22, 0.25), ["shoulder." + L, "chest"], "fur", 0.06))
		out.append(_limb(P.call("arm." + L), P.call("forearm." + L), 0.16, 0.16, ["arm." + L, "shoulder." + L], "fur", 0.04))
		out.append(_limb(P.call("forearm." + L), P.call("hand." + L) + Vector3(0, 0.08, 0), 0.155, 0.15, ["forearm." + L], "fur", 0.05))
		out.append(_ell(P.call("hand." + L) + Vector3(s * 0.01, -0.06, 0.03), Vector3(0.13, 0.15, 0.11), ["hand." + L], "skin"))
		for k in 3:   # knuckles / fingers
			out.append(_ell(P.call("hand." + L) + Vector3(s * 0.01 + (k - 1) * 0.07, -0.19, 0.06), Vector3(0.035, 0.07, 0.045), ["hand." + L], "skin", 0.0, Vector3.ZERO, 8, 10))
		out.append(_ell(P.call("hand." + L) + Vector3(s * -0.07, -0.13, 0.08), Vector3(0.03, 0.06, 0.035), ["hand." + L], "skin", 0.0, Vector3(0.4, 0, 0), 8, 10))
		# legs: heavy thighs, shins bent forward, long flat feet
		out.append(_limb(P.call("thigh." + L), P.call("shin." + L), 0.19, 0.19, ["thigh." + L, "hips"], "fur", 0.04))
		out.append(_limb(P.call("shin." + L), P.call("foot." + L) + Vector3(0, 0.05, 0), 0.14, 0.14, ["shin." + L], "fur", 0.035))
		out.append(_ell(P.call("foot." + L) + Vector3(0, -0.04, 0.1), Vector3(0.12, 0.06, 0.2), ["foot." + L], "skin"))
		out.append(_ell(Vector3(s * 0.27, 1.79, 0.12), Vector3(0.055, 0.075, 0.035), ["head"], "skin", 0.0, Vector3(0, s * 0.4, 0), 8, 12))
	# neck and head: a big skull pushed forward out of the hump, a wide bare face with deep-set glowing eyes under a
	# heavy brow, a long muzzle with nostrils, a lower jaw with fangs, fur sideburns and a crest
	out.append(_ell(Vector3(0, 1.60, 0.08), Vector3(0.25, 0.16, 0.24), ["neck", "chest"], "fur", 0.03))
	out.append(_ell(Vector3(0, 1.78, 0.18), Vector3(0.29, 0.28, 0.27), ["head"], "fur", 0.02, Vector3.ZERO, 16, 24))
	out.append(_ell(Vector3(0, 1.73, 0.36), Vector3(0.22, 0.17, 0.09), ["head"], "skin", 0.0, Vector3.ZERO, 14, 20))
	out.append(_ell(Vector3(0, 1.84, 0.37), Vector3(0.24, 0.055, 0.08), ["head"], "fur", 0.005))
	out.append(_ell(Vector3(0, 1.63, 0.43), Vector3(0.18, 0.115, 0.13), ["head"], "skin", 0.0, Vector3.ZERO, 14, 20))
	for s in [1.0, -1.0]:
		out.append(_ell(Vector3(s * 0.035, 1.665, 0.555), Vector3(0.022, 0.016, 0.012), ["head"], "dark", 0.0, Vector3.ZERO, 6, 10))
		out.append(_ell(Vector3(s * 0.085, 1.765, 0.43), Vector3(0.042, 0.028, 0.02), ["head"], "eye", 0.0, Vector3.ZERO, 8, 12))
		out.append(_ell(Vector3(s * 0.075, 1.53, 0.53), Vector3(0.016, 0.045, 0.016), ["jaw"], "fang", 0.0, Vector3(-0.15, 0, 0), 6, 8))
		out.append(_tuft(Vector3(s * 0.25, 1.68, 0.24), Vector3(s * 0.8, -0.6, 0.1), 0.12, ["head"]))
		out.append(_tuft(Vector3(s * 0.22, 1.62, 0.28), Vector3(s * 0.6, -0.8, 0.2), 0.1, ["jaw"]))
	out.append(_ell(Vector3(0, 1.55, 0.44), Vector3(0.155, 0.06, 0.11), ["jaw"], "skin"))
	out.append(_ell(Vector3(0, 1.585, 0.53), Vector3(0.11, 0.01, 0.02), ["jaw"], "dark", 0.0, Vector3.ZERO, 6, 12))
	for k in 3:
		out.append(_tuft(Vector3((k - 1) * 0.07, 2.0, 0.12 - k * 0.0), Vector3((k - 1) * 0.3, 0.5, -0.9), 0.13, ["head"]))
	# shaggy tufts: shoulders, back, forearms
	for s in [1.0, -1.0]:
		var L := "L" if s > 0 else "R"
		for k in 5:
			var a := float(k) / 4.0
			out.append(_tuft(Vector3(s * (0.3 + 0.2 * a), 1.66 - 0.18 * a, -0.12 + 0.08 * sin(a * 3.0)), Vector3(s * (0.3 + a), 0.4 - a, -0.4), 0.15,
				["shoulder." + L, "chest"]))
		for k in 3:
			var f := float(k) / 2.0
			var at: Vector3 = pos("forearm." + L).lerp(pos("hand." + L), 0.15 + 0.5 * f)
			out.append(_tuft(at + Vector3(s * 0.1, 0, -0.08), Vector3(s * 0.5, -0.5, -0.7), 0.13, ["forearm." + L]))
		out.append(_tuft(pos("arm." + L) + Vector3(s * 0.12, -0.2, -0.1), Vector3(s * 0.6, -0.3, -0.6), 0.13, ["arm." + L]))
	for k in 4:
		out.append(_tuft(Vector3(0, 1.62 - k * 0.17, -0.34 + k * 0.03), Vector3(0, 0.2 - k * 0.15, -1.0), 0.14, ["chest" if k < 2 else "spine2"]))
	# tail
	var tail := ["tail1", "tail2", "tail3", "tail4", "tail_end"]
	for k in 4:
		out.append(_limb(P.call(tail[k]), P.call(tail[k + 1]), 0.07 - k * 0.008, 0.07 - k * 0.008, [tail[k]], "fur", 0.02))
	return out

## Smooth weights among a part's bones by distance to each bone's segment (bone → its first child).
static func _weights(sk: Skeleton3D, p: Vector3, bones: PackedStringArray) -> Array:
	var ids: Array[int] = []
	var ws: Array[float] = []
	for b: String in bones:
		var i := sk.find_bone(b)
		if i < 0:
			continue
		var a := pos(b)
		var c := a
		for bb: Array in BONES:
			if bb[1] == b:
				c = bb[2]
				break
		var d := Geometry3D.get_closest_point_to_segment(p, a, c).distance_to(p)
		ids.append(i)
		ws.append(1.0 / pow(maxf(d, 0.02), 3.0))
	var total := 0.0
	for w in ws: total += w
	var out_b := PackedInt32Array([0, 0, 0, 0])
	var out_w := PackedFloat32Array([0, 0, 0, 0])
	for k in mini(4, ids.size()):
		out_b[k] = ids[k]
		out_w[k] = ws[k] / total
	if ids.size() > 4:   # keep the four strongest
		var order := range(ids.size())
		order.sort_custom(func(x: int, y: int) -> bool: return ws[x] > ws[y])
		total = 0.0
		for k in 4: total += ws[order[k]]
		for k in 4:
			out_b[k] = ids[order[k]]
			out_w[k] = ws[order[k]] / total
	return [out_b, out_w]

static func _mesh(sk: Skeleton3D, fur: Color, bare: Color, golden: bool) -> ArrayMesh:
	var surfaces := {"body": [], "eye": [], "fang": []}
	for s: String in surfaces:
		surfaces[s] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array(), PackedFloat32Array(), PackedInt32Array()]
	for part: Part in _parts():
		var sphere := SphereMesh.new()
		sphere.radius = 1.0; sphere.height = 2.0; sphere.radial_segments = part.segs; sphere.rings = part.rings
		var arr: Array = sphere.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var key := "eye" if part.kind == "eye" else ("fang" if part.kind == "fang" else "body")
		var S: Array = surfaces[key]
		var base: int = (S[0] as PackedVector3Array).size()
		var colour := fur if part.kind == "fur" else (bare if part.kind == "skin" else (Color(0.08, 0.05, 0.05) if part.kind == "dark" else Color.WHITE))
		var nb := part.xf.basis.inverse().transposed()
		for v in verts.size():
			var p := part.xf * verts[v]
			var n := (nb * norms[v]).normalized()
			if part.furry > 0.0:
				# shaggy clumps: a few crossing waves give tufts, strongest away from the ground-facing side
				var clump := 0.5 + 0.5 * sin(p.x * 31.0 + p.y * 17.0) * sin(p.y * 23.0 - p.z * 29.0)
				p += n * part.furry * (0.2 + 0.6 * clump)
			S[0].append(p)
			S[1].append(n)
			var c := colour
			if part.kind == "fur":
				c = colour.darkened(0.18 * (1.0 - clampf(n.y + 0.6, 0.0, 1.0)))
			S[2].append(c)
			var w := _weights(sk, p, part.bones)
			S[3].append_array(w[0])
			S[4].append_array(w[1])
		for i in idx:
			S[5].append(base + i)
	var mesh := ArrayMesh.new()
	for key: String in ["body", "eye", "fang"]:
		var S: Array = surfaces[key]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = S[0]; arrays[Mesh.ARRAY_NORMAL] = S[1]; arrays[Mesh.ARRAY_COLOR] = S[2]
		arrays[Mesh.ARRAY_BONES] = S[3]; arrays[Mesh.ARRAY_WEIGHTS] = S[4]; arrays[Mesh.ARRAY_INDEX] = S[5]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := StandardMaterial3D.new()
		match key:
			"body":
				m.vertex_color_use_as_albedo = true
				m.roughness = 0.92
				if golden:
					m.emission_enabled = true; m.emission = Color(0.9, 0.6, 0.1); m.emission_energy_multiplier = 0.15
			"eye":
				m.albedo_color = Color(0.95, 0.1, 0.08); m.emission_enabled = true; m.emission = Color(1.0, 0.08, 0.04)
				m.emission_energy_multiplier = 1.6 if golden else 1.1
			"fang":
				m.albedo_color = Color(1.0, 0.94, 0.82); m.roughness = 0.4
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	return mesh
