class_name Hair
extends RefCounted
# Anime hair meshes, ported from the JS model (spikyHair / formHair). Built in "head space": the JS head's
# frame (centre about (0, 0.06, 0), radius about 0.105, +Z is the face). HEAD_SPACE puts that frame on the
# mannequin's head (model space, rest pose). Meshes are cached per style and shared by every fighter.

const HEAD_SPACE := Transform3D(Vector3(0.98, 0, 0), Vector3(0, 1.1, 0), Vector3(0, 0, 1.12), Vector3(0, 1.66, 0.002))
const BASE := {"Spiky": "goku", "Wild": "wild", "Swept": "flame", "LongSpiky": "mane", "Short": "short", "Bowl": "bowl", "Ponytail": "ponytail", "Long": "long", "Bun": "bun"}
const FORM_STYLES := ["ssj1", "ssj2", "ssj3", "ssj4", "grade3", "legendary", "ego", "beast"]
static var _cache: Dictionary = {}

## The base hair style for a look (or "" for bald / races without hair).
static func base_style(look: Dictionary, race: Dictionary) -> String:
	var h := str(look.get("hair", "Spiky"))
	if not (race.get("hairStyles", []) as Array).has(h):
		return ""
	return str(BASE.get(h, ""))

## The hair a form shows on top of a base style ("" = keep the base hair).
static func form_style(form_hair: String, base: String) -> String:
	if form_hair == "same":
		return base if base in ["goku", "wild", "flame", "mane"] else "goku"
	if base == "flame" and form_hair in ["ssj1", "ssj2"]:
		return "flame_" + form_hair
	return form_hair

static func mesh(style: String) -> ArrayMesh:
	if style == "":
		return null
	if not _cache.has(style):
		var g := Geo.new()
		_build(g, style)
		_cache[style] = g.mesh()
	return _cache[style]

static func _build(g: Geo, style: String) -> void:
	match style:
		"goku", "wild", "flame", "mane":
			_cap(g, 0.112)
			_spiky(g, style)
		"flame_ssj1", "flame_ssj2":
			var sub := Geo.new()
			_cap(sub, 0.113)
			_spiky(sub, "flame")
			var k := 1.12 if style == "flame_ssj2" else 1.05
			g.add_arrays(sub.mesh().surface_get_arrays(0), Transform3D(Basis.from_scale(Vector3(1, k, 1)), Vector3.ZERO))
		"short":
			_cap(g, 0.114, 0.4, 0.6)
			for i in 26:
				var a := TAU * i / 26.0
				var y := 0.35 + 0.6 * float((i * 7) % 5) / 5.0
				var d := Vector3(sin(a) * cos(y), sin(y), cos(a) * cos(y))
				g.spike(d * 0.1 + Vector3(0, 0.05, -0.012), 0.045, 0.03, d + Vector3(0, 0.6, 0))
		"bowl":
			_cap(g, 0.12, 0.42, 0.72)
			for i in 9:   # a straight fringe
				var x := (i / 8.0 - 0.5) * 0.15
				g.spike(Vector3(x, 0.11, 0.09), 0.06, 0.022, Vector3(x * 0.6, -1, 0.35))
		"ponytail":
			_cap(g, 0.114, 0.4, 0.6)
			g.torus(Transform3D(Basis.from_euler(Vector3(1.2, 0, 0)), Vector3(0, 0.07, -0.115)), 0.026, 0.01, 16, 8)
			g.tube(PackedVector3Array([Vector3(0, 0.07, -0.115), Vector3(0, 0.02, -0.17), Vector3(0, -0.1, -0.18), Vector3(0, -0.22, -0.15)]), 0.032, 0.012, 20, 10)
		"long":   # long straight hair: a full cap, a side-swept fringe and a curtain of locks down the back
			_cap(g, 0.116, 0.38, 0.66)
			for i in 7:
				var x := (i / 6.0 - 0.5) * 0.17
				g.spike(Vector3(x, 0.115, 0.085), 0.05, 0.02, Vector3(x * 0.8 + 0.25, -1, 0.3))
			for i in 15:
				var a := lerpf(-1.9, 1.9, i / 14.0)
				var top := Vector3(sin(a) * 0.112, 0.03, cos(a) * 0.112 - 0.012)
				if cos(a) > 0.55:
					continue   # leave the face clear
				var out := Vector3(sin(a), 0, cos(a)) * 0.03
				g.tube(PackedVector3Array([top, top + out + Vector3(0, -0.1, -0.02), top + out * 1.3 + Vector3(0, -0.24, -0.035), top + out * 1.2 + Vector3(0, -0.36, -0.03)]), 0.026, 0.008, 14, 6)
		"bun":   # hair pulled back into a round bun with a short fringe
			_cap(g, 0.114, 0.4, 0.6)
			g.sphere(Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -0.1)), 0.05, 10, 14)
			g.torus(Transform3D(Basis.from_euler(Vector3(0.9, 0, 0)), Vector3(0, 0.12, -0.075)), 0.04, 0.008, 16, 6)
			for i in 5:
				var x := (i / 4.0 - 0.5) * 0.12
				g.spike(Vector3(x, 0.115, 0.088), 0.035, 0.016, Vector3(x * 0.5, -1, 0.35))
		_:
			_cap(g, 0.113)
			_form(g, style)

