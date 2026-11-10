class_name Cloth
extends RefCounted
# Thick, baggy martial-arts clothing on the one shared body mesh (cel-shaded style pass, 2026-11-10). The body's clothed
# regions are pushed outwards like loose cloth: muscle definition under the cloth is smoothed away, loose tops hang
# wide with a raised lapel round the V-neck, short sleeves flare open at the hem, trousers balloon at the thigh and
# knee and bunch up before gathering tightly into chunky boots with a flared cuff (toes smoothed into a boot shape).
#
# Everything is decided in mannequin rest space (CUSTOM0, the same space as BodyRegions), so the cloth follows the
# outfit borders on every body. The work is done once per base body and cloth setting as a per-vertex offset (smooth
# then push along the smoothed normals); a sculpted body (race/build/age) just adds that offset and gets its normals
# recomputed. Skin weights are untouched, so every animation still fits. Hands, neck and head never move.

const ITERATIONS := 14           # Taubin smoothing passes (shrink-free): enough to iron out abs, pecs and toes
static var _topology: Dictionary = {}   # rest-array hash -> {group, groups, nbr_start, nbr, tris}
static var _offsets: Dictionary = {}    # base mesh id + params -> per-vertex offset (PackedVector3Array)
static var _cache: Dictionary = {}      # sculpted mesh id + params -> clothed mesh

## Cloth settings for an outfit. amount: 0 skin-tight .. 1 very baggy (Outfits data, look.cloth overrides);
## sleeve: where the clothed part of the arm ends (rest |x|); boots: chunky boots (0 = bare painted feet shape).
static func params(parts: Dictionary, look: Dictionary) -> Dictionary:
	var amount := float(look.get("cloth", parts.get("cloth", 0.0)))
	var sleeve := BodyRegions.SLEEVE_X
	if parts.get("vest", false):
		sleeve = 0.0
	elif parts.get("sleeves", false):
		sleeve = BodyRegions.WRIST_X
	var boots := float(look.get("boots", parts.get("boots", 1.0)))
	if OS.get_environment("DL_CLOTH") == "0":   # dev: A/B checks without the cloth pass
		amount = 0.0; boots = 0.0
	return {"amount": clampf(amount, 0.0, 1.5), "sleeve": sleeve, "boots": boots, "boot_top": boot_top(boots)}

## Rest height of the boots' top edge: chunky boots reach up the shin (the classic painted boots stop at the ankle).
static func boot_top(boots: float) -> float:
	return BodyRegions.BOOT_Y + 0.09 * clampf(boots, 0.0, 1.0)

static func _key(p: Dictionary) -> String:
	return "%.3f_%.3f_%.3f" % [float(p.amount), float(p.sleeve), float(p.boots)]   # (boot_top follows boots)

static func is_none(p: Dictionary) -> bool:
	return float(p.amount) <= 0.001 and float(p.boots) <= 0.001

## `mesh` (possibly sculpted) dressed in cloth; `base` is the unsculpted body it was made from (same topology).
static func dressed(mesh: ArrayMesh, base: ArrayMesh, p: Dictionary) -> ArrayMesh:
	if is_none(p):
		return mesh
	var key := "%d|%s" % [mesh.get_instance_id(), _key(p)]
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var rest: Variant = arr[Mesh.ARRAY_CUSTOM0]
		if not (rest is PackedFloat32Array) or arr[Mesh.ARRAY_INDEX] == null:
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
			continue
		var off := _offset(base, s, p)
		var topo := _topo(base.surface_get_arrays(s))
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var wts: PackedFloat32Array = off[1]
		var d: PackedVector3Array = off[0]
		for i in verts.size():
			verts[i] += d[i]
		var fresh: PackedVector3Array = off[3]
		for i in verts.size():
			var w := wts[i]
			if w > 0.0 and i < norms.size():
				norms[i] = norms[i].lerp(fresh[i], w).normalized()
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_CUSTOM0] = off[2]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mesh.surface_get_format(s) & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
		out.surface_set_material(s, mesh.surface_get_material(s))
	_cache[key] = out
	return out

