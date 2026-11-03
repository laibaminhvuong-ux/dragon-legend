extends TestCase
# User request 2026-11-03: walking, running, slow flight and fast flight each look different.
func _settle(f: Fighter, anim: Dictionary, seconds := 2.0) -> void:
	for i in int(seconds * 60):
		f.update(1.0 / 60.0, anim)

func test_slow_and_fast_flight_use_different_poses() -> void:
	var f := Fighter.create({"race": "Saiyan"})
	_settle(f, {"speed": 6.8, "flying": true, "onGround": false, "sprint": false})
	var cruise := f.anim.mod.fast
	ok(cruise < 0.35, "slow flight stays an upright glide: %.2f" % cruise)
	_settle(f, {"speed": 17.0, "flying": true, "onGround": false, "sprint": true})
	ok(f.anim.mod.fast > 0.9, "fast flight goes horizontal: %.2f" % f.anim.mod.fast)
	f.dispose()

func test_walk_and_run_blend_to_different_clips() -> void:
	var f := Fighter.create({"race": "Saiyan"})
	_settle(f, {"speed": RuleMovement.WALK_SPEED, "onGround": true, "sprint": false}, 1.0)
	var walk: float = f.anim.tree.get("parameters/loco/blend_position")
	ok(walk < 3.0, "walking speed sits on the Walk clip: %.1f" % walk)
	_settle(f, {"speed": 9.0, "onGround": true, "sprint": true}, 1.0)
	var run: float = f.anim.tree.get("parameters/loco/blend_position")
	ok(run > 5.5, "running sits on Jog/Sprint: %.1f" % run)
	f.dispose()
