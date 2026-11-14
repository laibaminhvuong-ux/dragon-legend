class_name Hair
extends RefCounted
# Anime hair meshes, ported from the JS model (spikyHair / formHair). Built in "head space": the JS head's
# frame (centre about (0, 0.06, 0), radius about 0.105, +Z is the face). HEAD_SPACE puts that frame on the
# mannequin's head (model space, rest pose). Meshes are cached per style and shared by every fighter.

const HEAD_SPACE := Transform3D(Vector3(0.98, 0, 0), Vector3(0, 1.1, 0), Vector3(0, 0, 1.12), Vector3(0, 1.66, 0.002))
# Mohawk / AngelCrest / Dreadlocks are NPC-only styles (cast batch B1; not in the creator's HAIR_STYLES list)
const BASE := {"Spiky": "goku", "Wild": "wild", "Swept": "flame", "LongSpiky": "mane", "Short": "short", "Bowl": "bowl", "Ponytail": "ponytail", "Long": "long", "Bun": "bun",
	"Mohawk": "mohawk", "AngelCrest": "angelcrest", "Dreadlocks": "dreads",
	# cast batch B5 (NPC-only too): Tronks' centre part, Bulna's bob, Vidal's twin tails, Mr. Sadan's afro, Serpa's big
	# curls, a topknot, young Bulna's side ponytail, straight shoulder-length hair, slicked-back hair (Tau)
	"CenterPart": "centerpart", "Bob": "bob", "TwinTails": "twintails", "Afro": "afro", "BigCurly": "bigcurly",
	"Topknot": "topknot", "SidePonytail": "sideponytail", "ShoulderStraight": "shoulder", "Slick": "slick",
	# task C (2026-11-13): Chelai's short pixie and Meros's rounded bob, both covering the back of the head to the nape
	"Pixie": "pixie", "RoundBob": "roundbob"}
const FORM_STYLES := ["ssj1", "ssj2", "ssj3", "ssj4", "grade3", "legendary", "ego", "beast"]
static var _cache: Dictionary = {}

## Hair secondary motion (one per fighter; no allocations per frame): a damped spring for the offset of a free hair
## tip (world space, metres). Moving air pulls the tip along: the wind minus the fighter's own velocity, so hair trails
## behind when running / flying / jumping, overshoots a little and springs back when the fighter stops, and leans
## with the wind. The shaders (hair_motion.gdshaderinc) bend each spike or lock by this offset, more towards its tip.
class Motion:
	const FREQ := 3.0        # Hz: how fast it springs back
	const DAMPING := 0.35    # < 1: a little overshoot
	const REACH := 0.11      # m: largest tip offset (a strong headwind / full-speed flight)
	const RESPONSE := 0.11   # per m/s of air speed, before saturating at REACH
	const TELEPORT := 60.0   # m/s: faster than this between frames is a teleport, not motion
	var offset := Vector3.ZERO
	var velocity := Vector3.ZERO
	var air := Vector3.ZERO       # smoothed air speed relative to the fighter (m/s)
	var _last := Vector3.ZERO
	var _has_last := false

	## Where the free tip wants to sit for this relative air speed (saturating: it never stretches past REACH).
	static func target_for(rel_air: Vector3) -> Vector3:
		var s := rel_air.length()
		if s < 0.0001:
			return Vector3.ZERO
		var mag := REACH * tanh(s * RESPONSE)
		var t := rel_air * (mag / s)
		t.y *= 0.7
		return t

	## One step: `pos` is the fighter's world position now, `wind` the moving air (WorldWind.vector()).
	func step(dt: float, pos: Vector3, wind: Vector3) -> Vector3:
		if dt <= 0.0:
			return offset
		var v := Vector3.ZERO
		if _has_last:
			v = (pos - _last) / dt
			if v.length() > TELEPORT:
				v = Vector3.ZERO
		_last = pos
		_has_last = true
		air = air.lerp(wind - v, 1.0 - exp(-dt * 25.0))   # light smoothing (frame jitter) that keeps the bounce
		var target := target_for(air)
		var w := TAU * FREQ
		var left := minf(dt, 0.1)
		while left > 0.0:   # semi-implicit Euler in <= 1/60 s steps: stable at any frame rate
			var h := minf(left, 1.0 / 60.0)
			velocity += ((target - offset) * w * w - velocity * (2.0 * DAMPING * w)) * h
			offset += velocity * h
			left -= h
		if offset.length() > REACH * 1.4:
			offset = offset.limit_length(REACH * 1.4)
		return offset

	## Back to rest at once (teleports, re-enabling after being far from the camera).
	func reset() -> void:
		offset = Vector3.ZERO; velocity = Vector3.ZERO; air = Vector3.ZERO; _has_last = false

