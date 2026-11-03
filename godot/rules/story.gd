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
var combat_available: bool = RuleTables.table("schema").combat_available
func _init(game: RuleGame,bus: Object = null) -> void:
	_game = weakref(game)
	events = bus if bus!=null else game.events
	slot = game.slot
	zone = game.zone
	player = game.player
	game.schema._ensure_story(slot)
	state = slot.story
	for q: Dictionary in quests:
		quest[q.id] = q
	for n: Dictionary in npc_defs:
		npc[n.id] = n
	if zone.id not in state.visited:
		state.visited.append(zone.id)
	if zone.id not in state.unlocked:
		state.unlocked.append(zone.id)
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
	if n.zone!=zone.id or (n.has("after") and not is_done(n.after)) or (n.has("before") and is_done(n.before)) or (n.has("flagged") and not state.flags.get(n.flagged,false)):
		return false
	if n.has("afterStep") and not is_done(n.afterStep[0]) and not (is_active(n.afterStep[0]) and slot.quests[n.afterStep[0]].step>=n.afterStep[1]):
		return false
	return true
func npc_pos(n: Dictionary) -> Dictionary:
	if not positions.has(n.id):
		var p: Dictionary = zone.place(n.x,n.z)
		if n.has("y"):
			p.y = n.y
		positions[n.id] = RuleRuntime.position(zone.free_position(p))
	return positions[n.id]
func at(step: Dictionary) -> Dictionary:
	return zone.place(step.get("x",0),step.get("z",0)) if step.get("zone")==zone.id else {"x":step.get("x",0),"z":step.get("z",0)}
func can_accept(q: Dictionary) -> bool:
	if q.get("legacy",false) or q.get("automatic",false) or is_active(q.id) or (is_done(q.id) and not q.get("repeat",false)) or slot.level<q.get("level",1):
		return false
	if q.has("path") and not game().forms.has_form_path(slot,q.path):
		return false
	if q.has("races") and slot.race not in q.races:
		return false
	for id: String in q.get("after",[]):
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
	if (s.type=="level" and slot.level>=s.level) or (s.type=="travel" and zone.id==s.zone):
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
	return quests.filter(func(q: Dictionary) -> bool: return q.get("main",false) and not q.get("legacy",false) and not q.get("automatic",false) and (is_active(q.id) or can_accept(q)))
func tasks_here() -> Array:
	return story_quests().filter(func(q: Dictionary) -> bool: return quest_place(q)==zone.id).map(func(q: Dictionary) -> String: return q.title)
func travel_options() -> Array:
	if not tasks_here().is_empty():
		return []
	var next: Array = []
	for q: Dictionary in story_quests():
		var z: Variant = quest_place(q)
		if z!=null and z!=zone.id and z not in next:
			next.append(z)
	for q: Dictionary in quests:
		if not q.get("main",false) or q.get("legacy",false) or q.get("automatic",false) or is_done(q.id) or is_active(q.id):
			continue
		if q.has("races") and slot.race not in q.races:
			continue
		if q.has("path") and not game().forms.has_form_path(slot,q.path):
			continue
		var after_done: bool = true
		for id: String in q.get("after",[]):
			after_done = after_done and is_done(id)
		if not after_done:
			continue
		var z: Variant = npc.get(q.giver,{}).get("zone")
		if z!=null and z!=zone.id and z not in next:
			next.append(z)
		break
	var out: Array = []
	var order: Array = next.duplicate()
	for z: String in state.unlocked:
		if z not in order:
			order.append(z)
	for z: String in order:
		if z==zone.id or z=="test" or not worlds.has(z):
			continue
		out.append({"zone":z,"story":z in next,"name":worlds[z].name,"planet":worlds[z].planet})
	return out
func travel_guide() -> Variant:
	if travel_options().is_empty():
		return null
	if guide_pos==null:
		var tp: Dictionary = zone.travel_point if zone.travel_point!=null else zone.spawn
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
	return true
