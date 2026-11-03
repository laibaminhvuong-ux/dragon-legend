class_name AnimController
extends RefCounted
# Drives a fighter's animation from the JS model contract: update(dt, anim) with
#   anim = { speed, vy, onGround, flying, charging, dashing, blocking, attackSerial, attackKind, kaioken,
#            hurt, dead, talking, sitting, casting }
# An AnimationTree (advanced manually, so it follows the game clock) blends locomotion, air, flight base, talk/
# sit/death; one-shots play attacks and hit reactions (upper body only while moving, so legs keep running); the
# PoseModifier layers flight, power-up, dash, block and kick poses on top. One-shots always end: a timer
# returns the controller to its base state even if a new state cuts in.

const ATTACKS := {"jab": "Punch_Jab", "cross": "Punch_Cross", "hook": "Punch_Enter", "ki": "Spell_Simple_Shoot", "beam": "Spell_Simple_Shoot"}
const KICK_TIME := 0.5
const UPPER := ["DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head", "DEF-shoulder", "DEF-upper_arm", "DEF-forearm", "DEF-hand", "DEF-f_", "DEF-thumb"]

var tree: AnimationTree
var player: AnimationPlayer
var mod: PoseModifier
var state := "ground"         # ground, air, fly, talk, sit, dead
var one_shot := ""            # the attack/hit animation playing, "" when none
var one_shot_left := 0.0
var _serial := 0
var _hurt := false
var _kick_t := -1.0
var _bt: AnimationNodeBlendTree

func _init(f: Fighter) -> void:
	player = f.anim_player
	_bt = AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	for pt: Array in [["Idle", 0.0], ["Walk", 1.8], ["Jog_Fwd", 5.5], ["Sprint", 10.0]]:
		var a := AnimationNodeAnimation.new(); a.animation = pt[0]
		loco.add_blend_point(a, pt[1], -1, pt[0])
	loco.min_space = 0.0; loco.max_space = 12.0
	_bt.add_node("loco", loco, Vector2(0, 0))
	var mode := AnimationNodeTransition.new()
	mode.xfade_time = 0.22
	var inputs := {"ground": "loco", "air": "Jump", "fly": "Idle", "talk": "Idle_Talking", "sit": "Sitting_Idle", "dead": "Death01"}
	var idx := 0
	for st: String in inputs:
		mode.add_input(st)
		if inputs[st] != "loco":
			var a := AnimationNodeAnimation.new(); a.animation = inputs[st]
			_bt.add_node("a_" + st, a, Vector2(0, 100 * idx))
		idx += 1
	_bt.add_node("mode", mode, Vector2(300, 0))
	idx = 0
	for st: String in inputs:
		_bt.connect_node("mode", idx, "loco" if inputs[st] == "loco" else "a_" + st)
		idx += 1
	var shot_pick := AnimationNodeTransition.new()
	shot_pick.xfade_time = 0.0
	var shots := ["Punch_Jab", "Punch_Cross", "Punch_Enter", "Spell_Simple_Shoot", "Hit_Chest", "Hit_Head"]
	for i in shots.size():
		shot_pick.add_input(shots[i])
		var a := AnimationNodeAnimation.new(); a.animation = shots[i]
		_bt.add_node("s_" + shots[i], a, Vector2(300, 200 + 100 * i))
	_bt.add_node("pick", shot_pick, Vector2(500, 200))
	for i in shots.size():
		_bt.connect_node("pick", i, "s_" + shots[i])
	var os := AnimationNodeOneShot.new()
	os.fadein_time = 0.06; os.fadeout_time = 0.18
	for b: String in _upper_tracks(f.skeleton):
		os.set_filter_path(NodePath(b), true)
	_bt.add_node("shot", os, Vector2(700, 0))
	_bt.connect_node("shot", 0, "mode")
	_bt.connect_node("shot", 1, "pick")
	_bt.connect_node("output", 0, "shot")
	tree = AnimationTree.new()
	tree.name = "AnimTree"
	tree.tree_root = _bt
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	f.body.add_child(tree)
	tree.anim_player = tree.get_path_to(f.anim_player)
	tree.root_node = NodePath("..")
	tree.active = true
	tree.set("parameters/mode/transition_request", state)
	tree.set("parameters/pick/transition_request", "Punch_Jab")
	f.anim_player.stop()
	mod = PoseModifier.new()
	mod.name = "Poses"
	f.skeleton.add_child(mod)

