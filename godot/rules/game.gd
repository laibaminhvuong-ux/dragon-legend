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
static func get_zone(id: String) -> RuleZone:
	var key: String = id if RuleTables.table("zones").has(id) else "earth_plains"
	if not _zones.has(key):
		_zones[key] = RuleZone.new(key)
	return _zones[key]
static func empty_intents() -> Dictionary:
	return {"move_x":0,"move_z":0,"jump":false,"dash":false,"flight":false,"ascend":false,"descend":false,"fly_pitch":0,"charge":false,"melee":false,"block":false,"ki_blast":false,"beam":false,"transform":false,"kaioken":false,"lock_on":false,"interact":false}
func _init(index: int = 0,saved: Dictionary = {},bus: Object = null) -> void:
	slot_index = index
	slot = saved if not saved.is_empty() else schema.new_slot(schema.default_look())
	events = bus
	zone = get_zone(slot.zone)
	var spawn: Vector3 = RuleRuntime.vector(slot.position) if slot.get("position")!=null else Vector3(zone.spawn.x,zone.height_at(zone.spawn.x,zone.spawn.z),zone.spawn.z)
	player = {"id":"player","kind":"player","pos":spawn,"vel":Vector3.ZERO,"yaw":0.0,"onGround":spawn.y<=zone.height_at(spawn.x,spawn.z),"form":"",
		"health":0.0,"maxHealth":0.0,"ki":0.0,"maxKi":0.0,"kiCostScale":1.0,"runSpeed":0.0,"strength":1.0,"kiPower":1.0,"powerLevel":0,
		"flying":false,"dashing":false,"charging":false,"blocking":false,"stun":0.0,"lockTarget":null,"kaioken":0,"attackSerial":0,"attackKind":"jab"}
	entities = [player]
	refresh_derived(true)
	kaioken = RuleKaioken.new(self)
	combat = RuleCombat.new(self,events)
func emit(event: String,payload: Dictionary = {}) -> void:
	RuleRuntime.emit(events,event,payload)
func refresh_derived(fill_up: bool = false) -> void:
	var d: Dictionary = progression.derive(slot,player.form)
	var hp_fraction: float = player.health/player.maxHealth if player.maxHealth>0 else 1.0
	for key: String in ["maxHealth","maxKi","kiCostScale","runSpeed","strength","kiPower","powerLevel"]:
		player[key] = d[key]
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
	if id!="" and player.ki<forms.forms[id].kiDrain*player.kiCostScale:
		return "Charge more ki first."
	player.form = id
	if id!="UltraEgo":
		player.egoBoost = 0.0
	refresh_derived()
	kaioken.update(0)
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
		var unlocked: Array = forms.usable_forms(slot)
		var i: int = (unlocked.find(player.form)+1) % (unlocked.size()+1)
		var next: String = unlocked[i] if i<unlocked.size() else ""
		if next!="" and player.ki<forms.forms[next].kiDrain*player.kiCostScale:
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
	if not player.flying and not player.dashing and not player.charging and player.form=="" and player.health>0:
		RuleKi.regen_ki(player,dt)
	player.stun = maxf(0,player.stun-dt)
func hud() -> Dictionary:
	var form_name: String = forms.forms.get(player.form,{}).get("name",player.form) if player.form!="" else "Base"
	if player.kaioken>0:
		form_name += " + Kaiyoken x%d" % int(player.kaioken)
	return {"slot":slot_index,"race":slot.race,"raceName":progression.races.get(slot.race,{}).get("name",slot.race),"form":player.form,"formName":form_name,
		"level":slot.level,"xp":slot.xp,"xpNext":progression.xp_to_next(int(slot.level)),"statPoints":slot.statPoints,"zeni":slot.zeni,
		"health":player.health,"maxHealth":player.maxHealth,"ki":floori(player.ki),"maxKi":player.maxKi,"powerLevel":floori(player.powerLevel*(kaioken.multiplier() if kaioken!=null else 1)),
		"flying":player.flying,"charging":player.charging,"dashing":player.dashing,"blocking":player.blocking,"lockTarget":player.lockTarget,"zone":zone.id,"zoneName":zone.name}
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
func to_save() -> Dictionary:
	slot.position = RuleRuntime.position(player.pos)
	slot.playedAt = int(Time.get_unix_time_from_system()*1000)
	return slot
