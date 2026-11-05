class_name CoopRoom
extends RefCounted
const LIMIT := 8
const EDGE := ["jump","dash","flight","melee","ki_blast","transform","kaioken","lock_on","interact"]
var saved: Dictionary
var members: Dictionary = {}
var worlds: Dictionary = {}
var time := 0.0
var transfer_serial := 0
var rift_run: RuleRiftPatrol
class Sink extends RefCounted:
	var room: WeakRef
	var member: String
	func _init(r: CoopRoom,id: String) -> void: room = weakref(r); member = id
	func emit_named(event: String,payload: Dictionary = {}) -> void:
		if room.get_ref()!=null: room.get_ref().event(member,event,payload)
class PartyStory extends RefCounted:
	var room: WeakRef
	var member: String
	func _init(r: CoopRoom,id: String) -> void: room = weakref(r); member = id
	func encounters() -> Array:
		var r: CoopRoom = room.get_ref()
		var out := []
		var seen := {}
		if r==null or not r.members.has(member): return out
		for m: Dictionary in r.members.values():
			if not m.active or m.game.zone.id!=r.members[member].game.zone.id: continue
			for e: Dictionary in m.story.encounters():
				if not seen.has(e.key): out.append(e); seen[e.key] = true
		return out
	func enemy_defeated(enemy: String,zone_id: String) -> void:
		var r: CoopRoom = room.get_ref()
		if r==null or not r.members.has(member): return
		if r.rift_run!=null and r.rift_run.active():
			r.rift_run.enemy_defeated(enemy)
			return
		var source: RuleGame = r.members[member].game
		for id: String in r.members:
			var m: Dictionary = r.members[id]
			if not m.active or m.game.zone.id!=zone_id or m.game.player.pos.distance_to(source.player.pos)>90: continue
			m.story.enemy_defeated(enemy,zone_id)
			if id!=member:
				for e: Dictionary in source.combat.enemies:
					if e.key==enemy:
						m.game.add_xp(maxi(10,RuleRuntime.js_round(source.progression.xp_to_next(int(e.level))*source.combat.rpg.RPG.killXp)))
						m.game.add_zeni(e.level*source.combat.rpg.RPG.zeniPerLevel)
						break
func _init(data: Dictionary) -> void: saved = data
func add(identity: String,name: String,fighter_slot: Dictionary) -> Dictionary:
	if rift_run!=null and rift_run.active():return {"error":"A Rift mission is active. Join after the patrol returns."}
	if members.has(identity): return {"error":"This fighter is already connected to this server."}
	if members.size()>=LIMIT: return {"error":"This private server is full (8 players)."}
	# Private friend servers explicitly allow importing the chosen offline fighter.
	# Progress is authoritative only after import; this is not a ranked/anti-cheat economy.
	var imported: Dictionary = RuleSchema.new().normalize(fighter_slot.duplicate(true))
	imported.rift.erase("pending") # A private offline run cannot become a solo encounter inside this room.
	# Arrive with the owner while retaining the chosen fighter's progression.
	if not members.is_empty():
		var owner: RuleGame = members.values()[0].game
		imported.zone = owner.slot.zone
		imported.position = RuleRuntime.position(owner.player.pos+Vector3(2,0,0))
		if owner.zone is RulePlanet: imported.mapSpace = owner.zone.id
		else: imported.erase("mapSpace")
	saved.members[identity] = {"name":name.left(24),"slot":imported}
	var profile: Dictionary = saved.members[identity]
	var sink := Sink.new(self,identity)
	var game := RuleGame.new(-1,RuleSchema.new().normalize(profile.slot),sink)
	game.player.id = "friend:"+identity.left(12)
	var story := RuleStory.new(game,sink)
	var party_story := PartyStory.new(self,identity)
	members[identity] = {"game":game,"story":story,"sink":sink,"party":party_story,"name":profile.name,"input":CoopCodec.intents({}),"events":[],"active":false,"sequence":-1,"zeniRevision":0,"nextZeniAt":0.0}
	attach(identity)
	return {"ok":true,"id":game.player.id}
