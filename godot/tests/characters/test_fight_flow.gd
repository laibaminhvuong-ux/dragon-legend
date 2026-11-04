extends TestCase
# Fight flow (2026-11-04): style clips play, chain with crossfades, stances, hit-stop, lunges, legacy kinds.

const DT := 1.0 / 60.0

func _idle(f: Fighter, frames: int, extra := {}) -> void:
	for i in frames:
		var a := {"speed": 0.0, "onGround": true}
		a.merge(extra, true)
		f.update(DT, a)

func _arm(f: Fighter) -> Quaternion:
	return f.skeleton.get_bone_pose_rotation(f.skeleton.find_bone("DEF-upper_arm.R"))

func test_attack_plays_style_clip() -> void:
	var f := Fighter.create({"race": "Human"})
	_idle(f, 2)
	_idle(f, 3, {"attackSerial": 1, "attackKind": "jab", "style": "brawler", "move": "brawler_hammer_fist", "comboStep": 2})
	eq(f.anim.current_move, "brawler_combo2", "the style's clip plays")
	f.free()

func test_chain_blends_without_pop() -> void:
	# (poses only apply inside a live scene; the crossfade settings and the chain itself are checked here, the motion on the GPU)
	var f := Fighter.create({"race": "Human"})
	_idle(f, 2)
	var seen := false
	for i in 40:
		_idle(f, 1, {"attackSerial": 1 if i < 14 else 2, "attackKind": "jab", "style": "turtle", "comboStep": 1 if i < 14 else 2})
		seen = seen or f.anim.current_move == "turtle_combo2"
	ok(seen, "second hit played")
	ok(float((f.anim._bt.get_node("act") as AnimationNodeTransition).xfade_time) >= 0.08, "strikes crossfade into each other")
	ok(float((f.anim._bt.get_node("pick") as AnimationNodeTransition).xfade_time) >= 0.08, "old clips crossfade too")
	var os: AnimationNodeOneShot = f.anim._bt.get_node("shot")
	ok(os.fadein_time >= 0.08 and os.fadeout_time >= 0.08, "attacks blend in and out of movement")
	f.free()

func test_stance_when_in_combat() -> void:
	var f := Fighter.create({"race": "Human"})
	_idle(f, 4, {"inCombat": true, "style": "crane"})
	eq(f.anim.state, "stance", "guard stance in combat")
	_idle(f, 4, {"inCombat": false})
	eq(f.anim.state, "ground", "relaxed out of combat")
	f.free()

func test_hitstop_freezes_animation_only() -> void:
	var f := Fighter.create({"race": "Human"})
	var hit := {"attackSerial": 1, "attackKind": "jab", "style": "turtle", "comboStep": 2}
	_idle(f, 2)
	_idle(f, 6, hit)
	var stop := hit.duplicate(); stop.hitstop = 0.08; stop.hitstopSerial = 1
	_idle(f, 1, stop)
	var t := f.anim.move_time()
	_idle(f, 2, stop)
	near(f.anim.move_time(), t, 1e-6, "move clock frozen during hit-stop")
	_idle(f, 8, stop)
	ok(f.anim.move_time() > t + 0.05, "moves again after")
	f.free()

func test_lunge_scales_with_fighter() -> void:
	var peaks: Array[float] = []
	for s in [1.0, 2.0]:
		var f := Fighter.create({"race": "Human"})
		f.scale = Vector3.ONE * s
		_idle(f, 2)
		var peak := 0.0
		for i in 30:
			_idle(f, 1, {"attackSerial": 1, "attackKind": "jab", "style": "speedster", "move": "speedster_dash", "comboStep": 1})
			peak = maxf(peak, f.lunge_world())
		peaks.append(peak)
		f.free()
	ok(peaks[0] > 0.5, "dash-in travels (%.2f m)" % peaks[0])
	near(peaks[1], peaks[0] * 2.0, 0.05, "twice as far at twice the size")

func test_lunge_returns_home() -> void:
	var f := Fighter.create({"race": "Human"})
	_idle(f, 2)
	_idle(f, 40, {"attackSerial": 1, "attackKind": "jab", "style": "brawler", "comboStep": 3})
	_idle(f, 60)
	ok(absf(f.lunge_world()) < 0.05, "back on the spot after the move (%.3f)" % f.lunge_world())
	f.free()

func test_reaction_clip() -> void:
	var f := Fighter.create({"race": "Human"})
	_idle(f, 2)
	_idle(f, 2, {"hurt": true, "reactionSerial": 1, "reaction": "knockback", "hitWeight": 0.8})
	eq(f.anim.current_move, "react_knockback", "knockback reaction plays")
	f.free()

func test_legacy_attackKind_still_works() -> void:
	var f := Fighter.create({"race": "Human"})
	_idle(f, 2)
	_idle(f, 2, {"attackSerial": 1, "attackKind": "cross"})
	eq(f.anim.one_shot, "Punch_Cross", "no style → old clip")
	f.free()
