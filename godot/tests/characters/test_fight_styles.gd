extends TestCase
# Fight flow (2026-11-04): four fighting styles, each a full move set.

const SETS := ["stance", "combo1", "combo2", "combo3", "combo4", "dash", "finisher"]

func test_every_style_has_full_set() -> void:
	eq(FightStyles.IDS, ["turtle", "brawler", "speedster", "crane"], "style ids and order")
	for style: String in FightStyles.IDS:
		var m := FightStyles.moves(style)
		for slot: String in SETS:
			var id := "%s_%s" % [style, slot]
			ok(m.has(id), "%s exists" % id)
			if not m.has(id):
				continue
			var mv: Dictionary = m[id]
			var length := float(mv.length)
			if slot == "stance":
				ok(length >= 1.5 and length <= 3.0, "%s loops 1.5-3 s (%.2f)" % [id, length])
			else:
				ok(length >= 0.3 and length <= 1.2, "%s lasts 0.3-1.2 s (%.2f)" % [id, length])
				ok(float(mv.contact) > 0.05 and float(mv.contact) < length, "%s contact inside the clip" % id)

func test_move_for_fallbacks() -> void:
	eq(FightStyles.move_for("brawler", "brawler_combo2", 2), "brawler_combo2", "exact id")
	eq(FightStyles.move_for("brawler", "brawler_mystery", 3), "brawler_combo3", "unknown move → that style's combo step")
	eq(FightStyles.move_for("nope", "", 1), "turtle_combo1", "unknown style → turtle")
	eq(FightStyles.move_for("crane", "", 9), "crane_combo4", "step clamps to the combo")
	eq(FightStyles.move_for("speedster", "speedster_hammer", 0), "speedster_combo1", "step 0 → first hit")

func test_named_moves_alias_combo_slots() -> void:
	eq(FightStyles.move_for("brawler", "brawler_hammer_fist", 2), "brawler_combo2", "spec move names map to their combo slot")
	eq(FightStyles.move_for("crane", "crane_one_finger_strike", 4), "crane_finisher", "finisher names map to the finisher")
	eq(FightStyles.move_for("speedster", "speedster_afterimage_blink", 1), "speedster_dash", "dash-in names map to the dash")

func test_every_rules_move_id_has_a_clip() -> void:
	var table: Dictionary = RuleTables.table("fighting_styles")
	var n := 0
	for style: String in FightStyles.IDS:
		for step in range(1, 5):
			for dash in [false, true]:
				var mv: Dictionary = RuleStyles.move(style, step, dash)
				var id := str(mv.get("move", ""))
				ok(FightStyles.ALIASES.has(id), "%s is mapped to a clip" % id)
				n += 1
	ok(n == 32 and not table.is_empty(), "rules move table read")

func test_styles_differ() -> void:
	var sigs := {}
	for style: String in FightStyles.IDS:
		var mv: Dictionary = FightStyles.moves(style)["%s_combo1" % style]
		sigs[str(mv.length) + str(mv.keys)] = true
	eq(sigs.size(), 4, "four different first strikes")

func test_library_builds_clips_on_a_fighter() -> void:
	var f := Fighter.create({"race": "Human"})
	var lib := FightStyles.library(f)
	ok(lib.has_animation("brawler_combo2") and lib.has_animation("crane_stance"), "library holds every move")
	ok((lib.get_animation("crane_stance") as Animation).loop_mode == Animation.LOOP_LINEAR, "stances loop")
	ok(MoveClips.lunge_at(lib.get_animation("speedster_dash"), FightStyles.moves("speedster")["speedster_dash"].contact) > 0.3, "dash-in travels")
	f.free()