func attach(identity: String) -> void:
	var m: Dictionary = members[identity]
	var game: RuleGame = m.game
	var map: String = game.zone.id
	if not worlds.has(map):
		worlds[map] = {"enemies":game.combat.enemies,"projectiles":[]}
		for e: Dictionary in game.combat.enemies:
			var old: Dictionary = saved.get("worlds",{}).get(map,{}).get(str(e.id),{})
			if not old.is_empty():
				e.health = clampf(float(old.get("health",e.health)),0,e.maxHealth)
				e.pos = RuleRuntime.vector(old.pos)
				e.deadUntil = game.combat.c.enemyRespawn if e.health<=0 else 0.0
	game.combat.enemies = worlds[map].enemies
	game.combat.projectiles = worlds[map].projectiles
	game.entities = [game.player]+game.combat.enemies
	game.combat.clock = time
	game.combat.party = weakref(self)
	game.combat.set_story(m.party)
func remove(identity: String) -> void:
	if not members.has(identity): return
	if rift_run!=null and rift_run.active():rift_run.finish(false,"A patrol member disconnected.")
	saved.members[identity].slot = members[identity].game.to_save().duplicate(true)
	members.erase(identity)
	saved.members.erase(identity)
func game_for_player(id: String) -> Variant:
	for m: Dictionary in members.values():
		if m.game.player.id==id: return m.game
	return null
func nearest_player(map: String,pos: Vector3,fallback: Dictionary) -> Dictionary:
	var best: Dictionary = fallback
	var distance := INF
	for m: Dictionary in members.values():
		if not m.active or m.game.zone.id!=map or m.game.player.health<=0: continue
		var d: float = pos.distance_squared_to(m.game.player.pos)
		if d<distance: distance = d; best = m.game.player
	return best
func event(identity: String,type: String,payload: Dictionary) -> void:
	if not members.has(identity): return
	if type=="attack" and payload.get("phase","release")=="release": members[identity].visual_kind = members[identity].game.player.attackKind if payload.get("kind")=="melee" else payload.get("kind","ki")
	if type=="travel":
		members[identity].travel = str(payload.get("zone","")); return
	for id: String in members:
		if id!=identity and (type not in ["attack","damage","beam","avatarStrike","riftBossPhase","riftAllyDown","riftMissionFailed"] or members[id].game.zone.id!=members[identity].game.zone.id): continue
		if type in ["riftMissionStarted","riftMissionComplete","riftMissionFailed"]:_private_event(id,type,payload)
		elif members[id].events.size()<96: members[id].events.append({"name":type,"data":CoopCodec.json_value(payload)})
## Room-wide roster includes connected members in other maps and members in menus.
func player_list() -> Array:
	var out := []
	for member: Dictionary in members.values():
		out.append({"id":str(member.game.player.id),"name":str(member.name)})
	return out
func _private_event(identity: String,name: String,payload: Dictionary) -> void:
	# Transfer notices take priority over older presentation events; revision saves do not rely on this queue.
	var queue: Array = members[identity].events
	while queue.size()>=96: queue.pop_front()
	queue.append({"name":name,"data":CoopCodec.json_value(payload)})
