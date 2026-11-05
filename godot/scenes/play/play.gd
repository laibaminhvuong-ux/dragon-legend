class_name PlaySession
extends Node3D
# One play session in one world (port of the "play" scene in web/src/main.js): a RuleGame + RuleStory stepped at
# 1/60 s from the player's input, and views that only read rule state: the world, the player's fighter, enemies,
# NPCs, the follow camera. Travel saves and asks main to rebuild the session in the other world.

signal travel_requested(zone_id: String)
signal quit_requested
signal tutorial_step_done
signal cutscene_requested(scene: Dictionary)

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
var _music_check := 0.0
var fast_mode := false        # Shift toggles running / fast flight (user request 2026-11-03)
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
	Events.rift_mission_started.connect(_on_rift_started)
	Events.rift_mission_complete.connect(_on_rift_complete)
	Events.rift_mission_failed.connect(_on_rift_failed)
	Events.rift_boss_phase.connect(_on_rift_phase)
	Events.rift_ally_down.connect(_on_rift_ally_down)
	Events.enemy_defeated.connect(_on_enemy_defeated)
	Music.play(game.current_region())
	world = WorldView.build_zone(game.zone, quality)
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
	if world.has_meta("stream"):
		(world.get_meta("stream") as TerrainStream).target = camera
	return true

func _build_player() -> void:
	if player != null:
		player.dispose()
	var look: Dictionary = (game.slot.appearance as Dictionary).duplicate()
	look["race"] = game.slot.race
	if not look.has("faceSeed"):
		look["faceSeed"] = "player:" + str(game.slot.get("name", ""))   # your own face (the creator can reroll it)
	player = Fighter.create(look)
	if str(look.get("race", "")) in ["Saiyan", "HalfSaiyan"]:
		GreatApe.warm()   # Great Ape bodies ready before the first transformation
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
	# Q (user request 2026-11-04): the quick dash on the ground, the rocket boost while flying
	if game.player.flying:
		it.boost = it.dash
		it.dash = false
	for a: String in ["ascend", "descend", "charge", "block", "beam"]:
		it[a] = input.down(a)
	# hold Shift (or push the stick all the way) to run / fly fast; otherwise walk / cruise
	# tap Shift to switch between walking/running (slow/fast flight); gamepad: stick pushed all the way is fast
	if input.take("sprint"):
		fast_mode = not fast_mode
		Events.emit_named("notify", {"text": ("Fast: running / full-speed flight" if fast_mode else "Walking / slow flight") + " (%s to switch)" % UiKit.key_name("sprint")})
	it.sprint = fast_mode or (input.last_device == "gamepad" and mv.length() > 0.9)
	if game.player.flying and mv.y > 0:
		var tilt := float(Data.camera.pitch) - follow.pitch
		var dead := 0.1
		var v := signf(tilt) * maxf(0.0, absf(tilt) - dead) / 0.55
		it.fly_pitch = clampf(v, -1.0, 1.0) * mv.y
	it.melee = input.down("melee") or it.melee
	for k: String in forced:
		it[k] = forced[k]
	forced.erase("boost")   # a press, not a hold (a held boost would toggle off again)
	return it

## One fixed 1/60 s simulation step.
## Dev timing (microseconds summed per section; main prints averages with --shot).
var prof: Dictionary = {}
var prof_frames := 0
func _t(name: String, since: int) -> void:
	prof[name] = int(prof.get(name, 0)) + Time.get_ticks_usec() - since

func step(dt: float) -> void:
	if is_frozen():
		return
	var it := intents()
	prev_pos = game.player.pos
	var t0 := Time.get_ticks_usec()
	game.update(dt, it)
	_t("rules", t0); t0 = Time.get_ticks_usec()
	story.update(dt, it)
	_t("story", t0)
	if tutorial.update(dt, it, game.player) != null:
		tutorial_step_done.emit()
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

## Boss "before" scenes start the first time the player comes near a story boss.
func _after_step(_it: Dictionary) -> void:
	var sc: Variant = scenes.before_for(story.encounters(), game.player.pos)
	if sc is Dictionary:
		cutscene_requested.emit(sc)

func _on_enemy_defeated(d: Dictionary) -> void:
	var enemy := str(d.get("enemy", ""))
	var name_v: Variant = null
	for e: Dictionary in game.combat.enemies:
		if str(e.get("key", "")) == enemy:
			name_v = e.get("name")
	var sc: Variant = scenes.after_for(enemy, name_v)
	if sc is Dictionary:
		cutscene_requested.emit(sc)

