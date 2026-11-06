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
		_src[kind] = {"mesh": load(DIR + kind + ".res"), "joints": joints, "binds": PackedStringArray(data.binds)}
	return _src[kind]

## Baker: reads a source glTF (outside the project) and returns {mesh, joints, binds} for saving.
static func extract(gltf_path: String) -> Dictionary:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	doc.append_from_file(gltf_path, st)
	var scene: Node = doc.generate_scene(st)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var body: MeshInstance3D = null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if body == null or mi.get_aabb().size.y > body.get_aabb().size.y:
			body = mi
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
	return {"mesh": mesh, "joints": joints, "binds": binds}

## Moves our skeleton's joints to the new body's and dresses `body_mesh` with the new mesh, rebound to our bones.
## Returns how far each bone's joint moved (model space), so pieces placed for the old body can follow.
static func wear(kind: String, skeleton: Skeleton3D, body_mesh: MeshInstance3D) -> Dictionary:
	var src := source(kind)
	var joints: Dictionary = src.joints
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
	body_mesh.mesh = src.mesh
	body_mesh.skin = skin
	return shift
