class_name BodyRegions
extends RefCounted
# Body regions of the mannequin for the outfit shader. The mesh's rest pose is a T-pose (arms along ±X at
# y≈1.44, hips 0.92 m, neck 1.49 m, hands from |x|≈0.73), so every region is a function of the rest-pose
# position. Each vertex keeps its rest position in CUSTOM0 (it survives skinning) and outfit.gdshader picks the
# region per pixel, which gives smooth anti-aliased borders. region() is the same rule on the CPU (tests, tools).

enum { SKIN, TOP, PANTS, BOOTS, BELT, WRIST, SLEEVE, FOREARM, HANDS, UNDERSHIRT, PLATE, UPPER_ARM, TRIM }
const COUNT := 13
# Region borders (metres, rest pose). Mirrored in shaders/outfit.gdshader.
const ARM_X := 0.2        # |x| beyond this, above ARM_Y, is an arm
const ARM_Y := 1.22
const SLEEVE_X := 0.3     # short sleeve ends
const ELBOW_X := 0.47
const WRIST_X := 0.665
const HAND_X := 0.735
const BELT_LO := 0.93
const BELT_HI := 1.0
const BOOT_Y := 0.24
const NECK_Y := 1.47
const PLATE_Y := 1.13
static var _dressed: Dictionary = {}  # base mesh -> mesh with rest positions in CUSTOM0

static func dressed_mesh(mi: MeshInstance3D) -> ArrayMesh:
	var base: Mesh = mi.mesh
	if _dressed.has(base):
		return _dressed[base]
	var out := ArrayMesh.new()
	for s in base.get_surface_count():
		var arr: Array = base.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var rest := PackedFloat32Array(); rest.resize(verts.size() * 4)
		for v in verts.size():
			rest[v * 4] = verts[v].x; rest[v * 4 + 1] = verts[v].y; rest[v * 4 + 2] = verts[v].z; rest[v * 4 + 3] = 1.0
		arr[Mesh.ARRAY_CUSTOM0] = rest
		var fmt: int = (base.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) | Mesh.ARRAY_FORMAT_CUSTOM0 \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		out.surface_set_material(s, base.surface_get_material(s))
	_dressed[base] = out
	return out

## The region at a rest-pose position (same rules as the shader, without anti-aliasing).
static func region(p: Vector3) -> int:
	var ax := absf(p.x)
	if ax > ARM_X and p.y > ARM_Y:
		if ax > HAND_X: return HANDS
		if ax > WRIST_X: return WRIST
		if ax > ELBOW_X: return FOREARM
		return UPPER_ARM if ax > SLEEVE_X else SLEEVE
	if p.y > 1.53 or (p.y > NECK_Y and ax < 0.085): return SKIN
	if p.y < BOOT_Y: return BOOTS
	if p.y < BELT_LO: return PANTS
	if p.y < BELT_HI: return BELT
	if p.y > 1.36 and p.z > 0.03 and ax < (p.y - 1.33) * 0.9: return UNDERSHIRT
	return PLATE if p.y > PLATE_Y else TOP

## Region colours for an outfit on a given skin.
static func colours(parts: Dictionary, skin: Color) -> PackedColorArray:
	var c := PackedColorArray(); c.resize(COUNT)
	var hx := func(v: Variant) -> Color: return Color.hex((int(v) << 8) | 0xff)
	var top: Color = hx.call(parts.top)
	var sleeves: bool = parts.get("sleeves", false)
	var armor: bool = parts.has("armor")
	c[SKIN] = skin
	c[TOP] = hx.call(parts.armor.plate) if armor else top
	c[PLATE] = hx.call(parts.armor.plate) if armor else top
	c[TRIM] = hx.call(parts.armor.trim) if armor else top
	c[UNDERSHIRT] = top if armor else (hx.call(parts.undershirt) if parts.has("undershirt") else top)
	c[BELT] = hx.call(parts.sash) if parts.has("sash") else (top if not armor else hx.call(parts.armor.trim))
	c[PANTS] = hx.call(parts.pants)
	c[BOOTS] = hx.call(parts.shoes)
	c[SLEEVE] = skin if parts.get("vest", false) else top
	c[UPPER_ARM] = top if sleeves else skin
	c[FOREARM] = top if sleeves else skin
	c[WRIST] = hx.call(parts.wrist) if parts.has("wrist") else (hx.call(parts.gloves) if parts.has("gloves") else c[FOREARM])
	c[HANDS] = hx.call(parts.gloves) if parts.has("gloves") else skin
	return c