static func _upper_tracks(sk: Skeleton3D) -> Array:
	var out := []
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		for u: String in UPPER:
			if n.begins_with(u):
				out.append("Rig/Skeleton3D:" + n)
				break
	return out

func update(dt: float, anim: Dictionary) -> void:
	if dt <= 0.0:
		return
	var flying: bool = anim.get("flying", false)
	var on_ground: bool = anim.get("onGround", true)
	var speed := float(anim.get("speed", 0.0))
	var vy := float(anim.get("vy", 0.0))
	var next := "ground"
	if anim.get("dead", false): next = "dead"
	elif flying: next = "fly"
	elif not on_ground: next = "air"
	elif anim.get("sitting", false): next = "sit"
	elif anim.get("talking", false) and speed < 0.3: next = "talk"
	if next != state:
		state = next
		tree.set("parameters/mode/transition_request", state)
	tree.set("parameters/loco/blend_position", clampf(speed, 0.0, 12.0))
	# one-shots: a new attack serial starts one; getting hurt interrupts with a hit reaction
	var serial := int(anim.get("attackSerial", 0))
	if state != "dead":
		if serial != _serial and serial != 0:
			var kind := str(anim.get("attackKind", "jab"))
			if kind.contains("kick"):
				_kick_t = 0.0
				_end_shot()
			else:
				_play_shot(ATTACKS.get(kind, "Punch_Jab"))
		var hurt: bool = anim.get("hurt", false)
		if hurt and not _hurt:
			_play_shot("Hit_Chest" if randf() < 0.6 else "Hit_Head")
		_hurt = hurt
	_serial = serial
	if one_shot != "":
		one_shot_left -= dt
		if one_shot_left <= 0.0 or state == "dead":
			_end_shot()
	# procedural layers (eased as in the JS model)
	var e := minf(1.0, dt * 8.0)
	var w := mod
	w.fly += ((1.0 if flying else 0.0) - w.fly) * e
	w.charge += ((1.0 if anim.get("charging", false) else 0.0) - w.charge) * e
	w.dash += ((1.0 if anim.get("dashing", false) else 0.0) - w.dash) * e
	w.block += ((1.0 if anim.get("blocking", false) else 0.0) - w.block) * e
	var fly_speed := Vector2(speed, vy * 0.6).length()
	w.fast += (clampf((fly_speed - 2.0) / 8.0, 0.0, 1.0) - w.fast) * minf(1.0, dt * 3.0)
	w.climb += (clampf(vy / 10.0, -1.0, 1.0) - w.climb) * minf(1.0, dt * 3.0)
	if _kick_t >= 0.0:
		_kick_t += dt
		var p := _kick_t / KICK_TIME
		w.kick = clampf(p / 0.3, 0.0, 1.0) if p < 0.6 else clampf((1.0 - p) / 0.4, 0.0, 1.0)
		if p >= 1.0:
			_kick_t = -1.0; w.kick = 0.0
	mod.t += dt
	# the upper-body filter: whole body when standing still on the ground, arms only while moving or flying
	var shot: AnimationNodeOneShot = _bt.get_node("shot")
	shot.filter_enabled = speed > 0.5 or flying or not on_ground
	tree.advance(dt)

func _play_shot(anim_name: String) -> void:
	one_shot = anim_name
	var a := player.get_animation(anim_name) if player.has_animation(anim_name) else null
	one_shot_left = (a.length if a != null else 0.5) + 0.05
	tree.set("parameters/pick/transition_request", anim_name)
	tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _end_shot() -> void:
	if one_shot != "":
		tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	one_shot = ""
	one_shot_left = 0.0

func kicking() -> bool:
	return _kick_t >= 0.0