## Where a cutscene speaker stands: "you", a boss (combat enemy key) or a story NPC id. {} when unknown.
func actor(speaker: String) -> Dictionary:
	if game == null:
		return {}
	if speaker == "you":
		return {"pos": game.player.pos, "scale": float(Data.forms.get(str(game.player.form), {}).get("size", 1.0)) if str(game.player.form) != "" else 1.0}
	for e: Dictionary in game.combat.enemies:
		if str(e.get("key", "")) == speaker:
			return {"pos": e.pos, "scale": float(e.get("scale", 1.0))}
	for n: Dictionary in story.npcs():
		if str(n.id) == speaker:
			return {"pos": Vector3(float(n.x), float(n.y), float(n.z)), "scale": float(n.get("scale", 1.0))}
	return {}

## Face the boss and stop, as the JS game did when a scene starts.
func face_for_scene(sc: Dictionary) -> void:
	var p: Dictionary = game.player
	p.vel = Vector3.ZERO
	var boss := actor(str(sc.get("enemy", "")))
	if boss.is_empty():
		return
	var bp: Vector3 = boss.pos
	p.yaw = atan2(bp.x - p.pos.x, bp.z - p.pos.z)
	for e: Dictionary in game.combat.enemies:
		if str(e.get("key", "")) == str(sc.get("enemy", "")):
			e.yaw = atan2(p.pos.x - bp.x, p.pos.z - bp.z)

func save_now() -> void:
	if game != null:
		SaveStore.save_slot(slot_index, game.to_save())

## Saves with the destination world and asks main to rebuild play there.
func travel(zone_id: String) -> void:
	if game.zone is RulePlanet and game.zone.has_region(zone_id):   # same planet map: fly there, no loading
		var sp: Dictionary = game.zone.region_spawn(zone_id)
		game.player.pos = Vector3(sp.x, game.zone.height_at(sp.x, sp.z) + 0.2, sp.z)
		game.player.vel = Vector3.ZERO
		prev_pos = game.player.pos
		game.slot.zone = zone_id
		save_now()
		return
	game.leaving_to = zone_id
	var slot := game.to_save()
	SaveStore.save_slot(slot_index, slot)
	travel_requested.emit(zone_id)

# ------------------------------------------------------------------------------------------- Rift Patrol presentation
var _rift_fx: Node3D
var _rift_overlay: CanvasLayer
var _rift_env: Dictionary = {}   # the world's fog before corruption, to restore it
var _rift_amount := 0.0
var _rift_envnode: WorldEnvironment

## Corrupted timeline while a Rift mission is active: purple fog and screen tint, shards drifting round the
## fighter, rift tears in the sky. Eases in and out.
func _rift_view(pos: Vector3, frame_dt: float) -> void:
	var m: Dictionary = game.active_rift_mission() if game.has_method("active_rift_mission") else {}
	var want := 1.0 if m.get("corrupted", false) else 0.0
	_rift_amount = move_toward(_rift_amount, want, frame_dt * 0.6)
	if want == 0.0 and _rift_amount == 0.0 and _rift_fx == null:
		return   # no mission: nothing to do (and no searching the world every frame)
	if _rift_envnode == null:
		for n in world.find_children("*", "WorldEnvironment", true, false):
			_rift_envnode = n
			break
	var env_node: WorldEnvironment = _rift_envnode
	if env_node != null and env_node.environment != null:
		var e := env_node.environment
		if _rift_env.is_empty():
			_rift_env = {"fog": e.fog_enabled, "color": e.fog_light_color, "density": e.fog_density}
		e.fog_enabled = _rift_env.fog or _rift_amount > 0.01
		e.fog_light_color = (_rift_env.color as Color).lerp(Color(0.42, 0.18, 0.62), _rift_amount)
		e.fog_density = lerpf(float(_rift_env.density), maxf(float(_rift_env.density), 0.004), _rift_amount)
	if _rift_amount > 0.01 and _rift_fx == null:
		_rift_fx = _make_rift_fx()
		add_child(_rift_fx)
		_rift_overlay = CanvasLayer.new()
		_rift_overlay.layer = -1
		var tint := ColorRect.new()
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.color = Color(0.35, 0.1, 0.55, 0.0)
		tint.name = "Tint"
		_rift_overlay.add_child(tint)
		add_child(_rift_overlay)
	if _rift_fx != null:
		_rift_fx.visible = _rift_amount > 0.01
		_rift_fx.position = pos
		(_rift_overlay.get_node("Tint") as ColorRect).color.a = 0.12 * _rift_amount
		for c in _rift_fx.get_children():
			if c is Node3D and c.has_meta("orbit"):
				c.rotation.y += frame_dt * float(c.get_meta("orbit"))

