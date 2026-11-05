class_name RuleStory
extends RefCounted
const TALK_RANGE := 4.5
const PICKUP_RANGE := 2.6
var _game: WeakRef
var events: Object
var slot: Dictionary
var zone: RuleZone
var player: Dictionary
var state: Dictionary
var quests: Array = RuleTables.table("quests")
var npc_defs: Array = RuleTables.table("npcs")
var characters: Dictionary = RuleTables.table("characters")
var worlds: Dictionary = RuleTables.table("zones")
var narrative: Dictionary = RuleTables.table("narrative")
var quest: Dictionary = {}
var npc: Dictionary = {}
var positions: Dictionary = {}
var tracked_id: String = ""
var guide_pos: Variant = null
var guide_area := ""
var combat_available: bool = RuleTables.table("schema").combat_available
func _init(game: RuleGame,bus: Object = null) -> void:
	_game = weakref(game)
	events = bus if bus!=null else game.events
	slot = game.slot
	zone = game.zone
	player = game.player
	game.schema._ensure_story(slot)
	state = slot.story
	tracked_id = str(state.flags.get("trackedQuest",""))
	for q: Dictionary in quests:
		quest[q.id] = q
	for n: Dictionary in npc_defs:
		npc[n.id] = n
	var start_area: String = str(slot.zone) if zone.has_region(str(slot.zone)) else zone.id
	if start_area not in state.visited:
		state.visited.append(start_area)
	if start_area not in state.unlocked:
		state.unlocked.append(start_area)
	for q: Dictionary in active_quests():
		check_instant(q)
	game.combat.set_story(self)
func game() -> RuleGame:
	return _game.get_ref()
func emit(event: String,payload: Dictionary) -> void:
	RuleRuntime.emit(events,event,payload)
func say(speaker: String,text: String,kind: String,id: String = "") -> void:
	emit("dialogue",{"speaker":speaker,"text":text,"kind":kind,"questId":id})
	emit("notify",{"text":speaker+": "+text})
func is_done(id: String) -> bool:
	var s: Dictionary = slot.quests.get(id,{})
	return s.get("status")=="done" or s.get("completions",0)>0
func is_active(id: String) -> bool:
	return slot.quests.get(id,{}).get("status")=="active"
func visible(n: Dictionary) -> bool:
	if not zone.has_region(n.zone) or (n.has("after") and not is_done(n.after)) or (n.has("before") and is_done(n.before)) or (n.has("flagged") and not state.flags.get(n.flagged,false)):
		return false
	if n.has("afterStep") and not is_done(n.afterStep[0]) and not (is_active(n.afterStep[0]) and slot.quests[n.afterStep[0]].step>=n.afterStep[1]):
		return false
	return true
func npc_pos(n: Dictionary) -> Dictionary:
	if not positions.has(n.id):
		var p: Dictionary = zone.place_in(n.zone,n.x,n.z)
		if n.has("y"):
			p.y = float(n.y)+zone.lift_of(n.zone)
		positions[n.id] = RuleRuntime.position(zone.free_position(p))
	return positions[n.id]
func at(step: Dictionary) -> Dictionary:
	return zone.place_in(step.zone,step.get("x",0),step.get("z",0)) if zone.has_region(str(step.get("zone",""))) else {"x":step.get("x",0),"z":step.get("z",0)}
## The area the player stands in: the loaded area, or on a planet map the area around them.
func here() -> String:
	return game().current_region() if zone is RulePlanet else zone.id
## Only new fighters must finish childhood before the adult campaign.
func is_main(q: Dictionary) -> bool:
	return q.get("main",false) and (not q.get("origins",false) or state.flags.get("originsRequired",false))
func required_after(q: Dictionary) -> Array:
	var required: Array = q.get("after",[]).duplicate()
	if q.id=="m01_arrival" and not state.flags.get("originsRequired",false):
		required.erase("k07_piccor_jr")
	return required
func can_accept(q: Dictionary) -> bool:
	if q.get("legacy",false) or q.get("automatic",false) or is_active(q.id) or (is_done(q.id) and not q.get("repeat",false)) or slot.level<q.get("level",1):
		return false
	if q.has("path") and not game().forms.has_form_path(slot,q.path):
		return false
	if q.has("races") and slot.race not in q.races:
		return false
	for id: String in required_after(q):
		if not is_done(id):
			return false
	return true
func active_quests() -> Array:
	return quests.filter(func(q: Dictionary) -> bool: return is_active(q.id))
func step_of(q: Dictionary) -> Dictionary:
	return q.steps[int(slot.quests[q.id].step)]
