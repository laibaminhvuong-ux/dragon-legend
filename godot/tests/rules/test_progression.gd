extends TestCase
const Progression = preload("res://rules/progression.gd")
const Schema = preload("res://rules/schema.gd")
const Tables = preload("res://rules/tables.gd")

func test_all_2000_xp_thresholds_match_js() -> void:
	var rules := Progression.new()
	var expected: Array = Tables.table("parity").xp
	for i in expected.size():
		eq(rules.xp_to_next(i+1),int(expected[i]),"level %d" % (i+1))
	eq(rules.xp_for_levels(1,2),382)
	eq(rules.xp_for_levels(2000,8),0)

func test_all_race_level_and_form_derived_stats_match_js() -> void:
	var rules := Progression.new()
	var fixtures: Array = Tables.table("parity").progression
	for row: Dictionary in fixtures:
		var got: Dictionary = rules.derive(row.slot,row.form)
		for key: String in row.derived:
			ok(is_finite(float(got[key])),key+" finite")
			near(float(got[key]),float(row.derived[key]),1e-8,"%s/%s/%s/%s" % [row.slot.race,row.slot.level,row.form,key])
		eq(rules.forms_at_level(row.slot.race,int(row.slot.level)),row.forms)
	ok(fixtures.size()>500)

func test_level_up_cap_and_stat_spending() -> void:
	var rules := Progression.new()
	var schema := Schema.new()
	var slot: Dictionary = schema.new_slot(schema.default_look(),1000)
	eq(rules.add_xp(slot,432),2)
	eq(int(slot.level),3)
	eq(int(slot.xp),50)
	eq(int(slot.statPoints),6)
	eq(rules.spend_stat_point(slot,"Health",2),null)
	eq(int(slot.stats.Health),2)
	eq(rules.spend_stat_point(slot,"Health",9),"Not enough stat points")
	eq(rules.spend_stat_point(slot,"Luck"),"Unknown stat")
	for amount: Variant in [0,-1,1.5,"10",true]:
		eq(rules.spend_stat_point(slot,"Health",amount),"Bad amount")
	rules.add_xp(slot,1e12)
	eq(int(slot.level),2000)
	eq(int(slot.xp),0)
	eq(rules.add_xp(slot,100000),0)

func test_early_race_bonuses_and_legacy_form_filter() -> void:
	var rules := Progression.new()
	near(rules.apply_xp_bonus("HalfSaiyan",10,100),125)
	near(rules.apply_xp_bonus("HalfSaiyan",500,100),100)
	near(rules.apply_xp_bonus("Human",149,100),110)
	ok(not rules.form_for_race("HSSJ","HalfSaiyan"))
	ok(rules.form_for_race("SSJ","HalfSaiyan"))
	ok(not rules.form_for_race("toString","Saiyan"))

func test_fresh_foundation_data_loader_can_be_injected() -> void:
	var data: Node = load("res://core/data.gd").new()
	data.load_dir("res://data")
	eq(data.errors.size(),0)
	var rules := Progression.new(data)
	var schema := Schema.new(data)
	var slot: Dictionary = schema.new_slot(schema.default_look("Human"),1000)
	eq(rules.xp_to_next(1),100)
	eq(schema.validate_look(schema.default_look("Human")),null)
	ok(rules.derive(slot).maxHealth>0)
	data.free()
