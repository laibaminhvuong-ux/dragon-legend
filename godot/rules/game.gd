class_name RuleGame
extends RefCounted
static var _zones: Dictionary = {}
var slot_index: int
var slot: Dictionary
var zone: RuleZone
var player: Dictionary
var entities: Array = []
var time: float = 0
var events: Object
var progression := RuleProgression.new()
var schema := RuleSchema.new()
var forms := RuleForms.new()
var mastery := RuleMastery.new()
var movement := RuleMovement.new()
var kaioken: RefCounted
var combat: RefCounted
## The loaded map for an area: its planet's map (shared by every area on it) or the area itself.
static func get_zone(id: String) -> RuleZone:
	var key: String = id if RuleTables.table("zones").has(id) else "earth_plains"
	var pid := RulePlanet.planet_of(key)
	var cache_key: String = "planet:" + pid if pid != "" else key
	if not _zones.has(cache_key):
		_zones[cache_key] = RulePlanet.new(pid) if pid != "" else RuleZone.new(key)
	return _zones[cache_key]
static func empty_intents() -> Dictionary:
	return {"move_x":0,"move_z":0,"jump":false,"dash":false,"flight":false,"ascend":false,"descend":false,"fly_pitch":0,"charge":false,"melee":false,"block":false,"ki_blast":false,"beam":false,"transform":false,"kaioken":false,"lock_on":false,"interact":false,"sprint":true}
func _init(index: int = 0,saved: Dictionary = {},bus: Object = null) -> void:
	slot_index = index
	slot = saved if not saved.is_empty() else schema.new_slot(schema.default_look())
	slot.style = RuleStyles.normalize(slot.get("style"))
	events = bus
	zone = get_zone(slot.zone)
	if not zone.has_region(slot.zone):
		slot.zone = zone.id
	# positions saved before the open world were local to the area; on a planet map they move to the area's spot once
	if zone is RulePlanet and slot.get("position")!=null and slot.get("mapSpace")!=zone.id:
		var p: Dictionary = (zone as RulePlanet).to_planet(slot.zone,slot.position)
		slot.position = {"x":p.x,"y":p.y,"z":p.z}
	if zone is RulePlanet:
		slot.mapSpace = zone.id
	else:
		slot.erase("mapSpace")
	var start: Dictionary = zone.region_spawn(slot.zone)
	var spawn: Vector3 = RuleRuntime.vector(slot.position) if slot.get("position")!=null else Vector3(start.x,zone.height_at(start.x,start.z),start.z)
	player = {"id":"player","kind":"player","style":slot.style,"pos":spawn,"vel":Vector3.ZERO,"yaw":0.0,"onGround":spawn.y<=zone.height_at(spawn.x,spawn.z),"form":"",
		"health":0.0,"maxHealth":0.0,"ki":0.0,"maxKi":0.0,"kiCostScale":1.0,"runSpeed":0.0,"strength":1.0,"kiPower":1.0,"powerLevel":0,
		"flying":false,"sprinting":false,"dashing":false,"charging":false,"blocking":false,"stun":0.0,"lockTarget":null,"kaioken":0,"attackSerial":0,"attackKind":"jab"}
	if slot.get("position")==null and def_has_spawn_yaw():
		player.yaw = float(zone.def.spawnYaw)
	if slot.get("returnYaw")!=null:   # back outside a building's door, facing away from it
		player.yaw = float(slot.returnYaw)
		slot.erase("returnYaw")
	entities = [player]
	refresh_derived(true)
	kaioken = RuleKaioken.new(self)
	combat = RuleCombat.new(self,events)
func emit(event: String,payload: Dictionary = {}) -> void:
	RuleRuntime.emit(events,event,payload)
## User tuning (2026-11-03): every Ki cost is this much of the classic game's, and a form costs
## TRANSFORM_COST_SECONDS of its old per-second drain once when you transform (no drain while in it).
const KI_COST_EASE := 0.75
const TRANSFORM_COST_SECONDS := 5.0
func transform_cost(id: String) -> float:
	if id=="" or not forms.forms.has(id):
		return 0.0
	var f: Dictionary = forms.forms[id]
	return f.kiDrain*TRANSFORM_COST_SECONDS*player.kiCostScale*(0.7 if "GodKi" in slot.moves else 1.0)*(0.8 if slot.story.items.get("instinctMastery",0) and f.get("path")=="instinct" else 1.0)
## Usable forms in the race's own order (unlock order is random-looking), then any others.
func form_order() -> Array:
	var usable: Array = forms.usable_forms(slot)
	var race_list: Array = progression.races.get(slot.race,{}).get("forms",[])
	var out: Array = race_list.filter(func(id: String) -> bool:return id in usable)
	for id: String in usable:
		if id not in out:
			out.append(id)
	return out
