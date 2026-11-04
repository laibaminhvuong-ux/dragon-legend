class_name RuleCombat
extends RefCounted
var _game: WeakRef
var game: Variant:
	get:return _game.get_ref()
var _story: WeakRef
var party: WeakRef
var world_authority := true
var events: Object
var p: Dictionary
var zone: RuleZone
var enemies: Array = []
var projectiles: Array = []
var c: Dictionary = RuleTables.table("combat")
var a: Dictionary = RuleTables.table("avatar")
var moves: Dictionary = RuleTables.table("moves")
var rpg: Dictionary = RuleTables.table("rpg")
var forms := RuleForms.new()
var movement := RuleMovement.new()
var clock: float = 0
var serial: int = 0
var sync_at: float = 0
var strike_until := 0.0
var melee_cd: float = 0
var blast_cd: float = 0
var beam_cd: float = 0
var wolf_combo := 0
var wolf_swing := -100.0
var combo: int = 0
var last_swing: float = -10
var beam_held: bool = false
var beam_time: float = 0
var respawn_at: float = 0
var last_damage: float = -100
var avatar: Dictionary = {"remaining":0.0,"readyAt":0.0,"nextStrike":0.0,"damage":0.0,"pulse":0}
var last_kaioken := 0
var action_sequence := 0
var event_sequence := 0
var skill: Dictionary = {}
var impact_context: Dictionary = {}
var avatar_context: Dictionary = {}
var technique: String
## Ultra Instinct forms dodge every hit automatically this many times, then rest this long (user request 2026-11-03).
const UI_DODGES := 20
const UI_COOLDOWN := 30.0
const UTILITIES := ["Regeneration","SolarFlare","Afterimage","UltraInstinctSign","EnergyField","CandyBeam","InstantTransmission","Kaioken"]
func _init(owner_game: RefCounted,bus: Object = null) -> void:
	_game = weakref(owner_game)
	events = bus
	p = game.player
	zone = game.zone
	technique = game.slot.loadout.get("technique","EnergyWave")
	# three trainees near each area's start (on a planet map: every area, with its own key and level)
	for area: String in zone.region_ids():
		var base: Dictionary = camp_in(zone,area)
		for i in 3:
			spawn({"key":"patrol_"+area,"name":"Hostile Trainee","level":rpg.ZONE_LEVELS.get(area,1),"look":game.schema.default_look("Human").merged({"outfitTint":3},true),
				"x":base.x+(0 if zone.def.terrain.has("path") else (i-1)*4),"z":base.z+i*4,"boss":false},i)
	if technique not in available_techniques():
		technique = "EnergyWave"
	game.slot.loadout.technique = technique
static func camp(world: RuleZone) -> Dictionary:
	return world.place(0 if world.def.terrain.has("path") else world.spawn.x+18,world.spawn.z+22)
static func camp_in(world: RuleZone,area: String) -> Dictionary:
	if not (world is RulePlanet):
		return camp(world)
	var sp: Dictionary = world.region_spawn(area)
	return {"x":float(sp.x)+18,"z":float(sp.z)+22}
func emit(event: String,value: Dictionary = {}) -> void:
	RuleRuntime.emit(events,event,value)
## Presentation is runtime state only; combat remains authoritative and keeps its original timing.
func skill_packet(context: Dictionary,phase: String,extra: Dictionary = {}) -> Dictionary:
	event_sequence += 1
	return context.merged({"phase":phase,"server_time":clock,"event_id":"%s:%s:%d:%d:%d" % [p.id,zone.id,get_instance_id(),int(clock*1000000),event_sequence]},true).merged(extra,true)
## The host chooses visual strike variants. This never schedules an extra hit.
static func combo_metadata(id: String,step: int,seed: int) -> Dictionary:
	var definition: Dictionary = RuleTables.table("skill_presentation").skills.get(id,{}).get("combo",{})
	if definition.is_empty(): return {}
	var length: int = int(definition.length)
	var current := posmod(step-1,length)+1
	var choices: Array = definition.strikes[current-1]
	var strike: String = choices[posmod(seed,choices.size())]
	return {"combo_step":current,"combo_length":length,"strike":strike,"finisher":current==length,"socket":"foot_r" if strike in ["spin_kick","axe_kick","knee"] else "hand_l" if strike in ["jab","hook"] else "hand_r"}