## The base hair style for a look (or "" for bald / races without hair).
static func base_style(look: Dictionary, race: Dictionary) -> String:
	var h := str(look.get("hair", "Spiky"))
	# races with hair draw every style (a Saiyan with Short hair); hairless races (Namekian, Frost Demon, Majin)
	# only when the look says so with hairAnyRace (Kais, angels, aliens with hair)
	if not race_has_hair(look, race) and not (race.get("hairStyles", []) as Array).has(h):
		return ""
	return str(BASE.get(h, ""))

## Whether a fighter of this race can have hair at all: races with a hair style list, or a hairless race's look
## with hairAnyRace. Forms never grow hair on the others (a Namekian in a form keeps a bare head).
static func race_has_hair(look: Dictionary, race: Dictionary) -> bool:
	var any: Variant = look.get("hairAnyRace", false)
	return (race.get("hairStyles", []) as Array).size() > 1 or (any is bool and any)

## Hairless races have their own skull (tall Namekian cranium, narrow deep Frost Demon head): hair made for the
## human head sat on it like a hat lifted off the scalp. The skull of a rest-pose body mesh: crown height, half
## width and front/back at the hair line (cached per mesh; read once when a fighter is built).
static var _skulls: Dictionary = {}
static func skull(mesh: Mesh) -> Dictionary:
	var key := mesh.get_instance_id()
	if _skulls.has(key):
		return _skulls[key]
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top := -9.0
	for p in v:
		if p.y > 1.55 and absf(p.x) < 0.2:
			top = maxf(top, p.y)
	var s := {"top": top, "w": 0.0, "z0": 9.0, "z1": -9.0}
	for p in v:
		if p.y > top - 0.09 and p.y < top - 0.035:   # the band the hair line runs round (above the ears)
			if absf(p.z) < 0.05:
				s.w = maxf(s.w, absf(p.x))
			if absf(p.x) < 0.05:
				s.z0 = minf(s.z0, p.z); s.z1 = maxf(s.z1, p.z)
	if s.w <= 0.0 or s.z1 <= s.z0:   # nothing measured: no correction
		s = {}
	_skulls[key] = s
	return s