## Favourite forms the player pinned, in form order (only forms they can use right now).
func favorite_forms() -> Array:
	var favs: Array = slot.loadout.get("favoriteForms",[])
	return form_order().filter(func(id: String) -> bool:return id in favs)
func toggle_favorite_form(id: String) -> Variant:
	if not forms.forms.has(id) or id not in forms.usable_forms(slot):
		return "Unlock this form first."
	var favs: Array = slot.loadout.get("favoriteForms",[]).duplicate()
	if id in favs:
		favs.erase(id)
	else:
		favs.append(id)
	slot.loadout.favoriteForms = favs
	return null
func refresh_derived(fill_up: bool = false) -> void:
	var d: Dictionary = progression.derive(slot,player.form)
	var hp_fraction: float = player.health/player.maxHealth if player.maxHealth>0 else 1.0
	for key: String in ["maxHealth","maxKi","kiCostScale","runSpeed","strength","kiPower","powerLevel"]:
		player[key] = d[key]
	player.kiCostScale *= KI_COST_EASE
	player.health = d.maxHealth if fill_up else RuleRuntime.js_round(d.maxHealth*hp_fraction)
	player.ki = d.maxKi if fill_up else minf(player.ki,d.maxKi)
	emit("stats",hud())
func add_form_mastery(amount: float) -> Array:
	if player.form=="" or player.health<=0:
		return []
	var evolved: Array = mastery.gain_form_mastery(slot,player.form,amount)
	if not evolved.is_empty():
		player.form = evolved.back()
		refresh_derived()
		emit("notify",{"text":"Mastery evolution: %s!" % forms.forms[player.form].name})
	return evolved
func select_form(id: String) -> Variant:
	if player.health<=0 or player.stun>0:
		return "You cannot transform right now."
	if id!="" and id not in forms.usable_forms(slot):
		return "Unlock this form, its level and its chosen path first."
	if id!="" and id!=player.form and not RuleKi.try_spend_ki(player,transform_cost(id)):
		return "Charge more ki first."
	player.form = id
	if id!="UltraEgo":
		player.egoBoost = 0.0
	refresh_derived()
	kaioken.update(0)
	return null
## Menu command; the host owns validation and refuses switching while a strike/channel is active.
func set_style(id: String) -> Variant:
	if not RuleStyles.valid(id): return "Unknown fighting style."
	if id==player.style: return null
	if combat!=null and combat.style_busy(): return "Finish your current strike before changing fighting style."
	slot.style = id; player.style = id
	if combat!=null:
		combat.cancel_skill("style_changed")
		combat.combo = 0; combat.last_swing = -100.0
		emit("stats",hud())
	return null
func customize_appearance(changes: Dictionary) -> Variant:
	var next: Dictionary = {"race":slot.race}
	next.merge(slot.appearance,true)
	next.merge(changes,true)
	if next.race!=slot.race:
		return "Choose a new character slot to change race."
	if next.outfit not in slot.outfits or not schema.outfit_allowed(next.outfit,slot.race):
		return "You do not own that outfit."
	var checked: Dictionary = next.duplicate()
	checked.outfit = "TurtleGi"
	var error: Variant = schema.validate_look(checked)
	if error!=null:
		return error
	next.erase("race")
	slot.appearance.merge(next,true)
	return null
func choose_form_path(path: String) -> Variant:
	var error: Variant = forms.choose_form_path(slot,path)
	if error==null:
		emit("notify",{"text":"Chosen transformation path: %s. Speak to its trainers for unlock quests." % path})
	return error
func equip_accessory(id: String) -> Variant:
	var accessory: Dictionary = RuleTables.table("accessories").get(id,{})
	if accessory.is_empty() or (accessory.get("after")!=null and slot.quests.get(accessory.after,{}).get("status") not in ["done","repeatable"]):
		return "Complete the accessory's unlock quest first."
	slot.loadout.accessory = id
	slot.appearance.accessory = id
	return null
func equip_outfit(id: String) -> bool:
	if id not in slot.outfits or not schema.outfit_allowed(id,slot.race):
		return false
	slot.appearance.outfit = id
	return true
func update(dt: float,intents: Dictionary = {}) -> void:
	if not is_finite(dt) or dt<=0:
		return
	time += dt
	slot.playTime += dt
	var previous: Vector3 = player.pos
	if player.health>0:
		movement.step(player,intents,dt,zone)
	RuleCollision.resolve(player,zone,previous)
	if intents.get("transform",false) and player.health>0 and player.stun<=0:
		var unlocked: Array = form_order()
		var i: int = (unlocked.find(player.form)+1) % (unlocked.size()+1)
		var next: String = unlocked[i] if i<unlocked.size() else ""
		if next!="" and not RuleKi.try_spend_ki(player,transform_cost(next)):
			emit("notify",{"text":"Charge more ki before transforming."})
		else:
			player.form = next
			refresh_derived()
			emit("notify",{"text":forms.forms[next].name if next!="" else "Returned to base form."})
		if unlocked.is_empty():
			emit("notify",{"text":"Complete your race's transformation quests to unlock a form."})
	if intents.get("kaioken",false):
		var error: Variant = kaioken.toggle()
		if error!=null:
			emit("notify",{"text":error})
	kaioken.update(dt)
	combat.update(dt,intents)
	if player.form!="" and (player.charging or player.vel.length()>0.5):
		add_form_mastery(mastery.tuning.perSecond*dt)
	# Ki refills by itself only in base form (user tuning 2026-11-03); in a form only charging refills it.
	if not player.dashing and not player.charging and player.form=="" and player.health>0:
		RuleKi.regen_ki(player,dt)
	player.stun = maxf(0,player.stun-dt)
