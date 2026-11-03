class_name RuleForms
extends RefCounted
const FAMILY := ["Saiyan","HalfSaiyan"]
var progression := RuleProgression.new()
var forms: Dictionary = RuleTables.table("forms")
var combat: Dictionary = RuleTables.table("combat")
func form_for_race(id: String,race: String) -> bool:
	return progression.form_for_race(id,race)
static func has_form_path(slot: Dictionary,path: String) -> bool:
	return slot.get("loadout",{}).get("testAllPaths",false)==true or slot.get("loadout",{}).get("formPath")==path
func form_available(slot: Dictionary,id: String) -> bool:
	var form: Dictionary = forms.get(id,{})
	return form_for_race(id,slot.race) and slot.level>=form.unlockLevel and (not form.has("path") or has_form_path(slot,form.path))
func usable_forms(slot: Dictionary) -> Array:
	return slot.forms.filter(func(id: String) -> bool:return form_available(slot,id))
func choose_form_path(slot: Dictionary,path: String) -> Variant:
	if slot.race not in FAMILY:
		return "These paths are for Saiyans and Half-Saiyans."
	if slot.level<int(progression.stats.MAX_LEVEL):
		return "Reach level %d before choosing a path." % int(progression.stats.MAX_LEVEL)
	if path not in ["beast","instinct","ego"]:
		return "Choose Beast, Ultra Instinct or Ultra Ego."
	if slot.loadout.get("formPath")!=null and slot.loadout.formPath!=path:
		return "This character already chose a path."
	slot.loadout.formPath = path
	return null
func instinct_benefits(player: Dictionary,time: float) -> Dictionary:
	var chance: float = forms.get(player.form,{}).get("dodgeChance",0)
	if chance>0:
		return {"chance":chance,"cost":combat.uiDodgeCost,"cooldown":combat.uiFormDodgeCooldown,"kind":"form"}
	if player.get("uiTechniqueUntil",0)>time:
		return {"chance":combat.uiTechniqueChance,"cost":combat.uiDodgeCost,"cooldown":combat.uiTechniqueDodgeCooldown,"kind":"technique"}
	return {"chance":0,"cost":0,"cooldown":0,"kind":"none"}
func can_manifest_avatar(slot: Dictionary,player: Dictionary) -> bool:
	var a: Dictionary = RuleTables.table("avatar")
	return slot.race in FAMILY and slot.level>=int(progression.stats.MAX_LEVEL) and player.form in slot.forms and has_form_path(slot,a.path) and player.health>0 and player.form in a.forms and a.id in slot.moves
