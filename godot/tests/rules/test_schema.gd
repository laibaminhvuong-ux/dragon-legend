extends TestCase
const Schema = preload("res://rules/schema.gd")
const Tables = preload("res://rules/tables.gd")

func _json_value(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func test_v1_to_v6_import_and_migration_match_js() -> void:
	var rules := Schema.new()
	for row: Dictionary in Tables.table("parity").saves:
		# The JS oracle has 3 slots; the Godot game has SLOT_COUNT (10), the rest empty.
		var expected: Dictionary = row.expected.duplicate(true)
		expected.slots = _pad(expected.slots)
		eq(_json_value(rules.migrate(row.input)),expected,"migrate version %d" % row.version)
		var result: Dictionary = rules.import_code(row.code)
		ok(result.ok,"import version %d" % row.version)
		if result.ok:
			eq(_json_value(result.profile),expected,"save-code parity v%d" % row.version)
			var twice: Dictionary = rules.migrate(result.profile)
			eq(_json_value(twice),expected,"migration never scales twice")
			eq(result.profile.slots[0].quests.s_dragon_radar.collected,[0.0,2.0,5.0])

func test_new_slots_defaults_validation_and_independent_state() -> void:
	var rules := Schema.new()
	for race: String in Tables.table("race_order"):
		var look: Dictionary = rules.default_look(race)
		eq(rules.validate_look(look),null,race)
		var slot: Dictionary = rules.new_slot(look,1000)
		eq(slot.race,race)
		eq(slot.appearance.kiColorHex,null)
		eq(slot.loadout.kaiokenRank,2)
		eq(slot.story.unlocked,Tables.table("start_zones"))
		eq(slot.createdAt,1000)
		eq(_json_value(rules.normalize(slot)),_json_value(slot))
	var first: Dictionary = rules.new_slot(rules.default_look())
	var second: Dictionary = rules.new_slot(rules.default_look())
	first.story.flags.test = true
	ok(not second.story.flags.has("test"))
	var bad: Dictionary = rules.default_look()
	bad.skin = 0.5
	eq(rules.validate_look(bad),"Bad skin colour")

func test_unicode_codes_future_versions_and_damaged_input() -> void:
	var rules := Schema.new()
	var profile: Dictionary = rules.new_profile()
	profile.slots[0] = rules.new_slot(rules.default_look(),1000)
	profile.slots[0].story.flags.note = "龍 🐉 Việt Nam"
	var imported: Dictionary = rules.import_code("  " + rules.export_code(profile) + "  ")
	ok(imported.ok)
	eq(imported.profile.slots[0].story.flags.note,"龍 🐉 Việt Nam")
	profile.version = 99
	ok(not rules.import_code(rules.export_code(profile)).ok)
	for code: String in ["","DL2:abc","DL1:!@#$","DL1:====","DL1:e30=","DL1:bnVsbA==","DL1:////","DL1:"]:
		ok(not rules.import_code(code).ok,code)

func test_normalize_repairs_fields_preserves_unknown_flags_and_unlocks() -> void:
	var rules := Schema.new()
	var slot: Dictionary = rules.new_slot(rules.default_look(),1000)
	slot.level = 730
	slot.appearance.kiColorHex = "AbC"
	slot.appearance.kiColor = 99
	slot.loadout.testAllPaths = true
	slot.formMastery = {"SSJ":100,"bad":-1,"text":"4"}
	slot.quests = {"m37_moro_final":{"status":"done"},"Form_HSSJ":{"status":"done"}}
	slot.forms = ["HSSJ"]
	var result: Dictionary = rules.normalize(slot)
	eq(result.appearance.kiColorHex,"#aabbcc")
	eq(result.appearance.kiColor,0)
	eq(result.loadout.testAllPaths,true)
	eq(result.level,730)
	ok("SSJ" in result.forms)
	ok(result.quests.has("Form_SSJ"))
	ok("planet_cereal" in result.story.unlocked)
	eq(result.formMastery.bad,0)
	eq(result.formMastery.text,0)
	eq(slot.appearance.kiColorHex,"AbC","normalization does not mutate input")
	eq(rules.migrate(null).slots,_pad([]))
	for value: String in ["-ab","+ab","0xz","#12345g","#12345678"]:
		eq(rules.normalize_ki_hex(value),null)

func test_live_save_store_calls_new_slot_and_normalize() -> void:
	var store: Node = load("res://core/save_store.gd").new()
	store.path = "user://stage2_save_%d.json" % Time.get_ticks_usec()
	store.call("_ready")
	var schema := Schema.new()
	ok(store.create_slot(0,schema.default_look("Namekian")))
	var slot: Dictionary = store.load_slot(0)
	eq(slot.race,"Namekian")
	eq(int(slot.level),1)
	eq(slot.appearance.accessory,"None")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path))
	store.free()

func _pad(slots: Array) -> Array:
	var a: Array = slots.duplicate()
	a.resize(Schema.SLOT_COUNT)
	return a
