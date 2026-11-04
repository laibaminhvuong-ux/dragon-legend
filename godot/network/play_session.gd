class_name CoopPlaySession
extends PlaySession
var connection: CoopClient
var friends: Dictionary = {}
var remote_slot := ""
var send_clock := 0.0
var inputs_pending: Dictionary = {}
func start_online(client: CoopClient,data: Dictionary,gi: GameInput) -> bool:
	connection = client; input = gi; slot_index = client.slot_index; quality = str(Settings.get_value("quality"))
	game = CoopGameMirror.new(-1,RuleSchema.new().normalize(data.slot),Events)
	(game as CoopGameMirror).connection = weakref(client)
	game.combat = CoopGameMirror.CombatMirror.new(game,Events)
	game.kaioken = CoopGameMirror.KaiokenMirror.new(game)
	story = CoopStoryMirror.new(game,Events)
	(story as CoopStoryMirror).connection = weakref(client)
	tutorial = RuleTutorialRules.new(game.slot); tutorial.skip()
	scenes = RuleCutsceneRules.new(game.slot)
	world = WorldView.build_zone(game.zone,quality); add_child(world)
	camera = Camera3D.new(); camera.name = "Camera"; camera.far = 4000; camera.fov = 60; add_child(camera); camera.make_current()
	follow = FollowCamera.new(camera,game.zone,Data.camera)
	_build_player()
	combat_view = load("res://scenes/play/combat_view.gd").new(game.combat,camera); add_child(combat_view)
	story_view = load("res://scenes/play/story_view.gd").new(story,game.combat); add_child(story_view)
	if world.has_meta("grass"): world.get_meta("grass").target = player
	if world.has_meta("stream"): world.get_meta("stream").target = camera
	apply_frame(data)
	prev_pos = game.player.pos
	return true
func apply_frame(data: Dictionary) -> void:
	var authoritative := CoopCodec.entity(data.player)
	authoritative.id = "player"
	var error: float = game.player.pos.distance_to(authoritative.pos)
	var predicted: Vector3 = game.player.pos
	game.player.merge(authoritative,true)
	if error<2 and game.player.health>0: game.player.pos = predicted.lerp(authoritative.pos,0.35)
	game.slot.merge(data.slot,true)
	story.state = game.slot.story
	story.tracked_id = str(story.state.flags.get("trackedQuest",""))
	game.combat.clock = float(data.time)
	(game.combat as CoopGameMirror.CombatMirror).remote = data.combat
	(game.kaioken as CoopGameMirror.KaiokenMirror).remote = data.combat.get("kaioken",{})
	game.combat.enemies.clear()
	for e: Dictionary in data.enemies: game.combat.enemies.append(CoopCodec.entity(e))
	game.combat.projectiles.clear()
	for b: Dictionary in data.projectiles: game.combat.projectiles.append(CoopCodec.entity(b))
	game.entities = [game.player]+game.combat.enemies
	_update_friends(data.get("friends",[]))
	for event: Dictionary in data.get("events",[]):
		# our own host id becomes "player" in id/actor/source/target, so skill effects attach to our own model
		var payload: Dictionary = CoopCodec.localize_event(event.data,str(data.self))
		if event.name in ["notify","dialogue","questAccepted","questCompleted","questProgress","enemyDefeated","levelup","stats","attack","damage","beam","avatarStrike"]:
			Events.emit_named(event.name,payload)
func _update_friends(rows: Array) -> void:
	var seen := {}
	for row: Dictionary in rows:
		seen[row.id] = true
		if not friends.has(row.id):
			var fighter := Fighter.create(row.look)
			add_child(fighter)
			var tag := Label3D.new(); tag.text = row.name; tag.position.y = 2.4; tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; fighter.add_child(tag)
			friends[row.id] = {"fighter":fighter,"state":CoopCodec.entity(row.player),"form":row.form,"signature":JSON.stringify(row.look)}
		var v: Dictionary = friends[row.id]
		if v.signature!=JSON.stringify(row.look):
			v.fighter.dispose(); friends.erase(row.id)
			continue
		v.state = CoopCodec.entity(row.player); v.form = row.form; v.beamCharge = row.get("beamCharge",0); v.aimPitch = row.get("aimPitch",0)
	for id: String in friends.keys():
		if not seen.has(id): friends[id].fighter.dispose(); friends.erase(id)
func step(dt: float) -> void:
	var it: Dictionary = intents() if not is_frozen() else CoopCodec.intents({})
	for key: String in it:
		inputs_pending[key] = bool(inputs_pending.get(key,false)) or bool(it[key]) if key in CoopRoom.EDGE else it[key]
	send_clock += dt
	if send_clock>=1.0/30:
		connection.inputs(inputs_pending); inputs_pending.clear(); send_clock = 0
	prev_pos = game.player.pos
	if not is_frozen() and game.player.health>0:
		game.movement.step(game.player,it,dt,game.zone)
		RuleCollision.resolve(game.player,game.zone,prev_pos)
func render(dt: float,alpha: float) -> void:
	super.render(dt,alpha)
	for v: Dictionary in friends.values():
		var fighter: Fighter = v.fighter
		var p: Dictionary = v.state
		fighter.position = fighter.position.lerp(p.pos,1.0-exp(-dt*14))
		fighter.rotation.y = lerp_angle(fighter.rotation.y,float(p.yaw),1.0-exp(-dt*14))
		fighter.set_form(v.form); fighter.set_terrain(game.zone)
		fighter.update(dt,{"speed":Vector2(p.vel.x,p.vel.z).length(),"vy":p.vel.y,"flying":p.flying,"onGround":p.onGround,"charging":p.charging,"dashing":p.dashing,"blocking":p.blocking,"attackSerial":p.attackSerial,"attackKind":p.attackKind,"kaioken":p.kaioken,"dead":p.health<=0,"sprint":p.get("sprinting",false),"hurt":float(p.get("hurtUntil",0))>game.combat.clock,"beamCharge":v.get("beamCharge",0),"aimPitch":v.get("aimPitch",0)})
func save_now() -> void:
	if connection!=null: connection.save_progress()