func advance(q: Dictionary,quiet: bool = false) -> void:
	var s: Dictionary = slot.quests[q.id]
	s.step += 1
	s.t = 0.0
	s.count = 0
	s.collected = []
	if s.step>=q.steps.size():
		complete(q)
		return
	if not quiet:
		emit("questProgress",{"id":q.id,"objective":step_of(q).text})
	emit("notify",{"text":q.title+": "+step_of(q).text})
	check_instant(q)
func check_instant(q: Dictionary) -> void:
	if not is_active(q.id):
		return
	var s: Dictionary = step_of(q)
	if s.type=="travel" and s.zone not in state.unlocked:
		state.unlocked.append(s.zone)
		emit("notify",{"text":"New world: "+worlds[s.zone].name})
	if (s.type=="level" and slot.level>=s.level) or (s.type=="travel" and here()==s.zone):
		advance(q)
func accept(q: Dictionary) -> void:
	var completions: int = int(slot.quests.get(q.id,{}).get("completions",0))
	slot.quests[q.id] = {"status":"active","step":0,"t":0.0,"count":0,"collected":[],"completions":completions}
	say(characters[npc[q.giver].who].name,q.offer,"offer",q.id)
	emit("questAccepted",{"id":q.id,"title":q.title})
	emit("notify",{"text":"New quest: %s. %s" % [q.title,q.steps[0].text]})
	check_instant(q)
func complete(q: Dictionary) -> void:
	var s: Dictionary = slot.quests[q.id]
	s.status = "repeatable" if q.get("repeat",false) else "done"
	s.completions = s.get("completions",0)+1
	var final_npc: String = q.steps.back().npc if q.get("dragonHunt",false) else q.giver
	say(characters[npc[final_npc].who].name,q.done,"done",q.id)
	var r: Dictionary = q.get("rewards",{})
	var xp: Variant = r.get("xp",0)
	if xp is String:
		xp = game().progression.xp_for_levels(int(slot.level),float(xp.substr(7))) if xp.begins_with("levels:") else maxf(40,RuleRuntime.js_round(game().progression.xp_to_next(int(slot.level))*float(xp.substr(6))))
	if r.get("zeni",0)!=0:
		game().add_zeni(r.zeni)
	slot.statPoints += r.get("statPoints",0)
	if r.get("restore",false):
		player.health = player.maxHealth
		player.ki = player.maxKi
	for id: String in r.get("moves",[]):
		var move: Dictionary = RuleTables.table("moves")[id]
		if id not in slot.moves and (move.get("races")==null or slot.race in move.races):
			slot.moves.append(id)
	for id: String in r.get("forms",[]):
		if game().forms.form_for_race(id,slot.race) and id not in slot.forms:
			slot.forms.append(id)
	for id: String in r.get("outfits",[]):
		if id not in slot.outfits:
			slot.outfits.append(id)
	for id: String in r.get("unlock",[]):
		if id not in state.unlocked:
			state.unlocked.append(id)
	for id: String in r.get("items",{}):
		state.items[id] = state.items.get(id,0)+r.items[id]
	emit("questCompleted",{"id":q.id,"title":q.title})
	emit("notify",{"text":"Quest complete: %s (+%s XP)" % [q.title,xp]})
	if xp:
		game().add_xp(xp)
	else:
		emit("stats",game().hud())
	for a: Dictionary in active_quests():
		check_instant(a)
func quest_place(q: Dictionary) -> Variant:
	if not is_active(q.id):
		return npc.get(q.giver,{}).get("zone")
	var s: Dictionary = step_of(q)
	return npc.get(s.npc,{}).get("zone") if s.type=="talk" else s.get("zone")
func story_quests() -> Array:
	return quests.filter(func(q: Dictionary) -> bool: return is_main(q) and not q.get("legacy",false) and not q.get("automatic",false) and (is_active(q.id) or can_accept(q)))
func tasks_here() -> Array:
	return story_quests().filter(func(q: Dictionary) -> bool: return quest_place(q)==here()).map(func(q: Dictionary) -> String: return q.title)
func travel_options() -> Array:
	if game().rift!=null and game().rift.active():return []
	if not tasks_here().is_empty():
		return []
	var next: Array = []
	for q: Dictionary in story_quests():
		var z: Variant = quest_place(q)
		if z!=null and z!=here() and z not in next:
			next.append(z)
	for q: Dictionary in quests:
		if not is_main(q) or q.get("legacy",false) or q.get("automatic",false) or is_done(q.id) or is_active(q.id):
			continue
		if q.has("races") and slot.race not in q.races:
			continue
		if q.has("path") and not game().forms.has_form_path(slot,q.path):
			continue
		var after_done: bool = true
		for id: String in required_after(q):
			after_done = after_done and is_done(id)
		if not after_done:
			continue
		var z: Variant = npc.get(q.giver,{}).get("zone")
		if z!=null and z!=here() and z not in next:
			next.append(z)
		break
	var out: Array = []
	var order: Array = next.duplicate()
	for z: String in state.unlocked:
		if z not in order:
			order.append(z)
	for z: String in order:
		if z==here() or z==zone.id or z=="test" or not worlds.has(z):
			continue
		var need: int = travel_level(z)
		out.append({"zone":z,"story":z in next,"name":worlds[z].name,"planet":worlds[z].planet,"level":need,"locked":int(slot.level)<need})
	return out
