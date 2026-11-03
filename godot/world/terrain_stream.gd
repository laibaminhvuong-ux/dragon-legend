class_name TerrainStream
extends Node3D
# Streaming level-of-detail terrain for big maps (planets): the map is cut into 128 m chunks; each is meshed from
# the terrain grid every `step` cells (1 near the viewer, then 2, 4, 8 far away) on worker threads, with skirts
# hanging under the edges so neighbours of different detail never show cracks. Same grid format and material as
# WorldTerrain, so grass and props keep working. Gameplay never touches this: the rules give heights.

const CHUNK := 128.0
const LODS := [[260.0, 1], [620.0, 2], [1300.0, 4], [1e9, 8]]
const MAX_JOBS := 6
const APPLY_PER_FRAME := 4

var grid: Dictionary
var target: Node3D
var _mat: Material
var _floor_y := -100.0
var _per := 1            # grid cells per chunk
var _count := 1          # chunks per side
var _chunks := {}        # Vector2i -> {"mi": MeshInstance3D, "lod": int}
var _jobs := {}          # Vector2i -> [task_id, lod]
var _done: Array = []    # [key, lod, arrays] from workers
var _mutex := Mutex.new()

static func create(zone: RefCounted, g: Dictionary) -> TerrainStream:
	var s := TerrainStream.new()
	s.name = "Terrain"
	s.grid = g
	s.set_meta("grid", g)
	s._mat = WorldTerrain.material(zone)
	s._floor_y = float(zone.kill_y) if zone.kill_y != null else -100.0
	s._per = maxi(1, int(round(CHUNK / float(g.cell))))
	s._count = int(ceil(float(g.n) / s._per))
	return s

func chunk_count() -> int:
	return _chunks.size()

func chunk_of(p: Vector3) -> Vector2i:
	var c := float(_per) * float(grid.cell)
	return Vector2i(clampi(int((p.x + float(grid.half)) / c), 0, _count - 1), clampi(int((p.z + float(grid.half)) / c), 0, _count - 1))

func lod_of(key: Vector2i) -> int:
	return int(_chunks[key].lod) if _chunks.has(key) else 0

func mesh_at(p: Vector3) -> MeshInstance3D:
	var key := chunk_of(p)
	return _chunks[key].mi if _chunks.has(key) else null

func _want(key: Vector2i, p: Vector3) -> int:
	var c := float(_per) * float(grid.cell)
	var centre := Vector2(-float(grid.half) + (key.x + 0.5) * c, -float(grid.half) + (key.y + 0.5) * c)
	var d := maxf(0.0, centre.distance_to(Vector2(p.x, p.z)) - c * 0.5)
	for l in LODS:
		if d < float(l[0]):
			return int(l[1])
	return 8

## Brings every chunk to the detail it should have around p. `now` builds on this thread (first frame, tests).
func update_around(p: Vector3, now := false) -> void:
	for j in _count:
		for i in _count:
			var key := Vector2i(i, j)
			var want := _want(key, p)
			if _chunks.has(key) and int(_chunks[key].lod) == want:
				continue
			if now:
				_apply(key, want, _arrays(key, want))
			elif not _jobs.has(key) and _jobs.size() < MAX_JOBS:
				var id := WorkerThreadPool.add_task(_work.bind(key, want))
				_jobs[key] = [id, want]

func _process(_dt: float) -> void:
	if target != null and is_instance_valid(target):
		update_around(target.global_position)
	_mutex.lock()
	var ready: Array = _done.slice(0, APPLY_PER_FRAME)
	_done = _done.slice(APPLY_PER_FRAME)
	_mutex.unlock()
	for r: Array in ready:
		var key: Vector2i = r[0]
		if _jobs.has(key):
			WorkerThreadPool.wait_for_task_completion(int(_jobs[key][0]))
			_jobs.erase(key)
		_apply(key, int(r[1]), r[2])

func _exit_tree() -> void:
	for j: Array in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(int(j[0]))
	_jobs.clear()

func _work(key: Vector2i, lod: int) -> void:
	var arrays: Variant = _arrays(key, lod)
	_mutex.lock()
	_done.append([key, lod, arrays])
	_mutex.unlock()

