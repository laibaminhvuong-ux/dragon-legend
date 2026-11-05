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
# mouse-wheel zoom (multiplies the follow distance), eased toward the target
const ZOOM_MIN := 0.35
const ZOOM_MAX := 2.6
const ZOOM_STEP := 0.88
var zoom := 1.0
## Interiors and walk-in buildings keep the camera close (metres); INF elsewhere.
var max_distance := INF
## Interiors: the camera stays inside this world-space rectangle (x, z, width, depth); empty = no limit.
var bounds := Rect2()
## Inside a walk-in building: its frame {x, z, rot, hw, hd} (RuleTown); the camera stays inside its walls.
var room: Dictionary = {}
var zoom_target := 1.0

func _init(camera: Camera3D, z: RefCounted, cfg: Dictionary) -> void:
	cam = camera
	zone = z
	C = cfg
	pitch = float(C.get("pitch", 0.25))
	if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root.has_node("Settings"):
		zoom = clampf(float(Settings.get_value("cameraZoom")), ZOOM_MIN, ZOOM_MAX)
		zoom_target = zoom

## Wheel steps: negative = closer, positive = further.
func add_zoom(steps: float) -> void:
	if is_finite(steps):
		zoom_target = clampf(zoom_target * pow(ZOOM_STEP, -steps), ZOOM_MIN, ZOOM_MAX)

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
	zoom = lerpf(zoom, zoom_target, _blend(frame_dt, 12.0))
	var look := Vector3(target.x, target.y + float(C.height) * scale, target.z)
	var distance := float(C.distance) * scale * zoom
	if lock_target is Vector3:
		var lt: Vector3 = lock_target
		var dx := lt.x - target.x
		var dz := lt.z - target.z
		if Vector2(dx, dz).length() > 0.001:
			var angle := atan2(dx, dz)
			var delta := atan2(sin(angle - yaw), cos(angle - yaw))
			yaw += delta * _blend(frame_dt, float(C.lockTurnRate))
		distance = minf(float(C.maxLockDistance) * scale, float(C.distance) * scale + Vector2(dx, dz).length() * float(C.lockDistanceScale)) * zoom
		look = look.lerp(Vector3(lt.x, lt.y + float(C.lockHeight), lt.z), 0.5)
	distance = minf(distance, max_distance)
	var cp := cos(pitch)
	var want := Vector3(target.x - sin(yaw) * cp * distance, target.y + float(C.height) * scale + sin(pitch) * distance, target.z - cos(yaw) * cp * distance)
	want.y = maxf(want.y, _ground(want.x, want.z) + float(C.clearance))
	if zone.has_method("ceiling") and is_finite(float(zone.ceiling())):   # interiors: stay under the ceiling
		want.y = minf(want.y, float(zone.ceiling()) + 1.6)
	want = _blocked(look, want)
	if not room.is_empty():
		var r := float(room.rot); var cs := cos(r); var sn := sin(r)
		var dx := want.x - float(room.x); var dz := want.z - float(room.z)
		var lx := clampf(dx * cs - dz * sn, -float(room.hw) + 0.6, float(room.hw) - 0.6)
		var lz := clampf(dx * sn + dz * cs, -float(room.hd) + 0.6, float(room.hd) - 0.6)
		want.x = float(room.x) + lx * cs + lz * sn
		want.z = float(room.z) - lx * sn + lz * cs
		want.y = minf(want.y, float(room.get("ceil", want.y)))
	if bounds.has_area():
		want.x = clampf(want.x, bounds.position.x, bounds.end.x)
		want.z = clampf(want.z, bounds.position.y, bounds.end.y)
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

## Walls between the player and the camera (oriented-box colliders): the camera stops just in front of them, so
## you see your fighter inside a building instead of the outside of its wall.
func _blocked(look: Vector3, want: Vector3) -> Vector3:
	if not zone.has_method("props"):
		return want
	var a := Vector2(look.x, look.z); var b := Vector2(want.x, want.z)
	var seg := b - a
	var length := seg.length()
	if length < 0.01:
		return want
	var mid := (a + b) * 0.5
	var best := 1.0
	for c: Dictionary in zone.props().near(mid.x, mid.y, length * 0.5 + 1.0):
		if not c.has("hw") or float(c.top) < minf(look.y, want.y):
			continue
		var r := float(c.rot); var cs := cos(r); var sn := sin(r)
		var o := a - Vector2(float(c.x), float(c.z))
		var lo := Vector2(o.x * cs - o.y * sn, o.x * sn + o.y * cs)
		var ld := Vector2(seg.x * cs - seg.y * sn, seg.x * sn + seg.y * cs)
		var ex := float(c.hw) + 0.2; var ez := float(c.hd) + 0.2
		var t0 := 0.0; var t1 := 1.0
		var hit := true
		for axis in 2:
			var p := lo.x if axis == 0 else lo.y
			var dd := ld.x if axis == 0 else ld.y
			var e := ex if axis == 0 else ez
			if absf(dd) < 1e-6:
				if absf(p) > e:
					hit = false
					break
				continue
			var ta := (-e - p) / dd; var tb := (e - p) / dd
			t0 = maxf(t0, minf(ta, tb)); t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				hit = false
				break
		if hit and t0 > 0.0 and t0 < best:
			best = t0
	if best >= 1.0:
		return want
	var t := maxf(0.08, best - 0.3 / length)
	return look.lerp(want, t)
