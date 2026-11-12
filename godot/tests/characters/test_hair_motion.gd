extends TestCase
# Hair secondary motion (Hair.Motion + Fighter._secondary_motion): the spring rests when still, trails behind motion,
# springs back (with a little overshoot) when the fighter stops, leans with the wind, is frame-rate independent,
# ignores teleports, and the fighter feeds the hair shaders without breaking when hair motion is off.

func _run(m: Hair.Motion, frames: int, dt: float, pos: Vector3, vel: Vector3, wind := Vector3.ZERO) -> Vector3:
	var p := pos
	for i in frames:
		p += vel * dt
		m.step(dt, p, wind)
	return p

func test_rests_when_still() -> void:
	var m := Hair.Motion.new()
	_run(m, 120, 1.0 / 60.0, Vector3(5, 0, 5), Vector3.ZERO)
	ok(m.offset.length() < 1e-5, "no motion, no wind: rest shape (%s)" % m.offset)

func test_trails_and_springs_back() -> void:
	var m := Hair.Motion.new()
	var p := _run(m, 90, 1.0 / 60.0, Vector3.ZERO, Vector3(0, 0, 8))   # running +z
	ok(m.offset.z < -0.02, "hair trails behind a runner (%s)" % m.offset)
	ok(m.offset.length() <= Hair.Motion.REACH * 1.4 + 1e-6, "bounded")
	var run_off := m.offset.z
	var most_forward := -1.0
	for i in 30:   # stop dead: it swings forward past rest, then settles
		m.step(1.0 / 60.0, p, Vector3.ZERO)
		most_forward = maxf(most_forward, m.offset.z)
	ok(most_forward > 0.0, "overshoots forward when stopping (%s, was %s)" % [most_forward, run_off])
	_run(m, 240, 1.0 / 60.0, p, Vector3.ZERO)
	ok(m.offset.length() < 0.002, "settles back to rest (%s)" % m.offset)

func test_fast_flight_saturates() -> void:
	var a := Hair.Motion.new()
	var b := Hair.Motion.new()
	_run(a, 120, 1.0 / 60.0, Vector3.ZERO, Vector3(10, 0, 0))
	_run(b, 120, 1.0 / 60.0, Vector3.ZERO, Vector3(40, 0, 0))
	ok(absf(b.offset.x) > absf(a.offset.x), "faster = trails further")
	ok(absf(b.offset.x) <= Hair.Motion.REACH + 1e-3, "never past its reach")

func test_jump_and_wind() -> void:
	var m := Hair.Motion.new()
	_run(m, 30, 1.0 / 60.0, Vector3.ZERO, Vector3(0, 9, 0))
	ok(m.offset.y < -0.01, "hair drags down while rising")
	var w := Hair.Motion.new()
	_run(w, 180, 1.0 / 60.0, Vector3.ZERO, Vector3.ZERO, Vector3(6, 0, 0))
	ok(w.offset.x > 0.02, "leans with the wind (%s)" % w.offset)

func test_frame_rate_independent() -> void:
	var a := Hair.Motion.new()
	var b := Hair.Motion.new()
	_run(a, 60, 1.0 / 30.0, Vector3.ZERO, Vector3(0, 0, 8))
	_run(b, 240, 1.0 / 120.0, Vector3.ZERO, Vector3(0, 0, 8))
	ok(a.offset.distance_to(b.offset) < 0.006, "30 vs 120 fps agree (%s vs %s)" % [a.offset, b.offset])

func test_teleport_ignored() -> void:
	var m := Hair.Motion.new()
	m.step(1.0 / 60.0, Vector3.ZERO, Vector3.ZERO)
	m.step(1.0 / 60.0, Vector3(500, 0, 0), Vector3.ZERO)
	_run(m, 5, 1.0 / 60.0, Vector3(500, 0, 0), Vector3.ZERO)
	ok(m.offset.length() < 1e-4, "a respawn jump does not whip the hair")

func test_fighter_drives_hair_shader() -> void:
	var f := Fighter.create({"race": "Saiyan", "hair": "Long", "female": true})
	ok(f.hair != null, "long hair built")
	for i in 40:
		f.position.z += 8.0 / 60.0
		f.update(1.0 / 60.0, {"speed": 8.0, "onGround": true})
	ok(f.hair_motion != null and f.hair_motion.offset.length() > 0.01, "fighter hair trails while it runs")
	var sway: Variant = f.hair.get_instance_shader_parameter("hair_sway")
	ok(sway is Vector4 and (sway as Vector4).length() > 0.01, "hair_sway reaches the shader (%s)" % sway)
	f.free()
