class_name RuleSchema
extends RefCounted
# Saved dictionaries retain JS camelCase keys. Only rule method names use snake_case.
const Tables = preload("res://rules/tables.gd")
const SCHEMA_VERSION := 6
const CODE_PREFIX := "DL1:"
var stats: Dictionary
var races: Dictionary
var outfits: Dictionary
var appearance: Dictionary
var quests: Array
var start_zones: Array

func _init(data: Object = null) -> void:
	stats = Tables.table("stats", data)
	races = Tables.table("races", data)
	outfits = Tables.table("outfits", data)
	appearance = Tables.table("appearance", data)
	quests = Tables.table("quests", data)
	start_zones = Tables.table("start_zones", data)

func new_profile() -> Dictionary:
	return {"version":SCHEMA_VERSION,"slots":[null,null,null],"lastSlot":-1}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func normalize_ki_hex(value: Variant) -> Variant:
	if not value is String:
		return null
	var text: String = value.strip_edges().trim_prefix("#")
	if text.length() not in [3,6]:
		return null
	for c: String in text.to_lower():
		if c not in "0123456789abcdef":
			return null
	if text.length() == 3:
		text = text[0] + text[0] + text[1] + text[1] + text[2] + text[2]
	return "#" + text.to_lower()

func default_look(race_id: String = "Saiyan") -> Dictionary:
	var race: Dictionary = races.get(race_id, races.Saiyan)
	var outfit: String = "TurtleGi"
	for id: String in outfits:
		if outfits[id].starter and outfit_allowed(id, race.id):
			outfit = id
			break
	return {"race":race.id,"skin":0,"face":appearance.FACES[0].id,"hair":race.hairStyles[0],"hairColor":0,"kiColor":0,"build":"Average","outfit":outfit,"outfitTint":0}

func outfit_allowed(id: String, race_id: String) -> bool:
	return outfits.has(id) and (outfits[id].races == null or race_id in outfits[id].races)

static func _index(value: Variant, list: Array) -> bool:
	return _number(value) and float(value) == floor(float(value)) and value >= 0 and value < list.size()

static func _has_id(list: Array, id: Variant) -> bool:
	return list.any(func(row: Dictionary) -> bool: return row.id == id)

func validate_look(look: Variant) -> Variant:
	if not look is Dictionary:
		return "Missing appearance"
	var race: Dictionary = races.get(look.get("race", ""), {})
	if race.is_empty():
		return "Pick a race"
	if not _index(look.get("skin"), race.skins):
		return "Bad skin colour"
	if not _has_id(appearance.FACES, look.get("face")):
		return "Bad face"
	if not _has_id(appearance.HAIR_STYLES, look.get("hair")) or look.hair not in race.hairStyles:
		return "That hair isn't available for this race"
	if not _index(look.get("hairColor"), appearance.HAIR_COLORS):
		return "Bad hair colour"
	if look.has("kiColor") and not _index(look.kiColor, appearance.KI_COLORS):
		return "Bad Ki colour"
	if look.get("kiColorHex") != null and normalize_ki_hex(look.kiColorHex) == null:
		return "Enter a valid Ki hex colour, such as #63CFFF."
	if not _has_id(appearance.BUILDS, look.get("build")):
		return "Bad build"
	if not outfits.get(look.get("outfit", ""), {}).get("starter", false) or not outfit_allowed(str(look.get("outfit", "")), race.id):
		return "That outfit isn't available for this race"
	if not _index(look.get("outfitTint"), appearance.TINTS):
		return "Bad outfit colour"
	return null

