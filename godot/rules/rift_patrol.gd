class_name RuleRiftPatrol
extends RefCounted
var _game: WeakRef
var room: WeakRef
var managed:=false
var run: Dictionary={}
var mission: Dictionary={}
var ambient: Array=[]
var allies: Array=[]
var definitions: Array=[]
var serial:=0
func _init(g: RuleGame,resume: bool=true) -> void:
	_game=weakref(g)
	RuleHeroCards.normalize(g.slot)
	var pending: String=str(g.slot.rift.get("pending",""))
	if resume and pending!="" and unlocked(pending) and g.zone.has_region(str(find(pending).get("zone",""))): begin(pending)
func game() -> RuleGame: return _game.get_ref()
func active() -> bool: return run.get("status")=="active"
func available() -> bool:
	return game().slot.quests.get(RuleTables.table("rift_missions").unlock_quest,{}).get("status")=="done" or game().slot.quests.get(RuleTables.table("rift_missions").unlock_quest,{}).get("completions",0)>0
func find(id: String) -> Dictionary:
	for m: Dictionary in RuleTables.table("rift_missions").missions:
		if m.id==id:return m
	return {}
func unlocked(id: String) -> bool:
	var m:=find(id)
	if m.is_empty() or not available():return false
	for previous: String in m.after:
		if game().slot.rift.results.get(previous,{}).get("stars",0)<1:return false
	return true
func catalogue() -> Array:
	var out: Array=[]
	for m: Dictionary in RuleTables.table("rift_missions").missions:
		var result: Dictionary=game().slot.rift.results.get(m.id,{})
		out.append({"id":m.id,"arc":m.arc,"name":m.name,"zone":m.zone,"unlocked":unlocked(m.id),"stars":result.get("stars",0),"done":result.get("stars",0)>0})
	return out
func enter_hub() -> Variant:
	if not available():return "Finish the adult main story to join Rift Patrol."
	if active():return "Finish or abandon the current Rift mission first."
	if game().player.health<=0:return "Recover before entering the Time Nexus."
	game().slot.story.flags.riftPatrol=true
	if "time_nexus" not in game().slot.story.unlocked:game().slot.story.unlocked.append("time_nexus")
	game().leaving_to="time_nexus";game().leaving_position=null
	game().emit("travel",{"zone":"time_nexus"})
	return null
func start(id: String) -> Variant:
	if game().leaving_to!="":return "Wait for the rift gate to finish opening."
	if active():return "A Rift mission is already active."
	if not unlocked(id):return "That Rift mission is locked."
	if game().current_region()!="time_nexus":return "Visit the Mission Board in the Time Nexus."
	if game().player.health<=0:return "Recover before starting a Rift mission."
	var m:=find(id)
	game().slot.rift.pending=id
	if game().zone.has_region(m.zone):begin(id)
	else:
		game().leaving_to=m.zone;game().leaving_position=null
		game().emit("travel",{"zone":m.zone})
	return null
func begin(id: String) -> void:
	mission=find(id);serial+=1
	run={"id":id,"status":"active","timer":0.0,"wave":0,"kills":{},"ally_down":false,"objectives":[],"stars":0,"reason":"","serial":serial}
	for o: Dictionary in mission.objectives:run.objectives.append(o.merged({"progress":0},true))
	ambient=game().combat.enemies.duplicate()
	var p: Dictionary=game().zone.place_in(mission.zone,mission.spawn.x,mission.spawn.z)
	game().player.pos=game().zone.free_position(p);game().player.vel=Vector3.ZERO
	game().slot.zone=mission.zone
	allies.clear()
	for row: Dictionary in mission.allies:
		var c: Dictionary=RuleTables.table("characters")[row.character]
		var at: Dictionary=game().zone.place_in(mission.zone,row.x,row.z)
		var hp: float=float(row.health)*(1+RuleHeroCards.bonus(game().slot,"ally_health"))
		allies.append({"id":row.id,"key":row.character,"character":row.character,"kind":"ally","name":c.name,"look":c.look,"style":c.style,"scale":c.get("scale",1),"pos":game().zone.free_position(at),"home":game().zone.free_position(at),"vel":Vector3.ZERO,"yaw":0.0,"health":hp,"maxHealth":hp,"ki":100.0,"blocking":false,"stun":0.0,"hurtUntil":0.0,"attackSerial":0,"attackKind":"jab","cooldown":0.0,"damage":row.damage,"interval":row.cooldown,"protect":row.protect,"onGround":true,"flying":false,"runSpeed":12.0})
	game().combat.allies=allies
	make_wave()
	if game().rift!=null:game().combat.sync()
	game().emit("riftMissionStarted",{"id":id,"stars":0,"rewards":{}})
