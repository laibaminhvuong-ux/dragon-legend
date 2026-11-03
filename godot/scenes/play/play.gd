class_name PlaySession
extends Node3D
# One play session in one world (port of the "play" scene in web/src/main.js): a RuleGame + RuleStory stepped at
# 1/60 s from the player's input, and views that only read rule state: the world, the player's fighter, enemies,
# NPCs, the follow camera. Travel saves and asks main to rebuild the session in the other world.

signal travel_requested(zone_id: String)
signal quit_requested

const AUTOSAVE_SECONDS := 60.0
var slot_index := 0
var game: RuleGame
var story: RuleStory
var tutorial: RuleTutorialRules
var scenes: RuleCutsceneRules
var input: GameInput
var world: Node3D
var player: Fighter
var camera: Camera3D
var follow: FollowCamera
var combat_view: Node3D
var story_view: Node3D
var paused := false
var frozen_by: Array[String] = []   # "dialogue", "cutscene", "menu": anything that stops the simulation
var prev_pos := Vector3.ZERO
var save_timer := 0.0
var pending_travel := ""
var quality := "medium"
var forced: Dictionary = {}       # intents merged over the input's (tests, touch controls)
var _look_key := ""
var _last_form := "?"

## Builds the session from a save slot. Returns false when the slot is empty/invalid.
func start(index: int, gi: GameInput, q := "medium") -> bool:
	var slot: Variant = SaveStore.load_slot(index)
	if not (slot is Dictionary):
		return false
	if Data.camera.is_empty():
		Data.load_dir("res://data")   # headless tools/tests start before the autoload's _ready
	slot_index = index
	input = gi
	quality = q
	game = RuleGame.new(index, slot, Events)
	story = RuleStory.new(game, Events)
	tutorial = RuleTutorialRules.new(game.slot)
	scenes = RuleCutsceneRules.new(game.slot)
	Events.travel.connect(_on_travel)
	world = WorldView.build(str(game.zone.id), quality)
	add_child(world)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.far = 4000.0
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	follow = FollowCamera.new(camera, game.zone, Data.camera)
	follow.set_yaw(float(game.player.yaw))
	_build_player()
	prev_pos = game.player.pos
	var cv: GDScript = load("res://scenes/play/combat_view.gd") if ResourceLoader.exists("res://scenes/play/combat_view.gd") else null
	if cv != null:
		combat_view = cv.new(game.combat, camera)
		add_child(combat_view)
	var sv: GDScript = load("res://scenes/play/story_view.gd") if ResourceLoader.exists("res://scenes/play/story_view.gd") else null
	if sv != null:
		story_view = sv.new(story, game.combat)
		add_child(story_view)
	var grass: Node = world.get_meta("grass") if world.has_meta("grass") else null
	if grass != null:
		grass.set("target", player)
	return true

func _build_player() -> void:
	if player != null:
		player.dispose()
	var look: Dictionary = (game.slot.appearance as Dictionary).duplicate()
	look["race"] = game.slot.race
	player = Fighter.create(look)
	player.name = "Player"
	add_child(player)
	_look_key = _look_signature()
	_last_form = "?"

func _look_signature() -> String:
	var a: Dictionary = (game.slot.appearance as Dictionary).duplicate()
	a.erase("kiColor"); a.erase("kiColorHex")
	return JSON.stringify(a) + str(game.slot.race)

func _on_travel(zone: String) -> void:
	pending_travel = zone

func is_frozen() -> bool:
	return paused or not frozen_by.is_empty()

func freeze(reason: String, on: bool) -> void:
	if on and reason not in frozen_by:
		frozen_by.append(reason)
	elif not on:
		frozen_by.erase(reason)

