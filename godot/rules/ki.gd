class_name RuleKi
extends RefCounted
static func add_ki(entity: Dictionary, amount: float) -> float:
	entity.ki = clampf(entity.ki+amount,0,entity.maxKi)
	return entity.ki
static func try_spend_ki(entity: Dictionary, amount: float) -> bool:
	if entity.ki < amount:
		return false
	entity.ki -= amount
	return true
static func regen_ki(entity: Dictionary, dt: float) -> void:
	if entity.ki < entity.maxKi:
		add_ki(entity,float(RuleTables.table("stats").KI_REGEN_PER_SECOND)*(entity.maxKi/100.0)*dt)