func make_wave() -> void:
	definitions.clear()
	var wave: Dictionary=mission.waves[int(run.wave)]
	for i: int in wave.spawns.size():
		var s: Dictionary=wave.spawns[i]
		var c: Dictionary=RuleTables.table("characters")[s.character]
		var p: Dictionary=game().zone.place_in(mission.zone,s.x,s.z)
		var key: String="rift:%s:%d:%d" % [mission.id,int(run.wave),i]
		definitions.append(s.merged({"uid":key,"key":key,"name":c.name,"look":c.look,"style":c.style,"scale":c.get("scale",1),"x":p.x,"z":p.z,"boss":s.get("boss",false)},true))
func encounters() -> Array:
	return definitions.filter(func(d: Dictionary)->bool:return not run.kills.has(d.key)) if active() else []
func enemy_defeated(key: String) -> void:
	if not active() or run.kills.has(key) or not definitions.any(func(d: Dictionary)->bool:return d.key==key):return
	run.kills[key]=true
	var progress:=0
	for d: Dictionary in definitions:
		if run.kills.has(d.key):progress+=1
	run.objectives[int(run.wave)].progress=progress
	if progress<definitions.size():return
	if int(run.wave)+1<mission.waves.size():run.wave+=1;make_wave()
	else:finish(true,"")
func participants() -> Array:
	if managed and room!=null and room.get_ref()!=null:
		return room.get_ref().rift_players()
	return [game()]
func knocked_out(actor: Dictionary) -> bool:
	return actor.health<=0 or (game().zone.kill_y!=null and actor.pos.y<float(game().zone.kill_y))
func finish(clear: bool,reason: String) -> void:
	if not active():return
	for ally: Dictionary in allies:
		if knocked_out(ally):
			ally.health=0.0
			run.ally_down=true
			if ally.protect:clear=false;reason="A protected ally was knocked out."
	run.status="complete" if clear else "failed";run.reason=reason
	var stars:=0
	if clear:
		stars=1+(1 if run.timer<=mission.stars.time else 0)+(0 if run.ally_down else 1)
		run.stars=stars
		for o: Dictionary in run.objectives:
			if o.type=="protect":o.progress=1
	# Commit every fighter's persistent result/cards/wallet before broadcasting completion.
	var payouts: Array=[]
	for g: RuleGame in participants():
		g.slot.rift.erase("pending")
		if not clear:continue
		var old: Dictionary=g.slot.rift.results.get(mission.id,{"stars":0,"clears":0})
		var first: bool=int(old.get("clears",0))==0
		var reward: Dictionary=mission.rewards.duplicate(true)
		reward.zeni+=reward.first_zeni if first else 0
		reward.cards=[]
		if first and reward.card not in g.slot.rift.cards:g.slot.rift.cards.append(reward.card);reward.cards.append(reward.card)
		if stars==3 and reward.three_star_card not in g.slot.rift.cards:g.slot.rift.cards.append(reward.three_star_card);reward.cards.append(reward.three_star_card)
		g.slot.rift.results[mission.id]={"stars":maxi(stars,int(old.get("stars",0))),"clears":int(old.get("clears",0))+1}
		g.slot.zeni+=reward.zeni
		g.progression.add_xp(g.slot,reward.xp)
		payouts.append({"game":g,"rewards":reward})
	game().combat.enemies.clear();game().combat.enemies.append_array(ambient)
	game().combat.projectiles.clear();definitions.clear()
	if managed and room!=null and room.get_ref()!=null:room.get_ref().rift_checkpoint()
	if clear:
		for payout: Dictionary in payouts:payout.game.refresh_derived()
		for payout: Dictionary in payouts:payout.game.emit("riftMissionComplete",{"id":mission.id,"stars":stars,"rewards":payout.rewards})
	else:game().emit("riftMissionFailed",{"id":mission.id,"reason":reason})
