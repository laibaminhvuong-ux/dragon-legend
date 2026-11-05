class_name TownStream
extends Node3D
# Towns and hamlets load like chunks (user request 2026-11-05: "rendered like chunks in Minecraft, it's very laggy"):
# each town is built only when the player comes within LOAD metres of its edge and freed beyond UNLOAD, built on a worker
# thread so moving never stutters. The rules (collision, doors, floors) don't depend on this: only the visuals stream.

const LOAD := 700.0
const UNLOAD := 900.0

var zone: RefCounted
var towns: Array = []          # landmark dictionaries
var built: Dictionary = {}     # index -> Node3D
var _queue: Array[int] = []
var _primed := false

static func create(z: RefCounted, town_landmarks: Array) -> TownStream:
	var s := TownStream.new()
	s.name = "TownStream"
	s.zone = z
	s.towns = town_landmarks
	return s

## Call every frame with the player's position. The first call builds the towns right around the player at once
## (during the loading screen); everything else builds on a worker thread and pops in when ready.
func update_around(p: Vector3) -> void:
	_last_p = p
	var near_now: Array[int] = []
	for i in towns.size():
		var l: Dictionary = towns[i]
		var d := Vector2(p.x - float(l.x), p.z - float(l.z)).length() - float(l.get("radius", 120.0)) * float(l.get("scale", 1.0))
		if d < LOAD and not built.has(i) and not _queue.has(i) and i != _job_index:
			if d < PRIME:
				near_now.append(i)
			_queue.append(i)
		elif d > UNLOAD:
			if built.has(i):
				(built[i] as Node).queue_free()
				built.erase(i)
			_queue.erase(i)
	if not _primed:
		_primed = true
		for i in near_now:
			_queue.erase(i)
			_attach(i, _make(i))

const PRIME := 150.0
var _job := -1             # WorkerThreadPool task id
var _job_index := -1
var _job_result: Node3D

func _process(_dt: float) -> void:
	if _job >= 0:
		if not WorkerThreadPool.is_task_completed(_job):
			return
		_finish_job()
	if not _queue.is_empty():
		_job_index = _queue.pop_front()
		if debug:
			print("town %d queued" % _job_index)
		_job = WorkerThreadPool.add_task(_threaded.bind(_job_index), false, "town build")

## Collects the running build (each task id is waited on exactly once) and attaches it if still wanted.
func _finish_job() -> void:
	WorkerThreadPool.wait_for_task_completion(_job)
	_job = -1
	var i := _job_index
	_job_index = -1
	if _job_result != null:
		if _queue_wanted(i):
			_attach(i, _job_result)
		else:
			_job_result.free()
	_job_result = null

## The player may have walked away while the town was building; only keep it if still in range of a fresh check.
func _queue_wanted(i: int) -> bool:
	return not built.has(i) and _last_pos_ok(i)

var _last_p := Vector3.ZERO
func _last_pos_ok(i: int) -> bool:
	var l: Dictionary = towns[i]
	var d := Vector2(_last_p.x - float(l.x), _last_p.z - float(l.z)).length() - float(l.get("radius", 120.0)) * float(l.get("scale", 1.0))
	return d < UNLOAD

var debug := OS.get_cmdline_user_args().has("--towndebug=1")
func _threaded(i: int) -> void:
	var t := Time.get_ticks_msec()
	_job_result = _make(i)
	if debug:
		print("town %d built in %d ms (thread)" % [i, Time.get_ticks_msec() - t])

## Builds a town's node tree off the scene tree (safe on a worker thread: nothing touches the live tree).
func _make(i: int) -> Node3D:
	var l: Dictionary = towns[i]
	var g := Node3D.new()
	g.name = "town_%d" % i
	g.set_meta("landmark", l)
	var y: float = float(l.base) if l.get("flatten") != null and l.has("base") else zone.height_at(float(l.x), float(l.z))
	g.position = Vector3(float(l.x), y, float(l.z))
	g.rotation.y = float(l.get("rot", 0.0))
	WorldTown.build(g, zone, l)
	return g

func _attach(i: int, g: Node3D) -> void:
	if debug:
		print("town %d attached at frame %d" % [i, Engine.get_process_frames()])
	add_child(g)
	built[i] = g

## Finishes any pending build now (tests, and before the stream is freed).
func flush() -> void:
	while _job >= 0 or not _queue.is_empty():
		if _job >= 0:
			_finish_job()
		_process(0.0)

func _exit_tree() -> void:
	if _job >= 0:
		WorkerThreadPool.wait_for_task_completion(_job)
		_job = -1
		if _job_result != null:
			_job_result.free()
			_job_result = null

func built_count() -> int:
	return built.size()