func new_slot(look: Dictionary, now: int = -1) -> Dictionary:
	if now < 0:
		now = int(Time.get_unix_time_from_system() * 1000.0)
	var style: Dictionary = look.duplicate(true)
	var race: String = style.get("race", "Saiyan")
	style.erase("race")
	style["kiColor"] = style.get("kiColor", 0)
	style["kiColorHex"] = normalize_ki_hex(style.get("kiColorHex"))
	style["accessory"] = style.get("accessory") if style.get("accessory") else "None"
	var allocation: Dictionary = {}
	for stat: String in stats.STAT_NAMES:
		allocation[stat] = 0
	var slot: Dictionary = {"race":race,"appearance":style,"level":1,"xp":0,"statPoints":0,"stats":allocation,"zeni":stats.STARTING_ZENI,
		"outfits":[style.get("outfit", "TurtleGi")],"forms":[],"moves":[],"loadout":{"technique":"EnergyWave","formPath":null,"accessory":"None","kaiokenRank":2},
		"formMastery":{},"quests":{},"story":{},"zone":"earth_plains","position":null,"createdAt":now,"playedAt":now,"playTime":0}
	_ensure_story(slot)
	return slot

func _ensure_story(slot: Dictionary) -> void:
	if not slot.get("quests") is Dictionary:
		slot.quests = {}
	if not slot.get("story") is Dictionary:
		slot.story = {}
	var s: Dictionary = slot.story
	if not s.get("unlocked") is Array:
		s.unlocked = start_zones.duplicate()
	for zone_id: String in start_zones:
		if zone_id not in s.unlocked:
			s.unlocked.append(zone_id)
	if not s.get("visited") is Array:
		s.visited = []
	if not s.get("items") is Dictionary:
		s.items = {}
	if not s.get("flags") is Dictionary:
		s.flags = {}
	for q: Dictionary in quests:
		var saved: Variant = slot.quests.get(q.id)
		if saved is Dictionary and (saved.get("status") == "done" or float(saved.get("completions", 0)) > 0):
			for id: String in q.get("rewards", {}).get("unlock", []):
				if id not in s.unlocked:
					s.unlocked.append(id)

# Per-slot normalization is intentionally CURRENT-version: only migrate(profile) scales v1-v3 levels.
func normalize(input: Dictionary) -> Dictionary:
	var s: Dictionary = input.duplicate(true)
	if not s.get("appearance") is Dictionary:
		s.appearance = default_look(str(s.get("race", "Saiyan")))
		s.appearance.erase("race")
	var a: Dictionary = s.appearance
	a.kiColorHex = normalize_ki_hex(a.get("kiColorHex"))
	if not _index(a.get("kiColor"), appearance.KI_COLORS):
		a.kiColor = 0
	if not s.get("stats") is Dictionary:
		s.stats = {}
	for name: String in stats.STAT_NAMES:
		if s.stats.get(name) == null:
			s.stats[name] = 0
	for key: String in ["outfits","forms","moves"]:
		if not s.get(key) is Array:
			s[key] = [a.get("outfit", "TurtleGi")] if key == "outfits" else []
	if not s.get("loadout") is Dictionary:
		s.loadout = {}
	var loadout: Dictionary = s.loadout
	if not loadout.get("technique") is String:
		loadout.technique = "EnergyWave"
	if loadout.get("kaiokenRank") not in [2,10]:
		loadout.kaiokenRank = 2
	if loadout.get("accessory") == null:
		loadout.accessory = a.get("accessory") if a.get("accessory") else "None"
	if a.get("accessory") == null:
		a.accessory = loadout.accessory
	if loadout.get("formPath") not in ["beast","instinct","ego"]:
		loadout.formPath = null
	if not s.get("formMastery") is Dictionary:
		s.formMastery = {}
	for key: String in s.formMastery:
		if not _number(s.formMastery[key]) or s.formMastery[key] < 0:
			s.formMastery[key] = 0
	_ensure_story(s)
	if s.get("race") in ["Saiyan","HalfSaiyan"]:
		for ids: Array in [["HSSJ","SSJ"],["HSSJ2","SSJ2"]]:
			if ids[0] in s.forms and ids[1] not in s.forms:
				s.forms.append(ids[1])
			var old: String = "Form_" + ids[0]
			var current: String = "Form_" + ids[1]
			if s.quests.get(old) and not s.quests.get(current):
				s.quests[current] = s.quests[old].duplicate(true)
	for key: String in ["zeni","statPoints","xp","level","createdAt","playedAt","playTime","position"]:
		if s.get(key) != null:
			continue
		match key:
			"zeni": s[key] = stats.STARTING_ZENI
			"level": s[key] = 1
			"createdAt": s[key] = int(Time.get_unix_time_from_system() * 1000.0)
			"playedAt": s[key] = s.createdAt
			"position": s[key] = null
			_: s[key] = 0
	if not s.get("zone") or s.zone == "test":
		s.zone = "earth_plains"
	return s

