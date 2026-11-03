extends TestCase
# Stage 6 Task 3: the animation controller follows the anim contract and never gets stuck in a one-shot.

const DT := 1.0 / 60.0

func _run(f: Fighter, a: Dictionary, seconds: float) -> void:
	for i in int(seconds / DT):
		f.update(DT, a)

func test_states_follow_the_rules() -> void:
	var f := Fighter.create({"race": "Human"})
	_run(f, {}, 0.3)
	eq(String(f.anim.tree.get("parameters/mode/current_state")), "ground", "the tree starts on the ground state")
	_run(f, {"speed": 6.0, "onGround": true}, 0.2)
	eq(f.anim.state, "ground", "running")
	_run(f, {"onGround": false, "vy": 3.0}, 0.2)
	eq(f.anim.state, "air", "jumping")
	_run(f, {"flying": true, "onGround": false, "speed": 12.0}, 1.0)
	eq(f.anim.state, "fly", "flying")
	ok(f.anim.mod.fly > 0.95 and f.anim.mod.fast > 0.6, "full-speed flight pose (fly %.2f fast %.2f)" % [f.anim.mod.fly, f.anim.mod.fast])
	_run(f, {"onGround": true}, 1.0)
	eq(f.anim.state, "ground", "landed")
	ok(f.anim.mod.fly < 0.01, "flight pose eased out")
	_run(f, {"talking": true}, 0.1)
	eq(f.anim.state, "talk", "NPC talking")
	_run(f, {"dead": true, "flying": true}, 0.1)
	eq(f.anim.state, "dead", "death overrides flight")
	f.free()

func test_attacks_play_and_end() -> void:
	var f := Fighter.create({"race": "Saiyan"})
	_run(f, {}, 0.1)
	_run(f, {"attackSerial": 1, "attackKind": "jab"}, DT)
	eq(f.anim.one_shot, "Punch_Jab", "jab plays")
	_run(f, {"attackSerial": 1, "attackKind": "jab"}, 0.4)
	eq(f.anim.one_shot, "Punch_Jab", "the same serial does not restart it")
	_run(f, {"attackSerial": 2, "attackKind": "cross"}, DT)
	eq(f.anim.one_shot, "Punch_Cross", "a new serial cuts in")
	_run(f, {"attackSerial": 2}, 1.2)
	eq(f.anim.one_shot, "", "the cross ends by itself")
	_run(f, {"attackSerial": 3, "attackKind": "leg kick"}, DT)
	ok(f.anim.kicking(), "leg kick is procedural")
	_run(f, {"attackSerial": 3}, AnimController.KICK_TIME + 0.05)
	ok(not f.anim.kicking() and f.anim.mod.kick == 0.0, "kick ends")
	f.free()

func test_edge_cases() -> void:
	var f := Fighter.create({"race": "Saiyan"})
	# attack while flying: the punch plays on the upper body, the flight pose stays
	_run(f, {"flying": true, "onGround": false, "speed": 10.0}, 0.5)
	_run(f, {"flying": true, "onGround": false, "speed": 10.0, "attackSerial": 1, "attackKind": "cross"}, DT)
	eq(f.anim.state, "fly", "still flying")
	eq(f.anim.one_shot, "Punch_Cross", "punching in the air")
	ok((f.anim._bt.get_node("shot") as AnimationNodeOneShot).filter_enabled, "arms only while flying")
	# landing mid-punch: the state changes, the punch still finishes
	_run(f, {"onGround": true, "attackSerial": 1}, DT * 3)
	eq(f.anim.state, "ground", "landed")
	_run(f, {"onGround": true, "attackSerial": 1}, 1.2)
	eq(f.anim.one_shot, "", "the punch finished after landing")
	# charge while moving: both layers
	_run(f, {"onGround": true, "speed": 5.0, "charging": true}, 1.0)
	ok(f.anim.mod.charge > 0.95, "power-up pose while moving")
	# hurt interrupts, death clears the one-shot
	_run(f, {"attackSerial": 2, "attackKind": "jab"}, DT)
	_run(f, {"attackSerial": 2, "hurt": true}, DT)
	ok(f.anim.one_shot.begins_with("Hit_"), "a hit reaction cuts the jab")
	_run(f, {"attackSerial": 2, "dead": true}, DT)
	eq(f.anim.one_shot, "", "death clears the one-shot")
	f.free()

func test_never_stuck_in_a_one_shot() -> void:
	var f := Fighter.create({"race": "Human"})
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var serial := 0
	var kinds := ["jab", "cross", "hook", "leg kick", "ki", "beam", "weird"]
	for i in 1500:
		if rng.randf() < 0.08: serial += 1
		f.update(DT, {"speed": rng.randf() * 12.0, "vy": rng.randf_range(-10, 10), "onGround": rng.randf() < 0.5,
			"flying": rng.randf() < 0.3, "charging": rng.randf() < 0.2, "dashing": rng.randf() < 0.1, "blocking": rng.randf() < 0.1,
			"attackSerial": serial, "attackKind": kinds[rng.randi() % kinds.size()], "hurt": rng.randf() < 0.05})
	_run(f, {"attackSerial": serial}, 2.0)
	eq(f.anim.one_shot, "", "no one-shot left playing")
	ok(not f.anim.kicking(), "no kick left playing")
	eq(f.anim.state, "ground", "back on the ground")
	f.free()