## A scalp cap so no head shows between spikes; it rises at the front to clear the eyes.
static func _cap(g: Geo, r: float, front := 0.36, back := 0.62) -> void:
	g.cap(Transform3D(Basis.from_scale(Vector3(1.04, 1.0, 1.1)), Vector3(0, 0.05, -0.008)), r * 1.03, PI * front, PI * back)

static func _ring(g: Geo, n: int, y_angle: float, length: float, rad: float, tilt: float, spread := TAU, start := 0.0, up := 0.0, form := false, jitter := 0.3) -> void:
	for i in n:
		var a: float
		var l: float
		if form:
			a = start + (float(i) / maxf(1.0, n - (1 if spread < TAU else 0))) * spread
			l = length * (1.0 - jitter / 2.0 + jitter * (float((i * 37) % 10) / 10.0))
		else:
			a = start + (float(i) / n) * spread
			l = length * (0.85 + float((i * 37) % 10) / 33.0)
		var dir := Vector3(sin(a) * cos(y_angle), sin(y_angle), cos(a) * cos(y_angle))
		var base := dir * 0.085
		var d := dir; d.y += tilt
		g.spike(Vector3(base.x, base.y + 0.05, base.z - 0.015), l, rad, d, up)

static func _spiky(g: Geo, style: String) -> void:
	match style:
		"goku":
			_ring(g, 7, 0.25, 0.16, 0.042, 0.25, PI * 1.4, PI * 0.8)
			_ring(g, 5, 0.9, 0.15, 0.045, 0.35)
			_ring(g, 4, 0.15, 0.09, 0.03, -0.25, PI * 0.6, -PI * 0.3)
		"wild":
			_ring(g, 9, 0.2, 0.2, 0.045, 0.15, PI * 1.5, PI * 0.75)
			_ring(g, 6, 0.85, 0.2, 0.048, 0.3)
			_ring(g, 5, 0.1, 0.1, 0.03, -0.3, PI * 0.7, -PI * 0.35)
		"flame":
			_ring(g, 9, 0.55, 0.24, 0.045, 1.6, TAU, 0.0, -0.2)
			_ring(g, 6, 1.2, 0.26, 0.05, 1.8)
		"mane":
			_ring(g, 6, 0.6, 0.14, 0.045, 0.3)
			for i in 9:
				var a := PI * 0.65 + (i / 8.0) * PI * 0.7
				g.spike(Vector3(sin(a) * 0.07, 0.05, cos(a) * 0.07 - 0.03), 0.55 + (i % 3) * 0.12, 0.05, Vector3(sin(a) * 0.4, -1, cos(a) * 0.4 - 0.25), 0.1)

