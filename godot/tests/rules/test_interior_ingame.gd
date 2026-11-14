extends TestCase
# In-game door checks (2026-11-13): inside a building there is no Capsule Corp pilot (he stood in the room, and as a
# person he took the interact key from the exit door next to him) and no Hostile Trainee patrol (three were spawned
# outside the room's walls).

func _inside(style_zone: String) -> RuleGame:
	var g := RuleGame.new()
	var door := {"x": g.player.pos.x + 1.0, "z": g.player.pos.z, "yaw": 0.0, "interior": style_zone, "name": "Test door"}
	eq(g.enter_building(door), style_zone, "enter goes to %s" % style_zone)
	return RuleGame.new(0, g.to_save().duplicate(true))

func test_no_pilot_or_patrol_inside_and_the_exit_answers() -> void:
	for zid: String in ["interior_home", "interior_lab", "interior_tower", "interior_hangar", "interior_temple"]:
		var g := _inside(zid)
		var story := RuleStory.new(g, Events)
		eq(story.travel_guide(), null, "%s: no travel pilot inside" % zid)
		ok(not story.npcs().any(func(n: Dictionary) -> bool: return n.get("guide", false)), "%s: no pilot among the people" % zid)
		eq(g.combat.enemies.size(), 0, "%s: no patrol trainees" % zid)
		var exit: Dictionary = {}
		for d: Dictionary in g.zone.doors():
			if d.get("exit", false): exit = d
		g.player.pos = Vector3(float(exit.x), 0.0, float(exit.z) - 0.8)
		var near: Variant = story.interaction()
		ok(near is Dictionary and str(near.id) == "door" and str(near.action) == "Leave", "%s: at the exit the prompt is Leave (%s)" % [zid, near])

func test_outdoors_still_has_patrols() -> void:
	var g := RuleGame.new()
	ok(g.combat.enemies.size() > 0, "the open world keeps its trainees")

## Kama House: Master Roshu stands about 3 m from the door; standing at the door, the prompt is the door, not him.
func test_door_beats_a_person_further_away() -> void:
	var slot := RuleSchema.new().new_slot(RuleSchema.new().default_look())
	slot.zone = "kame_island"
	var g := RuleGame.new(0, slot)
	var story := RuleStory.new(g, Events)
	var door: Dictionary = {}
	for d: Dictionary in g.zone.doors():
		if str(d.name) == "Kama House": door = d
	ok(not door.is_empty(), "Kama House has a door")
	var yaw := float(door.yaw)
	g.player.pos = Vector3(float(door.x) + sin(yaw) * 2.0, 0.0, float(door.z) + cos(yaw) * 2.0)
	g.player.pos.y = g.zone.height_at(g.player.pos.x, g.player.pos.z)
	var near: Variant = story.interaction()
	ok(near is Dictionary and str(near.id) == "door", "at the door the prompt is the door (%s)" % [near])
	for n: Dictionary in story.npcs():
		if str(n.id) == "roshi":
			g.player.pos = Vector3(float(n.x) + 0.5, float(n.y), float(n.z))
			near = story.interaction()
			ok(near is Dictionary and str(near.id) == "roshi", "next to Master Roshu the prompt is him (%s)" % [near])
