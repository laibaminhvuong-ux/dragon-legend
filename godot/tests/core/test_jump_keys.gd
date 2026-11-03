extends TestCase
# User request 2026-11-03: jumping works while walking (W) and while running (Shift held).
func _key(code: Key, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code; e.physical_keycode = code; e.pressed = true; e.shift_pressed = shift
	return e

func test_space_jumps_while_walking_and_running() -> void:
	Controls.register()
	var gi := GameInput.new()
	gi._input(_key(KEY_SPACE))
	ok(gi.pressed("jump"), "Space alone")
	gi.end_tick()
	gi._input(_key(KEY_W))
	gi._input(_key(KEY_SPACE))
	ok(gi.pressed("jump"), "Space while walking")
	gi.end_tick()
	gi._input(_key(KEY_SPACE, true))
	ok(gi.pressed("jump"), "Space while holding Shift to run")
	gi.free()

func test_jump_from_a_run_in_the_rules() -> void:
	var g := RuleGame.new(0, RuleSchema.new().new_slot(RuleSchema.new().default_look("Saiyan"), 1000))
	g.player.pos = Vector3(0, g.zone.height_at(0, 0), 0); g.player.onGround = true
	for i in 30:
		g.update(1.0 / 60.0, {"move_z": 1, "sprint": true})
	g.update(1.0 / 60.0, {"move_z": 1, "sprint": true, "jump": true})
	ok(g.player.vel.y > 0.0 and not g.player.onGround, "jumps while running")
	ok(Vector2(g.player.vel.x, g.player.vel.z).length() > 5.0, "keeps running speed in the air")