func abandon() -> Variant:
	if not active():return "No Rift mission is active."
	finish(false,"Mission abandoned.")
	return null
func target(enemy: Dictionary,fallback: Dictionary) -> Dictionary:
	var best: Dictionary=fallback
	var nearest: float=enemy.pos.distance_squared_to(fallback.pos) if fallback.health>0 else INF
	for ally: Dictionary in allies:
		if ally.health<=0:continue
		var d: float=enemy.pos.distance_squared_to(ally.pos)
		if d<nearest:nearest=d;best=ally
	return best
func update(dt: float) -> void:
	if not active():return
	run.timer+=dt
	for g: RuleGame in participants():
		if knocked_out(g.player):g.player.health=0.0
	if not participants().any(func(g: RuleGame)->bool:return g.player.health>0):finish(false,"The patrol was defeated.");return
	for a: Dictionary in allies:
		if knocked_out(a):
			a.health=0.0
			run.ally_down=true
			if a.protect:finish(false,"A protected ally was knocked out.");return
			continue
		a.cooldown=maxf(0,a.cooldown-dt);a.stun=maxf(0,a.stun-dt)
		var enemies: Array=game().combat.enemies.filter(func(e: Dictionary)->bool:return e.health>0 and str(e.key).begins_with("rift:"))
		if enemies.is_empty():continue
		enemies.sort_custom(func(x: Dictionary,y: Dictionary)->bool:return a.pos.distance_squared_to(x.pos)<a.pos.distance_squared_to(y.pos))
		var e: Dictionary=enemies[0]
		var delta: Vector3=e.pos-a.pos
		a.yaw=atan2(delta.x,delta.z)
		a.vel=Vector3.ZERO
		if delta.length()>2.5 and a.stun<=0:
			var previous: Vector3=a.pos
			a.pos=a.pos.move_toward(e.pos,minf(12*dt,maxf(0,delta.length()-2)))
			a.pos.y=game().zone.ground_at(a.pos.x,a.pos.z)
			RuleCollision.resolve(a,game().zone,previous)
			if dt>0:a.vel=(a.pos-previous)/dt
		elif a.cooldown<=0 and a.stun<=0:
			a.cooldown=a.interval;a.attackSerial+=1
			game().combat.hit(e,a.damage,a,true)
			game().emit("attack",{"id":a.id,"actor_id":a.id,"kind":"melee","phase":"release","move_id":"Melee","style":a.style,"pos":a.pos,"combo_step":(int(a.attackSerial)-1)%4+1})
	for e: Dictionary in game().combat.enemies.duplicate():
		if e.health>0 and str(e.key).begins_with("rift:") and knocked_out(e):
			game().combat.hit(e,e.maxHealth+1,game().player,true)
			if not active():return
		if e.health<=0 or not str(e.key).begins_with("rift:") or not e.get("boss",false):continue
		var phase:=0
		for i: int in e.phases.size():
			if e.health/e.maxHealth<=float(e.phases[i].at):phase=i
		phase=maxi(phase,int(e.get("riftPhase",0)))
		if phase>int(e.get("riftPhase",-1)):
			e.riftPhase=phase;e.runSpeed=game().combat.c.enemySpeed*e.phases[phase].speed
			game().emit("riftBossPhase",{"id":e.id,"character":e.character,"phase":phase,"name":e.phases[phase].name,"pos":e.pos})
		e.damageMultiplier=float(e.damageScale)*float(e.phases[phase].damage)
func snapshot() -> Dictionary:
	if run.is_empty():return {}
	var out:=run.duplicate(true)
	out.zone=mission.zone;out.name=mission.name;out.arc=mission.arc;out.corrupted=active();out.allies=allies
	return out
func save_for(g: RuleGame) -> void:
	if active():g.slot.rift.pending=mission.id
	elif not run.is_empty():g.slot.rift.erase("pending")