func give_zeni(identity: String,target_player_id: String,amount: Variant) -> Variant:
	if not members.has(identity): return "Join a server to send zeni"
	var sender: Dictionary = members[identity]
	if target_player_id==sender.game.player.id: return "Choose another player to send zeni to."
	var target_identity := ""
	for id: String in members:
		if members[id].game.player.id==target_player_id: target_identity = id; break
	if target_identity=="": return "That player is no longer connected to this server."
	var receiver: Dictionary = members[target_identity]
	var staged := RuleZeniTransfer.plan(sender.game.slot.get("zeni"),receiver.game.slot.get("zeni"),amount)
	if not staged.ok: return staged.error
	if time<float(sender.nextZeniAt): return "Wait a second before sending zeni again."
	# Prepare both saved slot copies before touching either balance. No yield or callback in this commit.
	var sender_slot: Dictionary = sender.game.to_save().duplicate(true)
	var receiver_slot: Dictionary = receiver.game.to_save().duplicate(true)
	sender_slot.zeni = staged.sender; receiver_slot.zeni = staged.receiver
	sender.game.slot.zeni = staged.sender; receiver.game.slot.zeni = staged.receiver
	saved.members[identity].slot = sender_slot; saved.members[target_identity].slot = receiver_slot
	sender.zeniRevision += 1; receiver.zeniRevision += 1
	sender.nextZeniAt = time+RuleZeniTransfer.COOLDOWN
	transfer_serial += 1
	var receipt := {"transfer_id":"%s:%d" % [saved.code,transfer_serial],"from_id":str(sender.game.player.id),"to_id":str(receiver.game.player.id),"from_name":str(sender.name),"to_name":str(receiver.name),"amount":staged.amount}
	var number := RuleZeniTransfer.format_amount(int(staged.amount))
	_private_event(identity,"notify",{"text":"Sent %s zeni to %s" % [number,receiver.name]})
	_private_event(target_identity,"notify",{"text":"%s sent you %s zeni" % [sender.name,number]})
	_private_event(identity,"zeniTransfer",receipt)
	_private_event(target_identity,"zeniTransfer",receipt)
	# Stats observers run only after both wallets/saved slots and the private receipts are committed.
	sender.game.emit("stats",sender.game.hud()); receiver.game.emit("stats",receiver.game.hud())
	return null
func input_for(identity: String,raw: Dictionary,sequence: int) -> void:
	if not members.has(identity) or sequence<=members[identity].sequence: return
	var next := CoopCodec.intents(raw)
	for key: String in EDGE: next[key] = next[key] or members[identity].input.get(key,false)
	members[identity].input = next
	members[identity].sequence = sequence
func command(identity: String,name: String,args: Array) -> Variant:
	if not members.has(identity): return "Not connected."
	var m: Dictionary = members[identity]
	var g: RuleGame = m.game
	var story: RuleStory = m.story
	if args.size()>2: return "Invalid command."
	var value: Variant = args[0] if not args.is_empty() else ""
	if rift_run!=null and rift_run.active() and name in ["travel","talk","accept"]:return "Finish or abandon the room Rift mission first."
	match name:
		"enter": m.active = true; return null
		"rift_start":return start_rift(identity,value) if value is String and args.size()==1 else "Invalid Rift mission."
		"rift_hub":return rift_hub(identity)
		"rift_abandon":
			if identity!=members.keys()[0]:return "Only the server owner can end a room mission."
			return rift_run.abandon() if rift_run!=null else "No Rift mission is active."
		"hero_card":
			if args.size()!=2 or not args[0] is String:return "Invalid Hero Card command."
			var card_error: Variant=g.equip_hero_card(args[0],args[1])
			if card_error==null:
				saved.members[identity].slot=g.to_save().duplicate(true);m.zeniRevision+=1
			return card_error
		"give_zeni": return give_zeni(identity,args[0],args[1]) if args.size()==2 and args[0] is String else "Choose a player and a whole zeni amount."
		"set_style": return g.set_style(value) if args.size()==1 and value is String else "Invalid style command."
		"form": return g.select_form(str(value))
		"path": return g.choose_form_path(str(value))
		"appearance":
			if not value is Dictionary: return "Invalid appearance."
			for key: Variant in value:
				if not key is String: return "Invalid appearance."
				if key in ["race","face","hair","build","outfit","accessory","kiColorHex"]:
					if value[key]!=null and not value[key] is String: return "Invalid appearance."
				elif key in ["skin","hairColor","outfitTint","kiColor"]:
					if not (value[key] is int or value[key] is float) or not is_finite(float(value[key])): return "Invalid appearance."
				else: return "Unknown appearance field."
			return g.customize_appearance(value)
		"accessory": return g.equip_accessory(str(value))
		"outfit": return null if g.equip_outfit(str(value)) else "Outfit unavailable."
		"stat": return g.spend_stat_point(str(value),args[1]) if args.size()==2 and (args[1] is int or args[1] is float) else "Invalid stat command."
		"technique": return null if g.combat.set_technique(str(value)) else "Technique unavailable."
		"kaioken_rank": return g.kaioken.select(int(value)) if value is int or value is float else "Invalid intensity."
		"favorite": g.toggle_favorite_form(str(value)); return null
		"accept": return null if story.accept_quest(str(value)) else "Move closer to an available quest giver."
		"abandon": return null if story.abandon_quest(str(value)) else "Quest is not active."
		"track": return null if story.track_quest(str(value)) else "Quest is not active."
		"talk": story.interact(true); return null
		"travel": return null if story.travel_to(str(value)) else "Visit the travel pilot first."
		"buy": return story.buy(str(value))
		"item": return null if story.use_item(str(value)) else "Item cannot be used right now."
	return "Unknown command."
