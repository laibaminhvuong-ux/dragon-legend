class_name FaceShape
extends RefCounted
# Different faces for everyone (user request, 2026-11-04): a face is derived from a seed (an NPC's id, the player's
# name, or look.faceSeed) and sets the painted face's proportions in the outfit shader plus a little 3D structure:
#   eyes   Vector4(size, extra gap, outer-corner tilt, height offset)
#   brows  Vector4(thickness, length, arch, height offset)
#   mouth  Vector4(width, height offset, iris size, mark: 0 none, 1 scar, 2 freckles)
#   nose   3D nose size;  sculpt  small jaw/chin/cheek/brow-ridge differences for BodySculpt (quantised so many
#          characters still share a sculpted mesh)

static func _rng(seed: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("face:" + seed)
	return r

static func params(seed: String) -> Dictionary:
	var r := _rng(seed)
	var q := func(v: float, step := 0.02) -> float: return snappedf(v, step)
	var mark := 0
	var roll := r.randf()
	if roll < 0.08: mark = 1
	elif roll < 0.16: mark = 2
	return {
		"eyes": Vector4(r.randf_range(0.8, 1.2), r.randf_range(-0.004, 0.005), r.randf_range(-0.25, 0.3), r.randf_range(-0.004, 0.004)),
		"brows": Vector4(r.randf_range(0.6, 1.6), r.randf_range(0.75, 1.15), r.randf_range(-1.0, 1.0), r.randf_range(-0.003, 0.004)),
		"mouth": Vector4(r.randf_range(0.75, 1.3), r.randf_range(-0.004, 0.004), r.randf_range(0.8, 1.15), float(mark)),
		"nose": r.randf_range(0.8, 1.3),
		"sculpt": {"jaw": q.call(r.randf_range(0.94, 1.08)), "chin": q.call(r.randf_range(-0.004, 0.006), 0.002),
			"cheek": q.call(r.randf_range(0.95, 1.05)), "brow": q.call(r.randf_range(0.0, 0.006), 0.002)},
	}

## The seed for a look: an explicit faceSeed, else the whole look (characters built from the same look match).
static func seed_for(look: Dictionary) -> String:
	if look.get("faceSeed") != null and str(look.faceSeed) != "":
		return str(look.faceSeed)
	return JSON.stringify(look)