# --------------------------------------------------------------------------------------------- topology
## Vertices welded by rest position (UV seams split them) and each welded group's neighbours.
static func _topo(arr: Array) -> Dictionary:
	var rest: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var key := hash(rest) ^ idx.size()
	if _topology.has(key):
		return _topology[key]
	var n := rest.size() / 4
	var group := PackedInt32Array(); group.resize(n)
	var ids := {}
	var reps := PackedInt32Array()
	for i in n:
		var k := Vector3i(roundi(rest[i * 4] * 5000.0), roundi(rest[i * 4 + 1] * 5000.0), roundi(rest[i * 4 + 2] * 5000.0))
		if not ids.has(k):
			ids[k] = reps.size()
			reps.append(i)
		group[i] = ids[k]
	var g := reps.size()
	var edges := {}
	for t in idx.size() / 3:
		for e in 3:
			var a := group[idx[t * 3 + e]]
			var b := group[idx[t * 3 + (e + 1) % 3]]
			if a != b:
				edges[mini(a, b) * g + maxi(a, b)] = true
	var count := PackedInt32Array(); count.resize(g + 1)
	for e: int in edges:
		count[e / g] += 1
		count[e % g] += 1
	var start := PackedInt32Array(); start.resize(g + 1)
	for i in g:
		start[i + 1] = start[i] + count[i]
	var fill := start.duplicate()
	var nbr := PackedInt32Array(); nbr.resize(start[g])
	for e: int in edges:
		var a := e / g
		var b := e % g
		nbr[fill[a]] = b; fill[a] += 1
		nbr[fill[b]] = a; fill[b] += 1
	var t := {"group": group, "groups": g, "reps": reps, "start": start, "nbr": nbr, "idx": idx, "flip": false}
	# winding check: our face normals must agree with the mesh's own normals
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var own: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var mine := _normals(verts, t)
	var agree := 0.0
	for i in mini(own.size(), mine.size()):
		agree += own[i].dot(mine[i])
	t.flip = agree < 0.0
	_topology[key] = t
	return t

## Smooth vertex normals (area-weighted, shared across welded duplicates), oriented like the mesh's own normals.
static func _normals(verts: PackedVector3Array, topo: Dictionary) -> PackedVector3Array:
	var group: PackedInt32Array = topo.group
	var idx: PackedInt32Array = topo.idx
	var sums := PackedVector3Array(); sums.resize(int(topo.groups))
	for t in idx.size() / 3:
		var a := idx[t * 3]; var b := idx[t * 3 + 1]; var c := idx[t * 3 + 2]
		var fn := (verts[c] - verts[a]).cross(verts[b] - verts[a])   # Godot: clockwise front faces
		sums[group[a]] += fn; sums[group[b]] += fn; sums[group[c]] += fn
	var out := PackedVector3Array(); out.resize(verts.size())
	for i in verts.size():
		var s := sums[group[i]]
		out[i] = (s.normalized() if s.length_squared() > 1e-14 else Vector3.UP) * (-1.0 if topo.flip else 1.0)
	return out