## Model-space transform taking hair fitted to skull `from` onto skull `to` (identity when either is unknown):
## widths and depths in proportion, heights from the brow line up to the crown.
static func skull_fit(from: Dictionary, to: Dictionary) -> Transform3D:
	if from.is_empty() or to.is_empty():
		return Transform3D.IDENTITY
	var yb := float(from.top) - 0.12
	var sc := Vector3(float(to.w) / float(from.w), (float(to.top) - yb) / (float(from.top) - yb), (float(to.z1) - float(to.z0)) / (float(from.z1) - float(from.z0)))
	var a := Vector3(0, yb, (float(from.z0) + float(from.z1)) * 0.5)
	var b := Vector3(0, yb, (float(to.z0) + float(to.z1)) * 0.5)
	return Transform3D(Basis.from_scale(sc), b - Basis.from_scale(sc) * a)

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
		"mohawk":   # bald sides, one thick rounded crest from the forehead over the crown (Kais)
			var ridge := PackedVector3Array()
			for i in 7:
				var a := lerpf(-0.8, 1.7, i / 6.0)   # angle from the top of the head, + towards the back
				ridge.append(Vector3(0, 0.05 + cos(a) * 0.118, -0.008 - sin(a) * 0.124))
			g.tube(ridge, 0.04, 0.028, 18, 12)
			for i in 9:   # the crest: flattened locks standing up and swept back, tallest over the crown
				var a := lerpf(-0.7, 1.5, i / 8.0)
				var p := Vector3(0, 0.05 + cos(a) * 0.12, -0.008 - sin(a) * 0.126)
				var d := Vector3(0, cos(a), -sin(a))
				g.spike(p - d * 0.03, 0.075 + 0.05 * (1.0 - absf(a - 0.3) / 1.3), 0.045, d + Vector3(0, 0.8, -0.6), 0.1)
		"angelcrest":   # combed straight up into one tall rounded column growing out of the crown (angels)
			g.tube(PackedVector3Array([Vector3(0, 0.0, -0.035), Vector3(0, 0.09, -0.04), Vector3(0, 0.17, -0.05), Vector3(0, 0.24, -0.06)]), 0.085, 0.055, 20, 18)
			g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.8, 1.0)), Vector3(0, 0.24, -0.06)), 0.055, 10, 16)
		"dreads":   # dreadlocks: a cap and thick ropes hanging round the head to the shoulders
			_cap(g, 0.116, 0.38, 0.66)
			for i in 15:
				var a := lerpf(-2.1, 2.1, i / 14.0)
				if cos(a) > 0.6:
					continue   # leave the face clear
				var top := Vector3(sin(a) * 0.1, 0.1, cos(a) * 0.1 - 0.012)
				var out := Vector3(sin(a), 0, cos(a)) * 0.04
				var l := 0.26 + 0.04 * float((i * 7) % 3)
				g.tube(PackedVector3Array([top, top + out + Vector3(0, -0.06, -0.02), top + out * 1.5 + Vector3(0, -l * 0.6, -0.03), top + out * 1.6 + Vector3(0, -l, -0.02)]), 0.02, 0.012, 14, 6)
			for i in 5:   # a few locks falling over the forehead sides
				var x := (i / 4.0 - 0.5) * 0.16
				g.spike(Vector3(x, 0.115, 0.085), 0.06, 0.02, Vector3(x * 2.5, -1, 0.3))
		"centerpart", "bob", "twintails", "afro", "bigcurly", "topknot", "sideponytail", "shoulder", "slick":
			_b5(g, style)
		"pixie", "roundbob":
			_short_full(g, style)
		_:
			_cap(g, 0.113)
			_form(g, style)

## A curtain of straight locks round the back and sides from angle -span..span (0 = the face), `length` long,
## leaving the face clear; `flare` pushes the tips outwards, `curl` turns them in under the jaw (bob).
static func _curtain(g: Geo, n: int, span: float, length: float, flare: float, curl := 0.0, rad := 0.03, y0 := 0.06) -> void:
	for i in n:
		var a := lerpf(-span, span, i / float(n - 1))
		if cos(a) > 0.5:
			continue   # leave the face clear
		var out := Vector3(sin(a), 0, cos(a))
		var top := out * 0.112 + Vector3(0, y0, -0.012)
		var mid := top + out * flare + Vector3(0, -length * 0.55, -0.01)
		var tip := top + out * (flare * 0.8 - curl) + Vector3(0, -length, 0.0)
		g.tube(PackedVector3Array([top, top + out * flare * 0.6 + Vector3(0, -length * 0.25, -0.01), mid, tip]), rad, rad * 0.45, 12, 6)

## A lock of fringe from the crown down over the forehead to `tip`.
static func _lock(g: Geo, root: Vector3, tip: Vector3, rad: float) -> void:
	var mid := (root + tip) * 0.5 + (root + tip).normalized() * 0.025 + Vector3(0, 0.02, 0)
	g.tube(PackedVector3Array([root, mid, tip]), rad, rad * 0.25, 12, 6)