func style_busy() -> bool:
	return p.health>0 and (beam_held or melee_cd>0.00001 or clock<strike_until)
func begin_skill(id: String,phase: String = "release",charge: float = 0) -> Dictionary:
	if skill.get("move_id")!=id or skill.get("phase")!="prepare":
		cancel_skill("superseded")
		action_sequence += 1
		var profile: Dictionary = RuleTables.table("skill_presentation").skills.get(id,{})
		var ray := aim()
		skill = {"presentation_version":1,"move_id":id,"actor_id":p.id,"action_sequence":action_sequence,"started_at":clock,"seed":absi((str(p.id)+id+str(action_sequence)).hash()),"socket":profile.get("socket","cast_origin"),"pose":profile.get("pose","palm_shot"),"color":RuleRuntime.ki_color(game.slot.appearance),"origin":ray.origin,"direction":ray.dir,"target_id":p.get("lockTarget")}
	var recipe: Dictionary = RuleTables.table("skill_presentation").skills.get(id,{})
	skill.socket = recipe.get("phases",{}).get("prepare",{}).get("socket",recipe.get("socket","cast_origin")) if phase=="prepare" else recipe.get("socket","cast_origin")
	if phase=="release" and id in ["Melee","WolfFangFist"]:
		if id=="WolfFangFist":
			wolf_combo = wolf_combo%6+1 if clock-wolf_swing<=c.beamCooldown+c.comboWindow else 1
			wolf_swing = clock
		skill.merge(RuleStyles.move(p.style,maxi(1,combo),bool(p.get("dashing",false))) if id=="Melee" else combo_metadata(id,wolf_combo,int(skill.seed)),true)
	var style_tuning := RuleStyles.get_style(p.style)
	skill.style = p.style
	if not skill.has("move"): skill.move = id
	if not skill.has("chain_window"): skill.chain_window = style_tuning.chain_window
	if not skill.has("lunge"): skill.lunge = 0.0
	if not skill.has("strike_duration"): skill.strike_duration = float(recipe.get("release_window",.45))+float(recipe.get("recovery",.2))
	if phase=="release":
		strike_until = maxf(strike_until,clock+float(skill.strike_duration))
		skill.released_at = clock
		skill.hold_elapsed = maxf(0,clock-float(skill.started_at))
	skill.hold_min = recipe.get("hold_min",0)
	skill.release_window = recipe.get("release_window",.45)
	skill.recovery = recipe.get("recovery",.2)
	skill.phase = phase
	skill.charge = charge
	skill.until = clock+float(RuleTables.table("skill_presentation").skills.get(id,{}).get("max_duration",2))
	p.skillState = skill.duplicate(true)
	var packet := skill_packet(skill,phase,{"id":p.id,"kind":move_def(id).get("kind","melee"),"pos":p.pos,"combo":combo})
	emit("attack",packet)
	return skill.duplicate(true)
func emit_dodge() -> void:
	emit("attack",skill_packet({"presentation_version":1,"move_id":"UltraInstinctSign","actor_id":p.id,"action_sequence":action_sequence,"seed":event_sequence,"socket":"chest","pose":"evasive_step","origin":p.pos+Vector3.UP,"color":RuleRuntime.ki_color(game.slot.appearance)},"dodge",{"id":p.id,"pos":p.pos}))
func cancel_skill(reason: String = "interrupted") -> void:
	if skill.is_empty(): return
	emit("attack",skill_packet(skill,"cancel",{"id":p.id,"reason":reason,"pos":p.pos}))
	skill = {}; p.skillState = {}
func finish_skill() -> void:
	if skill.is_empty(): return
	emit("attack",skill_packet(skill,"recovery",{"id":p.id,"pos":p.pos}))
	skill = {}; p.skillState = {}
func notify(text: String) -> void:
	emit("notify",{"text":text})
func move_def(id: String) -> Dictionary:
	return c.starterMove if id=="EnergyWave" else moves.get(id,{})