# --------------------------------------------------------------------------------------------- the cloth shape
## [per-vertex offset, per-vertex normal blend] for a base body and cloth setting (cached).
static func _offset(base: ArrayMesh, s: int, p: Dictionary) -> Array:
	var key := "%d_%d|%s" % [base.get_instance_id(), s, _key(p)]
	if _offsets.has(key):
		return _offsets[key]
	var arr: Array = base.surface_get_arrays(s)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var rest: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
	var topo := _topo(arr)
	var group: PackedInt32Array = topo.group
	var reps: PackedInt32Array = topo.reps
	var start: PackedInt32Array = topo.start
	var nbr: PackedInt32Array = topo.nbr
	var g := int(topo.groups)
	# body size: the teen bodies are modelled smaller (and scaled up in the game), so cloth thickness follows the mesh
	var top := 0.0
	for v in verts:
		top = maxf(top, v.y)
	var k := top / 1.81
	var pos := PackedVector3Array(); pos.resize(g)
	var rp := PackedVector3Array(); rp.resize(g)
	var ws := PackedFloat32Array(); ws.resize(g)
	for i in g:
		var r := reps[i]
		pos[i] = verts[r]
		rp[i] = Vector3(rest[r * 4], rest[r * 4 + 1], rest[r * 4 + 2])
		ws[i] = smooth_weight(rp[i], p)
	# 1. iron out the anatomy under the cloth (Taubin: a smoothing step, then an inflating one, so nothing shrinks)
	var orig := pos.duplicate()
	var tmp := PackedVector3Array(); tmp.resize(g)
	for it in ITERATIONS * 2:
		var f := 0.55 if it % 2 == 0 else -0.58
		for i in g:
			var w := ws[i]
			if w <= 0.0:
				tmp[i] = pos[i]
				continue
			var a := start[i]; var b := start[i + 1]
			if b <= a:
				tmp[i] = pos[i]
				continue
			var avg := Vector3.ZERO
			for j in range(a, b):
				avg += pos[nbr[j]]
			avg /= float(b - a)
			tmp[i] = pos[i] + (avg - pos[i]) * f * w
		var sw := pos; pos = tmp; tmp = sw
	# the feet: many more passes, so the toes melt into one rounded boot
	if float(p.boots) > 0.0:
		var feet := PackedInt32Array()
		for i in g:
			if rp[i].y < 0.11 and ws[i] > 0.0:
				feet.append(i)
		for it in 60:
			var f := 0.6 if it % 2 == 0 else -0.62
			for i in feet:
				var a := start[i]; var b := start[i + 1]
				var avg := Vector3.ZERO
				for j in range(a, b):
					avg += pos[nbr[j]]
				tmp[i] = pos[i] + (avg / float(maxi(1, b - a)) - pos[i]) * f * (1.0 - smoothstep(0.07, 0.11, rp[i].y))
			for i in feet:
				pos[i] = tmp[i]
	# 2. push the cloth out along the smoothed surface's normals
	var smooth_verts := PackedVector3Array(); smooth_verts.resize(verts.size())
	for i in verts.size():
		smooth_verts[i] = pos[group[i]]
	var n := _normals(smooth_verts, topo)
	var gn := PackedVector3Array(); gn.resize(g)
	for i in verts.size():
		gn[group[i]] = n[i]
	var d := PackedVector3Array(); d.resize(verts.size())
	var bw := PackedFloat32Array(); bw.resize(verts.size())
	var gd := PackedVector3Array(); gd.resize(g)
	for i in g:
		gd[i] = pos[i] - orig[i] + gn[i] * push(rp[i], gn[i], p) * k
	for i in verts.size():
		var gi := group[i]
		d[i] = gd[gi]
		bw[i] = clampf(maxf(ws[gi], gd[gi].length() * 400.0), 0.0, 1.0)
	# cloth shading: normals of the clothed shape, smoothed further over the surface so the cel bands follow the cloth,
	# not the anatomy underneath (sculpted bodies reuse them, as BodySculpt keeps normals)
	var cv := PackedVector3Array(); cv.resize(verts.size())
	for i in verts.size():
		cv[i] = verts[i] + d[i]
	var cn := _normals(cv, topo)
	var gnn := PackedVector3Array(); gnn.resize(g)
	for i in verts.size():
		gnn[group[i]] = cn[i]
	var ntmp := gnn.duplicate()
	for it in 10:
		for i in g:
			var a := start[i]; var b := start[i + 1]
			if ws[i] <= 0.0 or b <= a:
				ntmp[i] = gnn[i]
				continue
			var avg := Vector3.ZERO
			for j in range(a, b):
				avg += gnn[nbr[j]]
			ntmp[i] = gnn[i].lerp(avg.normalized(), 0.8 * ws[i]).normalized()
		var sw3 := gnn; gnn = ntmp; ntmp = sw3
	var nn := PackedVector3Array(); nn.resize(verts.size())
	for i in verts.size():
		nn[i] = gnn[group[i]]
	# 3. straighten the rest coordinates on the lower legs: the body's mapping onto the mannequin ripples a little round
	# the shin (bones' shifts blend), which made the boot border, trim and laces zigzag
	var rs := rp.duplicate()
	var rtmp := rs.duplicate()
	var rw := PackedFloat32Array(); rw.resize(g)
	for i in g:
		rw[i] = (1.0 - smoothstep(0.5, 0.62, rp[i].y)) * (1.0 - _arm(rp[i]))
	for it in 24:
		var f := 0.6 if it % 2 == 0 else -0.62
		for i in g:
			var a := start[i]; var b := start[i + 1]
			if rw[i] <= 0.0 or b <= a:
				rtmp[i] = rs[i]
				continue
			var avg := Vector3.ZERO
			for j in range(a, b):
				avg += rs[nbr[j]]
			rtmp[i] = rs[i] + (avg / float(b - a) - rs[i]) * f * rw[i]
		var sw2 := rs; rs = rtmp; rtmp = sw2
	var new_rest := rest.duplicate()
	for i in verts.size():
		var r := rs[group[i]]
		new_rest[i * 4] = r.x; new_rest[i * 4 + 1] = r.y; new_rest[i * 4 + 2] = r.z
	_offsets[key] = [d, bw, new_rest, nn]
	return _offsets[key]

