class_name RuleMastery
extends RefCounted
var forms := RuleForms.new()
var tuning: Dictionary = RuleTables.table("mastery_tuning")
var evolutions: Array = RuleTables.table("mastery_evolutions")
static func mastery_key(id: String) -> String:
	return "SSJ" if id in ["SSJ","SSJGrade2","SSJGrade3","SSJFullPower"] else id
func gain_form_mastery(slot: Dictionary,id: String,amount: float) -> Array:
	if id not in slot.forms or not forms.form_available(slot,id) or amount<=0 or not is_finite(amount):
		return []
	var key: String = mastery_key(id)
	slot.formMastery[key] = float(slot.formMastery.get(key,0))+amount
	var evolved: Array = []
	for edge: Dictionary in evolutions:
		if edge.key!=key or edge.from not in slot.forms or edge.to in slot.forms:
			continue
		if slot.formMastery[key]<edge.required or not forms.form_available(slot,edge.to):
			continue
		if edge.has("after") and slot.quests.get(edge.after,{}).get("status") not in ["done","repeatable"]:
			continue
		slot.forms.append(edge.to)
		evolved.append(edge.to)
		slot.quests[forms.forms[edge.to].unlockQuest] = {"status":"done","step":1,"completions":1,"mastery":true}
	return evolved
func mastery_progress(slot: Dictionary,id: String) -> Dictionary:
	var key: String = mastery_key(id)
	var points: float = slot.formMastery.get(key,0)
	for edge: Dictionary in evolutions:
		if edge.key==key and edge.to not in slot.forms:
			return {"points":points,"level":floori(points/tuning.pointsPerLevel),"next":edge.to,"required":edge.required}
	return {"points":points,"level":floori(points/tuning.pointsPerLevel),"next":null,"required":null}