func migrate(input: Variant) -> Dictionary:
	if not input is Dictionary or not input.get("slots") is Array:
		return new_profile()
	var result: Dictionary = input.duplicate(true)
	var slots: Array = [null,null,null]
	var version: int = int(input.version) if _number(input.get("version")) else 1
	for i in mini(3, input.slots.size()):
		var value: Variant = input.slots[i]
		if not value is Dictionary or not value.get("race") or not value.get("appearance") is Dictionary:
			continue
		var s: Dictionary = value.duplicate(true)
		if version < 4 and _number(s.get("level")) and s.level > 1:
			var old: float = s.level
			var fraction: float = float(s.get("xp", 0)) / (floor(100.0 * pow(old, 1.5)) if old < 150 else 1.0)
			s.level = minf(2000.0, old * 10.0)
			s.statPoints = float(s.get("statPoints", 0)) + (s.level - old) * 3.0
			s.xp = floor( clampf(fraction, 0.0, 0.999) * 100.0 * pow(s.level, 1.5)) if s.level < 2000 else 0
		slots[i] = normalize(s)
	result.slots = slots
	var last: Variant = result.get("lastSlot")
	result.lastSlot = int(last) if _number(last) and float(last) == floor(float(last)) else -1
	result.version = SCHEMA_VERSION
	return result

static func _valid_utf8(bytes: PackedByteArray) -> bool:
	var i: int = 0
	while i < bytes.size():
		var lead: int = bytes[i]
		if lead < 128:
			i += 1
			continue
		var count: int = 1 if lead >= 0xc2 and lead <= 0xdf else 2 if lead >= 0xe0 and lead <= 0xef else 3 if lead >= 0xf0 and lead <= 0xf4 else -1
		if count < 0 or i + count >= bytes.size():
			return false
		var code: int = lead & (0x1f if count == 1 else 0x0f if count == 2 else 0x07)
		for j in range(1, count + 1):
			var part: int = bytes[i+j]
			if part < 0x80 or part > 0xbf:
				return false
			code = (code << 6) | (part & 0x3f)
		if code < (0x80 if count == 1 else 0x800 if count == 2 else 0x10000) or code > 0x10ffff or (code >= 0xd800 and code <= 0xdfff):
			return false
		i += count + 1
	return true

func import_code(code: String) -> Dictionary:
	var text: String = code.strip_edges()
	if not text.begins_with(CODE_PREFIX):
		return {"ok":false,"error":"That isn't a save code for The Dragon Legend"}
	var payload: String = text.substr(CODE_PREFIX.length())
	var regex := RegEx.new()
	regex.compile("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
	if payload.is_empty() or regex.search(payload) == null:
		return {"ok":false,"error":"The save code is damaged"}
	var bytes: PackedByteArray = Marshalls.base64_to_raw(payload)
	if not _valid_utf8(bytes):
		return {"ok":false,"error":"The save code is damaged"}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary or not json.data.get("slots") is Array:
		return {"ok":false,"error":"The save code is damaged"}
	if not _number(json.data.get("version", 1)):
		return {"ok":false,"error":"The save code is damaged"}
	if json.data.get("version", 1) > SCHEMA_VERSION:
		return {"ok":false,"error":"That save is from a newer version. Update the game first."}
	return {"ok":true,"profile":migrate(json.data)}

func export_code(profile: Dictionary) -> String:
	return CODE_PREFIX + Marshalls.raw_to_base64(JSON.stringify(profile).to_utf8_buffer())