static func _form(g: Geo, style: String) -> void:
	match style:
		"ssj1":
			_ring(g, 8, 0.3, 0.19, 0.05, 0.75, PI * 1.5, PI * 0.75, -0.15, true)
			_ring(g, 6, 1.0, 0.2, 0.054, 0.35, TAU, 0.0, -0.25, true)
			_ring(g, 4, 0.12, 0.1, 0.03, -0.4, PI * 0.55, -PI * 0.27, 0.0, true)
		"ssj2":
			_ring(g, 10, 0.45, 0.27, 0.036, 2.0, PI * 1.55, PI * 0.72, 0.0, true, 0.45)
			_ring(g, 8, 1.15, 0.3, 0.038, 1.6, TAU, 0.0, 0.0, true, 0.45)
			g.spike(Vector3(0.03, 0.115, 0.083), 0.16, 0.019, Vector3(0.25, -1, 0.6), 0.2)
		"ssj3":
			_ring(g, 6, 0.95, 0.15, 0.05, 0.45, TAU, 0.0, 0.0, true)
			_ring(g, 4, 0.15, 0.1, 0.03, -0.35, PI * 0.5, -PI * 0.25, 0.0, true)
			for i in 15:
				var a := PI * 0.5 + (i / 14.0) * PI
				var side := sin(a)
				var l := 0.62 + (1.0 - absf(side)) * 0.32 + ((i * 7) % 5) * 0.03
				g.spike(Vector3(side * 0.075, 0.08, cos(a) * 0.06 - 0.04), l, 0.06, Vector3(side * 0.42, -1, cos(a) * 0.25 - 0.42), 0.08)
		"ssj4":
			_ring(g, 7, 0.9, 0.15, 0.05, 0.25, TAU, 0.0, -0.2, true)
			_ring(g, 5, 0.12, 0.12, 0.03, -0.45, PI * 0.6, -PI * 0.3, 0.0, true)
			for i in 11:
				var a := PI * 0.55 + (i / 10.0) * PI * 0.9
				var side := sin(a)
				g.spike(Vector3(side * 0.075, 0.08, cos(a) * 0.06 - 0.04), 0.36 + ((i * 7) % 4) * 0.04, 0.055, Vector3(side * 0.6, -0.7, cos(a) * 0.3 - 0.6), 0.1)
		"grade3":
			_ring(g, 9, 0.35, 0.25, 0.066, 1.0, PI * 1.6, PI * 0.7, -0.1, true, 0.25)
			_ring(g, 7, 1.0, 0.27, 0.07, 0.6, TAU, 0.0, -0.15, true, 0.25)
			_ring(g, 4, 0.65, 0.2, 0.06, 0.9, PI * 0.7, -PI * 0.35, 0.1, true)
			g.spike(Vector3(0.025, 0.11, 0.085), 0.1, 0.028, Vector3(0.2, -1, 0.7), 0.15)
		"legendary":
			_ring(g, 11, 0.4, 0.3, 0.064, 0.55, PI * 1.7, PI * 0.65, -0.3, true, 0.4)
			_ring(g, 8, 1.05, 0.32, 0.066, 0.7, TAU, 0.0, -0.45, true, 0.4)
			_ring(g, 5, 0.75, 0.24, 0.058, 1.4, PI * 0.8, -PI * 0.4, -0.2, true, 0.3)
			for i in 9:
				var a := PI * 0.6 + (i / 8.0) * PI * 0.8
				var side := sin(a)
				g.spike(Vector3(side * 0.08, 0.06, cos(a) * 0.07 - 0.04), 0.3 + ((i * 7) % 4) * 0.04, 0.064, Vector3(side * 0.7, -0.9, cos(a) * 0.45 - 0.45), 0.15)
		"ego":
			_ring(g, 9, 0.5, 0.27, 0.058, 0.7, PI * 1.7, PI * 0.65, -0.2, true)
			_ring(g, 6, 1.2, 0.34, 0.062, 1.2, TAU, 0.0, -0.15, true, 0.25)
			_ring(g, 4, 0.85, 0.32, 0.056, 1.8, PI * 0.6, -PI * 0.3, -0.1, true, 0.25)
			g.spike(Vector3(0, 0.125, 0.09), 0.07, 0.022, Vector3(0, -1, 0.35), 0.0)
		"beast":
			_ring(g, 9, 0.55, 0.36, 0.05, 2.6, PI * 1.6, PI * 0.7, -0.35, true, 0.35)
			_ring(g, 6, 1.2, 0.42, 0.055, 2.8, TAU, 0.0, -0.3, true)
			_ring(g, 3, 0.12, 0.09, 0.026, -0.4, PI * 0.45, -PI * 0.22, 0.0, true)
