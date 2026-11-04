extends TestCase
# Mouse-wheel zoom (user request, 2026-11-04): the follow camera moves in and out, eases, stays in range.

class Flat extends RefCounted:
	func height_at(_x: float, _z: float) -> float:
		return 0.0

func _cam() -> FollowCamera:
	var c := Camera3D.new()
	return FollowCamera.new(c, Flat.new(), Fighter.Tables().camera if not Fighter.Tables().camera.is_empty() else {"pitch": 0.25, "minPitch": -0.6,
		"maxPitch": 1.2, "distance": 6, "height": 1.6, "followRate": 18, "clearance": 0.4, "lockHeight": 1.1, "lockTurnRate": 8,
		"lockDistanceScale": 0.55, "maxLockDistance": 12})

func _dist(f: FollowCamera) -> float:
	for i in 120:
		f.update(Vector3.ZERO, 1.0 / 60.0)
	return f.cam.position.distance_to(Vector3(0, float(f.C.height), 0))

func test_wheel_zooms_in_and_out() -> void:
	var f := _cam()
	var base := _dist(f)
	f.add_zoom(-3)
	var closer := _dist(f)
	ok(closer < base * 0.85, "wheel up moves closer (%.2f -> %.2f)" % [base, closer])
	f.add_zoom(6)
	ok(_dist(f) > base * 1.15, "wheel down moves away")
	f.cam.free()

func test_zoom_is_clamped() -> void:
	var f := _cam()
	f.add_zoom(-100)
	near(f.zoom_target, FollowCamera.ZOOM_MIN, 1e-6, "can't zoom into the head")
	f.add_zoom(200)
	near(f.zoom_target, FollowCamera.ZOOM_MAX, 1e-6, "can't zoom out forever")
	f.cam.free()

func test_zoom_eases() -> void:
	var f := _cam()
	f.update(Vector3.ZERO, 1.0 / 60.0)
	f.add_zoom(-4)
	f.update(Vector3.ZERO, 1.0 / 60.0)
	ok(f.zoom > f.zoom_target + 0.05, "eases toward the target instead of jumping")
	f.cam.free()
