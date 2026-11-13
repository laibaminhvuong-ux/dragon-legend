class_name LandmarksDivine
extends RefCounted
# Extra landmark builders for this world group, called from WorldLandmarks (hook keeps landmarks.gd small).
# Add a type name to TYPES and a match arm in build().
#
# Batch B3 (Other World & divine realms, 2026-11-10): silhouettes matched to the reference pack
# (art/reference/maps_audit.md, batch 3). Same approach as LandmarksOrigins (whose helper class B this file extends):
# primitive-built, merged into one mesh per material. Snake bodies keep their UVs (scale pattern) and are left out
# of the merge (meta "spin"). Local +z is the front. Data swaps that use these types are listed in
# art/reference/map_data_requests_divine.md; nothing is placed until the data names them.
# Optional params (all have defaults): see each builder's comment.
# Preview: godot/tests/preview_divine_landmarks.gd (DL_PREVIEW_LANDMARK=<type>|all).
# The serpent materials (serpent_scales / serpent_paving / serpent_spike) are shared with WorldTerrain's
# optional `path.serpent` road style.

const TYPES: Array[String] = ["checkinhall", "serpenthead", "serpentcoils", "kaiorb", "kaiband", "beerusisle", "godtree",
	"beeruscastle", "toparena", "zenopalace", "u6arena", "cupstand", "shieldbox", "needlepeak", "bloodpool"]

static func build(type: String, g: Node3D, zone: RefCounted, l: Dictionary) -> void:
	var b := D.new(g, zone, l)
	match type:
		"checkinhall": b.checkinhall()
		"serpenthead": b.serpenthead()
		"serpentcoils": b.serpentcoils()
		"kaiorb": b.kaiorb()
		"kaiband": b.kaiband()
		"beerusisle": b.beerusisle()
		"godtree": b.godtree()
		"beeruscastle": b.beeruscastle()
		"toparena": b.toparena()
		"zenopalace": b.zenopalace()
		"u6arena": b.u6arena()
		"cupstand": b.cupstand()
		"shieldbox": b.shieldbox()
		"needlepeak": b.needlepeak()
		"bloodpool": b.bloodpool()
		_:
			return
	b.finish()

# --- shared shader materials (cached) ------------------------------------------------------------------------------
static var _cache: Dictionary = {}
static var _clock := Mutex.new()

static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	_clock.lock()
	var hit: Variant = _cache.get(key)
	_clock.unlock()
	if hit != null:
		return hit
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	_clock.lock()
	_cache[key] = m
	_clock.unlock()
	return m

const _HASH := "float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\n"

## Lilac-grey snake scales. UV.x = metres along the body, UV.y = metres round it.
static func serpent_scales() -> ShaderMaterial:
	return _shader_mat("scales", "shader_type spatial;\nrender_mode cull_disabled;\n" + _HASH + """
void fragment() {
	vec2 p = vec2(UV.x / 0.75, UV.y / 0.6);
	p.y += mod(floor(p.x), 2.0) * 0.5;
	vec2 f = fract(p);
	float d = length(vec2(f.x * 1.05, (f.y - 0.5) * 1.5));
	float rim = smoothstep(0.62, 0.92, d);
	float v = hash2(floor(p)) * 0.10;
	vec3 base = vec3(0.50, 0.50, 0.70) * (0.93 + v);
	vec3 dark = vec3(0.22, 0.22, 0.36);
	ALBEDO = mix(base, dark, rim * 0.85) * (0.88 + 0.12 * f.x);
	ROUGHNESS = 0.38 + rim * 0.4;
	SPECULAR = 0.6;
}
""")

## Lilac stone paving for the road top. UV.x = metres across (0 = centre), UV.y = metres along.
static func serpent_paving() -> ShaderMaterial:
	return _shader_mat("paving", "shader_type spatial;\n" + _HASH + """
uniform float half_w = 2.1;
void fragment() {
	vec2 p = vec2(UV.x / 1.05, UV.y / 0.8);
	p.x += mod(floor(p.y), 2.0) * 0.5;
	vec2 f = fract(p);
	float e = min(min(f.x, 1.0 - f.x) * 1.05, min(f.y, 1.0 - f.y) * 0.8);
	float grout = 1.0 - smoothstep(0.02, 0.06, e);
	float h = hash2(floor(p));
	vec3 tile = mix(vec3(0.60, 0.60, 0.80), vec3(0.75, 0.74, 0.90), h);
	tile *= 0.92 + 0.08 * sin(UV.x * 3.1 + UV.y * 2.3 + h * 6.0);
	float edge = smoothstep(half_w - 0.35, half_w - 0.15, abs(UV.x));
	vec3 c = mix(tile, vec3(0.30, 0.30, 0.44), grout);
	ALBEDO = mix(c, vec3(0.42, 0.42, 0.60), edge);
	ROUGHNESS = 0.75;
}
""")

static func serpent_spike() -> StandardMaterial3D:
	_clock.lock()
	var hit: Variant = _cache.get("spike")
	_clock.unlock()
	if hit != null:
		return hit
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#4b4a6e")
	m.roughness = 0.4
	m.metallic = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_clock.lock()
	_cache["spike"] = m
	_clock.unlock()
	return m

## Zig-zag triangle bands for the Tournament of Might cone (object space: works after MeshMerge, needs no UVs).
static func top_cone_mat(top_y: float, bot_y: float) -> ShaderMaterial:
	var m := _shader_mat("topcone|%.1f|%.1f" % [top_y, bot_y], """shader_type spatial;
uniform float top_y = 0.0;
uniform float bot_y = -100.0;
varying vec3 opos;
void vertex() { opos = VERTEX; }
void fragment() {
	float k = clamp((top_y - opos.y) / (top_y - bot_y), 0.0, 1.0);
	float a = atan(opos.x, opos.z) / 6.2831853 + 0.5;
	float nb = 9.0;
	float band = floor(k * nb);
	float t = fract(k * nb);
	vec3 gold = vec3(0.80, 0.68, 0.38);
	vec3 teal = vec3(0.20, 0.42, 0.37);
	vec3 cream = vec3(0.88, 0.86, 0.68);
	vec3 dark = vec3(0.10, 0.17, 0.15);
	float m = mod(band, 3.0);
	vec3 c;
	float metal = 0.0;
	if (m < 0.5) {
		float z = abs(fract(a * 40.0) - 0.5) * 2.0;
		c = t < z ? gold : dark;
		metal = t < z ? 0.4 : 0.0;
	} else if (m < 1.5) {
		c = mix(cream, teal, step(0.5, fract(a * 120.0)));
		c = mix(c, dark, step(0.86, t) + step(t, 0.08));
	} else {
		c = (t < 0.18 || t > 0.82) ? cream : teal;
	}
	ALBEDO = c;
	ROUGHNESS = 0.55;
	METALLIC = metal;
}
""")
	m.set_shader_parameter("top_y", top_y)
	m.set_shader_parameter("bot_y", bot_y)
	return m