func travel_guide() -> Variant:
	if travel_options().is_empty():
		return null
	if guide_pos==null or guide_area!=here():
		guide_area = here()
		var tp_v: Variant = zone.region_travel_point(guide_area)
		var tp: Dictionary = tp_v if tp_v!=null else zone.region_spawn(guide_area)
		var p: Dictionary = zone.place(0,tp.z+4) if zone.def.terrain.has("path") else {"x":tp.x+2.5,"z":tp.z+2.5}
		guide_pos = RuleRuntime.position(zone.free_position(p))
	var n: Dictionary = {"id":"travel_guide_"+zone.id,"name":RuleRuntime.rename_text("Capsule Corp Pilot"),"look":{"race":"Human","skin":0,"face":"Calm","hair":"Short","hairColor":2,"build":"Average","outfit":"CapsuleCorp","outfitTint":4},"scale":1,"rot":0,"boss":false,"marker":"✈","main":true,"guide":true}
	n.merge(guide_pos)
	return n
func pads() -> Array:
	return []
func track_quest(id: String) -> bool:
	if not is_active(id):
		return false
	tracked_id = id
	state.flags.trackedQuest = id
	return true
func npcs() -> Array:
	var out: Array = []
	if game().rift!=null and game().rift.active():return out
	for n: Dictionary in npc_defs:
		if not visible(n):
			continue
		var marker: Variant = null
		for q: Dictionary in active_quests():
			var s: Dictionary = step_of(q)
			if s.type=="talk" and s.npc==n.id:
				marker = "?"
			if s.type=="defeat" and s.enemy==n.id:
				marker = "⚔"
		var main: bool = false
		for q: Dictionary in quests:
			if q.giver==n.id and can_accept(q):
				if marker==null:
					marker = "!"
				if is_main(q) and marker=="!":
					main = true
		var c: Dictionary = characters[n.who]
		var row: Dictionary = {"id":n.id,"name":c.name,"style":c.get("style","turtle"),"look":c.get("look"),"dragon":c.get("dragon"),"scale":c.get("scale",1),"rot":n.get("rot",0),"boss":n.get("boss",false),"marker":marker,"main":main,"sit":n.get("sit",false)}
		row.merge(npc_pos(n))
		out.append(row)
	var guide: Variant = travel_guide()
	if guide!=null:
		out.append(guide)
	var recruiter: Variant = rift_recruiter()
	if recruiter!=null:out.append(recruiter)
	return out
func travel_to(id: String) -> bool:
	var guide: Variant = travel_guide()
	if guide==null or player.health<=0 or distance(guide)>TALK_RANGE*1.1:
		return false
	for option: Dictionary in travel_options():
		if option.zone==id and option.get("locked",false):
			emit("notify",{"text":"Reach Lv. %d to travel to %s. Train with patrols and side quests first." % [int(option.level),option.name]})
			return false
		if option.zone==id:
			if id not in state.unlocked:
				state.unlocked.append(id)
			if zone.has_region(id) and zone is RulePlanet:   # same planet: fly there, no loading
				var sp: Dictionary = zone.region_spawn(id)
				player.pos = Vector3(sp.x,zone.height_at(sp.x,sp.z)+0.2,sp.z)
				player.vel = Vector3.ZERO
				slot.zone = id
				guide_pos = null
				emit("notify",{"text":"Flew to %s." % option.name})
				emit("teleport",{"zone":id})
				return true
			emit("notify",{"text":"Travelling to %s..." % option.name})
			emit("travel",{"zone":id})
			return true
	return false
func distance(p: Dictionary) -> float:
	return Vector2(p.x-player.pos.x,p.z-player.pos.z).length()
const DOOR_RANGE := 2.6
## The building door within reach, or null.
func door_here() -> Variant:
	var best: Variant = null
	var bd: float = DOOR_RANGE
	if not zone.has_method("doors"):
		return null
	for d: Dictionary in zone.doors():
		var dist: float = distance(d)
		if dist<bd:
			bd = dist
			best = d
	return best
func interaction() -> Variant:
	var nearest: Variant = null
	var best: float = TALK_RANGE
	for n: Dictionary in npcs():
		var d: float = distance(n)
		if d<best and absf(n.y-player.pos.y)<4 and not n.boss:
			best = d
			nearest = {"id":n.id,"name":n.name,"action":"Travel" if n.get("guide",false) else "Quests" if n.marker=="!" else "Talk","distance":d}
	if nearest==null:   # people first; a building door when nobody is near
		var door: Variant = door_here()
		if door!=null:
			nearest = {"id":"door","name":str(door.name),"action":"Leave" if door.get("exit",false) else "Enter","distance":distance(door)}
	return nearest
