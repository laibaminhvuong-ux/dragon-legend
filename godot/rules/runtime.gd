class_name RuleRuntime
extends RefCounted
const Tables = preload("res://rules/tables.gd")
static func vector(value: Variant) -> Vector3:
	return value if value is Vector3 else Vector3(float(value.get("x",0)),float(value.get("y",0)),float(value.get("z",0)))
static func position(value: Vector3) -> Dictionary:
	return {"x":value.x,"y":value.y,"z":value.z}
static func js_round(value: float) -> int:
	return floori(value+0.5)
static var _rename_rules: Array = []
static func rename_text(text: String) -> String:
	if _rename_rules.is_empty():
		var names: Dictionary = Tables.table("names")
		var safe: Dictionary = {
			"Hit":"\\bHit\\b(?=[ ,.!?:;'’)]|$)(?! (?:him|her|it|them|me|us|you|the|a|an|his|every|everything|hard|back|again|fast|where|with)\\b)",
			"Gas":"\\bGas\\b(?! (?:station|can|cloud|giant)\\b)",
			"Frost":"\\bFrost\\b(?! (?:Demon|Demons|demon|Armor|armour|Armour)\\b)"}
		for pair: Array in names.NAMES + names.TERMS:
			var regex := RegEx.new()
			regex.compile(safe.get(pair[0],"\\b"+String(pair[0]).replace("-","\\-")+"\\b"))
			_rename_rules.append([regex,pair[1]])
	for pair: Array in _rename_rules:
		text = pair[0].sub(text,pair[1],true)
	return text
static func emit(events: Object, event: String, payload: Dictionary = {}) -> void:
	if events == null:
		return
	var result: Dictionary = payload.duplicate()
	for key: String in ["text","title","speaker"]:
		if result.get(key) is String:
			result[key] = rename_text(result[key])
	events.emit_named(event,result)
static func ki_color(style: Dictionary) -> int:
	var hex_value: Variant = RuleSchema.normalize_ki_hex(style.get("kiColorHex"))
	if hex_value != null:
		return String(hex_value).trim_prefix("#").hex_to_int()
	var colors: Array = Tables.table("appearance").KI_COLORS
	var i: int = int(style.get("kiColor",0))
	return int(colors[i]) if i>=0 and i<colors.size() else int(colors[0])
