class_name HeroBody
extends RefCounted
# New body meshes from Quaternius's Universal Base Characters (CC0, assets/characters/ubc; user request 2026-11-06)
# worn on our existing rig. The packs use a different skeleton (pelvis/upperarm_l...), so instead of re-authoring every
# animation and fight move, the new mesh is moved onto our DEF- skeleton: our joints are moved to where the new body's
# joints are (orientations kept, so every animation and procedural pose still applies), and the mesh's skin is rebound
# to our bones. The result is a normal body mesh: BodyRegions paints outfits on it and BodySculpt shapes it as before.

const KINDS := ["hero_male", "hero_female", "teen_male", "teen_female"]
const DIR := "res://assets/characters/ubc/"
# The source packs live outside the game folder (art/quaternius, ~140 MB with 4K textures we don't use); the baker
# (tools_bake_bodies.gd) saves just each body's mesh plus its joints and skin binds here.
const SOURCES := {
	"hero_male": "Superhero_Male_FullBody.gltf", "hero_female": "Superhero_Female_FullBody.gltf",
	"teen_male": "Teen_Male_FullBody.gltf", "teen_female": "Teen_Female_FullBody.gltf",
}

## New bone -> our bone. Fingertip "leaf" bones fold into the last finger joint, the ball into the toe.
static func bone_map() -> Dictionary:
	var m := {"root": "root", "pelvis": "DEF-hips", "spine_01": "DEF-spine.001", "spine_02": "DEF-spine.002",
		"spine_03": "DEF-spine.003", "neck_01": "DEF-neck", "Head": "DEF-head"}
	for s: String in ["l", "r"]:
		var S := s.to_upper()
		m["clavicle_" + s] = "DEF-shoulder." + S
		m["upperarm_" + s] = "DEF-upper_arm." + S
		m["lowerarm_" + s] = "DEF-forearm." + S
		m["hand_" + s] = "DEF-hand." + S
		m["thigh_" + s] = "DEF-thigh." + S
		m["calf_" + s] = "DEF-shin." + S
		m["foot_" + s] = "DEF-foot." + S
		m["ball_" + s] = "DEF-toe." + S
		m["ball_leaf_" + s] = "DEF-toe." + S
		for f: String in ["index", "middle", "pinky", "ring"]:
			for i in 3:
				m["%s_0%d_%s" % [f, i + 1, s]] = "DEF-f_%s.0%d.%s" % [f, i + 1, S]
			m["%s_04_leaf_%s" % [f, s]] = "DEF-f_%s.03.%s" % [f, S]
		for i in 3:
			m["thumb_0%d_%s" % [i + 1, s]] = "DEF-thumb.0%d.%s" % [i + 1, S]
		m["thumb_04_leaf_" + s] = "DEF-thumb.03." + S
	return m

static var _src: Dictionary = {}   # kind -> {mesh, joints: {our bone: model-space joint position}, binds: [our bone]}

## The new body's mesh and joint positions (baked files; cached per body kind).
static func source(kind: String) -> Dictionary:
	if not _src.has(kind):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + kind + ".json"))
		var joints := {}
		for k: String in data.joints:
			var v: Array = data.joints[k]
			joints[k] = Vector3(v[0], v[1], v[2])
		_src[kind] = {"mesh": load(DIR + kind + ".res"), "joints": joints, "binds": PackedStringArray(data.binds), "eyes": data.get("eyes", [])}
	return _src[kind]

## Baker: reads a source glTF (outside the project) and returns {mesh, joints, binds} for saving.
static func extract(gltf_path: String) -> Dictionary:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(gltf_path, st)
	var scene: Node = doc.generate_scene(st)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var body: MeshInstance3D = null
	var eyes := []
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if body == null or mi.get_aabb().size.y > body.get_aabb().size.y:
			body = mi
		if mi.name.to_lower().begins_with("eyes"):   # the pack's eyeballs: where the eye sockets are
			var a := mi.get_aabb()
			eyes = [a.size.x * 0.5 - a.size.y * 0.5, a.get_center().y, a.end.z]
	var map := bone_map()
	var joints := {}
	for i in sk.get_bone_count():
		var ours: String = map.get(sk.get_bone_name(i), "")
		if ours != "" and not sk.get_bone_name(i).contains("leaf") and not joints.has(ours):
			var o := sk.get_bone_global_rest(i).origin
			joints[ours] = [o.x, o.y, o.z]
	var binds: Array = []
	for b in body.skin.get_bind_count():
		var n := body.skin.get_bind_name(b)
		if n == "" and body.skin.get_bind_bone(b) >= 0:
			n = sk.get_bone_name(body.skin.get_bind_bone(b))
		binds.append(map.get(n, "DEF-hips"))
	# plain mesh: geometry and skin weights only (our shader paints it, so no textures/materials)
	var mesh := ArrayMesh.new()
	for s in body.mesh.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.mesh.surface_get_arrays(s), [], {},
			body.mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	scene.free()
	return {"mesh": mesh, "joints": joints, "binds": binds, "eyes": eyes}

## The original mannequin's painted eyes (outfit.gdshader): half spacing, height.
const OLD_EYES := [0.039, 1.703]

