class_name BodySculpt
extends RefCounted
# Real body shapes instead of one mannequin for everyone (presentation rebuild, 2026-11-04): the shared rigged mesh
# is re-sculpted per profile, vertex by vertex in its rest (T-) pose, so races, builds and named fighters get their
# own head, jaw, neck, shoulders, chest, waist, belly, hips, limbs, hands and feet. Skin weights and the skeleton are
# untouched, so every animation still fits. CUSTOM0 keeps the original rest position: outfit regions and the painted
# face stay attached to the right vertices as the shape moves.
#
# Rest-pose landmarks (metres): head centre (0, 1.68, 0), neck 1.49, shoulders 1.44 (arms along ±X, axis z -0.065),
# elbows |x| 0.47, wrists 0.74, hips 0.92, legs at x ±0.089, knees 0.53, ankles 0.10.

const HEAD_C := Vector3(0, 1.68, 0.0)
const ARM_Y := 1.44
const ARM_Z := -0.065
const LEG_X := 0.089

## Every profile key and its neutral value (1 = unchanged scale, 0 = no offset).
const NEUTRAL := {
	"head_w": 1.0, "head_h": 1.0, "head_d": 1.0, "cranium": 1.0, "jaw": 1.0, "chin": 0.0, "brow": 0.0, "cheek": 1.0,
	"neck": 1.0, "shoulders": 1.0, "chest": 1.0, "back": 1.0, "waist": 1.0, "belly": 0.0, "hips": 1.0,
	"upper_arm": 1.0, "forearm": 1.0, "hands": 1.0, "thigh": 1.0, "calf": 1.0, "feet": 1.0, "soft": 0.0, "bust": 0.0,
}

static var _cache: Dictionary = {}