func step(dt: float) -> void:
	time += dt
	var leaders := {}
	for id: String in members:
		var m: Dictionary = members[id]
		m.game.combat.world_authority = false
		if m.active and (not leaders.has(m.game.zone.id) or m.game.player.health>0): leaders[m.game.zone.id] = id
	var order: Array = members.keys().filter(func(id: String) -> bool: return members[id].active and id not in leaders.values())+leaders.values()
	for id: String in order:
		var m: Dictionary = members[id]
		m.game.combat.world_authority = leaders.get(m.game.zone.id)==id
		m.game.combat.clock = time-dt
		m.game.update(dt,m.input)
		m.story.update(dt,m.input)
		for key: String in EDGE: m.input[key] = false
		if m.has("travel"):
			var target: String = m.travel
			m.erase("travel")
			if RuleTables.table("zones").has(target):
				var slot: Dictionary = m.game.to_save()
				slot.zone = target; slot.position = null
				m.game = RuleGame.new(-1,slot,m.sink)
				m.game.player.id = "friend:"+id.left(12)
				m.story = RuleStory.new(m.game,m.sink)
				attach(id)
	if rift_run!=null and rift_run.active():rift_run.update(dt)
func snapshot(identity: String) -> Dictionary:
	var m: Dictionary = members[identity]
	var g: RuleGame = m.game
	var friends := []
	for id: String in members:
		var other: Dictionary = members[id]
		if id!=identity and other.active and other.game.zone.id==g.zone.id:
			var pose: Dictionary = other.game.player.duplicate()
			pose.attackKind = other.get("visual_kind",pose.attackKind)
			friends.append({"beamCharge":other.game.combat.snapshot().beamCharge,"aimPitch":asin(clampf(other.game.combat.aim().dir.y,-1,1)),"id":other.game.player.id,"name":other.name,"look":other.game.slot.appearance.merged({"race":other.game.slot.race},true),"form":other.game.player.form,"player":CoopCodec.json_value(pose)})
	var shots := []
	for b: Dictionary in g.combat.projectiles:
		var shot: Dictionary = b.duplicate(); shot.erase("owner"); shots.append(CoopCodec.json_value(shot))
	var events: Array = m.events.duplicate(); m.events.clear()
	return {"type":"snapshot","code":saved.code,"time":time,"map":g.zone.id,"self":g.player.id,"slot":CoopCodec.json_value(g.to_save()),"player":CoopCodec.json_value(g.player),"enemies":CoopCodec.json_value(g.combat.enemies),"allies":CoopCodec.json_value(g.combat.allies),"rift":CoopCodec.json_value(g.active_rift_mission()),"projectiles":shots,"friends":friends,"players":player_list(),"zeniRevision":int(m.zeniRevision),"combat":CoopCodec.json_value(g.combat.snapshot()),"events":events,"count":members.size()}