func shop() -> Array:
	var out: Array = []
	for id: String in RuleTables.table("rpg").SHOP:
		var row: Dictionary = RuleTables.table("rpg").SHOP[id].duplicate()
		row.id = id
		out.append(row)
	for id: String in RuleTables.table("outfits"):
		var o: Dictionary = RuleTables.table("outfits")[id]
		if o.get("unlock")=="shop" and game().schema.outfit_allowed(id,slot.race):
			out.append({"id":id,"name":o.name,"price":o.price,"description":"Cosmetic outfit. Equip it from your fighter journal.","owned":id in slot.outfits})
	return out
func buy(id: String) -> Variant:
	var near_npc: Variant = interaction()
	if player.health<=0 or near_npc==null or not near_npc.id.begins_with("guide_"):
		return "Visit a nearby Training Guide to shop."
	var item: Dictionary = {}
	for row: Dictionary in shop():
		if row.id==id:
			item = row
	if item.is_empty() or item.get("owned",false):
		return "That item is unavailable or already owned."
	if slot.zeni<item.price:
		return "Not enough zeni. Complete patrols and story quests to earn more."
	game().add_zeni(-item.price)
	if RuleTables.table("rpg").SHOP.has(id):
		state.items[id] = state.items.get(id,0)+1
	else:
		slot.outfits.append(id)
	emit("notify",{"text":"Purchased %s." % item.name})
	return null
func use_item(id: String) -> bool:
	var item: Dictionary = RuleTables.table("rpg").SHOP.get(id,{})
	if player.health<=0 or item.is_empty() or state.items.get(id,0)<=0 or (player.health>=player.maxHealth and player.ki>=player.maxKi):
		return false
	state.items[id] -= 1
	player.health = minf(player.maxHealth,player.health+player.maxHealth*item.heal)
	player.ki = minf(player.maxKi,player.ki+player.maxKi*item.heal)
	emit("notify",{"text":"Used %s." % item.name})
	return true
func accept_quest(id: String) -> bool:
	if game().rift!=null and game().rift.active():return false
	var q: Dictionary = quest.get(id,{})
	var n: Dictionary = npc.get(q.get("giver",""),{})
	if player.health<=0 or q.is_empty() or n.is_empty() or not visible(n) or not can_accept(q):
		return false
	var p: Dictionary = npc_pos(n)
	if distance(p)>TALK_RANGE*1.1 or absf(p.y-player.pos.y)>4:
		return false
	accept(q)
	return true
func abandon_quest(id: String) -> bool:
	if not is_active(id):
		return false
	slot.quests[id].status = "abandoned"
	emit("notify",{"text":"Quest abandoned. Speak to its giver to start again."})
	return true
func enemy_defeated(enemy: String,defeated_zone: String = "") -> void:
	if game().rift!=null and game().rift.active():
		game().rift.enemy_defeated(enemy)
		return
	if defeated_zone!="" and defeated_zone!=zone.id and not zone.has_region(defeated_zone):
		return
	for q: Dictionary in active_quests():
		var s: Dictionary = step_of(q)
		if s.type=="defeat" and s.enemy==enemy and zone.has_region(s.zone):
			var st: Dictionary = slot.quests[q.id]
			st.count += 1
			emit("questProgress",{"id":q.id,"objective":s.text})
			if st.count>=s.get("count",1):
				advance(q)
## Enemies the active quests need on this map. A boss (one kill) is one enemy at its spot; a group fight (several
## kills, e.g. Saibamen or a hunt) puts at least GROUP_MIN of them spread around the quest's area (user request
## 2026-11-03). Each row has a unique "uid"; every kill of the key counts.
const GROUP_MIN := 10
func encounters() -> Array:
	if game().rift!=null and game().rift.active():return game().rift.encounters()
	var out: Array = []
	for q: Dictionary in active_quests():
		var s: Dictionary = step_of(q)
		if s.type!="defeat" or not zone.has_region(s.zone):
			continue
		var count: int = int(s.get("count",1))
		var n: Dictionary = npc.get(s.enemy,{})
		var c: Dictionary = characters[n.who] if not n.is_empty() else {}
		var name: String = c.get("name",s.enemy.replace("_"," ")) if not s.enemy.begins_with("patrol_") else "Hostile Trainee"
		var look: Variant = c.get("look") if not s.enemy.begins_with("patrol_") else game().schema.default_look("Human").merged({"outfitTint":3},true)
		var row := {"key":s.enemy,"style":c.get("style","turtle"),"questId":q.id,"step":slot.quests[q.id].step,"name":name,"look":look,"scale":c.get("scale",1),"level":s.get("enemyLevel",q.get("level",1))}
		if count<=1:
			if s.enemy.begins_with("patrol_"):
				continue
			var p: Dictionary = npc_pos(n) if not n.is_empty() and visible(n) else at(s)
			out.append(row.merged({"uid":s.enemy,"x":p.x,"y":p.get("y",zone.height_at(p.x,p.z)),"z":p.z,"boss":true},true))
			continue
		var total: int = maxi(GROUP_MIN,count)
		for i in total:
			var p: Dictionary = spread_point(s.zone,i,total)
			out.append(row.merged({"uid":"%s#%d" % [s.enemy,i],"index":i,"x":p.x,"z":p.z,"boss":false},true))
	return out

