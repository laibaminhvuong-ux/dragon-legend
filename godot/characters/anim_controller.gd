class_name AnimController
extends RefCounted
# Drives a fighter's animation from the JS model contract: update(dt, anim) with
#   anim = { speed, vy, onGround, flying, charging, dashing, blocking, attackSerial, attackKind, kaioken,
#            hurt, dead, talking, sitting, casting }
# An AnimationTree (advanced manually, so it follows the game clock) blends locomotion, air, flight base, talk/
# sit/death; one-shots play attacks and hit reactions (upper body only while moving, so legs keep running); the
# PoseModifier layers flight, power-up, dash, block and kick poses on top. One-shots always end: a timer
# returns the controller to its base state even if a new state cuts in.

const ATTACKS := {"jab": "Punch_Jab", "cross": "Punch_Cross", "hook": "Punch_Enter", "uppercut": "Punch_Cross", "palm_strike": "Push", "ki": "Spell_Simple_Shoot", "beam": "Spell_Simple_Shoot", "ultimate":"Spell_Simple_Shoot", "utility":"Spell_Simple_Shoot", "avatar":"Spell_Simple_Shoot"}
const KICK_TIME := 0.5
const UPPER := ["DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head", "DEF-shoulder", "DEF-upper_arm", "DEF-forearm", "DEF-hand", "DEF-f_", "DEF-thumb"]

var tree: AnimationTree
var player: AnimationPlayer
var mod: PoseModifier
var state := "ground"         # ground, air, fly, talk, sit, dead
var one_shot := ""            # the attack/hit animation playing, "" when none
var one_shot_left := 0.0
var _skill_serial := -1
var _skill_age := 10.0
var _held := 0.0
var _release_window := 0.45
var _recovery := 0.45
var _serial := 0
var _hurt := false
var _reaction_serial := 0
var _kick_t := -1.0
var form_id := ""
var style: Dictionary = MotionStyle.for_form("")
var _age := 10.0
var _kind := ""
var _speed := 0.0
var _yaw: Variant = null
var _ground := true
var _vy := 0.0
var _transform := 10.0
var _bt: AnimationNodeBlendTree
# fight flow (2026-11-04): style move clips crossfade through two alternating slots; visual lunge and hit-stop
var _f: Fighter
var current_move := ""
var _move_slot := "b"
var _move_t := 0.0
var _move_clip: Animation
var _lunge := 0.0
var _hitstop := 0.0
var _hitstop_serial := 0
var _style := ""