func checkpoint() -> Dictionary:
	for id: String in members: saved.members[id].slot = members[id].game.to_save().duplicate(true)
	saved.worlds = {}
	for map: String in worlds:
		saved.worlds[map] = {}
		for e: Dictionary in worlds[map].enemies: saved.worlds[map][str(e.id)] = {"health":e.health,"pos":CoopCodec.json_value(e.pos)}
	return saved

func rift_players() -> Array:
	var out: Array=[]
	for m: Dictionary in members.values():
		if m.active:out.append(m.game)
	return out
func rift_checkpoint() -> void:
	for id: String in members:
		saved.members[id].slot=members[id].game.to_save().duplicate(true)
		members[id].zeniRevision+=1 # Same durable fighter revision as wallet settlements.
func _rift_owner(identity: String) -> Variant:
	if identity!=members.keys()[0]:return "Only the server owner can launch the room patrol."
	if rift_run!=null and rift_run.active():return "A Rift mission is already active."
	for m: Dictionary in members.values():
		if not m.active or m.game.player.health<=0:return "Every connected fighter must be in-game and standing."
		if not m.game.rift.available():return "Every patrol member must finish the adult main story."
	return null
func _rift_rebuild(zone_id: String,pending: String="") -> void:
	for id: String in members:
		var m: Dictionary=members[id]
		var slot: Dictionary=m.game.to_save().duplicate(true)
		slot.zone=zone_id;slot.position=null
		if pending!="":slot.rift.pending=pending
		else:slot.rift.erase("pending")
		m.game=RuleGame.new(-1,slot,m.sink)
		m.game.player.id="friend:"+id.left(12)
		m.story=RuleStory.new(m.game,m.sink)
	# One clean authoritative mission world; old maps keep their own saved ambient state.
	var first: RuleGame=members.values()[0].game
	var previous_world: Dictionary=worlds.get(first.zone.id,{})
	worlds[first.zone.id]={"enemies":first.combat.enemies,"projectiles":[]}
	rift_run=first.rift if pending!="" else null
	if rift_run!=null:
		rift_run.managed=true;rift_run.room=weakref(self)
		if not previous_world.is_empty():rift_run.ambient=previous_world.enemies.duplicate()
	for id: String in members:
		var m: Dictionary=members[id]
		if rift_run!=null:m.game.rift=rift_run;m.game.combat.allies=rift_run.allies
		attach(id)
	if rift_run!=null:
		var bonus:=0.0
		for g: RuleGame in rift_players():bonus+=RuleHeroCards.bonus(g.slot,"ally_health")
		for i: int in rift_run.allies.size():
			var a: Dictionary=rift_run.allies[i]
			a.maxHealth=float(rift_run.mission.allies[i].health)*(1+minf(.09,bonus));a.health=a.maxHealth
func rift_hub(identity: String) -> Variant:
	var error: Variant=_rift_owner(identity)
	if error!=null:return error
	_rift_rebuild("time_nexus")
	for m: Dictionary in members.values():
		m.game.slot.story.flags.riftPatrol=true
		if "time_nexus" not in m.game.slot.story.unlocked:m.game.slot.story.unlocked.append("time_nexus")
	rift_checkpoint()
	return null
func start_rift(identity: String,id: String) -> Variant:
	var error: Variant=_rift_owner(identity)
	if error!=null:return error
	for m: Dictionary in members.values():
		if m.game.current_region()!="time_nexus":return "Bring the patrol to the Time Nexus first."
		if not m.game.rift.unlocked(id):return "That mission is locked for a patrol member."
	var mission: Dictionary=members[identity].game.rift.find(id)
	_rift_rebuild(mission.zone,id)
	return null

func rift_request(player_id: String,name: String,args: Array) -> Variant:
	for id: String in members:
		if members[id].game.player.id==player_id:return command(id,name,args)
	return "This patrol member is no longer connected."