static func _band(a: float, b: float, c: float, e: float, x: float) -> float:
	return smoothstep(a, b, x) * (1.0 - smoothstep(c, e, x))

## 1 on the arms (rest pose), same rule as BodySculpt.
static func _arm(r: Vector3) -> float:
	return smoothstep(0.17, 0.24, absf(r.x)) * smoothstep(1.18, 1.26, r.y)

## How much the anatomy under the cloth is smoothed at a rest point (0 = untouched skin).
static func smooth_weight(r: Vector3, p: Dictionary) -> float:
	var a := clampf(float(p.amount) * 1.4, 0.0, 1.0)
	var arm := _arm(r)
	var ax := absf(r.x)
	var sleeve := float(p.sleeve)
	var w := 0.0
	# top + belt (below the neck and the shoulder line)
	var trunk := (1.0 - arm) * smoothstep(0.86, 0.94, r.y) * (1.0 - smoothstep(1.36, 1.45, r.y))
	w = maxf(w, trunk * a)
	# sleeves: from the shoulder to the hem (never the hands)
	if sleeve > 0.0:
		w = maxf(w, arm * (1.0 - smoothstep(sleeve - 0.03, sleeve - 0.005, ax)) * a * 0.8)
	# trousers
	var bt := float(p.boot_top)
	var legs := (1.0 - smoothstep(0.88, 0.95, r.y)) * smoothstep(bt, bt + 0.03, r.y) * (1.0 - arm)
	w = maxf(w, legs * a)
	# boots: the whole foot becomes one smooth boot (no toes)
	var boot := 1.0 - smoothstep(bt, bt + 0.02, r.y)
	w = maxf(w, boot * clampf(float(p.boots), 0.0, 1.0))
	return w

