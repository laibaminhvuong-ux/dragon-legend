extends TestCase
# 2026-11-13: the World Tournament bouts are staged on the ring itself, so with the arena built every bout fighter
# stands on the ring's top (1.6 m up), not on the grass beside it.

func test_bout_fighters_stand_on_the_ring_top() -> void:
	var zone := RuleZone.new("tournament_island")
	var root := WorldLandmarks.build(zone)
	var bouts := 0
	for q: Dictionary in RuleTables.table("quests"):
		for s: Dictionary in q.steps:
			if s.type != "defeat" or str(s.get("zone", "")) != "tournament_island" or s.enemy == "tambourine":
				continue
			bouts += 1
			var f := zone.free_position({"x": float(s.x), "z": float(s.z)})
			ok(f.y > zone.height_at(f.x, f.z) + 1.4, "%s on the ring top (%.2f m up)" % [s.enemy, f.y - zone.height_at(f.x, f.z)])
			ok(Vector2(f.x - float(s.x), f.z - float(s.z)).length() < 1.0, "%s is not pushed off its spot" % s.enemy)
	eq(bouts, 7)
	root.free()
