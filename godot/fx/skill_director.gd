class_name SkillDirector
extends Node3D
## Scene integration supplies actor/socket resolution. Events never produce gameplay hits.
var resolve_actor: Callable
var audio: CombatAudio
var effects: Array[SkillEffect] = []
var charging: Dictionary = {}
var shots: Dictionary = {}
var seen: Dictionary = {}
var latest: Dictionary = {}
var closed: Dictionary = {}
var quality := "medium"
var paused := false
var local_actor := "player"
var _bus: Object
var _connections: Dictionary = {}
var ghost_factory: Callable
func bind(bus: Object,resolver: Callable,tier: String = "medium") -> void:
	unbind()
	resolve_actor = resolver; quality = tier
	if audio==null: audio = CombatAudio.new(); add_child(audio)
	_bus = bus
	for event: String in ["attack","beam","damage","avatarStrike"]:
		var signal_name: String = "avatar_strike" if event=="avatarStrike" else event
		if bus!=null and bus.has_signal(signal_name):
			var callback := func(packet: Dictionary) -> void: handle_event(event,packet)
			bus.connect(signal_name,callback); _connections[signal_name] = callback
func actor_key(packet: Dictionary) -> String:
	return str(packet.get("actor_id",packet.get("id","player")))
func socket_position(packet: Dictionary) -> Vector3:
	var offset := Vector3.ZERO
	if packet.get("phase")=="prepare":
		var values: Array = SkillCatalog.get_skill(str(packet.get("move_id",""))).get("gather_offset",[0,0,0])
		offset = Vector3(float(values[0]),float(values[1]),float(values[2]))
	var actor: Variant = resolve_actor.call(actor_key(packet)) if resolve_actor.is_valid() else null
	if is_instance_valid(actor) and actor.has_method("socket"):
		var pose: Transform3D = actor.socket(str(packet.get("socket","cast_origin")))
		return pose.origin+offset
	return RuleRuntime.vector(packet.get("origin",packet.get("pos",Vector3.ZERO)))+offset
func spawn_effect(profile: Dictionary,packet: Dictionary,phase: String,pos: Vector3) -> SkillEffect:
	var budget := SkillCatalog.budget(quality)
	if effects.size()>=int(budget.effects): remove_effect(effects[0])
	var effect := SkillEffect.new(); add_child(effect)
	effect.position = to_local(pos) if is_inside_tree() else pos
	effect.setup(profile,packet,phase,int(budget.segments)); effects.append(effect)
	return effect
func remove_effect(effect: SkillEffect) -> void:
	if not is_instance_valid(effect): return
	for key: Variant in charging.keys():
		if charging[key]==effect:
			charging.erase(key)
			if audio!=null: audio.stop_loop(str(key))
	for key: Variant in shots.keys():
		if shots[key]==effect: shots.erase(key)
	effects.erase(effect); effect.queue_free()