## Point i of n spread over an area (a sunflower spiral, so they never bunch up); on a road world, along the road.
func spread_point(zone_id: String,i: int,n: int) -> Dictionary:
	var region: RuleZone = (zone as RulePlanet).regions[zone_id].zone if zone is RulePlanet and (zone as RulePlanet).regions.has(zone_id) else zone
	if region.def.terrain.has("path"):
		var p: Dictionary = region.def.terrain.path
		return zone.place_in(zone_id,(1.6 if i%2==0 else -1.6),lerpf(float(p.from)+40.0,float(p.to)-20.0,(i+0.5)/n))
	var reach: float = float(region.size)*0.5*0.75
	if zone is RulePlanet:
		reach = minf(reach,float((zone as RulePlanet).regions[zone_id].radius)*0.85)
	if region.def.terrain.has("planetoid"):
		reach = float(region.def.terrain.planetoid.radius)*0.7
	var a: float = i*2.399963
	var d: float = reach*sqrt((i+0.5)/n)
	return zone.place_in(zone_id,cos(a)*d,sin(a)*d)
func radar() -> Dictionary:
	var here: Array = []
	var away: Dictionary = {}
	for q: Dictionary in active_quests():
		var s: Dictionary = step_of(q)
		if s.type!="collect" or not s.item.ends_with("_ball"):
			continue
		var got: Array = slot.quests[q.id].get("collected",[])
		for i: int in s.spots.size():
			if i in got:
				continue
			var p: Dictionary = s.spots[i]
			var z: String = p.get("zone",s.get("zone",""))
			if zone.has_region(z):
				var at_p: Dictionary = zone.place_in(z,p.x,p.z) if zone is RulePlanet else {"x":p.x,"z":p.z}
				here.append({"item":s.item,"x":at_p.x,"z":at_p.z})
			elif z!="":
				away[z] = away.get(z,0)+1
	var elsewhere: Array = []
	for z: String in away:
		elsewhere.append({"zone":z,"name":worlds.get(z,{}).get("name",z),"count":away[z]})
	return {"here":here,"elsewhere":elsewhere}
func pickups() -> Array:
	var out: Array = []
	for q: Dictionary in active_quests():
		var s: Dictionary = step_of(q)
		if s.type!="collect":
			continue
		for i: int in s.spots.size():
			var p: Dictionary = s.spots[i]
			if i in slot.quests[q.id].get("collected",[]) or not zone.has_region(str(p.get("zone",s.get("zone")))):
				continue
			var at_p: Dictionary = zone.place_in(str(p.get("zone",s.get("zone"))),p.x,p.z) if zone is RulePlanet else {"x":p.x,"z":p.z}
			out.append({"item":s.item,"questId":q.id,"index":i,"x":at_p.x,"y":zone.height_at(at_p.x,at_p.z)+0.6,"z":at_p.z})
	return out
func step_target(s: Dictionary) -> Variant:
	if s.type=="talk":
		var n: Dictionary = npc.get(s.npc,{})
		if n.is_empty():
			return null
		var out: Dictionary = npc_pos(n).duplicate() if zone.has_region(n.zone) and visible(n) else (zone.place_in(n.zone,n.x,n.z) if zone.has_region(n.zone) else {"x":n.x,"z":n.z})
		out.zone = n.zone
		return out
	if s.type=="defeat":
		var best: Variant = null
		var best_dist: float = INF
		for e: Dictionary in game().combat.enemies:
			if e.key==s.enemy and e.health>0 and zone.has_region(s.zone):
				var d: float = player.pos.distance_squared_to(e.pos)
				if d<best_dist:
					best = e
					best_dist = d
		if best!=null:
			var out: Dictionary = RuleRuntime.position(best.pos)
			out.zone = s.zone
			return out
		var n: Dictionary = npc.get(s.enemy,{})
		var out: Dictionary = npc_pos(n).duplicate() if not n.is_empty() and zone.has_region(n.zone) and visible(n) else at(s)
		out.zone = s.get("zone")
		return out
	if s.type=="reach" or (s.type=="train" and s.has("x")):
		var out: Dictionary = at(s)
		out.zone = s.get("zone")
		return out
	if s.type=="travel":
		return {"zone":s.zone}
	if s.type=="collect":
		var got: Array = []
		for q: Dictionary in active_quests():
			if step_of(q)==s:
				got = slot.quests[q.id].get("collected",[])
		var first: Variant = null
		for i: int in s.spots.size():
			if i in got:
				continue
			var p: Dictionary = s.spots[i]
			var z: Variant = p.get("zone",s.get("zone"))
			if first==null:
				first = {"zone":z}
			if zone.has_region(str(z)):
				var at_p: Dictionary = zone.place_in(str(z),p.x,p.z) if zone is RulePlanet else {"x":p.x,"z":p.z}
				return {"zone":z,"x":at_p.x,"z":at_p.z}
		return first
	return null
