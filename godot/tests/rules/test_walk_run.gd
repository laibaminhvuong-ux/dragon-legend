extends "res://tests/rules/game_case.gd"
# User request 2026-11-03: hold Shift to go fast; without it you walk / cruise.
func _speed(g: RuleGame) -> float:
	return Vector2(g.player.vel.x, g.player.vel.z).length()

func test_walk_without_shift_run_with_it() -> void:
	var g := fresh()
	tick(g, {"move_z": 1, "sprint": false}, 60)
	near(_speed(g), RuleMovement.WALK_SPEED, 0.05, "walking")
	eq(g.player.sprinting, false)
	tick(g, {"move_z": 1, "sprint": true}, 60)
	near(_speed(g), float(g.player.runSpeed), 0.05, "running")
	eq(g.player.sprinting, true)
	ok(float(g.player.runSpeed) > RuleMovement.WALK_SPEED * 2.5, "running is much faster")

func test_slow_and_fast_flight() -> void:
	var g := fresh()
	tick(g, {"flight": true})
	tick(g, {"move_z": 1, "sprint": false}, 90)
	var cruise := _speed(g)
	near(cruise, float(g.movement.tuning.flightSpeed) * RuleMovement.FLY_CRUISE, 0.1, "cruising")
	tick(g, {"move_z": 1, "sprint": true}, 90)
	near(_speed(g), float(g.movement.tuning.flightSpeed), 0.1, "full speed")

func test_without_the_key_the_old_full_speed_stays() -> void:
	# rules callers that don't send "sprint" (tests, bots, the classic parity traces) keep full speed
	var g := fresh()
	tick(g, {"move_z": 1}, 60)
	near(_speed(g), float(g.player.runSpeed), 0.05)

func test_charging_while_flying_hovers_in_place_and_refills_ki() -> void:
	# User request 2026-11-03: charge while flying.
	var g := fresh()
	tick(g, {"flight": true})
	tick(g, {"ascend": true}, 30)
	g.player.ki = 10.0
	var at: Vector3 = g.player.pos
	tick(g, {"charge": true, "move_z": 1, "ascend": true, "sprint": true}, 90)
	ok(g.player.flying and g.player.charging, "still flying, charging")
	ok(g.player.ki > 10.0, "Ki refills while charging in the air")
	ok(g.player.pos.distance_to(at) < 1.5, "hovers in place while charging (moved %.2f m)" % g.player.pos.distance_to(at))
	tick(g, {"move_z": 1, "sprint": true}, 30)
	ok(not g.player.charging and g.player.pos.distance_to(at) > 2.0, "flies on when you let go")