func _make_rift_fx() -> Node3D:
	var root := Node3D.new()
	root.name = "RiftCorruption"
	var shard_m := StandardMaterial3D.new()
	shard_m.albedo_color = Color(0.7, 0.5, 1.0); shard_m.emission_enabled = true; shard_m.emission = Color(0.6, 0.3, 1.0)
	shard_m.emission_energy_multiplier = 2.2
	for ring in 3:
		var holder := Node3D.new()
		holder.set_meta("orbit", 0.25 + ring * 0.12)
		root.add_child(holder)
		for i in 10:
			var a := float(i) / 10.0 * TAU + ring
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new(); bm.size = Vector3(0.25, 0.9, 0.25)
			mi.mesh = bm; mi.material_override = shard_m
			mi.position = Vector3(sin(a) * (14.0 + ring * 10.0), 3.0 + ring * 4.0 + float(i % 3) * 2.0, cos(a) * (14.0 + ring * 10.0))
			mi.rotation = Vector3(float(i), float(i) * 0.7, 0.4)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mi)
	# rift tears hanging in the sky
	var tear_m := StandardMaterial3D.new()
	tear_m.albedo_color = Color(0.9, 0.6, 1.0); tear_m.emission_enabled = true; tear_m.emission = Color(0.8, 0.3, 1.0)
	tear_m.emission_energy_multiplier = 3.0; tear_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 5:
		var a := float(i) / 5.0 * TAU + 0.4
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new(); qm.size = Vector2(3.0, 26.0)
		mi.mesh = qm; mi.material_override = tear_m
		mi.position = Vector3(sin(a) * 120.0, 60.0 + float(i % 2) * 20.0, cos(a) * 120.0)
		mi.rotation = Vector3(0, a + PI, 0.5 - float(i) * 0.25)
		root.add_child(mi)
	return root

func _on_rift_started(d: Dictionary) -> void:
	Events.emit_named("notify", {"text": "RIFT MISSION · %s — fix the timeline!" % str(d.get("name", game.active_rift_mission().get("name", "")))})

func _on_rift_complete(d: Dictionary) -> void:
	var r: Dictionary = d.get("rewards", {}) if d.get("rewards") is Dictionary else {}
	var cards: Array = r.get("cards", []) if r.get("cards") is Array else []
	Events.emit_named("notify", {"text": "Mission clear! %s  +%s zeni%s" % [RiftBoard.stars(int(d.get("stars", 1))), str(r.get("zeni", 0)),
		("  · New Hero Card!" if not cards.is_empty() else "")]})
	Burst.spawn(self, game.player.pos + Vector3.UP, Color(1.0, 0.85, 0.4), 4.0)

func _on_rift_failed(d: Dictionary) -> void:
	Events.emit_named("notify", {"text": "Mission failed: %s. Try again from the Mission Board." % str(d.get("reason", "the timeline collapsed"))})

func _on_rift_phase(d: Dictionary) -> void:
	Events.emit_named("notify", {"text": "%s — %s!" % [str(d.get("character", d.get("id", "Boss"))).capitalize(), str(d.get("name", "Phase"))]})
	Burst.spawn(self, RuleRuntime.vector(d.get("pos", game.player.pos)) + Vector3.UP * 1.5, Color(0.7, 0.3, 1.0), 5.0)

func _on_rift_ally_down(d: Dictionary) -> void:
	Events.emit_named("notify", {"text": "%s is down!" % str(d.get("name", "Your ally"))})

var _boost_serial := 0
var _trail_t := 0.0
## Rocket boost: a blast and dust on launch, a glowing trail while boosting, and a wider camera for speed.
func _boost_view(pos: Vector3, frame_dt: float) -> void:
	var p: Dictionary = game.player
	var color := Color.hex((int(RuleRuntime.ki_color(game.slot.appearance)) << 8) | 0xff)
	if int(p.get("boostSerial", 0)) != _boost_serial:
		_boost_serial = int(p.get("boostSerial", 0))
		Burst.spawn(self, pos + Vector3.UP * 0.3, color, 3.0)
		Burst.spawn(self, Vector3(pos.x, game.zone.height_at(pos.x, pos.z) + 0.1, pos.z), Color(0.7, 0.65, 0.55, 0.8), 3.5)
		Events.emit_named("notify", {"text": "Rocket boost! 20 s (%s again to stop)" % UiKit.key_name("dash")})
	var boosting: bool = p.get("boosting", false)
	if boosting:
		_trail_t -= frame_dt
		if _trail_t <= 0.0:
			_trail_t = 0.05
			Burst.spawn(self, pos + Vector3.UP * 0.9, color, 0.7)
	var want_fov := 60.0 + (16.0 if boosting else 0.0)
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-frame_dt * 4.0))