func navigation() -> Variant:
	if tracked_id!="" and not is_active(tracked_id):
		tracked_id = ""
		state.flags.erase("trackedQuest")
	var order: Array = active_quests()
	order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (10 if a.id==tracked_id else 1 if is_main(a) else 0)>(10 if b.id==tracked_id else 1 if is_main(b) else 0))
	if not order.is_empty():
		var q: Dictionary = order[0]
		var step: Dictionary = step_of(q)
		var target: Variant = step_target(step)
		var out := {"questId":q.id,"title":q.title,"text":step.text,"kind":"objective","zone":step.get("zone",slot.zone)}
		if step.type=="level":
			out.kind = "training"
			out.text = "%s · Complete patrols or training to gain XP." % step.text
			return out
		if target==null and step.type=="train":
			if zone.has_region(step.zone):
				out.merge(zone.region_spawn(step.zone))
			else: target = {"zone":step.zone}
		if target!=null:
			out.zone = target.get("zone",slot.zone)
			if zone.has_region(str(out.zone)):
				if target.has("x"):
					out.merge(target,true)
				elif zone is RulePlanet:
					out.merge(zone.region_spawn(str(out.zone)))
				else: out.merge(zone.spawn)
			else:
				var guide: Variant = travel_guide()
				out.kind = "travel" if guide!=null else "blocked"
				var destination: String = worlds.get(str(out.zone),{}).get("name",str(out.zone))
				out.text = "Visit the travel pilot for %s · %s" % [destination,step.text] if guide!=null else "Finish local story tasks to reach %s · %s" % [destination,step.text]
				if guide!=null: out.merge({"x":guide.x,"y":guide.y,"z":guide.z})
		if out.has("x"):
			out.y = out.get("y",zone.height_at(out.x,out.z))
		return out
	for q: Dictionary in quests:
		if is_main(q) and can_accept(q):
			var n: Dictionary = npc[q.giver]
			if zone.has_region(n.zone) and visible(n):
				var out: Dictionary = npc_pos(n).duplicate()
				out.merge({"questId":q.id,"title":q.title,"text":"Talk to "+characters[n.who].name,"kind":"offer","zone":n.zone})
				return out
			break
	return null
func waypoint() -> Variant:
	var route: Variant = navigation()
	return route if route!=null and route.has("x") else null
func progress_text(q: Dictionary) -> String:
	var st: Dictionary = slot.quests[q.id]
	var s: Dictionary = step_of(q)
	match s.type:
		"train": return "%d / %s s" % [int(st.t),s.seconds]
		"collect": return "%d / %d" % [st.get("collected",[]).size(),s.spots.size()]
		"defeat": return "%d / %s" % [int(st.count),s.count] if s.get("count",1)>1 else ""
		"level": return "level %s / %s" % [slot.level,s.level]
	return ""
func tracker() -> Array:
	var out: Array = []
	for q: Dictionary in active_quests():
		var t: Variant = step_target(step_of(q))
		out.append({"id":q.id,"title":q.title,"saga":q.get("saga"),"main":is_main(q),"tracked":q.id==tracked_id,"objective":step_of(q).text,"progress":progress_text(q),"where":worlds.get(t.get("zone"),{}).get("name") if t!=null and t.get("zone")!=null else null})
	return out
func next_main() -> Variant:
	for q: Dictionary in quests:
		if is_main(q) and can_accept(q):
			var n: Dictionary = npc[q.giver]
			return {"title":q.title,"saga":q.get("saga"),"giver":characters[n.who].name,"zone":worlds[n.zone].name}
	for q: Dictionary in quests:
		if is_main(q) and not is_done(q.id) and not is_active(q.id):
			return {"title":q.title,"level":q.get("level",1),"locked":slot.level<q.get("level",1)}
	return null
