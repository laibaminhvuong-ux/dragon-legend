class_name SkillCatalog
extends RefCounted
const VERSION := 1
static func all() -> Dictionary: return RuleTables.table("skill_presentation").get("skills",{})
static func get_skill(id: String) -> Dictionary: return all().get(id,{})
static func active(id: String) -> bool: return get_skill(id).get("availability")=="active"
static func budget(quality: String) -> Dictionary:
	var tiers: Dictionary = RuleTables.table("skill_presentation").get("quality",{})
	return tiers.get(quality,tiers.get("medium",{"effects":28,"segments":24,"particles":20}))
static func color(packet: Dictionary,profile: Dictionary) -> Color:
	var value: int = int(packet.get("color",profile.get("accent",0x63cfff)))
	return Color.hex((value<<8)|0xff)