func npcs() -> Array:
	var out: Array = []
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
				if q.get("main",false) and marker=="!":
					main = true
		var c: Dictionary = characters[n.who]
		var row: Dictionary = {"id":n.id,"name":c.name,"look":c.get("look"),"dragon":c.get("dragon"),"scale":c.get("scale",1),"rot":n.get("rot",0),"boss":n.get("boss",false),"marker":marker,"main":main}
		row.merge(npc_pos(n))
		out.append(row)
	var guide: Variant = travel_guide()
	if guide!=null:
		out.append(guide)
	return out
func travel_to(id: String) -> bool:
	var guide: Variant = travel_guide()
	if guide==null or player.health<=0 or distance(guide)>TALK_RANGE*1.1:
		return false
	for option: Dictionary in travel_options():
		if option.zone==id:
			if id not in state.unlocked:
				state.unlocked.append(id)
			emit("notify",{"text":"Travelling to %s..." % option.name})
			emit("travel",{"zone":id})
			return true
	return false
func distance(p: Dictionary) -> float:
	return Vector2(p.x-player.pos.x,p.z-player.pos.z).length()
func interaction() -> Variant:
	var nearest: Variant = null
	var best: float = TALK_RANGE
	for n: Dictionary in npcs():
		var d: float = distance(n)
		if d<best and absf(n.y-player.pos.y)<4 and not n.boss:
			best = d
			nearest = {"id":n.id,"name":n.name,"action":"Travel" if n.get("guide",false) else "Quests" if n.marker=="!" else "Talk","distance":d}
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
	if defeated_zone!="" and defeated_zone!=zone.id:
		return
	for q: Dictionary in active_quests():
		var s: Dictionary = step_of(q)
		if s.type=="defeat" and s.enemy==enemy and s.zone==zone.id:
			var st: Dictionary = slot.quests[q.id]
			st.count += 1
			emit("questProgress",{"id":q.id,"objective":s.text})
			if st.count>=s.get("count",1):
				advance(q)
func encounters() -> Array:
	var out: Array = []
	for q: Dictionary in active_quests():
		var s: Dictionary = step_of(q)
		if s.type!="defeat" or s.zone!=zone.id or s.enemy.begins_with("patrol_"):
			continue
		var n: Dictionary = npc.get(s.enemy,{})
		var c: Dictionary = characters[n.who] if not n.is_empty() else {}
		var p: Dictionary = npc_pos(n) if not n.is_empty() and visible(n) else at(s)
		out.append({"key":s.enemy,"questId":q.id,"step":slot.quests[q.id].step,"name":c.get("name",s.enemy.replace("_"," ")),"look":c.get("look"),"scale":c.get("scale",1),"x":p.x,"y":p.get("y",zone.height_at(p.x,p.z)),"z":p.z,"level":q.get("level",1),"boss":s.get("count",1)==1})
	return out
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
			if z==zone.id:
				here.append({"item":s.item,"x":p.x,"z":p.z})
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
			if i in slot.quests[q.id].get("collected",[]) or p.get("zone",s.get("zone"))!=zone.id:
				continue
			out.append({"item":s.item,"questId":q.id,"index":i,"x":p.x,"y":zone.height_at(p.x,p.z)+0.6,"z":p.z})
	return out
func step_target(s: Dictionary) -> Variant:
	if s.type=="talk":
		var n: Dictionary = npc.get(s.npc,{})
		if n.is_empty():
			return null
		var out: Dictionary = npc_pos(n).duplicate() if n.zone==zone.id and visible(n) else {"x":n.x,"z":n.z}
		out.zone = n.zone
		return out
	if s.type=="defeat":
		var best: Variant = null
		var best_dist: float = INF
		for e: Dictionary in game().combat.enemies:
			if e.key==s.enemy and e.health>0 and s.zone==zone.id:
				var d: float = player.pos.distance_squared_to(e.pos)
				if d<best_dist:
					best = e
					best_dist = d
		if best!=null:
			var out: Dictionary = RuleRuntime.position(best.pos)
			out.zone = zone.id
			return out
		var n: Dictionary = npc.get(s.enemy,{})
		var out: Dictionary = npc_pos(n).duplicate() if not n.is_empty() and n.zone==zone.id and visible(n) else at(s)
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
			if z==zone.id:
				return {"zone":z,"x":p.x,"z":p.z}
		return first
	return null