func journal() -> Dictionary:
	return {"done":quests.filter(func(q: Dictionary) -> bool: return is_done(q.id)).map(func(q: Dictionary) -> String: return q.id),"unlocked":state.unlocked.duplicate(),"visited":state.visited.duplicate(),"moves":slot.moves.duplicate(),"forms":slot.forms.duplicate(),"items":state.items.duplicate()}
func priority(q: Dictionary) -> int:
	return 0 if is_main(q) else 1 if q.id.begins_with("Form_") else 3 if q.get("repeat",false) else 2
func interact(choose: bool = false) -> Variant:
	if game().rift!=null and game().rift.active():return null
	var recruiter: Variant=rift_recruiter()
	if recruiter!=null and distance(recruiter)<TALK_RANGE and player.health>0:
		say("Archivist Tem","The timelines are fracturing. Join Rift Patrol at the Time Nexus; your allies are waiting.","riftPatrol")
		game().enter_rift_hub()
		return "rift"
	if player.health<=0:
		return null
	var near: Variant = interaction()
	var door: Variant = door_here() if near is Dictionary and near.id=="door" else null
	if door!=null:
		var to: Variant = game().leave_building() if door.get("exit",false) else game().enter_building(door)
		if to is String and RuleTables.table("zones").has(to):
			emit("travel",{"zone":to})
			return "door"
		emit("notify",{"text":str(to)})
		return null
	var here: Array = npcs().filter(func(n: Dictionary) -> bool: return distance(n)<TALK_RANGE*maxf(1,n.scale*0.8) and absf(n.y-player.pos.y)<4+n.scale*2)
	here.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return distance(a)<distance(b))
	for n: Dictionary in here:
		for q: Dictionary in active_quests():
			var s: Dictionary = step_of(q)
			if s.type=="talk" and s.npc==n.id:
				if slot.quests[q.id].step<q.steps.size()-1 or (not q.get("dragonHunt",false) and n.id!=q.giver):
					say(n.name,s.get("reply",narrative.talk_replies.get(n.id,"Alright. Let's go.")),"progress",q.id)
				advance(q)
				return "talk"
	for n: Dictionary in here:
		var offers: Array = quests.filter(func(q: Dictionary) -> bool: return q.giver==n.id and can_accept(q))
		offers.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return priority(a)<priority(b))
		if not offers.is_empty():
			if choose:
				var choices: Array = offers.map(func(q: Dictionary) -> Dictionary: return {"id":q.id,"title":q.title,"text":q.offer,"level":q.get("level",1),"rewards":q.get("rewards",{}),"objective":q.steps[0].text})
				emit("dialogue",{"speaker":n.name,"text":"Choose a quest.","kind":"choice","npcId":n.id,"choices":choices})
				return "offer"
			accept(offers[0])
			return "accept"
	if not here.is_empty():
		var n: Dictionary = here[0]
		if n.get("guide",false):
			var options: Array = travel_options()
			var text: String = "The ship is ready. Where do you want to go?"
			for o: Dictionary in options:
				if o.story:
					text = "Your work on %s is done. The story continues on %s. Where to?" % [zone.name,o.name]
					break
			emit("dialogue",{"speaker":n.name,"kind":"travel","options":options,"text":text})
			return "travel"
		for q: Dictionary in quests:
			if q.giver!=n.id or is_done(q.id) or is_active(q.id) or (q.has("races") and slot.race not in q.races):
				continue
			var after_done: bool = true
			for id: String in required_after(q):
				after_done = after_done and is_done(id)
			if after_done:
				if slot.level<q.get("level",1):
					say(n.name,"Come back when you're stronger (level %s)." % q.level,"ambient")
					return "ambient"
				break
		say(n.name,"..." if n.boss else narrative.ambient.get(n.id,"Train hard!"),"ambient")
		return "ambient"
	return null
