class_name RuleProgression
extends RefCounted
const Tables = preload("res://rules/tables.gd")
var stats: Dictionary
var races: Dictionary
var forms: Dictionary

func _init(data: Object = null) -> void:
	stats = Tables.table("stats", data)
	races = Tables.table("races", data)
	forms = Tables.table("forms", data)

func xp_to_next(level: int) -> int:
	return 0 if level >= int(stats.MAX_LEVEL) else floori(100.0 * pow(level, 1.5))

func xp_for_levels(level: int, count: float) -> int:
	var total: int = 0
	var i: int = 0
	while i < minf(50.0, maxf(0.0, count)):
		total += xp_to_next(level + i)
		i += 1
	return total

func apply_xp_bonus(race_id: String, level: int, amount: float) -> float:
	var bonus: Dictionary = races.get(race_id, {}).get("xpBonusBelowLevel", {})
	return floor(amount * (1.0 + float(bonus.bonus))) if not bonus.is_empty() and level < int(bonus.level) else amount

func points(slot: Dictionary, stat: String) -> float:
	return float(slot.get("stats", {}).get(stat, 0)) + float(races.get(slot.race, {}).get("statBonus", {}).get(stat, 0))

func form_multiplier(form_id: String) -> float:
	return float(forms.get(form_id, {}).get("multiplier", 1.0))

func form_for_race(form_id: String, race_id: String) -> bool:
	var form: Dictionary = forms.get(form_id, {})
	return not form.is_empty() and not form.get("legacy", false) and race_id in form.get("races", [form.get("race", "")])

func forms_at_level(race_id: String, level: int) -> Array:
	var out: Array = []
	for id: String in races.get(race_id, {}).get("forms", []):
		if form_for_race(id, race_id) and int(forms[id].unlockLevel) <= level:
			out.append(id)
	return out

func derive(slot: Dictionary, form_id: String = "") -> Dictionary:
	var race: Dictionary = races.get(slot.race, {})
	var mult: float = form_multiplier(form_id)
	var level: int = int(slot.level)
	var health: float = float(stats.BASE_HEALTH) + (level - 1) * float(stats.HEALTH_PER_LEVEL) + points(slot, "Health") * float(stats.HEALTH_PER_POINT)
	var ki: float = float(stats.BASE_KI) + (level - 1) * float(stats.KI_PER_LEVEL) + points(slot, "Ki") * float(stats.KI_PER_POINT)
	var speed: float = minf(float(stats.MAX_RUN_SPEED), float(stats.BASE_RUN_SPEED) + points(slot, "Speed") * float(stats.RUN_SPEED_PER_POINT) * mult) * float(forms.get(form_id, {}).get("speedFactor", 1.0))
	var total: float = 0.0
	for stat: String in stats.STAT_NAMES:
		total += points(slot, stat)
	return {"maxHealth":floori(health * mult), "maxKi":ki, "kiCostScale":(float(stats.BASE_KI) + (level - 1) * float(stats.KI_PER_LEVEL)) / float(stats.BASE_KI),
		"runSpeed":speed, "strength":(1.0 + points(slot, "Strength") * 0.02) * mult, "kiPower":(1.0 + points(slot, "KiPower") * 0.02) * mult,
		"powerLevel":floori((level * 50.0 + total * 25.0) * float(race.get("powerMultiplier", 1.0)) * mult)}

func add_xp(slot: Dictionary, amount: float) -> int:
	if not is_finite(amount) or amount <= 0 or int(slot.level) >= int(stats.MAX_LEVEL):
		return 0
	slot.xp += floori(amount)
	var gained: int = 0
	while int(slot.level) < int(stats.MAX_LEVEL) and slot.xp >= xp_to_next(int(slot.level)):
		slot.xp -= xp_to_next(int(slot.level))
		slot.level += 1
		slot.statPoints += int(stats.POINTS_PER_LEVEL)
		gained += 1
	if int(slot.level) >= int(stats.MAX_LEVEL):
		slot.xp = 0
	return gained

func spend_stat_point(slot: Dictionary, stat: String, amount: Variant = 1) -> Variant:
	if stat not in stats.STAT_NAMES:
		return "Unknown stat"
	if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)) or amount < 1:
		return "Bad amount"
	if slot.statPoints < amount:
		return "Not enough stat points"
	slot.statPoints -= amount
	slot.stats[stat] = slot.stats.get(stat, 0) + amount
	return null