## Cast batch B5 base styles.
static func _b5(g: Geo, style: String) -> void:
	match style:
		"centerpart":   # Tronks: a centre parting, two curtains of fringe falling to the cheeks, covered ears, straight back
			_cap(g, 0.116, 0.36, 0.66)
			for s in [1.0, -1.0]:
				for i in 5:
					var k := i / 4.0
					var root := Vector3(s * 0.008, 0.172 - k * 0.02, 0.03 - k * 0.04)
					var tip := Vector3(s * (0.03 + k * 0.06), 0.06 - k * 0.04, 0.112 - k * 0.04)
					_lock(g, root, tip, 0.03)
			_curtain(g, 15, 2.3, 0.15, 0.022, 0.0, 0.03)
		"bob":   # Bulna (Super): a full rounded bob to the jaw, tips curling in, side-swept fringe
			_cap(g, 0.118, 0.38, 0.7)
			_curtain(g, 17, 2.4, 0.12, 0.012, 0.018, 0.032, 0.07)
			for i in 6:
				var k := i / 5.0
				_lock(g, Vector3(-0.03 + k * 0.03, 0.17, 0.03), Vector3(-0.07 + k * 0.13, 0.085 - k * 0.012, 0.108 - absf(k - 0.5) * 0.03), 0.028)
		"twintails":   # Vidal: two low tails tied behind the ears, short fringe
			_cap(g, 0.114, 0.38, 0.62)
			for s in [1.0, -1.0]:
				var tie := Vector3(s * 0.085, 0.015, -0.06)
				g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, s * 1.2)), tie), 0.022, 0.009, 14, 6)
				g.tube(PackedVector3Array([tie, tie + Vector3(s * 0.035, -0.05, -0.015), tie + Vector3(s * 0.05, -0.15, -0.02), tie + Vector3(s * 0.04, -0.24, 0.0)]), 0.03, 0.01, 18, 8)
			for i in 7:
				var x := (i / 6.0 - 0.5) * 0.15
				g.spike(Vector3(x, 0.115, 0.088), 0.045, 0.018, Vector3(x * 0.8, -1, 0.35))
		"afro":   # Mr. Sadan: a big round curly afro over the top and sides of the head
			_cap(g, 0.118, 0.36, 0.64)
			for i in 60:   # curls packed over the cap, puffing it out
				var a := fmod(i * 2.39996, TAU)
				var th := acos(1.0 - (i + 0.5) / 60.0 * 1.2)
				var d := Vector3(sin(th) * sin(a), cos(th), sin(th) * cos(a))
				if d.z > 0.35 and d.y < 0.8:
					continue   # not over the face
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(d.x * 0.13, 0.065 + d.y * 0.125, -0.02 + d.z * 0.13)), 0.045, 6, 8)
			for s in [1.0, -1.0]:   # sideburns
				g.sphere(Transform3D(Basis.from_scale(Vector3(0.5, 1.4, 0.8)), Vector3(s * 0.098, 0.0, 0.03)), 0.024, 6, 8)
		"bigcurly":   # Princess Serpa / Baaba: a voluminous mass of curls round the head and down to the shoulders
			_cap(g, 0.12, 0.36, 0.66)
			for i in 64:
				var a := lerpf(-2.7, 2.7, fmod(i * 0.618, 1.0))
				var y := 0.17 - 0.32 * fmod(i * 0.381, 1.0)
				if cos(a) > 0.35 and y < 0.11:
					continue   # leave the face clear
				var r := 0.115 + 0.02 * (1.0 - absf(y - 0.05) * 3.0) + 0.03 * clampf(-y, 0.0, 1.0)
				g.sphere(Transform3D(Basis.IDENTITY, Vector3(sin(a) * r, y, cos(a) * r - 0.025)), 0.042, 6, 8)
			for i in 5:   # curls over the forehead
				g.sphere(Transform3D(Basis.IDENTITY, Vector3((i / 4.0 - 0.5) * 0.15, 0.135 - absf(i - 2) * 0.008, 0.075)), 0.03, 6, 8)
		"topknot":   # hair combed up into a round knot on the crown
			_cap(g, 0.114, 0.38, 0.62)
			g.sphere(Transform3D(Basis.from_scale(Vector3(1.0, 0.9, 1.0)), Vector3(0, 0.185, -0.02)), 0.042, 10, 14)
			g.torus(Transform3D(Basis.IDENTITY, Vector3(0, 0.155, -0.018)), 0.03, 0.008, 16, 6)
		"sideponytail":   # young Bulna: hair gathered into a ponytail high on her left side
			_cap(g, 0.114, 0.38, 0.62)
			var tie := Vector3(0.085, 0.12, -0.045)
			g.torus(Transform3D(Basis.from_euler(Vector3(0, 0, 0.8)), tie), 0.022, 0.009, 14, 6)
			g.tube(PackedVector3Array([tie, tie + Vector3(0.05, -0.02, -0.01), tie + Vector3(0.07, -0.13, -0.02), tie + Vector3(0.05, -0.27, 0.0)]), 0.034, 0.01, 18, 8)
			for i in 6:
				var x := (i / 5.0 - 0.5) * 0.14
				g.spike(Vector3(x, 0.115, 0.088), 0.05, 0.018, Vector3(x * 0.6 - 0.15, -1, 0.35))
		"shoulder":   # straight hair to the shoulders, parted at the side
			_cap(g, 0.116, 0.37, 0.66)
			_curtain(g, 15, 2.3, 0.24, 0.025, 0.0, 0.028)
			for i in 6:
				var k := i / 5.0
				_lock(g, Vector3(0.03, 0.17, 0.02), Vector3(-0.07 + k * 0.14, 0.09 - absf(k - 0.4) * 0.03, 0.105 - absf(k - 0.5) * 0.03), 0.026)
		"slick":   # combed flat straight back (Tau): a smooth cap with a few long swept locks
			_cap(g, 0.116, 0.34, 0.64)
			for i in 7:
				var x := (i / 6.0 - 0.5) * 0.12
				g.tube(PackedVector3Array([Vector3(x, 0.15, 0.07), Vector3(x * 1.1, 0.172, -0.01), Vector3(x * 1.1, 0.13, -0.1), Vector3(x, 0.05, -0.128)]), 0.014, 0.008, 12, 6)

