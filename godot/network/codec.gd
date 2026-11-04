class_name CoopCodec
extends RefCounted
const VERSION := 1
const MAX_PACKET := 131072
static func json_value(value: Variant) -> Variant:
	if value is Vector3: return {"x":value.x,"y":value.y,"z":value.z}
	if value is Dictionary:
		var out := {}
		for key: Variant in value: out[str(key)] = json_value(value[key])
		return out
	if value is Array:
		return value.map(func(v: Variant) -> Variant: return json_value(v))
	return value
static func entity(value: Dictionary) -> Dictionary:
	var out := value.duplicate(true)
	for key: String in ["pos","vel","home","dir"]:
		if out.get(key) is Dictionary: out[key] = RuleRuntime.vector(out[key])
	return out
static func code_valid(code: String) -> bool:
	if code.length()!=6: return false
	for c in code:
		if c<"0" or c>"9": return false
	return true
static func token_valid(token: String) -> bool:
	if token.length()!=64: return false
	for c in token:
		if c not in "0123456789abcdef": return false
	return true
static func secret() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()
static func intents(raw: Dictionary) -> Dictionary:
	var out := RuleGame.empty_intents()
	for key: String in out:
		if key in ["move_x","move_z","fly_pitch"]:
			var value: Variant = raw.get(key,0)
			out[key] = clampf(float(value),-1,1) if (value is int or value is float) and is_finite(float(value)) else 0.0
		else: out[key] = raw.get(key,false) is bool and bool(raw.get(key,false))
	return out
static func endpoint_valid(url: String) -> bool:
	return (url.begins_with("wss://") and url.length()>6 or url.begins_with("ws://") and url.length()>5) and "@" not in url and " " not in url and "\n" not in url

static func import_valid(slot: Dictionary) -> bool:
	if slot.has("style") and not RuleStyles.valid(slot.style): return false
	if not slot.get("race") is String or not RuleTables.table("races").has(slot.race) or not slot.get("appearance") is Dictionary: return false
	var level: Variant = slot.get("level")
	if not (level is int or level is float) or not is_finite(float(level)) or level<1 or level>2000: return false
	if not slot.get("quests",{}) is Dictionary or not slot.get("stats",{}) is Dictionary: return false
	for value: Variant in slot.get("stats",{}).values():
		if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>1000000: return false
	for key: String in ["forms","moves","outfits"]:
		if not slot.get(key,[]) is Array: return false
		for value: Variant in slot.get(key,[]):
			if not value is String: return false
	var quests := {}
	for q: Dictionary in RuleTables.table("quests"): quests[q.id] = q
	for id: Variant in slot.get("quests",{}):
		var q: Variant = slot.quests[id]
		if not id is String or not q is Dictionary or not q.get("status","") is String: return false
		for key: String in ["step","t","count","completions"]:
			var number: Variant = q.get(key,0)
			if not (number is int or number is float) or not is_finite(float(number)) or number<0: return false
		if not q.get("collected",[]) is Array: return false
		for number: Variant in q.get("collected",[]):
			if not (number is int or number is float) or not is_finite(float(number)) or number<0: return false
		if q.get("status")=="active" and quests.has(id):
			var step: Variant = q.get("step",0)
			if not (step is int or step is float) or not is_finite(float(step)) or step<0 or step>=quests[id].steps.size(): return false
	if not slot.get("story",{}) is Dictionary: return false
	var story: Dictionary = slot.get("story",{})
	if not story.get("items",{}) is Dictionary or not story.get("flags",{}) is Dictionary: return false
	for number: Variant in story.get("items",{}).values():
		if not (number is int or number is float) or not is_finite(float(number)) or number<0: return false
	for key: String in ["unlocked","visited"]:
		if not story.get(key,[]) is Array: return false
		for id: Variant in story.get(key,[]):
			if not id is String: return false
	var look: Dictionary = slot.appearance.duplicate()
	look.race = slot.race
	look.outfit = RuleSchema.new().default_look(slot.race).outfit
	for key: String in ["face","hair","build"]:
		if not look.get(key) is String: return false
	if RuleSchema.new().validate_look(look)!=null: return false
	return true

## Keep stable event ids while translating this client's actor identity for scene consumers.
static func localize_event(packet: Dictionary,self_id: String) -> Dictionary:
	var out := packet.duplicate(true)
	for key: String in ["id","actor_id","source_id","target_id"]:
		if out.get(key)==self_id: out[key] = "player"
	for key: String in ["pos","origin","direction","from","to"]:
		if out.get(key) is Dictionary: out[key] = RuleRuntime.vector(out[key])
	return out