func hud() -> Dictionary:
	var form_name: String = forms.forms.get(player.form,{}).get("name",player.form) if player.form!="" else "Base"
	if player.kaioken>0:
		form_name += " + Kaiyoken x%d" % int(player.kaioken)
	return {"slot":slot_index,"race":slot.race,"style":player.style,"styleName":RuleStyles.get_style(player.style).name,"raceName":progression.races.get(slot.race,{}).get("name",slot.race),"form":player.form,"formName":form_name,
		"level":slot.level,"xp":slot.xp,"xpNext":progression.xp_to_next(int(slot.level)),"statPoints":slot.statPoints,"zeni":slot.zeni,
		"health":player.health,"maxHealth":player.maxHealth,"ki":floori(player.ki),"maxKi":player.maxKi,"powerLevel":floori(player.powerLevel*(kaioken.multiplier() if kaioken!=null else 1)),
		"flying":player.flying,"charging":player.charging,"dashing":player.dashing,"blocking":player.blocking,"lockTarget":player.lockTarget,"zone":current_region(),"zoneName":RuleTables.table("zones").get(current_region(),{}).get("name",zone.name),"map":zone.id}
func add_xp(amount: float) -> int:
	var gained: int = progression.add_xp(slot,amount)
	if gained>0:
		refresh_derived(true)
		emit("levelup",{"level":slot.level,"gained":gained})
		emit("notify",{"text":"Level up! You are now level %d." % int(slot.level)})
	else:
		emit("stats",hud())
	return gained
func spend_stat_point(stat: String,amount: Variant = 1) -> Variant:
	var error: Variant = progression.spend_stat_point(slot,stat,amount)
	if error==null:
		refresh_derived()
	return error
func add_zeni(amount: float) -> void:
	slot.zeni = maxf(0,slot.zeni+floor(amount))
	emit("stats",hud())
## The area the player is in now (on a planet map: the last area they were in when out in the countryside).
func current_region() -> String:
	var here: String = zone.region_at(player.pos.x,player.pos.z)
	return here if here!="" else str(slot.zone)
## Set when the player sets off for another world: every later save of this session (the play scene saves again
## while closing) keeps that destination and its arrival point instead of the spot the player left.
var leaving_to := ""
## With leaving_to: where to arrive (a world position, e.g. back outside a building's door) instead of the spawn.
var leaving_position: Variant = null
func def_has_spawn_yaw() -> bool:
	return zone.def.has("spawnYaw")

## Enters a building's interior map (a door from zone.doors()); remembers where to come back to. Returns the
## interior zone id (the play scene travels there), or a refusal String.
func enter_building(door: Dictionary) -> Variant:
	var target := str(door.get("interior", ""))
	if target=="" or not RuleTables.table("zones").has(target):
		return "This door is locked."
	if player.health<=0:
		return "You can't do that now."
	var out := Vector3(float(door.x)+sin(float(door.yaw))*1.6,0.0,float(door.z)+cos(float(door.yaw))*1.6)
	out.y = zone.height_at(out.x,out.z)+0.1
	slot.returnTo = {"zone":current_region(),"position":RuleRuntime.position(out),"yaw":float(door.yaw),"mapSpace":slot.get("mapSpace")}
	leaving_to = target
	leaving_position = null
	return target

## Leaves an interior map through its exit: back outside the door you came in by. Returns the zone id to travel to.
func leave_building() -> Variant:
	var back: Variant = slot.get("returnTo")
	if not back is Dictionary:
		return "earth_plains"
	leaving_to = str(back.zone)
	leaving_position = back.position
	slot.returnYaw = float(back.get("yaw",0.0))
	if back.get("mapSpace")!=null:
		slot.mapSpace = back.mapSpace
	slot.erase("returnTo")
	return leaving_to

func to_save() -> Dictionary:
	if leaving_to!="":
		slot.zone = leaving_to
		slot.position = leaving_position
		slot.playedAt = int(Time.get_unix_time_from_system()*1000)
		return slot
	slot.position = RuleRuntime.position(player.pos)
	slot.zone = current_region()
	slot.playedAt = int(Time.get_unix_time_from_system()*1000)
	return slot