func _init(f: Fighter) -> void:
	player = f.anim_player
	_f = f
	if not player.has_animation_library("moves"):
		player.add_animation_library("moves", FightStyles.library(f))
	_bt = AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	for pt: Array in [["Idle", 0.0], ["Walk", 1.8], ["Jog_Fwd", 5.5], ["Sprint", 10.0]]:
		var a := AnimationNodeAnimation.new(); a.animation = pt[0]
		loco.add_blend_point(a, pt[1], -1, pt[0])
	loco.min_space = 0.0; loco.max_space = 12.0
	_bt.add_node("loco", loco, Vector2(0, 0))
	_bt.add_node("stride",AnimationNodeTimeScale.new(),Vector2(150,0))
	_bt.connect_node("stride",0,"loco")
	var mode := AnimationNodeTransition.new()
	mode.xfade_time = 0.22
	var inputs := {"ground": "loco", "air": "Jump", "fly": "Idle", "talk": "Idle_Talking", "sit": "Sitting_Idle", "dead": "Death01", "cast":"Spell_Simple_Idle",
		"stance": "moves/turtle_stance"}
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
		_bt.connect_node("mode", idx, "stride" if inputs[st] == "loco" else "a_" + st)
		idx += 1
	var shot_pick := AnimationNodeTransition.new()
	shot_pick.xfade_time = 0.1   # one strike flows into the next instead of snapping
	var shots := ["Punch_Jab", "Punch_Cross", "Punch_Enter", "Push", "Spell_Simple_Shoot", "Hit_Chest", "Hit_Head"]
	if player.has_animation("Jump_Land"): shots.append("Jump_Land")
	for i in shots.size():
		shot_pick.add_input(shots[i])
		var a := AnimationNodeAnimation.new(); a.animation = shots[i]
		_bt.add_node("s_" + shots[i], a, Vector2(300, 200 + 100 * i))
	_bt.add_node("pick", shot_pick, Vector2(500, 200))
	for i in shots.size():
		_bt.connect_node("pick", i, "s_" + shots[i])
	var os := AnimationNodeOneShot.new()
	os.fadein_time = 0.1; os.fadeout_time = 0.22
	for b: String in _upper_tracks(f.skeleton):
		os.set_filter_path(NodePath(b), true)
	_bt.add_node("shot", os, Vector2(700, 0))
	_bt.connect_node("shot", 0, "mode")
	_bt.connect_node("shot", 1, "pick")
	# style moves and reactions: a top-level layer that crossfades from whatever is playing into the move, between
	# two alternating move slots (so a chained strike blends from the previous one), and back out when it ends
	var act := AnimationNodeTransition.new()
	act.xfade_time = 0.12
	act.add_input("base")
	for slot: String in ["a", "b"]:
		act.add_input("move_" + slot)
		var m := AnimationNodeAnimation.new(); m.animation = "moves/turtle_combo1"
		_bt.add_node("m_" + slot, m, Vector2(700, 300 + (100 if slot == "b" else 0)))
	_bt.add_node("act", act, Vector2(900, 0))
	_bt.connect_node("act", 0, "shot")
	_bt.connect_node("act", 1, "m_a")
	_bt.connect_node("act", 2, "m_b")
	_bt.connect_node("output", 0, "act")
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
	var flying: bool = anim.get("flying", false) and not anim.get("dead",false)
	var on_ground: bool = anim.get("onGround", true)
	var speed := maxf(0.0,float(anim.get("speed", 0.0)))
	var vy := float(anim.get("vy", 0.0))
	_age += dt
	_transform += dt
	mod.landing = maxf(0.0,mod.landing-dt*3.5)
	mod.takeoff = maxf(0.0,mod.takeoff-dt*4.0)
	if on_ground and not _ground and not flying:
		mod.landing = clampf(absf(_vy)/14.0,0.18,0.85)
		if speed<3 and one_shot=="" and _kick_t<0 and player.has_animation("Jump_Land"):
			_play_shot("Jump_Land")
	if (not on_ground and _ground) or (flying and state!="fly"):
		mod.takeoff = 1.0
	_ground = on_ground
	_vy = vy
	var acceleration := (speed-_speed)/maxf(dt,0.001)
	_speed = lerpf(_speed,speed,1.0-exp(-dt*12.0))
	var yaw := float(anim.get("yaw",0.0))
	var turn: float = wrapf(yaw-float(_yaw),-PI,PI)/maxf(dt,0.001) if _yaw!=null else 0.0
	_yaw = yaw
	mod.lean = lerpf(mod.lean,clampf(turn*speed*0.012,-0.25,0.25),1.0-exp(-dt*9.0))
	mod.brake = lerpf(mod.brake,clampf(-acceleration*0.008,0.0,0.23),1.0-exp(-dt*8.0))
	mod.surge_weight = sin(clampf(_transform/0.65,0,1)*PI) if _transform<0.65 else 0.0
	mod.style = style
	mod.idle = 1.0 if speed<0.5 and on_ground and not flying and not anim.get("dead",false) else 0.0
	mod.dash_side = float(anim.get("dashSide",0))
	mod.dash_back = float(anim.get("dashBack",0))
	mod.aim_pitch = lerpf(mod.aim_pitch,clampf(float(anim.get("aimPitch",0)),-0.9,0.9),1.0-exp(-dt*14))
	var generic_cast := 0.0 if SkillPoses.has_pose(str(anim.get("skillHoldPose",""))) else clampf(float(anim.get("beamCharge",0)),0,1)
	mod.cast = lerpf(mod.cast,generic_cast,1.0-exp(-dt*14))
	mod.heavy_hit = lerpf(mod.heavy_hit,0.0,1.0-exp(-dt*7))
	var next := "ground"
	if anim.get("dead", false): next = "dead"
	elif flying: next = "fly"
	elif not on_ground: next = "air"
	elif anim.get("sitting", false): next = "sit"
	elif float(anim.get("beamCharge",0))>0.05 and speed<0.5 and not SkillPoses.has_pose(str(anim.get("skillHoldPose",""))): next = "cast"
	elif anim.get("talking", false) and speed < 0.3: next = "talk"
	elif anim.get("inCombat", false) and speed < 0.5: next = "stance"
	var style := str(anim.get("style", ""))
	if style != "" and style != _style and FightStyles.IDS.has(style):
		_style = style
		(_bt.get_node("a_stance") as AnimationNodeAnimation).animation = "moves/%s_stance" % style
	if next != state:
		state = next
		tree.set("parameters/mode/transition_request", state)
	tree.set("parameters/loco/blend_position", clampf(speed, 0.0, 12.0))
	var expected_speed := 1.8 if speed<3 else 5.5 if speed<8 else 10.0
	tree.set("parameters/stride/scale",clampf(speed/expected_speed,0.65,1.6) if speed>0.5 else 1.0)
	var air: AnimationNodeAnimation = _bt.get_node("a_air")
	air.animation = "Jump_Start" if vy>1 and player.has_animation("Jump_Start") else "Jump"
	# one-shots: a new attack serial starts one; getting hurt interrupts with a hit reaction
	var serial := int(anim.get("attackSerial", 0))
	if state != "dead":
		if serial != _serial and serial != 0:
			var kind := str(anim.get("attackKind", "jab"))
			_age = 0.0
			_kind = kind
			mod.finisher = 1.25 if anim.get("finisher", false) else 1.0
			if style != "" and not SkillPoses.has_pose(str(anim.get("skillReleasePose", ""))) and kind not in ["ki", "beam", "ultimate", "utility", "avatar"]:
				_play_move(FightStyles.move_for(style, str(anim.get("move", "")), int(anim.get("comboStep", 1))))
				_kind = ""   # the clip carries the whole motion; no procedural strike layer on top
			elif kind.contains("kick") or kind == "knee":
				_kick_t = 0.0   # leg strikes are procedural (PoseModifier: front kick, knee, spin kick, axe kick)
				_end_shot()
			elif SkillPoses.has_pose(str(anim.get("skillReleasePose", ""))):
				_end_shot()   # the skill's own release pose (SkillPoses) replaces the generic spell clip
			else:
				_play_shot(ATTACKS.get(kind, "Punch_Jab"))
		var hurt: bool = anim.get("hurt", false)
		var reaction_serial := int(anim.get("reactionSerial",0))
		if hurt and (not _hurt or reaction_serial!=_reaction_serial):
			var reaction := str(anim.get("reaction", ""))
			if reaction in ["stagger", "knockback", "launch"]:
				_play_move("react_" + reaction)
			else:
				_play_shot("Hit_Head" if absf(float(anim.get("hitSide",0)))>0.5 else "Hit_Chest")
			mod.heavy_hit = clampf(float(anim.get("hitWeight",0.4)),0.15,1.0)
			mod.hit_side = clampf(float(anim.get("hitSide",0)),-1,1)
			_age = 10.0
			_kick_t = -1.0
			mod.kick = 0.0
		_hurt = hurt
		_reaction_serial = reaction_serial
	_serial = serial
	if one_shot != "":
		one_shot_left -= dt
		if one_shot_left <= 0.0 or state == "dead":
			_end_shot()
	# procedural layers (eased as in the JS model)
	if state=="dead":
		_kick_t = -1.0
		mod.kick = 0.0
		mod.heavy_hit = 0.0
		mod.cast = 0.0
		mod.surge_weight = 0.0
		_age = 10.0
	mod.strike = MotionStyle.strike(_age,0.38 if _kind=="jab" else 0.5) if _age<0.5 else 0.0
	# skill poses: hold while the technique is gathered, then the release pose for ~0.8 s after it fires
	var hold_pose := str(anim.get("skillHoldPose", ""))
	if hold_pose != "":
		mod.skill_hold_pose = hold_pose
	mod.skill_hold = lerpf(mod.skill_hold, clampf(float(anim.get("skillHold", 0.0)), 0.0, 1.0) if hold_pose != "" and state != "dead" else 0.0, 1.0 - exp(-dt * 10.0))
	# Codex's catalogue timings (visual only): the gather shows for at least hold_min even on a quick tap, the release
	# pose holds for release_window, then eases out over recovery.
	if hold_pose != "":
		_held += dt
	var release_pose := str(anim.get("skillReleasePose", ""))
	if release_pose != "" and serial != _skill_serial:
		_skill_serial = serial
		mod.skill_release_pose = release_pose
		_release_window = float(anim.get("skillReleaseWindow", 0.45))
		_recovery = maxf(0.1, float(anim.get("skillRecovery", 0.45)))
		_skill_age = -maxf(0.0, float(anim.get("skillHoldMin", 0.0)) - _held)
		if _skill_age < 0.0:
			mod.skill_hold_pose = str(anim.get("skillHoldPoseOf", release_pose))
	if hold_pose == "" and _skill_age >= 0.0:
		_held = 0.0
	_skill_age += dt
	if _skill_age < 0.0 and state != "dead":
		mod.skill_hold = 1.0   # still showing the gather of a quick tap
	var target := 0.0
	if mod.skill_release_pose != "" and state != "dead" and _skill_age >= 0.0:
		target = clampf(_skill_age / 0.08, 0.0, 1.0) * (1.0 - clampf((_skill_age - _release_window) / _recovery, 0.0, 1.0))
	mod.skill_release = target
	mod.strike_kind = _kind
	var e := 1.0-exp(-dt*8.0)
	var w := mod
	w.fly += ((1.0 if flying else 0.0) - w.fly) * e
	w.charge += ((1.0 if anim.get("charging", false) and state!="dead" else 0.0) - w.charge) * e
	w.dash += ((1.0 if anim.get("dashing", false) and state!="dead" else 0.0) - w.dash) * e
	w.block += ((1.0 if anim.get("blocking", false) and state!="dead" else 0.0) - w.block) * e
	var fly_speed := Vector2(speed, vy * 0.6).length()
	# slow cruise (no Shift) keeps an upright, lightly leaning glide; only fast flight goes fully horizontal
	var fast_target := clampf((fly_speed - 2.0) / 8.0, 0.0, 1.0) * (1.0 if anim.get("sprint", true) else 0.3)
	w.fast += (fast_target - w.fast) * minf(1.0, dt * 3.0)
	w.climb += (clampf(vy / 10.0, -1.0, 1.0) - w.climb) * minf(1.0, dt * 3.0)
	if _kick_t >= 0.0:
		_kick_t += dt
		var p := _kick_t / KICK_TIME
		w.kick = clampf(p / 0.3, 0.0, 1.0) if p < 0.6 else clampf((1.0 - p) / 0.4, 0.0, 1.0)
		w.kick_phase = clampf(p, 0.0, 1.0)
		if p >= 1.0:
			_kick_t = -1.0; w.kick = 0.0
	mod.t += dt
	# the upper-body filter: whole body when standing still on the ground, arms only while moving or flying
	var shot: AnimationNodeOneShot = _bt.get_node("shot")
	shot.filter_enabled = (speed > 0.5 or flying or not on_ground) and current_move == ""
	# hit-stop: a short freeze of this fighter's animation on impact (visual only; the game keeps running)
	var hs_serial := int(anim.get("hitstopSerial", 0))
	if hs_serial != _hitstop_serial:
		_hitstop_serial = hs_serial
		_hitstop = clampf(float(anim.get("hitstop", 0.0)), 0.0, 0.2)
	var adv := dt
	if _hitstop > 0.0:
		_hitstop -= dt
		adv = 0.0
	# visual lunge: the body travels with the move's root motion, then eases back onto the fighter's real spot
	if current_move != "":
		_move_t += adv
		_lunge = MoveClips.lunge_at(_move_clip, _move_t)
		if _move_t >= _move_clip.length - 0.12 or state == "dead":
			current_move = ""   # crossfade back to movement over the clip's last frames
			tree.set("parameters/act/transition_request", "base")
	else:
		_lunge = lerpf(_lunge, 0.0, 1.0 - exp(-dt * 7.0))
	_f.body.position = Vector3(0, 0, _lunge)
	tree.advance(adv)

