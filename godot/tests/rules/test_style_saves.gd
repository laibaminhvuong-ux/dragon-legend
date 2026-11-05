extends TestCase
func test_old_slots_default_to_turtle_without_rescaling_current_progress() -> void:
	var schema := RuleSchema.new()
	for version in range(4,RuleSchema.SCHEMA_VERSION+1):
		var slot := schema.new_slot(schema.default_look("Saiyan"),1000)
		slot.erase("style"); slot.level = 1275; slot.xp = 1234; slot.forms = ["SSJ","SSJ4"]; slot.formMastery = {"SSJ":88}
		slot.quests.kept = {"status":"done"}; slot.story.flags.note = "龍 Việt Nam"
		var profile := {"version":version,"slots":[slot],"lastSlot":0}
		var migrated := schema.migrate(profile)
		eq(migrated.version,RuleSchema.SCHEMA_VERSION); eq(migrated.slots[0].style,"turtle"); eq(migrated.slots[0].level,1275)
		eq(migrated.slots[0].xp,1234); eq(migrated.slots[0].formMastery.SSJ,88)
		eq(migrated.slots[0].quests.kept.status,"done"); eq(migrated.slots[0].story.flags.note,"龍 Việt Nam")
		eq(schema.migrate(migrated),migrated); ok(not slot.has("style"))
func test_all_styles_survive_v7_save_code_and_store_roundtrips() -> void:
	var schema := RuleSchema.new()
	var store: Node = load("res://core/save_store.gd").new()
	store.path = "user://styles_%d.json" % Time.get_ticks_usec()
	var index := 0
	for id: String in RuleStyles.all():
		var slot := schema.new_slot(schema.default_look(),1000); slot.style = id
		var profile := schema.new_profile(); profile.slots[index] = slot
		var decoded := schema.import_code(schema.export_code(profile))
		ok(decoded.ok); eq(decoded.profile.slots[index].style,id)
		ok(store.save_slot(index,slot)); eq(store.load_slot(index).style,id)
		index += 1
	var reloaded: Node = load("res://core/save_store.gd").new(); reloaded.path = store.path
	index = 0
	for id: String in RuleStyles.all(): eq(reloaded.load_slot(index).style,id); index += 1
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path)); eq(int(raw.version),RuleSchema.SCHEMA_VERSION)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path)); store.free(); reloaded.free()
func test_invalid_offline_styles_are_repaired_and_future_codes_are_rejected() -> void:
	var schema := RuleSchema.new()
	for value: Variant in [null,"","invalid",12,{},[],true]:
		var slot := schema.new_slot(schema.default_look(),1000); slot.style = value
		eq(schema.normalize(slot).style,"turtle")
	var profile := schema.new_profile(); profile.version = RuleSchema.SCHEMA_VERSION+1
	ok(not schema.import_code(schema.export_code(profile)).ok)
