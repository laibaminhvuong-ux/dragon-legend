extends TestCase
# Rocket boost (user request, 2026-11-04): Q launches the fighter like a rocket and flies much faster for 20 s.

const DT := 1.0 / 60.0

func _step(g: RuleGame, it: Dictionary, frames: int) -> void:
	for i in frames:
		var full := RuleGame.empty_intents()
		full.merge(it, true)
		g.update(DT, full)

func test_boost_launches_and_flies_fast_for_twenty_seconds() -> void:
	# Test the speed/timer on the original clear route; the Origins spawn faces the hut.
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look())
	slot.zone = "earth_plains"
	var g := RuleGame.new(0, slot)
	var y0: float = g.player.pos.y
	_step(g, {"boost": true}, 1)
	ok(g.player.boosting and g.player.flying, "Q launches into a boost")
	_step(g, {}, 30)
	ok(g.player.pos.y > y0 + 4.0, "it blasts up off the ground (%.1f m)" % (g.player.pos.y - y0))
	_step(g, {"move_z": 1.0}, 120)
	var v := Vector2(g.player.vel.x, g.player.vel.z).length()
	ok(v > float(RuleTables.table("movement").flightSpeed) * 2.0, "much faster than normal flight (%.1f m/s)" % v)
	_step(g, {}, 60)
	ok(Vector2(g.player.vel.x, g.player.vel.z).length() > 20.0, "keeps rocketing forward with no keys")
	_step(g, {}, int(19.0 / DT))
	ok(not g.player.boosting, "the boost lasts 20 seconds")
	ok(g.player.flying, "then you're simply flying")

func test_q_again_ends_the_boost_and_cooldown_applies() -> void:
	# Test the speed/timer on the original clear route; the Origins spawn faces the hut.
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look())
	slot.zone = "earth_plains"
	var g := RuleGame.new(0, slot)
	_step(g, {"boost": true}, 1)
	_step(g, {}, 20)
	_step(g, {"boost": true}, 1)
	ok(not g.player.boosting, "Q again stops the boost")
	_step(g, {"boost": true}, 1)
	ok(not g.player.boosting, "cooldown before the next boost")
	_step(g, {}, int(6.2 / DT))
	_step(g, {"boost": true}, 1)
	ok(g.player.boosting, "boost again after the cooldown")

func test_boost_is_free() -> void:
	# Test the speed/timer on the original clear route; the Origins spawn faces the hut.
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look())
	slot.zone = "earth_plains"
	var g := RuleGame.new(0, slot)
	var ki: float = g.player.ki
	_step(g, {"boost": true}, 1)
	_step(g, {"move_z": 1.0}, 300)
	ok(g.player.ki >= ki - 0.001, "no Ki spent")