func _apply(key: Vector2i, lod: int, arrays: Variant) -> void:
	var e: Dictionary = _chunks.get(key, {})
	if e.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Chunk_%d_%d" % [key.x, key.y]
		add_child(mi)
		e = {"mi": mi, "lod": 0}
		_chunks[key] = e
	e.lod = lod
	var mi: MeshInstance3D = e.mi
	if arrays == null:
		mi.mesh = null
		return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mat)
	mi.mesh = mesh

## Mesh arrays for one chunk at one detail step (thread-safe: reads the grid only). Void quads are skipped.
func _arrays(key: Vector2i, step: int) -> Variant:
	var n: int = grid.n
	var cell: float = grid.cell
	var half: float = grid.half
	var h: PackedFloat32Array = grid.h
	var col: PackedColorArray = grid.col
	var extra: PackedVector2Array = grid.extra
	var i0 := key.x * _per
	var j0 := key.y * _per
	var w := mini(_per, n - i0)
	var d := mini(_per, n - j0)
	if w <= 0 or d <= 0:
		return null
	var cols_n := int(ceil(float(w) / step)) + 1
	var rows_n := int(ceil(float(d) / step)) + 1
	var verts := PackedVector3Array(); var norms := PackedVector3Array()
	var cols := PackedColorArray(); var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var gi := PackedInt32Array()   # grid index per surface vertex
	for r in rows_n:
		var j := mini(j0 + r * step, j0 + d)
		for c in cols_n:
			var i := mini(i0 + c * step, i0 + w)
			var k := j * (n + 1) + i
			gi.append(k)
			verts.append(Vector3(-half + i * cell, h[k], -half + j * cell))
			norms.append(_normal(h, n, i, j, cell * step))
			cols.append(col[k])
			uv2.append(extra[k])
	for r in rows_n - 1:
		for c in cols_n - 1:
			var a := r * cols_n + c
			var b := a + cols_n
			if h[gi[a]] <= _floor_y or h[gi[a + 1]] <= _floor_y or h[gi[b]] <= _floor_y or h[gi[b + 1]] <= _floor_y:
				continue
			idx.append_array(PackedInt32Array([a, a + 1, b + 1, a, b + 1, b]))
	if idx.is_empty():
		return null
	# skirts: a strip hanging under each edge hides cracks against coarser neighbours
	var drop := cell * step * 2.0 + 1.0
	var edges := [[], [], [], []]
	for c in cols_n:
		edges[0].append(c); edges[1].append((rows_n - 1) * cols_n + cols_n - 1 - c)
	for r in rows_n:
		edges[2].append((rows_n - 1 - r) * cols_n); edges[3].append(r * cols_n + cols_n - 1)
	for e: Array in edges:
		for t in e.size() - 1:
			var p0: int = e[t]; var p1: int = e[t + 1]
			if h[gi[p0]] <= _floor_y or h[gi[p1]] <= _floor_y:
				continue
			var base := verts.size()
			for p in [p0, p1]:
				verts.append(verts[p] - Vector3(0, drop, 0))
				norms.append(norms[p]); cols.append(cols[p]); uv2.append(uv2[p])
			idx.append_array(PackedInt32Array([p0, base, p1, p1, base, base + 1]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts; arr[Mesh.ARRAY_NORMAL] = norms; arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2; arr[Mesh.ARRAY_INDEX] = idx
	return arr

static func _normal(h: PackedFloat32Array, n: int, i: int, j: int, span: float) -> Vector3:
	var s := maxi(1, int(round(span)))  # grid steps either side, never past the edge
	var il := maxi(i - 1, 0); var ir := mini(i + 1, n)
	var jd := maxi(j - 1, 0); var ju := mini(j + 1, n)
	var dx: float = h[j * (n + 1) + ir] - h[j * (n + 1) + il]
	var dz: float = h[ju * (n + 1) + i] - h[jd * (n + 1) + i]
	var cell := span / maxf(1.0, float(s))
	return Vector3(-dx / maxf(cell * (ir - il), 0.001), 1.0, -dz / maxf(cell * (ju - jd), 0.001)).normalized()