func spawn(definition: Dictionary,index: int = 0) -> Dictionary:
	var health: float = (c.enemyHealth+(definition.level-1)*c.healthPerLevel)*(c.bossHealth if definition.get("boss",false) else 1)
	var position: Vector3 = zone.free_position({"x":definition.x,"z":definition.z})
	var enemy: Dictionary = definition.duplicate(true)
	enemy.merge({"id":"enemy:%s:%d" % [definition.key,index],"kind":"enemy","style":RuleStyles.normalize(definition.get("style",RuleStyles.npc_style(str(definition.key)))),"pos":position,"home":position,"vel":Vector3.ZERO,"health":health,"maxHealth":health,
		"ki":100.0,"maxKi":100.0,"yaw":PI,"onGround":true,"runSpeed":c.enemySpeed,"strength":1,"stun":0.0,"flying":false,"dashing":false,"charging":false,"blocking":false,
		"cooldown":0.0,"windup":0.0,"attackSerial":0,"attackKind":"jab","deadUntil":0.0,"hurtUntil":0.0},true)
	enemies.append(enemy)
	game.entities.append(enemy)
	return enemy
func set_story(story: RefCounted) -> void:
	_story = weakref(story)
	sync()
func sync() -> void:
	var definitions: Dictionary = {}
	if _story!=null and _story.get_ref()!=null:
		for d: Dictionary in _story.get_ref().encounters():
			definitions[str(d.get("uid",d.key))] = d
	for i in range(enemies.size()-1,-1,-1):
		var e: Dictionary = enemies[i]
		if (String(e.key).begins_with("patrol_") and not e.has("uid")) or definitions.has(str(e.get("uid",e.key))):
			continue
		enemies.remove_at(i)
		game.entities.erase(e)
		if p.lockTarget==e.id:
			p.lockTarget = null
	for uid: String in definitions:
		var d: Dictionary = definitions[uid]
		if not enemies.any(func(e: Dictionary) -> bool:return str(e.get("uid",e.key))==uid and (e.has("uid") or not String(e.key).begins_with("patrol_"))):
			spawn(d.merged({"look":d.look if d.get("look") is Dictionary else game.schema.default_look("Saiyan")},true),100+int(d.get("index",0)))
## A trainee you hit fights back, and so do the trainees standing right next to it.
func provoke(target: Dictionary) -> void:
	target.provoked = true
	if String(target.key).begins_with("patrol_"):
		for e: Dictionary in enemies:
			if e.key==target.key and e.health>0 and (e.pos as Vector3).distance_to(target.pos)<18.0:
				e.provoked = true
