class_name RuleKaioken
extends RefCounted
var _game: WeakRef
var game: Variant:
	get:return _game.get_ref()
var p: Dictionary
var forms := RuleForms.new()
var tuning: Dictionary = RuleTables.table("kaioken")
var active: int = 0
var remaining: float = 0
var cooldown: float = 0
func _init(owner_game: RefCounted) -> void:
	_game = weakref(owner_game)
	p = owner_game.player
func ranks() -> Array:
	var result: Array = [2] if "Kaioken" in game.slot.moves or "Kaioken" in game.slot.forms or "Kaioken10" in game.slot.forms else []
	if "Kaioken10" in game.slot.forms and forms.form_available(game.slot,"Kaioken10"):
		result.append(10)
	return result
func compatible() -> bool:
	return p.form not in ["Kaioken","Kaioken10"] and (p.form=="" or game.slot.race in RuleForms.FAMILY)
func stop() -> void:
	if active>0:
		cooldown = tuning.cooldown
	active = 0
	remaining = 0
	p.kaioken = 0
func select(rank: int) -> Variant:
	if rank not in ranks():
		return "Complete the Kaiyoken training for that intensity."
	if active>0:
		return "Switch Kaiyoken off before changing intensity."
	game.slot.loadout.kaiokenRank = rank
	return null
func toggle() -> Variant:
	if active>0:
		stop()
		return null
	if p.health<=0 or p.stun>0:
		return "You cannot activate Kaiyoken right now."
	if not compatible():
		return "Use base form or a Saiyan transformation; Kaiyoken cannot stack with itself."
	var rank: int = int(game.slot.loadout.get("kaiokenRank",2))
	if rank not in ranks():
		return "Learn Kaiyoken from King Kae first."
	if cooldown>0:
		return "Kaiyoken cooldown: %ds." % ceili(cooldown)
	var tier: Dictionary = tuning.tiers[str(rank)]
	if p.health<=p.maxHealth*tuning.minHealth or p.ki<tier.kiDrain*p.kiCostScale:
		return "Recover health and charge more Ki before using Kaiyoken."
	active = rank
	remaining = tier.duration
	p.kaioken = rank
	return null
func multiplier() -> float:
	return float(tuning.tiers[str(active)].multiplier) if active>0 and compatible() and p.health>0 else 1.0
func snapshot() -> Dictionary:
	return {"active":active>0,"rank":active if active>0 else game.slot.loadout.get("kaiokenRank",2),"remaining":remaining,"cooldown":cooldown,"multiplier":multiplier()}
func update(dt: float) -> void:
	cooldown = maxf(0,cooldown-dt)
	if active==0:
		return
	var tier: Dictionary = tuning.tiers[str(active)]
	remaining = maxf(0,remaining-dt)
	if not compatible() or p.health<=p.maxHealth*tuning.minHealth or remaining<=0 or active not in ranks() or not RuleKi.try_spend_ki(p,tier.kiDrain*p.kiCostScale*dt):
		stop()
		return
	p.health = maxf(p.maxHealth*tuning.minHealth,p.health-p.maxHealth*tier.healthDrain*dt)
	if p.health<=p.maxHealth*tuning.minHealth:
		stop()