class D extends LandmarksOrigins.B:
	var rng := RandomNumberGenerator.new()

	func _init(group: Node3D, z: RefCounted, landmark: Dictionary) -> void:
		super(group, z, landmark)
		rng.seed = int(floor(float(landmark.get("x", 0)) * 13 + float(landmark.get("z", 0)) * 7)) + 991

	func num(key: String, def: float) -> float:
		return float(l.get(key, def))

	## Off-road on a path world the ground is the void (-400): float at "alt" (default 0) instead.
	func unvoid() -> void:
		if g.position.y <= -399.0:
			g.position.y = num("alt", 0.0)

	# --- extra shapes ----------------------------------------------------------------------------------------------
	static func basis_y(dir: Vector3) -> Basis:
		var axis := Vector3.UP.cross(dir)
		if axis.length() < 1e-5:
			return Basis() if dir.y > 0 else Basis(Vector3.RIGHT, PI)
		return Basis(axis.normalized(), Vector3.UP.angle_to(dir))

	## A (tapered) cylinder from a to b.
	func limb(a: Vector3, b: Vector3, r0: float, r1: float, m: Material, seg := 8, p: Node3D = null) -> MeshInstance3D:
		var d := b - a
		var ln := d.length()
		if ln < 0.001:
			return null
		var mi := cyl(r1, r0, ln, m, (a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5, seg, p)
		mi.basis = basis_y(d / ln)
		return mi

	## Square frustum with flat facets: top half-width wt at y0, bottom half-width wb at y1 (y1 < y0 or > y0).
	func frustum(wt: float, wb: float, y0: float, y1: float, m: Material, x := 0.0, z := 0.0, cap := true) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var c := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
		for i in 4:
			var a: Vector2 = c[i]; var b: Vector2 = c[(i + 1) % 4]
			var ta := Vector3(a.x * wt, y0, a.y * wt); var tb := Vector3(b.x * wt, y0, b.y * wt)
			var ba := Vector3(a.x * wb, y1, a.y * wb); var bb := Vector3(b.x * wb, y1, b.y * wb)
			var mid := Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
			var n := (tb - ta).cross(ba - ta).normalized()
			if n.dot(mid) < 0:
				n = -n
			_quad(st, ta, tb, bb, ba, n)
		if cap:
			var up := Vector3.UP if y0 > y1 else Vector3.DOWN
			_quad(st, Vector3(-wt, y0, -wt), Vector3(wt, y0, -wt), Vector3(wt, y0, wt), Vector3(-wt, y0, wt), up)
		st.index()   # MeshMerge needs indexed surfaces
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.position = Vector3(x, 0, z)
		g.add_child(mi)
		return mi

	## Two triangles facing n (winding fixed up so the face points along n).
	static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
		var tris := [[a, b, c], [a, c, d]]
		for t: Array in tris:
			var p0: Vector3 = t[0]; var p1: Vector3 = t[1]; var p2: Vector3 = t[2]
			if (p1 - p0).cross(p2 - p0).dot(n) > 0:   # Godot front faces are clockwise
				var tmp := p1; p1 = p2; p2 = tmp
			for v: Vector3 in [p0, p1, p2]:
				st.set_normal(n); st.add_vertex(v)

	## A snake-body tube along pts (UV in metres for the scale shader), kept out of MeshMerge. Returns ring frames
	## [centre, up-ish normal, radius] so callers can add dorsal spikes.
	func tube(pts: PackedVector3Array, radius: float, end_taper := 1.0, sides := 14) -> Array:
		var holder := Node3D.new()
		holder.set_meta("spin", true)   # MeshMerge leaves it alone (keeps its UVs)
		g.add_child(holder)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := pts.size()
		var frames: Array = []
		var nrm := Vector3.UP
		var along := 0.0
		for i in n:
			var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
			nrm = (nrm - t * nrm.dot(t))
			if nrm.length() < 1e-3:
				nrm = t.cross(Vector3.RIGHT)
			nrm = nrm.normalized()
			var bn := t.cross(nrm)
			if i > 0:
				along += pts[i].distance_to(pts[i - 1])
			var r := radius * lerpf(1.0, end_taper, float(i) / maxf(n - 1, 1))
			var upish := (Vector3.UP - t * Vector3.UP.dot(t))
			upish = upish.normalized() if upish.length() > 1e-3 else nrm
			frames.append([pts[i], upish, r, t])
			for s in sides + 1:
				var a := float(s) / sides * TAU
				var dir := nrm * cos(a) + bn * sin(a)
				st.set_normal(dir)
				st.set_uv(Vector2(along, float(s) / sides * TAU * radius))
				st.add_vertex(pts[i] + dir * r)
		for i in n - 1:
			for s in sides:
				var a := i * (sides + 1) + s
				var b := a + sides + 1
				st.add_index(a); st.add_index(a + 1); st.add_index(b)
				st.add_index(a + 1); st.add_index(b + 1); st.add_index(b)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = LandmarksDivine.serpent_scales()
		holder.add_child(mi)
		return frames

	## Saw-tooth dorsal fins along tube frames (every `every` rings).
	func dorsal(frames: Array, every: int, size: float) -> void:
		var sp := LandmarksDivine.serpent_spike()
		for i in range(1, frames.size() - 1, every):
			var f: Array = frames[i]
			var c: Vector3 = f[0]; var up: Vector3 = f[1]; var r: float = f[2]; var t: Vector3 = f[3]
			var base := c + up * r * 0.92
			var fin := limb(base, base + up * size * 1.1 - t * size * 0.5, size * 0.38, 0.0, sp, 3)
			if fin != null:
				fin.scale = Vector3(1.0, 1.0, 0.35)

	func ring_tree(pos: Vector3, out: Vector3, r: float) -> void:
		var n := pivot(pos.x, pos.y, pos.z)
		n.basis = basis_y(out.normalized())
		cyl(r * 0.12, r * 0.18, r * 1.4, mat(0x6a4a2a), 0, r * 0.7, 0, 8, n)
		sphere(r, mat(0x2f7a34, {"rough": 0.9}), 0, r * 1.9, 0, 12, n)
		sphere(r * 0.7, mat(0x3e9040, {"rough": 0.9}), r * 0.5, r * 2.3, r * 0.3, 10, n)
		sphere(r * 0.6, mat(0x2a6a2e, {"rough": 0.9}), -r * 0.5, r * 2.1, -r * 0.3, 10, n)

	# ======================================================================================================
	## King Yemmo's Check-In Station, reference palette (audit 105): yellow tiled floor, green pillars, white panelled
	## walls with red round windows on the rear half, red tile roof over a yellow plank ceiling, a red balustrade.
	## Same footprint, desk/dais heights and soul queue as the old `checkin` (NPC positions unchanged).
	## Params: "door" (radians from +z: gap in the rear wall towards Serpent Road, default -0.45), "queue" (bool).
	func checkinhall() -> void:
		var yellow := mat(0xf8dc58, {"rough": 0.55}); var grout := mat(0xc89a2a, {"rough": 0.7})
		var green := mat(0x3f8a4e, {"rough": 0.45}); var green_dk := mat(0x2e6a3a, {"rough": 0.5})
		var wall_m := mat(0xe6eaf6, {"rough": 0.8}); var red := mat(0xd8442c, {"rough": 0.45})
		var pane := mat(0xf3c8d8, {"rough": 0.2, "emissive": 0x5a3040, "glow": 0.3})
		var roof_m := mat(0xb83a26, {"rough": 0.5}); var gold := mat(0xd8a733, {"metal": 0.8, "rough": 0.3})
		var plank := mat(0xf0c860, {"rough": 0.7})
		var wood := mat(0xc89a64, {"rough": 0.55}); var wood_dk := mat(0x8a6038, {"rough": 0.55})
		var door := num("door", -0.45)
		# floor, tiled, with steps round the rim
		cyl(53.5, 53.5, 0.3, yellow, 0, -0.13, 0, 64)
		cyl(54.5, 55.0, 0.5, mat(0xb9ad98, {"stone": true}), 0, -0.45, 0, 64)
		for i in range(-52, 53, 4):
			var half := sqrt(53.0 * 53.0 - float(i * i))
			box(half * 2.0, 0.03, 0.18, grout, 0, 0.03, i)
			box(0.18, 0.03, half * 2.0, grout, i, 0.03, 0)
		box(5, 0.04, 44, mat(0xd8322a, {"rough": 0.95}), 0, 0.05, -27)
		# twelve green pillars, a beam ring
		for i in 12:
			var a := (float(i) + 0.5) / 12.0 * TAU
			var cx := sin(a) * 33.0; var cz := cos(a) * 33.0
			cyl(1.2, 1.3, 22, green, cx, 11, cz, 16)
			cyl(1.7, 1.7, 0.8, green_dk, cx, 22.0, cz, 16)
			cyl(1.8, 2.0, 0.8, green_dk, cx, 0.4, cz, 16)
		torus(33.0, 0.7, green, 0, 22.6, 0)
		# rear wall panels between the pillars, with a doorway towards the road
		for i in 12:
			var a0 := (float(i) + 0.5) / 12.0 * TAU
			var a1 := (float(i) + 1.5) / 12.0 * TAU
			var mid := wrapf((a0 + a1) * 0.5, -PI, PI)
			if absf(mid) > 1.7 or absf(angle_difference(mid, door)) < 0.5:
				continue
			var chord := 2.0 * 33.0 * sin(PI / 12.0) - 2.2
			var pv := pivot(sin(mid) * 33.0 * cos(PI / 12.0), 0, cos(mid) * 33.0 * cos(PI / 12.0), mid)
			box(chord, 21.0, 0.6, wall_m, 0, 11.0, 0, 0.0, pv)
			box(chord, 4.5, 0.75, green, 0, 2.25, 0, 0.0, pv)
			box(chord, 0.5, 0.8, green, 0, 14.5, 0, 0.0, pv)
			for k in 3:   # panel seams
				box(0.25, 10.0, 0.7, green_dk, -chord * 0.5 + chord * (k + 1) / 4.0, 9.5, 0, 0.0, pv)
			# round red window, facing in and out
			var w := torus(2.6, 0.32, red, 0, 9.3, 0, pv); w.rotation.x = PI / 2
			var gl := cyl(2.4, 2.4, 0.5, pane, 0, 9.3, 0, 20, pv); gl.rotation.x = PI / 2
			box(0.3, 5.0, 0.8, red, 0, 9.3, 0, 0.0, pv)
			box(5.0, 0.3, 0.8, red, 0, 9.3, 0, 0.0, pv)
		# yellow plank ceiling under a red two-tier tile roof
		cyl(46, 46, 0.4, plank, 0, 23.0, 0, 8).rotation.y = PI / 8
		var roof := cone(47, 9, roof_m, 0, 27.6, 0, 8); roof.rotation.y = PI / 8
		cyl(47.5, 47.5, 0.6, green, 0, 23.2, 0, 8).rotation.y = PI / 8
		var upper := cone(25, 8, roof_m, 0, 36, 0, 8); upper.rotation.y = PI / 8
		cyl(17, 17, 4, wall_m, 0, 31, 0, 8).rotation.y = PI / 8
		for k in 8:
			var a := (float(k) + 0.5) / 8.0 * TAU
			var ww := torus(1.2, 0.18, red, sin(a) * 15.9, 31, cos(a) * 15.9); ww.basis = Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI / 2)
		cyl(25.5, 25.5, 0.5, green, 0, 32.1, 0, 8).rotation.y = PI / 8
		sphere(1.6, gold, 0, 40.6, 0)
		cone(0.5, 3, gold, 0, 42.6, 0, 12)
		# red balustrade round the rim (gaps: arrivals from the south-east, the carpet, the road door)
		for i in 96:
			var a := (float(i) + 0.5) / 96.0 * TAU
			var aw := wrapf(a, -PI, PI)
			if absf(angle_difference(aw, 2.09)) < 0.35 or absf(angle_difference(aw, PI)) < 0.12 or absf(angle_difference(aw, door)) < 0.2:
				continue
			on_ring(0, 0, 52.6, a, 1.15, 3.3, 0.16, 0.3, red)
			on_ring(0, 0, 52.6, a, 0.55, 0.18, 1.1, 0.18, red)
		# sign over the south entrance
		box(26, 4, 0.6, green, 0, 18.5, -33.6)
		box(27, 4.6, 0.3, gold, 0, 18.5, -33.3)
		label("CHECK-IN STATION", Vector3(0, 18.5, -34.0), 0.012, Color("#ffe3a0"), Color("#1e3a1a"), PI)
		# the desk (plain light wood, green blotter), as in the reference
		const TOP := 3.6
		box(17, 0.5, 6.4, wood, 0, TOP - 0.25, 2.4)
		box(16.4, TOP - 0.5, 0.4, wood_dk, 0, (TOP - 0.5) / 2.0, -0.4)
		for x in [-7.9, 7.9]:
			for zz in [-0.4, 5.2]:
				box(0.7, TOP - 0.5, 0.7, wood_dk, x, (TOP - 0.5) / 2.0, zz)
		box(16.8, 0.6, 0.3, wood_dk, 0, TOP - 0.8, 5.4)
		box(7.0, 0.04, 3.4, mat(0x2a6a3a, {"rough": 0.8}), 0.5, TOP + 0.02, 2.8)
		label("King Yemmo", Vector3(0, 2.3, -0.75), 0.01, Color("#3a2410"), Color("#f6efe0"), PI)
		box(4.0, 1.0, 0.1, mat(0xf6efe0), 0, 2.3, -0.62)
		# the book of souls, a light-blue telephone, a pen cup, a flower pot
		var book := box(3.2, 0.25, 2.2, mat(0xf3eedf, {"rough": 0.8}), -3.8, TOP + 0.15, 3.0); book.rotation.y = 0.15
		box(3.4, 0.2, 2.4, mat(0x5a5a68), -3.8, TOP + 0.02, 3.0).rotation.y = 0.15
		var phone := mat(0x8ad0e8, {"rough": 0.35})
		box(1.6, 0.5, 1.3, phone, -6.6, TOP + 0.25, 1.8)
		var hand := box(1.9, 0.35, 0.5, phone, -6.6, TOP + 0.65, 1.8); hand.rotation.z = 0.05
		cyl(0.4, 0.4, 0.8, mat(0xf6f6f2), 3.0, TOP + 0.4, 2.4, 14)
		for k in 3:
			limb(Vector3(3.0, TOP + 0.5, 2.4), Vector3(3.0 + (k - 1) * 0.25, TOP + 1.5, 2.4), 0.06, 0.06, mat(0x2a4ac8 if k == 1 else 0x222222), 6)
		cyl(0.7, 0.5, 0.9, mat(0xb0a898, {"rough": 0.9}), 6.0, TOP + 0.45, 3.4, 14)
		for k in 6:
			var a := float(k) / 6.0 * TAU
			sphere(0.32, mat(0xffd23a, {"emissive": 0x664400, "glow": 0.2}), 6.0 + sin(a) * 0.45, TOP + 1.3, 3.4 + cos(a) * 0.45, 8)
		sphere(0.55, mat(0x3a8a3a), 6.0, TOP + 1.1, 3.4, 10)
		# dais and chair (dais top 1.4 = the NPC's authored y; seat as the old station)
		box(15, 1.4, 10, mat(0x8a7d68, {"stone": true}), 0, 0.7, 10.5)
		box(15.4, 0.2, 10.4, green, 0, 1.45, 10.5)
		var seat := mat(0x6a4aa0, {"rough": 0.6})
		box(9, 1.8, 5.5, seat, 0, 1.4 + 0.9, 10.2)
		box(9.4, 0.3, 5.9, gold, 0, 1.4 + 1.85, 10.2)
		box(9, 10, 1.2, seat, 0, 1.4 + 5.0, 13.2)
		box(9.6, 0.5, 1.6, gold, 0, 1.4 + 10.2, 13.2)
		for x in [-4.7, 4.7]:
			box(0.8, 1.6, 5.0, seat, x, 1.4 + 2.9, 10.4)
		if flag("queue"):
			var q := SoulQueue.create(PackedVector3Array([Vector3(44, 0, -24), Vector3(34, 0, -30), Vector3(20, 0, -26),
				Vector3(12, 0, -16), Vector3(6, 0, -8), Vector3(1.5, 0, -3.2)]))
			q.set_meta("spin", true)   # animated: MeshMerge must leave its souls alone
			g.add_child(q)
		light(Color("#fffaf0"), 1.8, 60, Vector3(0, 16, -4))
		light(Color("#fffaf0"), 1.0, 40, Vector3(0, 12, 18))

	## The serpent's head at the start of Serpent Road (replaces `snakehead`): a lilac-scaled head with an open
	## jaw, fangs, glowing yellow eyes, swept horns and a spiked crest, sitting beside the road (local +x) and
	## looking down the road towards the arrivals (-z); its neck drops into the cloud sea.
	## Params: "side" (offset across the road, default 7), "size" (default 1).
	func serpenthead() -> void:
		unvoid()
		var s := num("size", 1.0)
		var root := pivot(num("side", 7.0), 0, 0)
		root.scale = Vector3.ONE * s
		var skin := mat(0x8a88b8, {"rough": 0.4}); var belly := mat(0xd8d0b8, {"rough": 0.6})
		var mouth := mat(0x7a1a2a, {"rough": 0.6}); var tooth := mat(0xf6f2e6, {"rough": 0.3})
		var horn := mat(0xe6d6a0, {"rough": 0.4}); var eye := mat(0xffd23a, {"emissive": 0xc08000, "glow": 1.2})
		var sp := LandmarksDivine.serpent_spike()
		var skull := sphere(3.4, skin, 0, 4.2, 1.0, 20, root); skull.scale = Vector3(1.0, 0.75, 1.5)
		var snout := sphere(2.4, skin, 0, 3.6, -3.6, 18, root); snout.scale = Vector3(1.0, 0.6, 1.4)
		var jaw := sphere(2.6, belly, 0, 1.4, -2.0, 18, root); jaw.scale = Vector3(0.95, 0.4, 1.6); jaw.rotation.x = 0.25
		var inner := sphere(2.3, mouth, 0, 2.4, -2.4, 16, root); inner.scale = Vector3(0.85, 0.35, 1.45)
		for side in [-1.0, 1.0]:
			for k in 3:
				cone(0.22, 0.9, tooth, side * (1.3 - k * 0.15), 2.55, -4.8 + k * 1.0, 6, root).rotation.x = PI
				cone(0.18, 0.7, tooth, side * (1.2 - k * 0.15), 1.95, -4.2 + k * 1.0, 6, root)
			var e := sphere(0.55, eye, side * 2.3, 5.0, -0.6, 12, root); e.scale = Vector3(0.6, 1.0, 1.2)
			box(0.12, 0.7, 0.3, mat(0x1a1a1a), side * 2.62, 5.0, -0.6, 0.0, root)
			var brow := box(1.6, 0.5, 2.4, skin, side * 2.0, 5.65, -0.4, side * 0.25, root); brow.rotation.z = side * 0.35
			sphere(0.22, mat(0x1a1a2a), side * 0.7, 4.2, -6.9, 8, root)
			# horns sweep back
			var h0 := Vector3(side * 1.6, 6.2, 1.6)
			var h1 := h0 + Vector3(side * 1.4, 2.2, 2.6)
			limb(h0, h1, 0.55, 0.32, horn, 8, root)
			limb(h1, h1 + Vector3(side * 0.3, 0.6, 3.0), 0.32, 0.0, horn, 8, root)
		for k in 6:   # crest
			cone(0.45, 1.8 - k * 0.15, sp, 0, 6.6 - k * 0.15, -1.0 + k * 1.3, 4, root).rotation.x = 0.5
		# neck: scaled tube from the back of the head down into the clouds
		var pts := PackedVector3Array()
		for i in 26:
			var t := float(i) / 25.0
			pts.append(Vector3(num("side", 7.0) + sin(t * 3.0) * 7.0 * s, (3.2 + sin(t * 2.4) * 3.0 - t * t * 24.0) * s, (3.5 + t * 26.0) * s))
		var fr := tube(pts, 2.6 * s, 0.85)
		dorsal(fr, 2, 1.1 * s)

	## Snake Way coils: loops of the serpent's body hanging in the clouds beside the road (decoration, no collision).
	## Params: "span" (m, default 150), "loops" (default 3), "radius" (body radius, default 2.2), "drop" (default 30).
	func serpentcoils() -> void:
		unvoid()
		var span := num("span", 150.0); var loops := int(num("loops", 3)); var r := num("radius", 2.2)
		var drop := num("drop", 30.0)
		var pts := PackedVector3Array()
		var n := 60 * loops
		var ph := rng.randf() * TAU
		for i in n + 1:
			var t := float(i) / n
			var a := t * TAU * loops + ph
			var x := (t - 0.5) * span + sin(a) * span * 0.12
			var y := -drop + sin(a * 0.5 + 1.0) * drop * 0.5 + cos(a) * drop * 0.35 - pow(absf(t - 0.5) * 2.0, 3.0) * drop
			var z := cos(a) * span * 0.16 + sin(t * PI * 2.0) * span * 0.1
			pts.append(Vector3(x, y, z))
		var fr := tube(pts, r, 0.8)
		dorsal(fr, 3, r * 0.5)

	## King Kae's planet seen from Serpent Road's end (replaces `kaiplanet`; same params "alt", "radius"): lime
	## sphere with the white band road round it, round trees sticking out of its sides, house + car + tree on top.
	## Param "clouds" (default false): the old golden puff ring.
	func kaiorb() -> void:
		g.position.y = num("alt", 110.0)
		var r := num("radius", 34.0)
		var lime := mat(0x9cc23a, {"rough": 0.8})
		var planet := sphere(r, lime, 0, 0, 0, 48)
		planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_band(Vector3.ZERO, r, 0.06, false)   # all round the sphere (there is no planetoid terrain under a floating orb)
		for i in 7:
			var a := float(i) / 7.0 * TAU + 0.4
			var el := -0.35 + (i % 3) * 0.3
			var out := Vector3(sin(a) * cos(el), sin(el), cos(a) * cos(el))
			if absf(out.x) < 0.2:
				continue   # keep the band clear
			ring_tree(out * (r - 0.3), out, r * 0.09)
		# house, car and tree each stand on the curved top, upright along the sphere's normal (a flat 1.6x pivot at the
		# pole left the house, car and tree floating up to 3.6 m over the curve; audit 2026-11-12)
		var on_top := func(px: float, pz: float, ry := 0.0) -> Node3D:
			var up := Vector3(px * 1.6, sqrt(maxf(r * r - (px * px + pz * pz) * 2.56, 0.0)), pz * 1.6).normalized()
			var n := pivot(0, 0, 0)
			n.transform = Transform3D(basis_y(up) * Basis(Vector3.UP, ry) * Basis.from_scale(Vector3.ONE * 1.6), up * (r - 0.25))
			return n
		var house: Node3D = on_top.call(6.0, 2.0)
		dome(4, mat(0xf3eadb), 0, 0, 0, 24, house)
		torus(4, 0.3, mat(0xc83228), 0, 0.1, 0, house)
		sphere(0.8, mat(0xc83228), 0, 4, 0, 12, house)
		box(1.4, 2.2, 0.2, mat(0x6a4a2a), 0, 1.1, 3.9, 0.0, house)
		var car: Node3D = on_top.call(-6.0, 5.0, 1.2)
		box(3, 0.7, 1.6, mat(0xc8322a, {"metal": 0.5, "rough": 0.3}), 0, 0.4, 0, 0.0, car)   # on the ground (was 0.35 m up)
		box(1.6, 0.6, 1.4, mat(0xddeeff, {"opacity": 0.5, "rough": 0.1}), -0.2, 1.0, 0, 0.0, car)
		var tree: Node3D = on_top.call(-6.0, -5.0)
		cyl(0.35, 0.5, 6, mat(0x6a4a2a), 0, 2.8, 0, 10, tree)
		sphere(3.2, mat(0x2f8a3a, {"rough": 0.8}), 0, 7.3, 0, 20, tree)
		if flag("clouds", false):
			var cloud := mat(0xfff0c0, {"rough": 1.0, "emissive": 0x806030, "glow": 0.4})
			no_shadow.append(cloud)
			for i in 18:
				var a := float(i) / 18.0 * TAU + 0.2
				var puff := sphere(r * 0.2, cloud, sin(a) * r * 1.12, -r * 0.15 + sin(a * 3.0) * 1.5, cos(a) * r * 1.12, 14)
				puff.scale = Vector3(1.6, 0.6, 1.0)

	## The white band road: an open ring round a sphere (centre c, radius r), in the local y-z plane (over the top).
	## The white road round King Kae's planetoid: a strip mesh (not a cylinder, whose flat facets and seams stood
	## proud of the terrain and let the grass through). The top half follows the terrain's own height (zone.height_at,
	## so it lies on the ground even with the noise); the underside and the horizon follow the sphere.
	## on_terrain false (kaiorb, a floating orb): the whole ring follows the sphere. True (kaiband) leaves the top half to
	## the planetoid terrain; on the orb that bent the ring's top ends down onto the zone's ground (a white pillar from
	## Serpent Road's end up to the orb, audit 2026-11-12).
	func _band(c: Vector3, r: float, lift: float, on_terrain := true) -> void:
		var w := clampf(r * 0.11, 2.0, 7.0)
		var off := g.position.y / maxf(g.scale.y, 0.01)
		var R := r + lift
		var steps := int(ceil(TAU * R / 0.9))
		var white := mat(0xe8ecf2, {"rough": 0.6}); var rim := mat(0xb8bcc8, {"rough": 0.5})
		for part: Array in [[-w * 0.5, w * 0.5, 0.0, white], [-w * 0.5 - 0.18, -w * 0.5, 0.01, rim], [w * 0.5, w * 0.5 + 0.18, 0.01, rim]]:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in steps:
				var a0 := float(i) / steps * TAU; var a1 := float(i + 1) / steps * TAU
				if on_terrain and cos(a0) > 0.1 and cos(a1) > 0.1 and absf(sin(a0) * R) < R - 2.0 and absf(sin(a1) * R) < R - 2.0:
					continue   # the top half is painted on the terrain itself (zone.surface_at, terrain.planetoid.road)
				var q := [_band_pt(c, R, off, float(part[0]), a0, float(part[2]), on_terrain), _band_pt(c, R, off, float(part[1]), a0, float(part[2]), on_terrain),
					_band_pt(c, R, off, float(part[1]), a1, float(part[2]), on_terrain), _band_pt(c, R, off, float(part[0]), a1, float(part[2]), on_terrain)]
				for k in [0, 2, 1, 0, 3, 2]:
					st.set_normal(Vector3.UP if on_terrain and cos(a0) > 0.0 else (q[k] - c).normalized())
					st.add_vertex(q[k])
			var mi := MeshInstance3D.new()
			st.index()
			mi.mesh = st.commit()
			var bm: BaseMaterial3D = (part[3] as BaseMaterial3D).duplicate()
			bm.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = bm
			mi.set_meta("no_collision", true)   # walked on at ground level, never a wall
			g.add_child(mi)

	## One band vertex at lateral offset x and angle a (0 = the top): on the terrain over the top, else on the sphere.
	func _band_pt(c: Vector3, R: float, off: float, x: float, a: float, up: float, on_terrain := true) -> Vector3:
		var z := sin(a) * R
		var y := c.y + cos(a) * R
		if on_terrain and zone != null and cos(a) > 0.1 and absf(z) < R - 2.0 and zone.has_method("height_at"):
			y = zone.height_at(x, z) + 0.05 - off
		return Vector3(x, y + up, z)

	## King Kae's planetoid (zone king_kai, terrain.planetoid): the white band road over the terrain dome, the lower
	## hemisphere under it (the terrain only draws the top) and trees sticking out of its sides.
	## Place at x 0, z 0. Params: "radius" (default zone planetoid radius / 58), "underside" (default true), "trees".
	func kaiband() -> void:
		var r := num("radius", 58.0)
		if zone != null and not l.has("radius"):
			var t: Dictionary = zone.get("def").terrain if zone.get("def") != null else {}
			if t.has("planetoid"):
				r = float(t.planetoid.radius)
		var cy := -r - g.position.y / maxf(g.scale.y, 0.01)
		var c := Vector3(0, cy, 0)
		_band(c, r, 0.12)
		if flag("underside"):
			# only below 50° from the top: a full sphere 0.35 m under the dome came up through every flattened site
			# (King Kae's house pad cuts the dome ~1 m down on its uphill side: a lime disc showed beside the house)
			var lime := mat(0x8fb83a, {"rough": 0.85})
			var s := _sphere_below(c, r - 0.35, deg_to_rad(50.0), lime)
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if flag("trees"):
			for i in 6:
				var a := float(i) / 6.0 * TAU + 0.5
				var el := -0.45 + (i % 2) * 0.2
				var out := Vector3(sin(a) * cos(el), sin(el), cos(a) * cos(el))
				ring_tree(c + out * (r - 0.6), out, 3.2)

	## The part of a sphere (centre c, radius rad) more than theta0 from its top: smooth normals, open at the top.
	func _sphere_below(c: Vector3, rad: float, theta0: float, m: Material, seg := 64, rings := 40) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pt := func(i: int, j: int) -> Vector3:
			var th := lerpf(theta0, PI, float(j) / rings)
			var ph := float(i) / seg * TAU
			return Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
		for j in rings:
			for i in seg:
				var q: Array = [pt.call(i, j), pt.call(i + 1, j), pt.call(i + 1, j + 1), pt.call(i, j + 1)]
				for t: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
					var a: Vector3 = t[0]; var b: Vector3 = t[1]; var d: Vector3 = t[2]
					if (b - a).cross(d - a).dot(a + b + d) > 0:   # Godot front faces are clockwise: face outward
						var tmp := b; b = d; d = tmp
					for v: Vector3 in [a, b, d]:
						st.set_normal(v); st.add_vertex(c + v * rad)
		st.index()   # MeshMerge needs indexed surfaces
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.set_meta("no_collision", true)   # under the terrain dome: never a wall
		g.add_child(mi)
		return mi

	## Beeros's planet (audit 118): a floating INVERTED stepped pyramid of purple metal, teal foliage hanging over
	## each tier, a stepped spike underneath. Top face is at local y 0 (sits under a `platform` terrain disc; the
	## square's corners get their own collision). Params: "half" (top half-width, default 110), "collide" handled by
	## WorldLandmarks is not needed; "corners" (bool, default true: collision box over the whole top).
	func beerusisle() -> void:
		var h := num("half", 110.0)
		var purple := mat(0x6a42b0, {"metal": 0.55, "rough": 0.32}); var lilac := mat(0x9a6ad8, {"metal": 0.5, "rough": 0.3})
		var stripe := mat(0xc890ff, {"emissive": 0x7a3ad0, "glow": 0.6, "rough": 0.3})
		var dark := mat(0x3a2468, {"metal": 0.6, "rough": 0.35})
		var lawn := mat(0x4f9a52, {"rough": 0.9})
		var leaf := mat(0x2aa8a0, {"rough": 0.85}); var leaf2 := mat(0x1f8a86, {"rough": 0.85})
		box(h * 2.0, 0.3, h * 2.0, lawn, 0, -0.2, 0)
		# tier 1: thick slab with a bright stripe
		frustum(h, h * 0.98, -0.35, -7.0, lilac)
		box(h * 1.97, 0.8, h * 1.97, stripe, 0, -4.2, 0)
		frustum(h * 0.98, h * 0.78, -7.0, -20.0, purple, 0, 0, false)
		# tier 2: overhanging lip, then the long taper
		frustum(h * 0.86, h * 0.84, -20.0, -26.0, lilac)
		box(h * 1.69, 0.7, h * 1.69, stripe, 0, -23.0, 0)
		frustum(h * 0.84, h * 0.5, -26.0, -26.0 - h * 0.45, purple, 0, 0, false)
		var y := -26.0 - h * 0.45
		frustum(h * 0.5, h * 0.12, y, y - h * 0.38, dark, 0, 0, false)
		y -= h * 0.38
		# stepped spike
		for k in 5:
			var w := h * (0.13 - k * 0.022)
			frustum(w, w * 0.8, y, y - 3.5, lilac if k % 2 == 0 else dark)
			y -= 3.5
		limb(Vector3(0, y, 0), Vector3(0, y - h * 0.12, 0), h * 0.025, 0.0, lilac, 4)
		# teal foliage hanging over both tier lips
		for tier: Array in [[h, -0.6], [h * 0.86, -20.4]]:
			var w: float = tier[0]; var ty: float = tier[1]
			var count := int(w * 2.0 / 3.2)
			for side in 4:
				for i in count:
					var u := -w + (float(i) + 0.5) * (w * 2.0 / count) + rng.randf_range(-0.8, 0.8)
					var off := rng.randf_range(-0.6, 1.4)
					var p := Vector3(u, ty, w + off) if side == 0 else (Vector3(u, ty, -w - off) if side == 1 else (Vector3(w + off, ty, u) if side == 2 else Vector3(-w - off, ty, u)))
					var lump := sphere(rng.randf_range(1.6, 3.0), leaf if i % 3 else leaf2, p.x, p.y + rng.randf_range(-1.2, 0.4), p.z, 8)
					lump.scale = Vector3(1.2, rng.randf_range(0.6, 1.1), 1.2)
					if i % 5 == 0:   # drooping vines
						var d := rng.randf_range(2.5, 7.0)
						var hang := sphere(0.7, leaf2, p.x, p.y - d * 0.5, p.z, 6)
						hang.scale = Vector3(1.0, d * 0.7, 1.0)
		if flag("corners"):
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var bs := BoxShape3D.new(); bs.size = Vector3(h * 2.0, 2.0, h * 2.0)
			shape.shape = bs
			shape.position.y = -1.05
			body.add_child(shape)
			g.add_child(body)

	## A giant twisted bare tree (Beeros's planet, audit 118): three strands spiralling up a core, flaring roots
	## and forking bare branches. Params: "height" (default 46), "bark" (hex colour).
	func godtree() -> void:
		var H := num("height", 46.0)
		var bark := mat(int(l.get("bark", 0x6a4a52)), {"rough": 0.95}); var bark2 := mat(0x543842, {"rough": 0.95})
		var trunk_h := H * 0.55
		var r0 := H * 0.075
		limb(Vector3(0, -1, 0), Vector3(0, trunk_h, 0), r0 * 1.1, r0 * 0.55, bark2, 12)
		for sidx in 3:
			var prev := Vector3.ZERO
			for k in 13:
				var t := float(k) / 12.0
				var a := float(sidx) / 3.0 * TAU + t * 2.6
				var rr := r0 * lerpf(1.25, 0.55, t)
				var p := Vector3(cos(a) * rr, t * trunk_h - 0.5, sin(a) * rr)
				if k > 0:
					limb(prev, p, r0 * lerpf(0.75, 0.35, t), r0 * lerpf(0.7, 0.32, t + 0.08), bark, 8)
				prev = p
		for i in 7:   # roots
			var a := float(i) / 7.0 * TAU + rng.randf() * 0.4
			var a0 := Vector3(cos(a) * r0 * 0.9, r0 * 0.9, sin(a) * r0 * 0.9)
			var a1 := Vector3(cos(a) * r0 * 2.6, r0 * 0.15, sin(a) * r0 * 2.6)
			limb(a0, a1, r0 * 0.5, r0 * 0.28, bark, 7)
			limb(a1, a1 + Vector3(cos(a) * r0 * 1.6, -r0 * 0.4, sin(a) * r0 * 1.6), r0 * 0.28, 0.05, bark, 6)
		for i in 6:
			var a := float(i) / 6.0 * TAU + rng.randf() * 0.5
			var base := Vector3(cos(a) * r0 * 0.4, trunk_h * rng.randf_range(0.82, 1.0), sin(a) * r0 * 0.4)
			var dir := Vector3(cos(a), rng.randf_range(0.6, 1.3), sin(a)).normalized()
			_branch(base, dir, H * 0.26, r0 * 0.55, 4, bark)

	func _branch(p: Vector3, dir: Vector3, ln: float, r: float, depth: int, m: Material) -> void:
		var bend := (dir + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.05, 0.25), rng.randf_range(-0.3, 0.3))).normalized()
		var mid := p + dir * ln * 0.5
		var end := mid + bend * ln * 0.5
		limb(p, mid, r, r * 0.8, m, 6)
		limb(mid, end, r * 0.8, r * 0.62 if depth > 0 else 0.02, m, 6)
		if depth <= 0:
			return
		var kids := 2 + (1 if rng.randf() < 0.45 else 0)
		for k in kids:
			var a := rng.randf() * TAU
			var side := Vector3(cos(a), 0, sin(a))
			var nd := (bend + side * rng.randf_range(0.5, 0.9) + Vector3(0, rng.randf_range(0.0, 0.4), 0)).normalized()
			_branch(end, nd, ln * rng.randf_range(0.58, 0.72), r * 0.62, depth - 1, m)

	## Beeros's castle (audit 119): a tall purple tower-palace with gold trims and swept teal roofs on every tier, a
	## stepped plinth and a gold-orb spire (~48 m). Door faces +z.
	func beeruscastle() -> void:
		var stone := mat(0xb8a8d0, {"rough": 0.6, "stone": true}); var wall := mat(0x5a3a8a, {"rough": 0.45})
		var gold := mat(0xd8b048, {"metal": 0.75, "rough": 0.3}); var roof := mat(0x2a9a8a, {"rough": 0.4})
		var win := mat(0x1e1430, {"rough": 0.3}); var glow := mat(0xffe6a0, {"emissive": 0xc08a20, "glow": 1.0})
		box(30, 2, 30, stone, 0, 1, 0)
		box(24, 2, 24, stone, 0, 3, 0)
		for k in range(1, 5):   # front stairs up to the 2 m terrace: 0.5 m risers (were two 1 m blocks, the upper one
			var top := 0.5 * k  # sunk into the terrace with its top flush on it: z-fighting)
			box(8, top, 0.9, stone, 0, top * 0.5, 15.0 + (4 - k) * 0.9 + 0.45)
		var y := 4.0
		var tiers := [[9.0, 9.0], [7.5, 8.0], [6.0, 7.5], [4.6, 7.0], [3.2, 6.0]]
		for i in tiers.size():
			var r: float = tiers[i][0]; var th: float = tiers[i][1]
			cyl(r * 0.92, r, th, wall, 0, y + th * 0.5, 0, 8).rotation.y = PI / 8
			cyl(r + 0.25, r + 0.25, 0.5, gold, 0, y + 0.25, 0, 8).rotation.y = PI / 8
			for k in 8:
				var a := float(k) / 8.0 * TAU
				on_ring(0, 0, r * 0.94, a, y + th * 0.55, r * 0.22, th * 0.45, 0.25, win)
				on_ring(0, 0, r * 0.95, a, y + th * 0.55 + th * 0.26, r * 0.28, 0.25, 0.3, gold)
			y += th
			var eave := cone(r * 1.55, 2.4, roof, 0, y + 0.6, 0, 8); eave.rotation.y = PI / 8
			cyl(r * 1.56, r * 1.56, 0.35, gold, 0, y - 0.55, 0, 8).rotation.y = PI / 8
			for k in 8:   # upturned eave tips
				var a := (float(k) + 0.5) / 8.0 * TAU
				var tip := cone(0.35, 1.6, gold, sin(a) * r * 1.5, y - 0.1, cos(a) * r * 1.5, 6)
				tip.rotation = Vector3(cos(a) * 0.9, 0, -sin(a) * 0.9)
			y += 0.5
		box(3.4, 5, 0.4, win, 0, 6.5, 8.6)
		box(4.2, 0.6, 0.6, gold, 0, 9.2, 8.6)
		cyl(0.35, 0.6, 7, gold, 0, y + 3.5, 0, 8)
		sphere(1.6, glow, 0, y + 7.6, 0, 16)
		no_shadow.append(glow)
		torus(2.2, 0.15, gold, 0, y + 7.6, 0)
		light(Color("#ffd27a"), 1.2, 30, Vector3(0, y + 7.6, 0))

	## Tournament of Might stage underside (audit 123/124): an inverted cone with gold/teal zig-zag bands under the
	## `platform` disc, a striped stem with a pointed tip, a tile rim and the open spiral ring above.
	## Place at the platform centre. Params: "radius" (default zone platform radius or 100), "spiral" (bool).
	func toparena() -> void:
		var R := num("radius", 100.0)
		if zone != null and not l.has("radius"):
			var t: Dictionary = zone.get("def").terrain if zone.get("def") != null else {}
			if t.has("platform"):
				R = float(t.platform.radius)
		var top := -0.6
		var bot := -R * 1.05
		var cm := LandmarksDivine.top_cone_mat(top, bot)
		cyl(R * 0.95, R * 0.07, top - bot, cm, 0, (top + bot) * 0.5, 0, 72)
		# tile rim just under the walking edge
		var cols := [0xe8e0b0, 0x8ac8b8, 0xd8b860, 0x3a6a5a]
		for i in 90:
			var a := float(i) / 90.0 * TAU
			on_ring(0, 0, R * 0.95, a, -1.2, R * 0.95 * TAU / 90.0 * 0.96, 1.6, 0.6, mat(int(cols[i % 4]), {"rough": 0.5}))
		# striped stem and tip
		var stripe_a := mat(0xe8e0b0, {"rough": 0.5}); var stripe_b := mat(0x3a6a5a, {"rough": 0.5})
		var y := bot
		for k in 8:
			cyl(R * 0.055, R * 0.06, R * 0.04, stripe_a if k % 2 == 0 else stripe_b, 0, y - R * 0.02, 0, 16)
			y -= R * 0.04
		cone(R * 0.055, R * 0.14, stripe_a, 0, y - R * 0.07, 0, 16).rotation.x = PI
		if flag("spiral"):
			_spiral(R)

	func _spiral(R: float) -> void:
		var m := mat(0x2f5a4e, {"rough": 0.5}); var edge := mat(0xd8d0a0, {"rough": 0.5})
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var w := R * 0.07; var th := R * 0.025
		var n := 120
		var prev: Array = []
		for i in n + 1:
			var t := float(i) / n
			var a := t * TAU * 0.85
			var rr := R * lerpf(1.05, 1.18, t)
			var cy := lerpf(-R * 0.12, R * 0.22, t)
			var o := Vector3(sin(a), 0, cos(a))
			var cur := [o * (rr - w) + Vector3(0, cy, 0), o * (rr + w) + Vector3(0, cy, 0),
				o * (rr + w) + Vector3(0, cy - th, 0), o * (rr - w) + Vector3(0, cy - th, 0)]
			if i > 0:
				for f in 4:
					var a0: Vector3 = prev[f]; var a1: Vector3 = prev[(f + 1) % 4]
					var b0: Vector3 = cur[f]; var b1: Vector3 = cur[(f + 1) % 4]
					var mid := (a0 + a1 + b0 + b1) * 0.25
					var centre := o * rr + Vector3(0, cy - th * 0.5, 0)
					var nn := (a1 - a0).cross(b0 - a0).normalized()
					if nn.dot(mid - centre) < 0:
						nn = -nn
					_quad(st, a0, a1, b1, b0, nn)
			prev = cur
			if i % 6 == 0:
				box(w * 2.1, th * 1.1, R * 0.006, edge, o.x * rr, cy - th * 0.5, o.z * rr, a + PI / 2).set_meta("no_collision", true)
		st.index()   # MeshMerge needs indexed surfaces
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.set_meta("no_collision", true)   # a hollow ribbon round the arena: its box would cover the whole floor
		g.add_child(mi)

	## Grand Zenno's palace / the Grand Minister's realm (audit 122): white palace with gold trims, three stepped
	## storeys of windows, a wide swept roof with a dark edge and gold horn ornaments, floating standing stones and
	## dark marble orbs. ~32 m tall. Params: "stones" (bool), "floor" (bool: pale sand disc, default false).
	func zenopalace() -> void:
		var white := mat(0xf6f4ee, {"rough": 0.5}); var gold := mat(0xe0b838, {"metal": 0.7, "rough": 0.3})
		var winm := mat(0x8a5a2a, {"rough": 0.6}); var roofd := mat(0x2a2a48, {"rough": 0.5})
		var roofw := mat(0xfbfaf6, {"rough": 0.4}); var wood := mat(0xc89a5a, {"rough": 0.6})
		if flag("floor", false):
			cyl(60, 60, 0.3, mat(0xf2e8c8, {"rough": 0.9}), 0, -0.1, 0, 48)
		var storeys := [[40.0, 7.0, 14.0], [28.0, 7.0, 12.0], [20.0, 7.0, 10.0]]
		var y := 0.0
		for s: Array in storeys:
			var w: float = s[0]; var h: float = s[1]; var d: float = s[2]
			box(w, h, d, white, 0, y + h * 0.5, 0)
			box(w + 0.6, 0.5, d + 0.6, gold, 0, y + 0.25, 0)
			box(w + 0.6, 0.5, d + 0.6, gold, 0, y + h - 0.25, 0)
			for sx in [-1.0, 1.0]:
				box(0.5, h, 0.5, gold, sx * w * 0.5, y + h * 0.5, d * 0.5 + 0.05)
			var count := int(w / 2.2)
			for i in count:
				var x := -w * 0.5 + (float(i) + 0.5) * (w / count)
				if absf(x) < 3.0 and y == 0.0:
					continue
				box(0.9, 1.4, 0.2, winm, x, y + h * 0.5, d * 0.5 + 0.05)
			y += h
		# door with a little dark roof
		box(5, 5, 0.3, wood, 0, 2.5, 7.1)
		box(0.15, 5, 0.35, mat(0x6a4a2a), 0, 2.5, 7.15)
		gable(7.0, 2.0, 1.4, roofd, null, 0, 5.2, 7.6, PI / 2)
		# the big swept roof
		box(34, 1.2, 18, roofd, 0, y + 0.6, 0)
		var rw := pivot(0, y + 1.2, 0)
		for sz in [-1.0, 1.0]:
			var slab := box(34, 1.2, 10, roofw, 0, 2.6, sz * 4.4, 0.0, rw)
			slab.rotation.x = sz * 0.55
		box(10, 4, 8, mat(0xb88a4a, {"rough": 0.6}), 0, 3.0, 0, 0.0, rw)
		for sx in [-1.0, 1.0]:   # upturned corners
			var c := cone(1.2, 5.0, roofd, sx * 17.5, 1.6, 0, 6, rw)
			c.rotation.z = -sx * 1.15
			cone(0.5, 2.0, gold, sx * 16.0, 7.2, 0, 6, rw)
		box(30, 0.7, 1.0, gold, 0, 5.9, 0, 0.0, rw)
		for sx in [-1.0, 1.0]:   # gold horns on the ridge
			var h0 := Vector3(sx * 1.2, 6.2, 0)
			var h1 := h0 + Vector3(sx * 0.9, 2.4, 0)
			limb(h0, h1, 0.45, 0.35, gold, 8, rw)
			limb(h1, h1 + Vector3(-sx * 0.6, 1.8, 0), 0.35, 0.05, gold, 8, rw)
		if flag("stones"):
			var rock := mat(0xe6e6ee, {"rough": 0.8}); var orb := mat(0x1a1a4a, {"rough": 0.05, "metal": 0.3, "emissive": 0x2a3a9a, "glow": 0.35})
			for i in 8:
				var a := (float(i) + 0.5) / 8.0 * TAU + 0.3
				var rr := rng.randf_range(34.0, 44.0)
				if cos(a) > 0.6:
					continue   # keep the front clear
				var hh := rng.randf_range(8.0, 16.0)
				var st := sphere(hh * 0.5, rock, sin(a) * rr, hh * 0.5 + rng.randf_range(1.5, 4.0), cos(a) * rr, 6)
				st.scale = Vector3(0.55, 1.0, 0.5)
				st.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
				if i % 2 == 0:
					sphere(rng.randf_range(2.0, 3.2), orb, sin(a + 0.35) * rr * 0.8, rng.randf_range(14.0, 26.0), cos(a + 0.35) * rr * 0.8, 20)

	## The Nameless Planet arena (audit 126): a square glass-tile ring with a blue edge band, a gold skirt and gold
	## claw feet at the corners. Top at local y 1.0 like `cellarena` (fight spots unchanged). Param "size" (50).
	func u6arena() -> void:
		var s := num("size", 50.0)
		var glass := mat(0xd6eef2, {"rough": 0.08, "metal": 0.15}); var line := mat(0xa8c8dc, {"rough": 0.2})
		var blue := mat(0x2a6ac8, {"rough": 0.3, "metal": 0.2}); var gold := mat(0xd8b048, {"metal": 0.75, "rough": 0.3})
		box(s, 0.12, s, glass, 0, 0.94, 0)
		box(s + 0.6, 0.85, s + 0.6, blue, 0, 0.45, 0)
		box(s + 1.6, 0.35, s + 1.6, gold, 0, 0.12, 0)
		var step := 2.5
		var n := int(s / step)
		for i in range(1, n):
			var p := -s * 0.5 + i * step
			box(s, 0.02, 0.08, line, 0, 1.005, p)
			box(0.08, 0.02, s, line, p, 1.005, 0)
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var cx: float = c.x * (s * 0.5 + 0.2); var cz: float = c.y * (s * 0.5 + 0.2)
			var foot := frustum(2.6, 0.9, 0.9, -0.6, gold, cx, cz)
			foot.rotation.y = PI / 4
			for k in 3:   # claws
				var a := atan2(c.x, c.y) + (k - 1) * 0.5
				limb(Vector3(cx, 0.2, cz), Vector3(cx + sin(a) * 3.0, -0.1, cz + cos(a) * 3.0), 0.45, 0.05, gold, 6)
			sphere(0.8, gold, cx, 1.3, cz, 12)

	## Floating bowl spectator cup on a gold stem (audit 126). Params: "alt" (bowl bottom height, default 7),
	## "top" ("dome" blue cushion dome | "seats"), "radius" (default 6).
	func cupstand() -> void:
		var r := num("radius", 6.0); var alt := num("alt", 7.0)
		var green := mat(0x2f9a6a, {"rough": 0.4}); var gold := mat(0xd8b048, {"metal": 0.75, "rough": 0.3})
		var blue := mat(0x3aa8e0, {"rough": 0.5}); var cream := mat(0xf2ecd8, {"rough": 0.5})
		var bowl := dome(r, green, 0, alt + r * 0.62, 0, 24)
		bowl.rotation.x = PI
		bowl.scale = Vector3(1, 0.62, 1)
		cyl(r * 1.02, r * 1.02, 0.5, cream, 0, alt + r * 0.62, 0, 32)
		torus(r * 1.03, 0.22, gold, 0, alt + r * 0.62 + 0.25, 0)
		torus(r * 0.8, 0.15, gold, 0, alt + r * 0.3, 0)
		for k in 6:
			var a := float(k) / 6.0 * TAU
			limb(Vector3(sin(a) * r * 0.82, alt + r * 0.32, cos(a) * r * 0.82), Vector3(sin(a) * r * 0.98, alt + r * 0.6, cos(a) * r * 0.98), 0.12, 0.12, gold, 6)
		cyl(0.5, 0.8, 3.2, gold, 0, alt - 1.2, 0, 12)
		sphere(0.9, gold, 0, alt - 2.9, 0, 12)
		for k in 4:
			var a := float(k) / 4.0 * TAU + PI / 4
			limb(Vector3(0, alt - 2.9, 0), Vector3(sin(a) * 1.8, alt - 4.0, cos(a) * 1.8), 0.3, 0.05, gold, 6)
		if str(l.get("top", "dome")) == "seats":
			for k in 5:
				var a := float(k) / 5.0 * TAU
				box(1.2, 1.2, 1.0, blue, sin(a) * r * 0.55, alt + r * 0.62 + 0.8, cos(a) * r * 0.55, a)
		else:
			var cushion := dome(r * 0.98, blue, 0, alt + r * 0.62 + 0.2, 0, 24)
			cushion.scale = Vector3(1, 0.35, 1)

	## Shield-shaped viewing box of the two gods (audit 126): upright blue oval shield with a gold rim, a gold
	## four-petal emblem and crown, on claw feet, with a bench behind it. Front faces +z. Param "size" (default 1).
	func shieldbox() -> void:
		var root := pivot(0, 0, 0)
		root.scale = Vector3.ONE * num("size", 1.0)
		var blue := mat(0x2a4ab0, {"metal": 0.4, "rough": 0.3}); var gold := mat(0xd8b048, {"metal": 0.75, "rough": 0.3})
		var dark := mat(0x18204a, {"rough": 0.4})
		var face := cyl(1, 1, 0.8, blue, 0, 6.5, 0, 32, root); face.rotation.x = PI / 2; face.scale = Vector3(4.0, 0.8, 5.6)
		var rim := torus(1.0, 0.07, gold, 0, 6.5, 0.0, root); rim.rotation.x = PI / 2; rim.scale = Vector3(4.05, 1.0, 5.65)
		var rim2 := torus(1.0, 0.04, gold, 0, 6.5, 0.4, root); rim2.rotation.x = PI / 2; rim2.scale = Vector3(3.4, 1.0, 4.9)
		sphere(0.7, gold, 0, 6.5, 0.45, 14, root).scale = Vector3(1, 1, 0.4)
		for k in 4:
			var a := float(k) / 4.0 * TAU + PI / 4
			var pet := sphere(1.0, gold, sin(a) * 1.5, 6.5 + cos(a) * 1.9, 0.42, 12, root)
			pet.scale = Vector3(0.35, 1.0, 0.2)
			pet.rotation.z = -a
			var bl := sphere(0.9, dark, sin(a + PI / 4) * 2.6, 6.5 + cos(a + PI / 4) * 3.4, 0.38, 10, root)
			bl.scale = Vector3(0.6, 0.6, 0.15)
		cone(0.9, 1.6, gold, 0, 12.6, 0, 8, root)
		for sx in [-1.0, 1.0]:
			var sc := torus(0.6, 0.12, gold, sx * 1.1, 12.3, 0, root); sc.rotation.x = PI / 2
			limb(Vector3(sx * 1.6, 1.4, 0), Vector3(sx * 2.8, 0.0, 0.6), 0.4, 0.1, gold, 6, root)
		limb(Vector3(0, 1.2, 0), Vector3(0, 0.0, 0.0), 0.8, 0.3, gold, 8, root)
		box(6, 0.8, 3, blue, 0, 1.8, -3.0, 0.0, root)
		box(6.4, 0.3, 3.4, gold, 0, 1.4, -3.0, 0.0, root)
		box(5.6, 1.3, 2.9, dark, 0, 0.6, -3.0, 0.0, root)   # plinth: the bench floated 1.25 m over the ground (audit)
		box(6, 2.4, 0.6, blue, 0, 3.0, -4.3, 0.0, root)

	## Hell's needle mountain (audit 113, batch 6 Hell zone): a cluster of tall needle spikes on a rock mound.
	## Params: "count" (default 14), "height" (default 30).
	func needlepeak() -> void:
		var H := num("height", 30.0)
		var rock := mat(0x5a3a3a, {"rough": 0.9, "stone": true}); var steel := mat(0xb8b8c8, {"metal": 0.85, "rough": 0.25})
		var mound := sphere(H * 0.35, rock, 0, -H * 0.12, 0, 12); mound.scale = Vector3(1.0, 0.55, 1.0)
		for i in int(num("count", 14)):
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.0, H * 0.28)
			var hh := H * rng.randf_range(0.45, 1.0) * (1.0 - d / (H * 0.5))
			var base := Vector3(sin(a) * d, H * 0.05, cos(a) * d)
			var tip := base + Vector3(sin(a) * hh * 0.12, hh, cos(a) * hh * 0.12)
			limb(base, tip, H * 0.035, 0.0, steel if i % 3 else rock, 6)

	## Blood pool (Hell): a glossy dark-red pool in a rock rim. Params: "radius" (default 14).
	func bloodpool() -> void:
		var r := num("radius", 14.0)
		var red := mat(0x8a0a12, {"rough": 0.05, "metal": 0.2, "emissive": 0x3a0004, "glow": 0.4})
		var rock := mat(0x4a3030, {"rough": 0.9, "stone": true})
		cyl(r, r, 0.3, red, 0, 0.05, 0, 40)
		for i in 22:
			var a := float(i) / 22.0 * TAU + rng.randf() * 0.1
			var s := sphere(rng.randf_range(1.2, 2.2), rock, sin(a) * (r + 0.6), 0.2, cos(a) * (r + 0.6), 8)
			s.scale = Vector3(1.3, 0.6, 1.0)
