class_name FollowCamera
extends RefCounted
# Third-person orbit camera (port of web/src/render/camera.js): follows the player's interpolated feet, turns
# towards a lock-on target, pulls back for big forms, and never dips under the terrain.

var cam: Camera3D
var zone: RefCounted
var yaw := PI
var pitch := 0.25        # + = above, looking down
var C: Dictionary
var _pos := Vector3.ZERO
var _first := true
var _last_scale := 1.0

func _init(camera: Camera3D, z: RefCounted, cfg: Dictionary) -> void:
	cam = camera
	zone = z
	C = cfg
	pitch = float(C.get("pitch", 0.25))

func add_look(d: Vector2) -> void:
	yaw -= d.x if is_finite(d.x) else 0.0
	pitch = clampf(pitch + (d.y if is_finite(d.y) else 0.0), float(C.minPitch), float(C.maxPitch))

func set_yaw(y: float) -> void:
	if is_finite(y):
		yaw = y

static func _blend(dt: float, rate: float) -> float:
	return 1.0 - exp(-maxf(0.0, dt) * rate)

func _ground(x: float, z: float) -> float:
	var h: float = zone.height_at(x, z)
	return h if is_finite(h) else -1e9

## target = interpolated feet; lock_target = an enemy's feet or null; scale = form size.
func update(target: Vector3, frame_dt: float, lock_target: Variant = null, scale := 1.0) -> void:
	scale = maxf(1.0, scale) if is_finite(scale) else 1.0
	if scale != _last_scale:
		_first = true
		_last_scale = scale
	var look := Vector3(target.x, target.y + float(C.height) * scale, target.z)
	var distance := float(C.distance) * scale
	if lock_target is Vector3:
		var lt: Vector3 = lock_target
		var dx := lt.x - target.x
		var dz := lt.z - target.z
		if Vector2(dx, dz).length() > 0.001:
			var angle := atan2(dx, dz)
			var delta := atan2(sin(angle - yaw), cos(angle - yaw))
			yaw += delta * _blend(frame_dt, float(C.lockTurnRate))
		distance = minf(float(C.maxLockDistance) * scale, float(C.distance) * scale + Vector2(dx, dz).length() * float(C.lockDistanceScale))
		look = look.lerp(Vector3(lt.x, lt.y + float(C.lockHeight), lt.z), 0.5)
	var cp := cos(pitch)
	var want := Vector3(target.x - sin(yaw) * cp * distance, target.y + float(C.height) * scale + sin(pitch) * distance, target.z - cos(yaw) * cp * distance)
	want.y = maxf(want.y, _ground(want.x, want.z) + float(C.clearance))
	if _first:
		_pos = want
		_first = false
	else:
		_pos = _pos.lerp(want, _blend(frame_dt, float(C.followRate)))
	_pos.y = maxf(_pos.y, _ground(_pos.x, _pos.z) + float(C.clearance))
	# the camera's parent sits at the world origin, so local = world (and this works outside the tree)
	cam.position = _pos
	if not _pos.is_equal_approx(look):
		cam.transform = cam.transform.looking_at(look, Vector3.UP)