func hit(target: Dictionary,damage: float,source: Dictionary,finisher: bool = false,context: Dictionary = {}) -> void:
	if party!=null and party.get_ref()!=null:
		var owner: Variant = party.get_ref().game_for_player(str(target.id)) if target.get("kind")=="player" else party.get_ref().game_for_player(str(source.get("id","")))
		if owner!=null and owner.combat!=self:
			owner.combat.hit(target,damage,source,finisher,context)
			return
	if target.health<=0 or (target==p and p.get("evadeUntil",0)>clock):
		return
	if target.get("kind")=="enemy" and source.get("kind")=="player":
		provoke(target)
	if target==p:
		var instinct: Dictionary = forms.instinct_benefits(p,clock)
		if instinct.kind=="form":   # Ultra Instinct forms: UI_DODGES sure dodges, then UI_COOLDOWN seconds without
			if int(p.get("uiDodges",UI_DODGES))<=0 and clock>=float(p.get("uiRecharge",0)):
				p.uiDodges = UI_DODGES
				notify("Ultra Instinct is ready again: %d dodges." % UI_DODGES)
			var left: int = int(p.get("uiDodges",UI_DODGES))
			if left>0:
				p.uiDodges = left-1
				if p.uiDodges==0:
					p.uiRecharge = clock+UI_COOLDOWN
					notify("Ultra Instinct dodge! Instinct exhausted: back in %d s." % int(UI_COOLDOWN))
				else:
					notify("Ultra Instinct dodge! (%d left)" % p.uiDodges)
				emit_dodge()
				return
		elif clock>=p.get("dodgeReady",0) and p.ki>=instinct.cost and randf()<instinct.chance:
			RuleKi.try_spend_ki(p,instinct.cost)
			p.dodgeReady = clock+instinct.cooldown
			emit_dodge()
			notify("Ultra Instinct dodge!" if instinct.kind=="form" else "Instinct focus: dodged.")
			return
	if source==p:
		game.add_form_mastery(game.mastery.tuning.perHit)
	var hit_context: Dictionary = context if not context.is_empty() else impact_context if source==p and not impact_context.is_empty() else {"presentation_version":1,"move_id":"Melee","actor_id":source.id,"action_sequence":source.get("attackSerial",0),"seed":int(source.get("attackSerial",0)),"color":0xffdca0}
	hit_context = hit_context.duplicate(true)
	hit_context.style = RuleStyles.normalize(hit_context.get("style",source.get("style")))
	var style_tuning := RuleStyles.get_style(hit_context.style)
	var melee_hit: bool = hit_context.get("move_id")=="Melee"
	var guard_cost: float = c.guardCost*(float(style_tuning.guard_pressure) if melee_hit else 1.0)
	var amount: float = damage
	if target.blocking and target.ki>=guard_cost and not finisher:
		target.ki -= guard_cost
		amount *= c.guardDamage
	elif target.blocking and finisher:
		target.blocking = false
		target.stun = c.stunLimit
		notify("Guard broken!")
	if target==p and p.get("barrierUntil",0)>clock:
		amount *= c.shieldReduction
	amount = maxi(1,RuleRuntime.js_round(amount))
	target.health = maxf(0,target.health-amount)
	target.stun = minf(c.stunLimit,target.get("stun",0)+c.hitStun)
	target.hurtUntil = clock+0.2
	var delta: Vector3 = target.pos-source.pos
	var distance: float = maxf(1e-20,sqrt(delta.x*delta.x+delta.z*delta.z))
	if distance<1e-10:
		distance = 1.0
	var impulse: float = c.knockback*(float(style_tuning.knockback_scale) if melee_hit else 1.0)
	target.vel.x += delta.x/distance*impulse
	target.vel.z += delta.z/distance*impulse
	hit_context.merge(RuleStyles.reaction(hit_context.style,bool(hit_context.get("finisher",finisher)),amount<damage*.5),true)
	emit("damage",skill_packet(hit_context,"impact",{"id":target.id,"source_id":source.id,"target_id":target.id,"amount":amount,"pos":target.pos+Vector3(0,1.6,0),"blocked":amount<damage*0.5,"finisher":hit_context.get("finisher",finisher),"guard_breaker":finisher}))
	if target==p:
		last_damage = clock
		if p.form=="UltraEgo":
			p.egoBoost = minf(c.egoMaxBonus,p.get("egoBoost",0)+forms.forms.UltraEgo.damageGrowth)
	if target.health>0:
		return
	if target==p:
		p.flying = false
		p.dashing = false
		p.charging = false
		p.lockTarget = null
		p.form = ""
		cancel_skill("defeated")
		respawn_at = clock+c.respawnSeconds
		beam_held = false
		projectiles.clear()
		notify("You were defeated. Respawning at the safe area. Your quests and rewards are kept.")
	else:
		target.deadUntil = clock+(c.bossRespawn if target.boss else c.enemyRespawn)
		if p.lockTarget==target.id:
			p.lockTarget = null
		var xp: int = maxi(10,RuleRuntime.js_round(game.progression.xp_to_next(int(target.level))*rpg.RPG.killXp))
		var zeni: float = target.level*rpg.RPG.zeniPerLevel
		game.add_form_mastery(game.mastery.tuning.perKill)
		game.add_xp(xp)
		game.add_zeni(zeni)
		if _story!=null and _story.get_ref()!=null:
			_story.get_ref().enemy_defeated(target.key,zone.id)
		emit("enemyDefeated",{"id":target.id,"enemy":target.key,"zone":zone.id,"xp":xp,"zeni":zeni})
		notify("%s defeated · +%d XP · +%d zeni" % [target.name,xp,int(zeni)])
func locked() -> Dictionary:
	for e: Dictionary in enemies:
		if e.id==p.lockTarget and e.health>0:
			return e
	return {}
func target_in_front(distance: float) -> Dictionary:
	var lock: Dictionary = locked()
	if not lock.is_empty() and p.pos.distance_to(lock.pos)<=distance:
		return lock
	var candidates: Array = []
	for e: Dictionary in enemies:
		var delta: Vector3 = e.pos-p.pos
		var planar: float = sqrt(delta.x*delta.x+delta.z*delta.z)
		if e.health>0 and p.pos.distance_to(e.pos)<=distance and (planar<0.01 or (delta.x*sin(p.yaw)+delta.z*cos(p.yaw))/planar>c.meleeArc):
			candidates.append(e)
	candidates.sort_custom(func(x: Dictionary,y: Dictionary) -> bool:return p.pos.distance_to(x.pos)<p.pos.distance_to(y.pos))
	return candidates[0] if not candidates.is_empty() else {}