## Head proportions, measured from the vertices above the head joint: half width, front/back, top; plus the eyes.
static func head_box(mesh: Mesh, head_y: float, eyes: Array) -> Dictionary:
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b := {"x": 0.0, "z0": 9.0, "z1": -9.0, "top": head_y, "y": head_y}
	for p in v:
		if p.y > head_y + 0.03 and absf(p.x) < 0.16:
			b.x = maxf(b.x, absf(p.x)); b.z0 = minf(b.z0, p.z); b.z1 = maxf(b.z1, p.z); b.top = maxf(b.top, p.y)
	b.ex = float(eyes[0]) if eyes.size() > 1 else OLD_EYES[0]
	b.ey = float(eyes[1]) if eyes.size() > 1 else OLD_EYES[1]
	return b

## Maps head points of one head onto another: the eye line and the top of the head line up, the face fronts line up,
## and sideways either the eyes (`by_eyes`, for the painted face) or the head width (hair and head pieces).
static func head_fit(from: Dictionary, to: Dictionary, by_eyes: bool) -> Transform3D:
	var sx: float = (to.ex / from.ex) if by_eyes else (to.x / from.x)
	var sc := Vector3(sx, (to.top - to.ey) / (from.top - from.ey), (to.z1 - to.z0) / (from.z1 - from.z0))
	var a := Vector3(0, from.ey, from.z1)
	var b := Vector3(0, to.ey, to.z1)
	if not by_eyes:   # hair: the new foreheads are shorter, so lift the fringe clear of the brows and widen a touch
		b.y += 0.014
		sc.x *= 1.03
	return Transform3D(Basis.from_scale(sc), b - Basis.from_scale(sc) * a)

static var _old_head: Dictionary = {}
static var _dressed: Dictionary = {}   # kind -> mesh with CUSTOM0 = each vertex mapped onto the original mannequin

## Moves our skeleton's joints to the new body's and dresses `body_mesh` with the new mesh, rebound to our bones.
## Returns {shift: how far each joint moved, head: old-head -> new-head transform, hips: hips rest offset,
## height: new body's top / mannequin's top}, so add-on pieces, poses and heights can follow.
static func wear(kind: String, skeleton: Skeleton3D, body_mesh: MeshInstance3D) -> Dictionary:
	var src := source(kind)
	var joints: Dictionary = src.joints
	if _old_head.is_empty():
		_old_head = head_box(body_mesh.mesh, skeleton.get_bone_global_rest(skeleton.find_bone("DEF-head")).origin.y, [])
	var new_head := head_box(src.mesh, (joints["DEF-head"] as Vector3).y, src.eyes)
	var hips_i := skeleton.find_bone("DEF-hips")
	var old_hips := skeleton.get_bone_rest(hips_i).origin
	# 1. joints: walk the hierarchy parents-first, keep each bone's global orientation, move its origin
	var globals := {}
	var shift := {}
	for i in skeleton.get_bone_count():
		var name := skeleton.get_bone_name(i)
		var g := skeleton.get_bone_global_rest(i)
		if joints.has(name):
			shift[name] = (joints[name] as Vector3) - g.origin
			g.origin = joints[name]
		globals[i] = g
	for i in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(i)
		var local: Transform3D = globals[i] if parent < 0 else (globals[parent] as Transform3D).affine_inverse() * globals[i]
		skeleton.set_bone_rest(i, local)
		skeleton.set_bone_pose(i, local)
	# 2. skin: same bind order as the mesh's bone indices, each bind now our bone at its new rest
	var skin := Skin.new()
	for n: String in src.binds:
		var bi := skeleton.find_bone(n)
		skin.add_named_bind(n, skeleton.get_bone_global_rest(bi).affine_inverse())
	var to_old := head_fit(new_head, _old_head, true)
	if not _dressed.has(kind):
		_dressed[kind] = _dress(src, shift, to_old)
	body_mesh.mesh = _dressed[kind]
	body_mesh.skin = skin
	return {"shift": shift, "head": head_fit(_old_head, new_head, false), "hips": skeleton.get_bone_rest(hips_i).origin - old_hips,
		"height": float(new_head.top) / float(_old_head.top)}

## The new mesh with CUSTOM0 = where each vertex would be on the original mannequin (blend of its bones: each joint's
## shift undone, the head mapped by head shape). Outfit regions, the painted face and BodySculpt all work in that
## space, so they land on the same body parts whatever the body's size.
static func _dress(src: Dictionary, shift: Dictionary, head_to_old: Transform3D) -> ArrayMesh:
	var mesh: Mesh = src.mesh
	var binds: PackedStringArray = src.binds
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(1, verts.size())
		var rest := PackedFloat32Array(); rest.resize(verts.size() * 4)
		for i in verts.size():
			var v := verts[i]
			var acc := Vector3.ZERO
			var wsum := 0.0
			for k in per:
				var w := weights[i * per + k]
				if w <= 0.0:
					continue
				var b := binds[bones[i * per + k]]
				var m: Vector3 = head_to_old * v if b == "DEF-head" else v - (shift.get(b, Vector3.ZERO) as Vector3)
				acc += m * w
				wsum += w
			var p := acc / wsum if wsum > 0.0 else v
			rest[i * 4] = p.x; rest[i * 4 + 1] = p.y; rest[i * 4 + 2] = p.z; rest[i * 4 + 3] = 1.0
		arr[Mesh.ARRAY_CUSTOM0] = rest
		var fmt: int = (mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) | Mesh.ARRAY_FORMAT_CUSTOM0 \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
	return out