func waypoint() -> Variant:
	var order: Array = active_quests()
	order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (10 if a.id==tracked_id else 1 if a.get("main",false) else 0)>(10 if b.id==tracked_id else 1 if b.get("main",false) else 0))
	for q: Dictionary in order:
		var t: Variant = step_target(step_of(q))
		if t!=null and t.get("zone")==zone.id and t.has("x"):
			return {"x":t.x,"y":t.get("y",zone.height_at(t.x,t.z)),"z":t.z,"questId":q.id,"text":step_of(q).text}
	for q: Dictionary in quests:
		if q.get("main",false) and can_accept(q):
			var n: Dictionary = npc[q.giver]
			if n.zone==zone.id and visible(n):
				var out: Dictionary = npc_pos(n).duplicate()
				out.merge({"questId":q.id,"text":"Talk to "+characters[n.who].name})
				return out
			break
	return null
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
		out.append({"id":q.id,"title":q.title,"saga":q.get("saga"),"main":q.get("main",false),"objective":step_of(q).text,"progress":progress_text(q),"where":worlds.get(t.get("zone"),{}).get("name") if t!=null and t.get("zone")!=null else null})
	return out
func next_main() -> Variant:
	for q: Dictionary in quests:
		if q.get("main",false) and can_accept(q):
			var n: Dictionary = npc[q.giver]
			return {"title":q.title,"saga":q.get("saga"),"giver":characters[n.who].name,"zone":worlds[n.zone].name}
	for q: Dictionary in quests:
		if q.get("main",false) and not is_done(q.id) and not is_active(q.id):
			return {"title":q.title,"level":q.get("level",1),"locked":slot.level<q.get("level",1)}
	return null
func journal() -> Dictionary:
	return {"done":quests.filter(func(q: Dictionary) -> bool: return is_done(q.id)).map(func(q: Dictionary) -> String: return q.id),"unlocked":state.unlocked.duplicate(),"visited":state.visited.duplicate(),"moves":slot.moves.duplicate(),"forms":slot.forms.duplicate(),"items":state.items.duplicate()}
func priority(q: Dictionary) -> int:
	return 0 if q.get("main",false) else 1 if q.id.begins_with("Form_") else 3 if q.get("repeat",false) else 2
func interact(choose: bool = false) -> Variant:
	if player.health<=0:
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
			for id: String in q.get("after",[]):
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
	if player.health<=0 or not is_finite(dt) or dt<=0:
		return
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
		if s.type=="reach" and s.zone==zone.id and distance(at(s))<s.r:
			advance(q)
		elif (s.type=="travel" and s.zone==zone.id) or (s.type=="level" and slot.level>=s.level):
			advance(q)
		elif s.type=="train" and s.zone==zone.id:
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
				if i in st.collected or p.get("zone",s.get("zone"))!=zone.id:
					continue
				if distance(p)<PICKUP_RANGE and absf(zone.height_at(p.x,p.z)-player.pos.y)<3.5:
					st.collected.append(i)
					emit("notify",{"text":"Found %s (%d / %d)" % [narrative.item_names.get(s.item,s.item),st.collected.size(),s.spots.size()]})
					if st.collected.size()>=s.spots.size():
						if s.has("summonFlag"):
							state.flags[s.summonFlag] = true
						elif s.item=="dragon_ball":
							state.flags.shenron = true
						advance(q)
						break