func aim() -> Dictionary:
	var e: Dictionary = locked()
	var origin: Vector3 = p.pos+Vector3(0,1.15*forms.forms.get(p.form,{}).get("size",1),0)
	var delta: Vector3 = e.pos+Vector3.UP-origin if not e.is_empty() else Vector3(sin(p.yaw),0,cos(p.yaw))
	return {"origin":origin,"dir":delta.normalized()}
func aim_state() -> Dictionary:
	var ray: Dictionary = aim()
	var e: Dictionary = locked()
	return ray.merged({"locked":not e.is_empty(),"point":e.pos+Vector3.UP if not e.is_empty() else ray.origin+ray.dir*c.beamRange})
func fire(id: String,charge: float = 0) -> bool:
	if id=="Kaioken":
		var error: Variant = game.kaioken.toggle()
		if skill.get("move_id")=="Kaioken": cancel_skill("toggle_complete")
		if error!=null:
			notify(error)
		return error==null
	if id in ["GodKi","FusionDance"]: return false
	var definition: Dictionary = move_def(id)
	if definition.get("kind")=="avatar":
		if not forms.can_manifest_avatar(game.slot,p):
			cancel_skill("requirements")
			notify("The Avatar requires learned training and active Perfected or True Ultra Instinct.")
			return false
		if avatar.remaining>0 or clock<avatar.readyAt:
			cancel_skill("cooldown")
			notify("Avatar cooldown: %ds." % ceili(maxf(0,avatar.readyAt-clock)))
			return false
	if definition.is_empty() or not RuleKi.try_spend_ki(p,definition.kiCost*p.kiCostScale):
		cancel_skill("insufficient_ki")
		notify("Not enough ki. Hold Charge to recover.")
		return false
	p.attackSerial += 1
	p.attackKind = "cross"
	impact_context = begin_skill(id,"release",charge)
	var ray: Dictionary = aim()
	var damage: float = c.meleeDamage*p.kiPower*definition.power*(1+charge)*game.kaioken.multiplier()*(1+p.get("egoBoost",0) if p.form=="UltraEgo" else 1)
	match definition.kind:
		"avatar":
			avatar.remaining = a.duration
			avatar.readyAt = clock+a.cooldown
			avatar.nextStrike = clock
			avatar.damage = damage
			avatar_context = impact_context.duplicate(true)
			notify("Ultra Instinct Energy Avatar manifested!")
		"utility":
			match id:
				"Regeneration":p.health = minf(p.maxHealth,p.health+p.maxHealth*c.utilityHeal)
				"SolarFlare":
					for e: Dictionary in enemies:
						if e.health>0 and p.pos.distance_to(e.pos)<c.utilityRange:
							e.stun = c.utilityDuration
				"EnergyField":p.barrierUntil = clock+c.utilityDuration
				"CandyBeam":
					var e: Dictionary = target_in_front(c.utilityRange)
					if not e.is_empty():
						hit(e,e.health if e.health<e.maxHealth*c.candyThreshold else c.candyDamage,p)
				"InstantTransmission":
					var e: Dictionary = target_in_front(c.lockRange)
					if not e.is_empty():
						p.pos = e.pos-Vector3(sin(e.yaw),0,cos(e.yaw))*c.teleportOffset
						emit("attack",skill_packet(impact_context,"impact",{"id":p.id,"pos":p.pos,"destination":p.pos}))
				"UltraInstinctSign":
					p.uiTechniqueUntil = clock+c.uiTechniqueDuration
					notify("Ultra Instinct Sign focus: small dodge chance, no form stat boost.")
				_:p.evadeUntil = clock+c.utilityDuration
		"melee":
			var e: Dictionary = target_in_front(c.meleeRange+1)
			if not e.is_empty():
				hit(e,damage,p,true)
		"beam","ultimate":
			var end: Vector3 = ray.origin+ray.dir*c.beamRange
			for e: Dictionary in enemies:
				if e.health>0 and segment_distance(e.pos+Vector3.UP,ray.origin,end)<c.beamRadius:
					hit(e,damage,p,true)
			emit("beam",skill_packet(impact_context,"release",{"from":ray.origin,"to":end,"color":RuleRuntime.ki_color(game.slot.appearance)}))
		_:
			serial += 1
			projectiles.append({"id":(p.id+":"+str(serial)) if party!=null else serial,"pos":ray.origin,"dir":ray.dir,"life":c.projectileLife,"damage":damage,"owner":p,"move_id":id,"presentation":impact_context.duplicate(true),"color":RuleRuntime.ki_color(game.slot.appearance)})
	impact_context = {}
	return true