func _play_shot(anim_name: String) -> void:
	one_shot = anim_name
	var a := player.get_animation(anim_name) if player.has_animation(anim_name) else null
	one_shot_left = (a.length if a != null else 0.5) + 0.05
	tree.set("parameters/pick/transition_request", anim_name)
	tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

## Seconds into the current move clip (frozen during hit-stop).
func move_time() -> float:
	return _move_t

## Plays a clip from the "moves" library (style strikes, reactions); chains crossfade from whatever is playing.
func _play_move(id: String) -> void:
	var clip := player.get_animation("moves/" + id) if player.has_animation("moves/" + id) else null
	if clip == null:
		return
	_move_slot = "a" if _move_slot == "b" else "b"
	(_bt.get_node("m_" + _move_slot) as AnimationNodeAnimation).animation = "moves/" + id
	current_move = id
	_move_clip = clip
	_move_t = 0.0
	_end_shot()
	tree.set("parameters/act/transition_request", "move_" + _move_slot)

func _end_shot() -> void:
	if one_shot != "":
		tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	one_shot = ""
	one_shot_left = 0.0

func kicking() -> bool:
	return _kick_t >= 0.0

func set_form(id: String) -> void:
	form_id = id
	style = MotionStyle.for_form(id)
	_transform = 0.0