## The intents for one step from the player's input (port of the JS play update).
func intents() -> Dictionary:
	var it := RuleGame.empty_intents()
	var mv := input.move_axis()
	var yaw := follow.yaw
	it.move_x = sin(yaw) * mv.y - cos(yaw) * mv.x
	it.move_z = cos(yaw) * mv.y + sin(yaw) * mv.x
	for a: String in ["jump", "dash", "flight", "melee", "ki_blast", "transform", "kaioken", "lock_on", "interact"]:
		it[a] = input.pressed(a)
	for a: String in ["ascend", "descend", "charge", "block", "beam"]:
		it[a] = input.down(a)
	if game.player.flying and mv.y > 0:
		var tilt := float(Data.camera.pitch) - follow.pitch
		var dead := 0.1
		var v := signf(tilt) * maxf(0.0, absf(tilt) - dead) / 0.55
		it.fly_pitch = clampf(v, -1.0, 1.0) * mv.y
	it.melee = input.down("melee") or it.melee
	for k: String in forced:
		it[k] = forced[k]
	return it

## One fixed 1/60 s simulation step.
func step(dt: float) -> void:
	if is_frozen():
		return
	var it := intents()
	prev_pos = game.player.pos
	game.update(dt, it)
	story.update(dt, it)
	if tutorial.update(dt, it, game.player) != null:
		save_now()
	_after_step(it)
	if pending_travel != "":
		var z := pending_travel
		pending_travel = ""
		travel(z)
		return
	save_timer += dt
	if save_timer >= AUTOSAVE_SECONDS:
		save_timer = 0.0
		save_now()

## Hook for cutscene/tutorial wiring (Task 6).
func _after_step(_it: Dictionary) -> void:
	pass

func save_now() -> void:
	if game != null:
		SaveStore.save_slot(slot_index, game.to_save())

## Saves with the destination world and asks main to rebuild play there.
func travel(zone_id: String) -> void:
	var slot := game.to_save()
	slot["zone"] = zone_id
	slot["position"] = null
	SaveStore.save_slot(slot_index, slot)
	travel_requested.emit(zone_id)

## Per frame: interpolate, animate, move the camera.
func render(frame_dt: float, alpha: float) -> void:
	if game == null:
		return
	var p: Dictionary = game.player
	var ra := 1.0 if is_frozen() else alpha
	var pos: Vector3 = prev_pos.lerp(p.pos, ra)
	var frozen := is_frozen()
	var anim_dt := frame_dt if (frozen_by.has("cutscene") or not frozen) else 0.0
	var look := input.take_look(frame_dt)
	if not frozen:
		follow.add_look(look)
		tutorial.look(absf(look.x) + absf(look.y))
	if _look_signature() != _look_key:
		_build_player()
	player.visible = float(p.health) > 0.0
	player.position = pos
	player.rotation.y = float(p.yaw)
	if _last_form != str(p.form):
		_last_form = str(p.form)
		player.set_form(_last_form)
	var vel: Vector3 = p.vel
	player.update(anim_dt, {"speed": Vector2(vel.x, vel.z).length(), "vy": vel.y, "onGround": p.onGround, "flying": p.flying,
		"charging": p.charging, "kaioken": p.kaioken, "dashing": p.dashing, "blocking": p.blocking,
		"attackSerial": p.attackSerial, "attackKind": p.attackKind, "hurt": float(p.get("hurtUntil", 0.0)) > float(game.combat.get("clock")) if game.combat.get("clock") != null else false})
	var target: Variant = null
	for e: Dictionary in game.combat.enemies:
		if e.id == p.lockTarget and float(e.health) > 0.0:
			target = e.pos
	var scale := float(Data.forms.get(str(p.form), {}).get("size", 1.0)) if str(p.form) != "" else 1.0
	if bool(game.combat.avatar_state().get("active", false)):
		scale = maxf(scale, float(Data.avatar.get("cameraScale", 1.0)))
	follow.update(pos, 0.0 if frozen else frame_dt, target, scale)
	if combat_view != null:
		combat_view.call("update_view", anim_dt)
	if story_view != null:
		story_view.call("update_view", anim_dt, pos)

func shutdown() -> void:
	if Events.travel.is_connected(_on_travel):
		Events.travel.disconnect(_on_travel)
	if player != null:
		player.dispose()
		player = null
	game = null
	story = null