func available_techniques() -> Array:
	var result: Array = ["EnergyWave"]
	for id: String in game.slot.moves:
		if moves.has(id) and (moves[id].power>0 or id in UTILITIES) and id not in result:
			result.append(id)
	if not game.kaioken.ranks().is_empty() and "Kaioken" not in result:
		result.append("Kaioken")
	return result
func set_technique(id: String) -> bool:
	if id not in available_techniques():
		return false
	if id!=technique:
		cancel_skill("technique_changed")
		beam_held = false; beam_time = 0
	technique = id
	game.slot.loadout.technique = id
	return true
func avatar_info() -> Dictionary:
	var allowed: bool = forms.can_manifest_avatar(game.slot,p)
	return {"active":avatar.remaining>0 and allowed,"remaining":avatar.remaining if allowed else 0,"cooldown":maxf(0,avatar.readyAt-clock),"pulse":avatar.pulse}
func avatar_state() -> Dictionary:
	return avatar_info().merged({"pos":p.pos,"yaw":p.yaw})
func snapshot() -> Dictionary:
	var e: Dictionary = locked()
	var target: Variant = null if e.is_empty() else {"id":e.id,"name":e.name,"level":e.level,"health":e.health,"maxHealth":e.maxHealth,"boss":e.boss}
	return {"style":p.style,"styleBusy":style_busy(),"skill":skill.duplicate(true),"kaioken":game.kaioken.snapshot(),"avatar":avatar_info(),"instinctFocus":maxf(0,p.get("uiTechniqueUntil",0)-clock),"instinctDodges":int(p.get("uiDodges",UI_DODGES)),"instinctRecharge":maxf(0,float(p.get("uiRecharge",0))-clock),"technique":technique,"techniqueName":move_def(technique).get("name"),
		"beamCharge":minf(1,beam_time/c.beamCharge),"meleeCd":melee_cd,"blastCd":blast_cd,"beamCd":beam_cd,"target":target,"respawn":maxf(0,respawn_at-clock) if respawn_at>0 else 0}
static func segment_distance(point: Vector3,start: Vector3,end: Vector3) -> float:
	var delta: Vector3 = end-start
	var weight: float = clampf((point-start).dot(delta)/delta.length_squared(),0,1) if delta.length_squared()>0 else 0.0
	return point.distance_to(start+delta*weight)