static func profile_key(p: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in NEUTRAL:
		parts.append("%s=%.3f" % [k, float(p.get(k, NEUTRAL[k]))])
	return ",".join(parts)

static func is_neutral(p: Dictionary) -> bool:
	for k: String in p:
		if NEUTRAL.has(k) and absf(float(p[k]) - float(NEUTRAL[k])) > 0.0005:
			return false
	return true

## The base mesh (already carrying rest positions in CUSTOM0) re-sculpted for a profile; shared per profile.
static func sculpted(base: ArrayMesh, p: Dictionary) -> ArrayMesh:
	if is_neutral(p):
		return base
	var key := "%d|%s" % [base.get_instance_id(), profile_key(p)]
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	for s in base.get_surface_count():
		var arr: Array = base.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms := smooth_normals(verts, arr[Mesh.ARRAY_NORMAL])
		for i in verts.size():
			verts[i] = shape(verts[i], norms[i], p)
		arr[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, base.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		out.surface_set_material(s, base.surface_get_material(s))
	_cache[key] = out
	return out

## Normals averaged over vertices that share a position: the mannequin has hard panel edges (split vertices),
## and pushing split vertices along different normals would tear the surface open.
static func smooth_normals(verts: PackedVector3Array, norms: PackedVector3Array) -> PackedVector3Array:
	var sums: Dictionary = {}
	for i in verts.size():
		var k := Vector3i((verts[i] * 2000.0).round())
		sums[k] = sums.get(k, Vector3.ZERO) + (norms[i] if i < norms.size() else Vector3.UP)
	var out := PackedVector3Array(); out.resize(verts.size())
	for i in verts.size():
		var n: Vector3 = sums[Vector3i((verts[i] * 2000.0).round())]
		out[i] = n.normalized() if n.length() > 0.0001 else Vector3.UP
	return out

## A smooth bump: 0 outside [a, d], 1 inside [b, c].
static func _band(a: float, b: float, c: float, d: float, x: float) -> float:
	return smoothstep(a, b, x) * (1.0 - smoothstep(c, d, x))

## Where one rest-pose vertex goes for a profile.
static func shape(p: Vector3, n: Vector3, pr: Dictionary) -> Vector3:
	var g := func(k: String) -> float: return float(pr.get(k, NEUTRAL[k]))
	var q := p
	var ax := absf(p.x)
	var arm := smoothstep(0.17, 0.24, ax) * smoothstep(1.18, 1.26, p.y)     # 1 on the arms
	var leg := 1.0 - smoothstep(0.90, 0.98, p.y)                             # 1 on the legs
	var trunk := (1.0 - arm) * (1.0 - leg) * (1.0 - smoothstep(1.50, 1.56, p.y))

	# head
	var wh := smoothstep(1.51, 1.57, p.y)
	if wh > 0.0:
		var d := p - HEAD_C
		var lower := clampf(-d.y / 0.14, 0.0, 1.0)
		var upper := clampf(d.y / 0.15, 0.0, 1.0)
		d.x *= g.call("head_w") * lerpf(1.0, g.call("jaw"), lower) * lerpf(1.0, g.call("cheek"), _band(-0.08, -0.03, 0.02, 0.06, d.y))
		d.y *= g.call("head_h") * lerpf(1.0, g.call("cranium"), upper)
		d.z *= g.call("head_d")
		if d.z > 0.0:
			d.z += g.call("chin") * lower * lower * smoothstep(0.0, 0.08, d.z)
			d.z += g.call("brow") * _band(-0.01, 0.02, 0.05, 0.08, d.y) * smoothstep(0.05, 0.1, d.z)
		if d.y > 0.0 and d.z < 0.0:
			d.z *= lerpf(1.0, g.call("cranium"), upper * 0.6)   # a tall cranium also sweeps back
		q = q.lerp(HEAD_C + d, wh)

	# neck
	var wn := _band(1.44, 1.48, 1.53, 1.57, p.y) * (1.0 - arm)
	if wn > 0.0:
		var c := Vector3(0, p.y, -0.01)
		var off := (q - c) * Vector3(g.call("neck"), 1.0, g.call("neck"))
		q = q.lerp(c + off, wn)

	# trunk: shoulders, chest/back, waist, belly, hips
	if trunk > 0.0:
		var t := q
		t.x *= lerpf(1.0, g.call("shoulders"), _band(1.24, 1.34, 1.46, 1.52, p.y))
		if p.z > 0.0:
			t.z *= lerpf(1.0, g.call("chest"), _band(1.12, 1.24, 1.42, 1.50, p.y))
		else:
			t.z *= lerpf(1.0, g.call("back"), _band(1.12, 1.24, 1.42, 1.50, p.y))
		var waist := _band(0.92, 1.0, 1.12, 1.24, p.y)
		t.x *= lerpf(1.0, g.call("waist"), waist)
		t.z *= lerpf(1.0, g.call("waist"), waist * 0.8)
		if p.z > 0.0 and g.call("bust") > 0.0:   # female figure: two soft lobes on the chest
			var lobe := exp(-(pow(ax - 0.08, 2.0) / 0.0042 + pow(p.y - 1.34, 2.0) / 0.0055))
			t.z += g.call("bust") * lobe
			t.y -= g.call("bust") * lobe * 0.25
		if p.z > -0.02:
			t.z += g.call("belly") * _band(0.92, 1.02, 1.14, 1.28, p.y) * smoothstep(-0.02, 0.10, p.z) * (1.0 - smoothstep(0.08, 0.16, ax))
		t.x *= lerpf(1.0, g.call("hips"), _band(0.80, 0.88, 0.96, 1.04, p.y))
		q = q.lerp(t, trunk)

	# arms: thickness round the arm's axis (upper arm, forearm), hands scaled round the wrist
	if arm > 0.0:
		var s := lerpf(g.call("upper_arm"), g.call("forearm"), smoothstep(0.42, 0.52, ax))
		var a := q
		a.y = ARM_Y + (q.y - ARM_Y) * s
		a.z = ARM_Z + (q.z - ARM_Z) * s
		var hand := smoothstep(0.72, 0.76, ax)
		if hand > 0.0:
			var wrist := Vector3(signf(p.x) * 0.74, ARM_Y, ARM_Z)
			a = a.lerp(wrist + (a - wrist) * g.call("hands"), hand)
		# shoulders follow the trunk's shoulder width where the arm joins
		a.x *= lerpf(g.call("shoulders"), 1.0, smoothstep(0.24, 0.40, ax))
		q = q.lerp(a, arm)

	# legs: thickness round each leg's axis (thigh, calf), feet scaled round the ankle
	if leg > 0.0:
		var lx := signf(p.x) * LEG_X if ax > 0.005 else 0.0
		var s := lerpf(g.call("calf"), g.call("thigh"), smoothstep(0.45, 0.62, p.y))
		var l := q
		l.x = lx + (q.x - lx) * s
		l.z = q.z * s
		var foot := 1.0 - smoothstep(0.10, 0.16, p.y)
		if foot > 0.0:
			var ankle := Vector3(lx, 0.06, -0.02)
			l = l.lerp(ankle + (l - ankle) * Vector3(g.call("feet"), 1.0, g.call("feet")), foot)
		l.x *= lerpf(1.0, g.call("hips"), smoothstep(0.70, 0.92, p.y))
		q = q.lerp(l, leg)

	# soft bodies (Majin): everything swells outwards a little, more on the belly and limbs
	var soft: float = g.call("soft")
	if soft > 0.0:
		var away := 1.0 - smoothstep(0.70, 0.76, ax) * smoothstep(1.2, 1.3, p.y)   # not the hands
		q += n * soft * away * (1.0 - wh * 0.5)
	return q

# ------------------------------------------------------------------------------------------------ profiles
## Race anatomy: each race reads differently in silhouette before any colour is applied.
const RACES := {
	"Saiyan": {"shoulders": 1.12, "chest": 1.14, "back": 1.06, "waist": 0.9, "hips": 0.96, "upper_arm": 1.12, "forearm": 1.06,
		"thigh": 1.08, "neck": 1.16, "jaw": 1.04, "brow": 0.008},
	"HalfSaiyan": {"shoulders": 1.05, "chest": 1.06, "waist": 0.94, "upper_arm": 1.05, "neck": 1.06},
	"Human": {"shoulders": 0.98, "upper_arm": 0.96, "forearm": 0.97},
	"Namekian": {"height": 1.07, "head_h": 1.08, "cranium": 1.45, "head_d": 1.04, "jaw": 0.74, "cheek": 0.88, "brow": 0.016,
		"neck": 0.84, "shoulders": 1.2, "chest": 1.04, "waist": 0.78, "hips": 0.88, "upper_arm": 1.04, "forearm": 0.9,
		"hands": 1.2, "thigh": 0.94, "calf": 0.86, "feet": 1.12},
	"FrostDemon": {"height": 0.97, "head_w": 0.9, "head_d": 1.12, "cranium": 1.18, "jaw": 0.78, "neck": 0.78,
		"shoulders": 0.86, "chest": 0.9, "back": 0.92, "waist": 0.74, "hips": 0.98, "upper_arm": 0.8, "forearm": 0.84,
		"thigh": 1.0, "calf": 0.8, "hands": 0.9, "feet": 1.22},
	"Majin": {"height": 0.96, "head_w": 1.16, "head_d": 1.1, "head_h": 0.96, "jaw": 1.16, "cranium": 0.86, "neck": 1.4,
		"shoulders": 1.04, "chest": 1.12, "back": 1.08, "waist": 1.3, "belly": 0.05, "hips": 1.16, "upper_arm": 1.22,
		"forearm": 1.18, "thigh": 1.22, "calf": 1.16, "hands": 1.12, "feet": 1.06, "soft": 0.022},
}

## Builds (look.build) still scale the whole rig; these add the shape that goes with them.
const BUILDS := {
	"Slim": {"shoulders": 0.95, "chest": 0.94, "waist": 0.94, "upper_arm": 0.9, "forearm": 0.92, "thigh": 0.92, "calf": 0.94},
	"Average": {},
	"Muscular": {"shoulders": 1.1, "chest": 1.14, "back": 1.08, "waist": 0.96, "neck": 1.16, "upper_arm": 1.2, "forearm": 1.14,
		"thigh": 1.12, "calf": 1.08, "hands": 1.04},
	"Tall": {"neck": 0.96, "waist": 0.96},
	"Short": {"head_w": 1.04, "head_h": 1.04, "head_d": 1.03, "hands": 0.96},
}

## Named fighters' own physiques (look.physique). Values multiply the race and build shape (offsets add).
const NAMED := {
	"gokan": {"jaw": 1.04, "chin": 0.004, "shoulders": 1.04, "upper_arm": 1.04},
	"vegara": {"jaw": 0.94, "cheek": 0.94, "brow": 0.01, "chest": 1.06, "waist": 0.92, "neck": 1.06},
	"piccor": {"cranium": 1.08, "shoulders": 1.08, "upper_arm": 1.08, "forearm": 1.04, "hands": 1.06},
	"nappo": {"head_w": 1.08, "jaw": 1.14, "neck": 1.24, "shoulders": 1.1, "chest": 1.1, "back": 1.1, "belly": 0.012, "waist": 1.04,
		"upper_arm": 1.14, "forearm": 1.08},
	"krilan": {"head_w": 1.06, "head_h": 0.96, "cranium": 0.92, "jaw": 1.04, "neck": 0.94},
	"roshu": {"neck": 0.86, "shoulders": 0.9, "chest": 0.9, "belly": 0.03, "waist": 1.08, "upper_arm": 0.86, "forearm": 0.92, "thigh": 0.88, "calf": 0.86},
	"frigor": {"head_w": 0.96, "cranium": 1.06, "jaw": 0.86, "neck": 0.9, "shoulders": 0.92, "waist": 0.88, "upper_arm": 0.92},
	"boo_fat": {"head_w": 1.04, "cranium": 0.9, "neck": 1.2, "chest": 1.12, "belly": 0.11, "waist": 1.5, "hips": 1.3,
		"upper_arm": 1.2, "forearm": 1.14, "thigh": 1.22, "calf": 1.12, "hands": 1.15, "soft": 0.02},
	"boo_kid": {"head_w": 1.06, "cranium": 0.88, "neck": 0.94, "shoulders": 0.9, "chest": 0.94, "waist": 0.9, "upper_arm": 0.94,
		"forearm": 0.94, "thigh": 0.94, "calf": 0.94, "soft": 0.004},
	"kold": {"head_w": 1.06, "jaw": 1.08, "neck": 1.2, "shoulders": 1.16, "chest": 1.14, "back": 1.1, "waist": 1.0, "upper_arm": 1.14, "forearm": 1.12,
		"thigh": 1.1},
	"cyborg16": {"head_w": 1.04, "jaw": 1.12, "chin": 0.008, "neck": 1.22, "shoulders": 1.16, "chest": 1.12, "back": 1.12, "waist": 1.06,
		"upper_arm": 1.18, "forearm": 1.16, "hands": 1.1},
	"recume": {"head_w": 0.94, "neck": 1.3, "shoulders": 1.18, "chest": 1.2, "back": 1.14, "belly": 0.02, "waist": 1.1, "upper_arm": 1.24,
		"forearm": 1.18, "thigh": 1.16, "calf": 1.1},
	"brolo": {"head_w": 1.04, "jaw": 1.12, "neck": 1.35, "shoulders": 1.2, "chest": 1.22, "back": 1.16, "waist": 1.02, "upper_arm": 1.3,
		"forearm": 1.22, "thigh": 1.2, "calf": 1.12, "hands": 1.1},
	"jiran": {"head_w": 1.08, "cranium": 0.94, "neck": 1.3, "shoulders": 1.14, "chest": 1.12, "back": 1.12, "waist": 1.0, "upper_arm": 1.16,
		"forearm": 1.1, "thigh": 1.08},
	"toppa": {"head_w": 1.06, "jaw": 1.1, "neck": 1.2, "shoulders": 1.1, "chest": 1.14, "belly": 0.07, "waist": 1.28, "hips": 1.12,
		"upper_arm": 1.12, "forearm": 1.08, "thigh": 1.1},
	"dodorra": {"head_w": 1.16, "head_h": 0.9, "cranium": 0.84, "neck": 1.3, "chest": 1.1, "belly": 0.12, "waist": 1.55, "hips": 1.3,
		"upper_arm": 1.08, "forearm": 1.04, "thigh": 1.14, "calf": 1.0, "soft": 0.012},
	"zarvon": {"jaw": 0.92, "neck": 0.94, "shoulders": 1.02, "waist": 0.88, "hips": 0.94, "upper_arm": 0.96},
	"gohin": {"jaw": 0.96, "shoulders": 1.04, "chest": 1.04, "waist": 0.92, "upper_arm": 1.04},
	"tronks": {"jaw": 0.95, "shoulders": 1.02, "waist": 0.9, "upper_arm": 0.98, "thigh": 0.96},
	"cyborg_slim": {"head_w": 0.96, "jaw": 0.92, "neck": 0.92, "shoulders": 0.96, "waist": 0.88, "upper_arm": 0.92, "forearm": 0.94},
	"cel": {"head_h": 1.04, "cranium": 1.18, "jaw": 0.86, "neck": 0.96, "shoulders": 1.12, "chest": 1.06, "waist": 0.82, "upper_arm": 1.0,
		"forearm": 0.96, "thigh": 1.02, "calf": 0.92, "feet": 1.1},
	"tenzo": {"head_h": 1.04, "cranium": 1.08, "neck": 1.14, "shoulders": 1.1, "chest": 1.1, "waist": 0.94, "upper_arm": 1.12},
	"yamcho": {"jaw": 1.02, "shoulders": 1.04, "waist": 0.94, "upper_arm": 1.04},
	"dabora": {"head_w": 1.04, "jaw": 1.1, "neck": 1.24, "shoulders": 1.12, "chest": 1.14, "waist": 1.0, "upper_arm": 1.14, "forearm": 1.08},
	"hitto": {"head_w": 0.94, "head_h": 1.06, "jaw": 0.84, "neck": 0.86, "shoulders": 1.0, "chest": 0.94, "waist": 0.82, "upper_arm": 0.86,
		"forearm": 0.88, "thigh": 0.9, "calf": 0.88},
	"beeros": {"head_w": 1.08, "cranium": 1.06, "jaw": 0.82, "neck": 0.78, "shoulders": 0.86, "chest": 0.86, "waist": 0.8, "hips": 0.92,
		"upper_arm": 0.78, "forearm": 0.8, "thigh": 0.84, "calf": 0.8, "hands": 0.94},
	"wiss": {"head_w": 0.96, "jaw": 0.86, "neck": 0.9, "shoulders": 0.92, "waist": 0.86, "upper_arm": 0.86, "forearm": 0.88},
	"sadan": {"head_w": 1.04, "jaw": 1.1, "chin": 0.006, "neck": 1.16, "shoulders": 1.08, "chest": 1.16, "belly": 0.015, "waist": 1.04,
		"upper_arm": 1.1},
	"kafla": {"waist": 0.86, "hips": 1.06, "shoulders": 0.96},
	"paragos": {"jaw": 1.06, "chin": 0.005, "neck": 1.04, "shoulders": 1.04, "chest": 1.04, "waist": 0.98},
	"gama": {"head_w": 0.96, "jaw": 1.04, "chin": 0.01, "neck": 1.06, "shoulders": 1.12, "chest": 1.08, "waist": 0.86, "upper_arm": 1.06,
		"thigh": 1.04},
	"morro": {"head_w": 1.06, "head_h": 0.94, "neck": 0.9, "shoulders": 0.92, "chest": 0.96, "belly": 0.02, "waist": 1.06,
		"upper_arm": 0.9, "forearm": 0.92, "thigh": 0.94},
}

## Younger versions (look.age, user request 2026-11-05): a child has a much bigger head for the body (about 1/5 of
## the height instead of 1/7), a soft round jaw, a thin neck, narrow shoulders and slim limbs; a teen sits between.
const AGES := {
	"child": {"head_w": 1.72, "head_h": 1.66, "head_d": 1.66, "jaw": 0.84, "chin": -0.006, "cheek": 1.08, "brow": -0.004, "neck": 0.62,
		"shoulders": 0.76, "chest": 0.82, "back": 0.84, "waist": 0.92, "belly": 0.012, "hips": 0.9, "upper_arm": 0.72, "forearm": 0.76,
		"hands": 0.82, "thigh": 0.82, "calf": 0.8, "feet": 0.85, "height": 0.92},
	"teen": {"head_w": 1.16, "head_h": 1.14, "head_d": 1.14, "height": 0.96, "jaw": 0.93, "neck": 0.88, "shoulders": 0.92, "chest": 0.93, "waist": 0.93,
		"upper_arm": 0.88, "forearm": 0.9, "thigh": 0.92, "calf": 0.92, "hands": 0.92},
}

## Every female character (look.female): narrower shoulders, neck and arms, a defined waist and wider hips.
const FEMALE := {"head_w": 0.95, "head_h": 0.98, "jaw": 0.86, "chin": -0.004, "cheek": 0.97, "neck": 0.84, "shoulders": 0.88, "chest": 0.96,
	"back": 0.92, "waist": 0.82, "hips": 1.12, "upper_arm": 0.84, "forearm": 0.86, "hands": 0.86, "thigh": 1.03, "calf": 0.93, "feet": 0.88,
	"bust": 0.055, "height": 0.96}

const OFFSETS := ["chin", "brow", "belly", "soft", "bust"]

static func combine(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k: String in b:
		if k in OFFSETS:
			out[k] = float(out.get(k, 0.0)) + float(b[k])
		else:
			out[k] = float(out.get(k, 1.0)) * float(b[k])
	return out

## The full profile for a look: race anatomy, build shape, named physique, then any explicit look.sculpt overrides.
static func profile_for(look: Dictionary) -> Dictionary:
	var p := combine(RACES.get(str(look.get("race", "Human")), {}), BUILDS.get(str(look.get("build", "Average")), {}))
	if look.get("female", false):
		p = combine(p, FEMALE)
	p = combine(p, AGES.get(str(look.get("age", "")), {}))
	p = combine(p, NAMED.get(str(look.get("physique", "")), {}))
	var extra: Variant = look.get("sculpt")
	if extra is Dictionary:
		p = combine(p, extra)
	return p

## Head pieces (hair, antennae, dome, hats) are built for the neutral head: this keeps them on the sculpted one.
static func head_xform(p: Dictionary) -> Transform3D:
	var gv := func(k: String) -> float: return float(p.get(k, NEUTRAL[k]))
	var s := Vector3(gv.call("head_w"), gv.call("head_h") * (1.0 + (gv.call("cranium") - 1.0) * 0.55), gv.call("head_d"))
	var c := HEAD_C + Vector3(0, -0.04, 0)
	return Transform3D(Basis.from_scale(s), c - Basis.from_scale(s) * c)