func handle_event(name: String,packet: Dictionary) -> void:
	if name not in ["attack","beam","damage","avatarStrike"]: return
	var event_id := str(packet.get("event_id",""))
	if event_id!="":
		if seen.has(event_id): return
		seen[event_id] = true
		if seen.size()>512: seen.erase(seen.keys()[0])
	var id := str(packet.get("move_id","Melee" if name=="damage" else "EnergyWave"))
	var profile := SkillCatalog.get_skill(id)
	if profile.is_empty(): return
	var phase := str(packet.get("phase","impact" if name=="damage" else "release"))
	# Kaioken is a simultaneous overlay; it cannot close an independently held technique.
	if id=="Kaioken":
		if phase=="release":
			var overlay_pos := socket_position(packet)
			spawn_effect(profile,packet,"release",overlay_pos)
			if audio!=null: audio.play_skill(id,"release",overlay_pos,int(packet.get("seed",0)))
		return
	var key := actor_key(packet)
	var sequence := int(packet.get("action_sequence",0))
	if phase=="prepare" and sequence<=int(closed.get(key,-1)): return
	if phase in ["prepare","release","cancel","recovery"]:
		if sequence<int(latest.get(key,-1)): return
		latest[key] = sequence
	if phase in ["release","cancel","recovery"]: closed[key] = maxi(sequence,int(closed.get(key,-1)))
	if phase in ["cancel","recovery"]:
		if charging.has(key) and int(charging[key].packet.get("action_sequence",0))<=sequence: remove_effect(charging[key])
		return
	if phase=="prepare":
		if charging.has(key):
			if int(charging[key].packet.get("action_sequence",0))>=sequence: return
			remove_effect(charging[key])
		charging[key] = spawn_effect(profile,packet,"prepare",socket_position(packet))
		if audio!=null: audio.start_loop(key,profile.phases.prepare.audio,socket_position(packet),int(packet.get("seed",0)))
		return
	if phase=="release" and charging.has(key) and int(charging[key].packet.get("action_sequence",0))<=sequence:
		var gather: SkillEffect = charging[key]
		var remaining := maxf(0,float(profile.get("hold_min",0))-gather.age)
		if remaining>0:
			charging.erase(key)
			if audio!=null: audio.stop_loop(key)
			gather.sustained = false; gather.duration = gather.age+remaining
		else: remove_effect(gather)
	var pos := socket_position(packet)
	if phase=="release" and name=="attack" and profile.has("layers"):
		spawn_effect(profile,packet,"recoil",pos)
		if profile.delivery=="projectile": spawn_effect(profile,packet,"release",pos)
	if name in ["damage","avatarStrike"] or phase=="impact": pos = RuleRuntime.vector(packet.get("pos",pos))
	if id=="InstantTransmission" and phase=="impact": pos += Vector3.UP*1.1
	# Instant rays draw once on the beam event; their attack event provides pose/audio only.
	if name=="beam" and profile.geometry in ["spirit","eclipse","heavy_orb","destruction"]:
		spawn_effect(profile,packet,"impact",RuleRuntime.vector(packet.get("to",pos)))
	if name=="beam" or name in ["damage","avatarStrike"] or profile.delivery=="utility" or profile.delivery=="contact":
		spawn_effect(profile,packet,"impact" if name=="damage" else "release",pos)
	if profile.geometry=="afterimage" and name=="attack" and ghost_factory.is_valid():
		var ghost: Variant = ghost_factory.call(key,SkillCatalog.color(packet,profile))
		if ghost is Node3D:
			var carrier := spawn_effect(profile,packet,"release",pos)
			carrier.add_child(ghost)
	if audio!=null and name!="beam":
		if name=="damage" and packet.get("blocked",false): audio.play_cue("guard",pos,1,int(packet.get("seed",0)))
		else:
			audio.play_skill(id,"impact" if name in ["damage","avatarStrike"] or phase=="impact" else "release",pos,int(packet.get("seed",0)))
			if name=="damage" and packet.get("finisher",false): audio.play_cue("impact_heavy",pos,1.4,int(packet.get("seed",0)))
func update_actor_states(states: Array) -> void:
	var live := {}
	for actor: Dictionary in states:
		var state: Dictionary = actor.get("skillState",{})
		if state.get("phase")!="prepare": continue
		var key := actor_key(state); live[key] = true
		if not charging.has(key) or int(charging[key].packet.get("action_sequence",0))!=int(state.get("action_sequence",0)) or charging[key].packet.get("move_id")!=state.get("move_id"): handle_event("attack",state)
		if charging.has(key):
			charging[key].packet = state.duplicate(true)
			charging[key].strength = float(state.get("charge",0))
	for key: String in charging.keys():
		if not live.has(key): remove_effect(charging[key])
func sync_projectiles(rows: Array) -> void:
	var live := {}
	for row: Dictionary in rows:
		var key := str(row.id); live[key] = true
		if not shots.has(key):
			var packet: Dictionary = row.get("presentation",{}).duplicate(true)
			packet.color = row.get("color",0x66ccff)
			shots[key] = spawn_effect(SkillCatalog.get_skill(str(row.get("move_id","KiBlast"))),packet,"projectile",RuleRuntime.vector(row.pos))
		shots[key].position = to_local(RuleRuntime.vector(row.pos)) if is_inside_tree() else RuleRuntime.vector(row.pos)
		var direction: Vector3 = RuleRuntime.vector(row.get("dir",row.get("presentation",{}).get("direction",Vector3.FORWARD)))
		if direction.length_squared()>.0001: shots[key].quaternion = Quaternion(Vector3.BACK,direction.normalized())
	for key: String in shots.keys():
		if not live.has(key): remove_effect(shots[key])
func cancel_actor(id: String) -> void:
	for effect in effects.duplicate():
		if actor_key(effect.packet)==id: remove_effect(effect)
func set_paused(value: bool) -> void:
	paused = value
	if audio!=null: audio.set_paused(value)
func clear() -> void:
	for effect in effects.duplicate(): remove_effect(effect)
	if audio!=null: audio.stop_all()
	seen.clear(); latest.clear(); closed.clear()
func _process(dt: float) -> void:
	if paused: return
	for effect in effects.duplicate():
		if not effect.advance(dt): remove_effect(effect)
	for key: String in charging:
		var effect: SkillEffect = charging[key]
		var pos := socket_position(effect.packet)
		effect.position = to_local(pos)
		if audio!=null: audio.update_loop(key,pos,.3+effect.strength*.7)
func unbind() -> void:
	if is_instance_valid(_bus):
		for key: String in _connections:
			if _bus.is_connected(key,_connections[key]): _bus.disconnect(key,_connections[key])
	_connections.clear(); _bus = null
func _exit_tree() -> void:
	unbind()