func update(dt: float,intents: Dictionary = {}) -> void:
	if game().rift!=null and game().rift.active():return
	if player.health<=0 or not is_finite(dt) or dt<=0:
		return
	if zone is RulePlanet:   # entering an area on the planet map for the first time discovers it
		var area: String = game().current_region()
		if area!="" and area not in state.visited:
			state.visited.append(area)
			if area not in state.unlocked:
				state.unlocked.append(area)
			emit("notify",{"text":"Discovered: "+str(worlds.get(area,{}).get("name",area))})
			emit("discovered",{"zone":area})
	_check_portals()
	if zone.kill_y!=null and player.pos.y<zone.kill_y:
		player.pos = Vector3(zone.spawn.x,zone.height_at(zone.spawn.x,zone.spawn.z)+0.5,zone.spawn.z)
		player.vel = Vector3.ZERO
		emit("notify",{"text":"You fell off Snake Way! King Yemma's ogres carry you back to the start." if zone.id=="snake_way" else "You fell off! Back to the start."})
	if intents.get("interact",false):
		interact(true)
	var speed: float = Vector2(player.vel.x,player.vel.z).length()
	for q: Dictionary in active_quests():
		var st: Dictionary = slot.quests[q.id]
		var s: Dictionary = step_of(q)
		if s.type=="reach" and zone.has_region(s.zone) and distance(at(s))<s.r:
			advance(q)
		elif (s.type=="travel" and here()==s.zone) or (s.type=="level" and slot.level>=s.level):
			advance(q)
		elif s.type=="train" and zone.has_region(s.zone):
			if s.has("requiredForms") and player.form not in s.requiredForms:
				continue
			if s.has("x") and distance(at(s))>s.r:
				continue
			var charging: bool = player.charging or (intents.get("charge",false) and speed<1.5)
			var valid: bool = true
			match s.get("mode",""):
				"move": valid = speed>1.5 or (player.flying and player.vel.length()>1.5)
				"charge": valid = charging
				"fly": valid = player.flying or not player.onGround
				"still": valid = speed<0.4 and not charging
			if not valid:
				continue
			var before: int = floori(st.t/10.0)
			st.t += dt
			if floori(st.t/10.0)>before and st.t<s.seconds:
				emit("notify",{"text":"%s: %d / %s s" % [s.text,int(st.t),s.seconds]})
			if st.t>=s.seconds:
				advance(q)
		elif s.type=="collect":
			if not st.has("collected"):
				st.collected = []
			for i: int in s.spots.size():
				var p: Dictionary = s.spots[i]
				if i in st.collected or not zone.has_region(str(p.get("zone",s.get("zone")))):
					continue
				var at_p: Dictionary = zone.place_in(str(p.get("zone",s.get("zone"))),p.x,p.z) if zone is RulePlanet else p
				if distance(at_p)<PICKUP_RANGE and absf(zone.height_at(at_p.x,at_p.z)-player.pos.y)<3.5:
					st.collected.append(i)
					emit("notify",{"text":"Found %s (%d / %d)" % [narrative.item_names.get(s.item,s.item),st.collected.size(),s.spots.size()]})
					if st.collected.size()>=s.spots.size():
						if s.has("summonFlag"):
							state.flags[s.summonFlag] = true
						elif s.item=="dragon_ball":
							state.flags.shenron = true
						advance(q)
						break

## Places in the sky you fly into to reach another area (King Kae's planet above Serpent Road's end).
var _portal_used := false
var _portal_told := 0.0
func _check_portals() -> void:
	if _portal_used:
		return
	for p: Dictionary in zone.def.get("portals",[]):
		var at: Dictionary = zone.place(float(p.x),float(p.z))
		if player.pos.distance_to(Vector3(at.x,float(p.y),at.z))>float(p.r):
			continue
		if str(p.zone) in state.unlocked and int(slot.level)<travel_level(str(p.zone)):
			if game().time-_portal_told>4.0:
				_portal_told = game().time
				emit("notify",{"text":"Reach Lv. %d to land on %s." % [travel_level(str(p.zone)),str(worlds.get(str(p.zone),{}).get("name",p.zone))]})
		elif str(p.zone) in state.unlocked:
			_portal_used = true
			emit("notify",{"text":"Landing on %s..." % str(worlds.get(str(p.zone),{}).get("name",p.zone))})
			emit("travel",{"zone":p.zone})
		elif game().time-_portal_told>4.0:
			_portal_told = game().time
			emit("notify",{"text":str(p.get("locked","You can't land there yet."))})

## The level you need to travel to an area (user request 2026-11-03): the area's own level (rpg ZONE_LEVELS);
## open-world towns have none. Walking or flying between areas on the same planet map is never gated.
func travel_level(zone_id: String) -> int:
	var need: int = int(RuleTables.table("rpg").get("ZONE_LEVELS",{}).get(zone_id,0))
	# Reused adult areas (especially Lv1900 Red Ribbon) must also admit their childhood story.
	# Only the current Origins destination gets this transport exception; patrol/difficulty data stay intact.
	for q: Dictionary in quests:
		if q.get("origins",false) and (is_active(q.id) or (is_main(q) and can_accept(q))) and quest_place(q)==zone_id:
			need = mini(need,int(q.level))
	return need

func rift_recruiter() -> Variant:
	if game().rift==null or not game().rift.available() or game().rift.active():return null
	var c: Dictionary=characters.archivist_tem
	var base: Variant=travel_guide()
	if base==null:
		var tp: Variant=zone.region_travel_point(here())
		base=tp if tp!=null else zone.region_spawn(here())
	var p: Dictionary=RuleRuntime.position(zone.free_position({"x":float(base.x)+5,"z":float(base.z)}))
	return p.merged({"id":"rift_recruiter","name":c.name,"look":c.look,"style":c.style,"scale":1,"rot":0,"boss":false,"main":false,"marker":"!","rift":true},true)