## Walk-in buildings: cut the one you're in away above waist height; interiors keep the camera in the room.
func _building_view(pos: Vector3) -> void:
	WorldTown.ensure_globals()
	var inside: Dictionary = game.zone.inside_building(pos.x, pos.z) if game.zone.has_method("inside_building") else {}
	if inside.is_empty():
		RenderingServer.global_shader_parameter_set(&"inside_building", Vector4.ZERO)
	else:
		RenderingServer.global_shader_parameter_set(&"inside_building", Vector4(float(inside.x), float(inside.z),
			maxf(float(inside.hw), float(inside.hd)) * 1.5 + 1.0, game.zone.height_at(float(inside.x), float(inside.z))))
	follow.room = {}
	if not inside.is_empty():
		var k := 0.78 if inside.get("round", false) else 1.0
		follow.room = {"x": inside.x, "z": inside.z, "rot": inside.rot, "hw": float(inside.hw) * k, "hd": float(inside.hd) * k,
			"ceil": game.zone.height_at(float(inside.x), float(inside.z)) + float(inside.h) - 0.5}
	var interior := str(game.zone.def.get("kind", "")) == "interior"
	follow.max_distance = 6.0 if interior else (5.0 if not inside.is_empty() else INF)
	if interior and not follow.bounds.has_area():
		var d: Dictionary = RuleInterior.dims(RuleInterior.style_of(game.zone.id))
		follow.bounds = Rect2(-float(d.w) * 0.5 + 0.6, -float(d.d) * 0.5 + 0.6, float(d.w) - 1.2, float(d.d) - 1.2)

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
	var wheel := input.take_zoom()
	if not frozen:
		follow.add_look(look)
		if wheel != 0.0:
			follow.add_zoom(wheel)
			Settings.set_value("cameraZoom", follow.zoom_target)
		tutorial.look(absf(look.x) + absf(look.y))
	if _look_signature() != _look_key:
		_build_player()
	prof_frames += 1
	var t1 := Time.get_ticks_usec()
	if world.has_meta("towns"):
		(world.get_meta("towns") as TownStream).update_around(pos)
	_t("town_stream", t1); t1 = Time.get_ticks_usec()
	_building_view(pos)
	_t("building_view", t1); t1 = Time.get_ticks_usec()
	_boost_view(pos, frame_dt)
	_rift_view(pos, frame_dt)
	_t("rift_view", t1); t1 = Time.get_ticks_usec()
	player.visible = float(p.health) > 0.0
	player.position = pos
	player.rotation.y = float(p.yaw)
	if _last_form != str(p.form):
		_last_form = str(p.form)
		player.set_form(_last_form)
	var vel: Vector3 = p.vel
	player.update(anim_dt, {"speed": Vector2(vel.x, vel.z).length(), "vy": vel.y, "onGround": p.onGround, "flying": p.flying, "sprint": p.get("sprinting", true),
		"charging": p.charging, "kaioken": p.kaioken, "dashing": p.dashing, "blocking": p.blocking,
		"boosting": p.get("boosting", false), "boostLaunch": float(p.get("boostLaunch", 0.0)),
		"attackSerial": p.attackSerial, "attackKind": p.attackKind, "hurt": float(p.get("hurtUntil", 0.0)) > float(game.combat.get("clock")) if game.combat.get("clock") != null else false})
	_t("player", t1); t1 = Time.get_ticks_usec()
	var target: Variant = null
	for e: Dictionary in game.combat.enemies:
		if e.id == p.lockTarget and float(e.health) > 0.0:
			target = e.pos
	var scale := float(Data.forms.get(str(p.form), {}).get("size", 1.0)) if str(p.form) != "" else 1.0
	if bool(game.combat.avatar_state().get("active", false)):
		scale = maxf(scale, float(Data.avatar.get("cameraScale", 1.0)))
	follow.update(pos, 0.0 if frozen else frame_dt, target, scale)
	_music_check += frame_dt
	if _music_check > 1.0:
		_music_check = 0.0
		var villain := false
		for n: Dictionary in story.npcs():
			if n.get("boss", false) and Vector2(float(n.x) - pos.x, float(n.z) - pos.z).length() < 45.0:
				villain = true
		Music.play("battle" if villain else game.current_region())
	_t("camera_music", t1); t1 = Time.get_ticks_usec()
	if combat_view != null:
		combat_view.call("update_view", anim_dt)
	_t("combat_view", t1); t1 = Time.get_ticks_usec()
	if story_view != null:
		story_view.call("update_view", anim_dt, pos)
	_t("story_view", t1)

func shutdown() -> void:
	if Events.travel.is_connected(_on_travel):
		Events.travel.disconnect(_on_travel)
	if Events.enemy_defeated.is_connected(_on_enemy_defeated):
		Events.enemy_defeated.disconnect(_on_enemy_defeated)
	if player != null:
		player.dispose()
		player = null
	game = null
	story = null
