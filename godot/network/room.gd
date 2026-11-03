class_name CoopRoom
extends RefCounted
const LIMIT := 8
const EDGE := ["jump","dash","flight","melee","ki_blast","transform","kaioken","lock_on","interact"]
var saved: Dictionary
var members: Dictionary = {}
var worlds: Dictionary = {}
var time := 0.0
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
	if members.has(identity): return {"error":"This fighter is already connected to this server."}
	if members.size()>=LIMIT: return {"error":"This private server is full (8 players)."}
	# Private friend servers explicitly allow importing the chosen offline fighter.
	# Progress is authoritative only after import; this is not a ranked/anti-cheat economy.
	var imported: Dictionary = RuleSchema.new().normalize(fighter_slot.duplicate(true))
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
	members[identity] = {"game":game,"story":story,"sink":sink,"party":party_story,"name":profile.name,"input":CoopCodec.intents({}),"events":[],"active":false,"sequence":-1}
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
	if type=="attack": members[identity].visual_kind = members[identity].game.player.attackKind if payload.get("kind")=="melee" else payload.get("kind","ki")
	if type=="travel":
		members[identity].travel = str(payload.get("zone","")); return
	for id: String in members:
		if id!=identity and (type not in ["attack","damage","beam","avatarStrike"] or members[id].game.zone.id!=members[identity].game.zone.id): continue
		if members[id].events.size()<96: members[id].events.append({"name":type,"data":CoopCodec.json_value(payload)})
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
	match name:
		"enter": m.active = true; return null
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
	return {"type":"snapshot","code":saved.code,"time":time,"map":g.zone.id,"self":g.player.id,"slot":CoopCodec.json_value(g.to_save()),"player":CoopCodec.json_value(g.player),"enemies":CoopCodec.json_value(g.combat.enemies),"projectiles":shots,"friends":friends,"combat":CoopCodec.json_value(g.combat.snapshot()),"events":events,"count":members.size()}
func checkpoint() -> Dictionary:
	for id: String in members: saved.members[id].slot = members[id].game.to_save().duplicate(true)
	saved.worlds = {}
	for map: String in worlds:
		saved.worlds[map] = {}
		for e: Dictionary in worlds[map].enemies: saved.worlds[map][str(e.id)] = {"health":e.health,"pos":CoopCodec.json_value(e.pos)}
	return saved