## How far (metres, adult body) the cloth stands off the smoothed body at a rest point, along the normal.
static func push(r: Vector3, nrm: Vector3, p: Dictionary) -> float:
	var a := float(p.amount)
	var arm := _arm(r)
	var ax := absf(r.x)
	var sleeve := float(p.sleeve)
	var out := 0.0
	# --- top: hangs loose off the shoulders, blouses out over the sash, a raised lapel round the V-neck
	var trunk := (1.0 - arm) * smoothstep(0.93, 0.97, r.y) * (1.0 - smoothstep(1.40, 1.47, r.y))
	if trunk > 0.0:
		var t := 0.016 + 0.012 * _band(1.01, 1.05, 1.09, 1.2, r.y)
		t *= lerpf(1.0, 0.55, smoothstep(1.34, 1.44, r.y))   # the cloth rests on the shoulders
		if r.z > 0.0 and r.y > 1.3:   # V-neck: undershirt sits close, the gi's lapel stands proud of it
			var dv := ax - (r.y - 1.33) * 0.9   # > 0 outside the V (gi), < 0 the undershirt
			var lapel := smoothstep(-0.014, 0.006, dv)
			t = lerpf(0.01, t, lapel) + 0.007 * _band(-0.006, 0.006, 0.02, 0.036, dv) * smoothstep(0.02, 0.05, r.z)
		out = maxf(out, t * trunk * a)
	# --- belt line: just enough for the sash to sit on the cloth
	var belt := (1.0 - arm) * _band(0.88, 0.92, 0.98, 1.0, r.y)
	out = maxf(out, 0.012 * belt * a)
	# --- sleeves: wider towards the hem, then a sharp drop: the open sleeve mouth
	if sleeve > 0.0 and arm > 0.0:
		var span := maxf(0.05, sleeve - 0.2)
		var t := 0.018 + 0.03 * smoothstep(0.2, sleeve, ax) if sleeve < 0.5 else 0.016 + 0.026 * smoothstep(0.35, sleeve, ax)
		t *= 1.0 - smoothstep(sleeve - 0.004, sleeve + 0.01, ax)
		t *= lerpf(1.0, 0.5, smoothstep(0.0, -0.8, nrm.y) * (1.0 - smoothstep(0.2, 0.2 + span * 0.5, ax)))   # less in the armpit
		out = maxf(out, t * arm * a)
	# --- trousers: full at the thigh and knee, bunched above the boot, gathered tight into it
	var top := float(p.boot_top)
	var leg := (1.0 - arm) * (1.0 - smoothstep(0.9, 0.96, r.y)) * smoothstep(top + 0.002, top + 0.01, r.y)
	if leg > 0.0:
		var t := _curve(r.y, [top + 0.01, 0.012, top + 0.03, 0.032, top + 0.06, 0.042, top + 0.1, 0.034, maxf(0.52, top + 0.15), 0.042,
			0.66, 0.036, 0.8, 0.026, 0.9, 0.014])
		var inner := clampf(-nrm.x * signf(r.x), 0.0, 1.0) * smoothstep(0.55, 0.75, r.y)   # less between the thighs
		t *= lerpf(1.0, 0.4, inner)
		t *= lerpf(1.0, 0.5, (1.0 - smoothstep(0.03, 0.07, ax)) * smoothstep(0.78, 0.88, r.y))   # crotch
		out = maxf(out, t * leg * a)
	# --- boots: chunky shaft with a flared cuff; a solid smooth foot
	var bt := clampf(float(p.boots), 0.0, 1.5)
	if bt > 0.0 and r.y < top + 0.015:
		var t := 0.016 + 0.022 * smoothstep(top - 0.07, top - 0.004, r.y)
		t *= 1.0 - smoothstep(top, top + 0.012, r.y)
		t = lerpf(t, 0.008, 1.0 - smoothstep(0.08, 0.12, r.y))   # the foot: a little fuller, no toes
		out = maxf(out, t * bt)
	return out

## Piecewise smooth curve through [x0, y0, x1, y1, ...] (flat outside).
static func _curve(x: float, pts: Array) -> float:
	if x <= float(pts[0]):
		return float(pts[1])
	for i in range(0, pts.size() - 2, 2):
		var x0 := float(pts[i]); var x1 := float(pts[i + 2])
		if x <= x1:
			return lerpf(float(pts[i + 1]), float(pts[i + 3]), smoothstep(x0, x1, x))
	return float(pts[pts.size() - 1])