## Short hair that covers the whole skull down to the nape (the B5 curtains stop at the sides, which leaves the
## back of the head as a bare cap rim: on a long neck that read as a hat sitting on top).
## pixie (Chelai): volume on top, layered locks over the back and above the ears, fringe swept to her left;
## roundbob (Meros): a rounded bob over the ears to the jaw, straight fringe to the brows.
static func _short_full(g: Geo, style: String) -> void:
	if style == "pixie":   # fringe swept across to her left brow, ears clear, layered points at the nape
		_shell(g, 0.12, PI * 0.43, PI * 0.5, PI * 0.8, 0.03, 0.0, PI * 0.07, 13, 0.12, PI * 0.06)
	else:   # bob over the ears to the jaw, fringe to the brows
		_shell(g, 0.117, PI * 0.47, PI * 0.8, PI * 0.84, 0.07, 0.04, PI * 0.04, 26, 0.05)

## A smooth hair shell over the skull (head space, same frame as _cap): polar angle reaches `front` over the face
## (minus `sweep` on the right, plus on the left: a side-swept fringe), `side` over the ears and `back` at the nape;
## `flare` widens it below the equator (a bob), `curl` turns the hem back in; the hem is cut into `jags` points
## `jag` deep (locks, half as deep over the face); `crown` adds volume on top.
static func _shell(g: Geo, r: float, front: float, side: float, back: float, flare: float, curl: float, jag: float, jags: int, crown: float, sweep := 0.0, rings := 14, segs := 104) -> void:
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var idx := PackedInt32Array()
	var xf := Transform3D(Basis.from_scale(Vector3(1.04, 1.0, 1.1)), Vector3(0, 0.05, -0.008))
	for ri in rings + 1:
		var t := float(ri) / rings
		for si in segs + 1:
			var a := TAU * float(si) / segs
			var c := cos(a)   # 1 = the face, -1 = the back
			var tmax := lerpf(side, front + sweep * sin(a), smoothstep(0.3, 0.85, c)) if c > 0.0 else lerpf(side, back, -c)
			var saw := absf(fmod(a / TAU * jags + 0.5, 1.0) * 2.0 - 1.0)   # 0..1 zigzag round the head
			tmax += jag * (saw - 0.5) * (1.0 - 0.5 * smoothstep(0.2, 0.7, c))
			var th := tmax * t
			var rr := r * (1.0 + flare * smoothstep(PI * 0.42, PI * 0.85, th) + crown * pow(maxf(cos(th), 0.0), 2.0) - curl * pow(t, 6.0))
			rr *= 1.0 + 0.022 * t * (absf(saw - 0.5) * 2.0)   # a ridge down each lock (strands catch the light)
			var d := Vector3(sin(th) * sin(a), cos(th), sin(th) * cos(a))
			verts.append(d * rr); norms.append(d)
	for ri in rings:
		for si in segs:
			var a0 := ri * (segs + 1) + si
			var b0 := a0 + segs + 1
			idx.append_array([a0, a0 + 1, b0, a0 + 1, b0 + 1, b0])   # clockwise seen from outside (Geo.cap's order shows its inside)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_INDEX] = idx
	var fn := Geo._normals(verts, idx)   # from the faces (ridges shade); flipped outwards to match the clockwise winding
	for k in fn.size():
		fn[k] = -fn[k] if fn[k].dot(norms[k]) < 0.0 else fn[k]
	arr[Mesh.ARRAY_NORMAL] = fn
	g.add_arrays(arr, xf)

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