func update(dt: float,it: Dictionary) -> void:
	clock += dt
	if int(p.get("kaioken",0))!=last_kaioken:
		last_kaioken = int(p.get("kaioken",0))
		action_sequence += 1
		var ray := aim()
		var activation := {"presentation_version":1,"move_id":"Kaioken","actor_id":p.id,"action_sequence":action_sequence,"started_at":clock,"seed":action_sequence,"charge":0.0,"socket":"aura_root","pose":"strain_activation","origin":ray.origin,"direction":ray.dir,"target_id":p.lockTarget,"color":RuleRuntime.ki_color(game.slot.appearance),"rank":last_kaioken,"id":p.id,"kind":"utility","pos":p.pos}
		emit("attack",skill_packet(activation,"release" if last_kaioken>0 else "cancel"))
	if not skill.is_empty() and skill.phase!="prepare" and clock>=float(skill.until): finish_skill()
	melee_cd = maxf(0,melee_cd-dt)
	blast_cd = maxf(0,blast_cd-dt)
	beam_cd = maxf(0,beam_cd-dt)
	if clock>=sync_at:
		sync_at = clock+c.syncInterval
		sync()
	if p.health<=0:
		avatar.remaining = 0.0
		if respawn_at>0 and clock>=respawn_at:
			respawn_at = 0
			game.refresh_derived(true)
			p.pos = Vector3(zone.spawn.x,zone.height_at(zone.spawn.x,zone.spawn.z),zone.spawn.z)
			p.vel = Vector3.ZERO
			p.stun = 0.0
			p.onGround = true
			p.invulnerableUntil = clock+c.spawnProtection
			for e: Dictionary in enemies if party==null else []:
				e.pos = e.home
				e.health = e.maxHealth
				e.windup = 0.0
				e.cooldown = 0.0
			notify("Recovered. Return to your quest when you are ready.")
		return
	var lock: Dictionary = locked()
	if p.lockTarget!=null and (lock.is_empty() or p.pos.distance_to(lock.pos)>c.lockRange):
		p.lockTarget = null
	if it.get("lock_on",false):
		if p.lockTarget!=null:
			p.lockTarget = null
		else:
			var candidates: Array = enemies.filter(func(e: Dictionary) -> bool:return e.health>0 and p.pos.distance_to(e.pos)<c.lockRange)
			candidates.sort_custom(func(x: Dictionary,y: Dictionary) -> bool:return p.pos.distance_to(x.pos)<p.pos.distance_to(y.pos))
			p.lockTarget = candidates[0].id if not candidates.is_empty() else null
	lock = locked()
	if not lock.is_empty():
		p.yaw = atan2(lock.pos.x-p.pos.x,lock.pos.z-p.pos.z)
	if p.stun<=0 and not p.charging and not p.blocking:
		if it.get("melee",false) and melee_cd==0:
			var style_tuning := RuleStyles.get_style(p.style)
			combo = combo%4+1 if clock-last_swing<float(style_tuning.chain_window) else 1
			last_swing = clock
			melee_cd = float(style_tuning.cadence[combo-1])
			var target: Dictionary = target_in_front(float(style_tuning.reach)*forms.forms.get(p.form,{}).get("size",1))
			p.attackSerial += 1
			p.attackKind = ["jab","cross","hook","leg kick"][combo-1]
			impact_context = begin_skill("Melee")
			if not target.is_empty():
				hit(target,c.meleeDamage*float(style_tuning.damage_scale)*p.strength*game.kaioken.multiplier()*(1+p.get("egoBoost",0) if p.form=="UltraEgo" else 1)*(c.comboFinish if combo==4 else 1),p,combo==4)
		impact_context = {}
		if it.get("ki_blast",false) and blast_cd==0 and fire("KiBlast"):
			blast_cd = c.blastCooldown
		if it.get("beam",false) and beam_cd==0:
			if not beam_held or skill.get("move_id")!=technique: begin_skill(technique,"prepare")
			beam_held = true
			beam_time = minf(c.beamCharge,beam_time+dt)
			if skill.get("phase")=="prepare":
				skill.charge = beam_time/c.beamCharge
				var ray := aim()
				skill.origin = ray.origin; skill.direction = ray.dir
				p.skillState = skill.duplicate(true)
		if not it.get("beam",false) and beam_held:
			if fire(technique,beam_time/c.beamCharge):
				beam_cd = c.utilityCooldown if move_def(technique).kind=="utility" else c.beamCooldown
			beam_held = false
			beam_time = 0
	else:
		if beam_held: cancel_skill("interrupted")
		beam_held = false
		beam_time = 0
	if avatar.remaining>0:
		if not forms.can_manifest_avatar(game.slot,p):
			avatar.remaining = 0.0
		else:
			avatar.remaining = maxf(0,avatar.remaining-dt)
			if avatar.remaining>0 and clock>=avatar.nextStrike:
				avatar.nextStrike += a.strikeInterval
				avatar.pulse += 1
				for enemy: Dictionary in enemies:
					var dx: float = enemy.pos.x-p.pos.x
					var dz: float = enemy.pos.z-p.pos.z
					var along: float = dx*sin(p.yaw)+dz*cos(p.yaw)
					if enemy.health>0 and along>=0 and along<=a.range and absf(dx*cos(p.yaw)-dz*sin(p.yaw))<=a.halfWidth and absf(enemy.pos.y-p.pos.y)<=a.verticalReach:
						hit(enemy,avatar.damage,p,true,avatar_context)
				emit("avatarStrike",skill_packet(avatar_context,"impact",{"pos":p.pos,"yaw":p.yaw,"pulse":avatar.pulse}))
	if p.form!="UltraEgo":
		p.egoBoost = 0.0
	if clock-last_damage>c.regenDelay and not game.kaioken.snapshot().active:
		p.health = minf(p.maxHealth,p.health+p.maxHealth*c.playerRegen*dt)
	if not world_authority: return
	for i in range(projectiles.size()-1,-1,-1):
		var b: Dictionary = projectiles[i]
		var old: Vector3 = b.pos
		b.life -= dt
		b.pos += b.dir*c.projectileSpeed*dt
		for target: Dictionary in enemies:
			if target.health>0 and segment_distance(target.pos+Vector3.UP,old,b.pos)<c.projectileRadius:
				hit(target,b.damage,b.owner,false,b.get("presentation",{}))
				b.life = 0.0
				break
		if b.life<=0 or b.pos.y<zone.height_at(b.pos.x,b.pos.z):
			projectiles.remove_at(i)
	for e: Dictionary in enemies:
		var victim: Dictionary = party.get_ref().nearest_player(zone.id,e.pos,p) if party!=null and party.get_ref()!=null else p
		if e.health<=0:
			if clock>=e.deadUntil and victim.pos.distance_to(e.home)>c.respawnSafeRange:
				e.health = e.maxHealth
				e.pos = e.home
				e.stun = 0.0
				e.windup = 0.0
			continue
		var distance: float = e.pos.distance_to(victim.pos)
		var home_distance: float = e.pos.distance_to(e.home)
		# trainees (patrols) leave you alone until you hit them (user request 2026-11-04); quest enemies always fight
		var peaceful: bool = String(e.key).begins_with("patrol_") and not e.get("provoked",false)
		e.cooldown = maxf(0,e.cooldown-dt)
		e.stun = maxf(0,e.stun-dt)
		if peaceful and home_distance<0.5:
			e.aggro = false
			e.windup = 0.0
			e.health = minf(e.maxHealth,e.health+e.maxHealth*dt*c.enemyRegen)
			continue
		if distance>c.aggroRange and not e.get("aggro",false) and home_distance<0.5:
			e.provoked = false   # you left: it calms down
			e.health = minf(e.maxHealth,e.health+e.maxHealth*dt*c.enemyRegen)
			continue
		var returning: bool = peaceful or distance>c.leashRange or home_distance>c.leashRange or victim.pos.y-e.pos.y>5
		var goal: Vector3 = e.home if returning else victim.pos
		var delta: Vector3 = goal-e.pos
		var planar: float = sqrt(delta.x*delta.x+delta.z*delta.z)
		if planar==0:
			planar = 1
		e.aggro = not returning
		if returning and home_distance<1.0:
			e.provoked = false   # back at its spot: calm again
		if returning:
			e.windup = 0.0
			e.health = minf(e.maxHealth,e.health+e.maxHealth*dt*c.enemyRegen)
		if e.windup>0:
			e.windup -= dt
			if e.windup<=0 and e.stun<=0 and distance<c.enemyRange+0.5 and not victim.get("invulnerableUntil",0)>clock:
				e.attackSerial += 1
				e.attackKind = "cross"
				var npc_move := RuleStyles.move(e.style,(int(e.attackSerial)-1)%4+1)
				var npc_context := npc_move.merged({"presentation_version":1,"move_id":"Melee","actor_id":e.id,"action_sequence":e.attackSerial,"started_at":clock,"seed":absi((str(e.id)+str(e.attackSerial)).hash()),"color":0xffdca0,"origin":e.pos+Vector3.UP,"direction":(victim.pos-e.pos).normalized(),"target_id":victim.id,"socket":npc_move.socket,"pose":"melee_combo","charge":0.0},true)
				emit("attack",skill_packet(npc_context,"release",{"id":e.id,"kind":"melee","pos":e.pos,"combo":npc_move.combo_step}))
				hit(victim,(c.enemyDamage+(e.level-1)*c.enemyDamagePerLevel)*(c.bossDamage if e.boss else 1),e,false,npc_context)
		elif not returning and distance<c.enemyRange and e.cooldown==0 and e.stun==0:
			e.windup = c.enemyWindup
			e.cooldown = c.enemyCooldown
		var previous: Vector3 = e.pos
		var moving: bool = (planar>0.5 if returning else distance>c.enemyRange*0.85) and e.windup<=0
		movement.step(e,{"move_x":delta.x/planar if moving else 0,"move_z":delta.z/planar if moving else 0},dt,zone)
		RuleCollision.resolve(e,zone,previous)
