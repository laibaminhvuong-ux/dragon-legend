extends "res://tests/rules/game_case.gd"
# Godot-only content from tools/godot_additions.mjs (user requests 2026-11-03).
func test_other_world_starts_at_the_check_in_station() -> void:
	var zone := RuleZone.new("snake_way")
	var station: Dictionary = zone.landmarks.filter(func(l: Dictionary) -> bool: return l.type=="checkin")[0]
	near(zone.height_at(zone.spawn.x,zone.spawn.z),0.0,0.0001,"spawn stands on the station floor")
	ok(Vector2(zone.spawn.x-station.x,zone.spawn.z-station.z).length()<52,"spawn inside the hall")
	ok(zone.spawn.z<station.z,"spawn south of the desk")
	near(zone.height_at(station.x+40,station.z),0.0,0.0001,"floor reaches 40 m out")
	ok(zone.height_at(station.x+70,station.z)<-100,"void beyond the floor")
	# walk from the spawn to the desk side, then along the road's centre line: never over the void
	var from := Vector2(zone.spawn.x,zone.spawn.z)
	var road_start: Dictionary = zone.place(0,-392)
	var to := Vector2(road_start.x,road_start.z)
	for i in 101:
		var p: Vector2 = from.lerp(to,i/100.0)
		ok(zone.height_at(p.x,p.y)>-1,"walkable at %s" % p)
	for z in range(-392,-300,4):
		var q: Dictionary = zone.place(0,z)
		ok(zone.height_at(q.x,z)>-1,"road at %d" % z)
	var tp: Dictionary = zone.travel_point
	ok(zone.height_at(tp.x,tp.z)>-1,"pilot on the floor")
func test_king_yemmo_sits_behind_his_desk() -> void:
	var schema := RuleSchema.new()
	var slot: Dictionary = schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.zone = "snake_way"
	var g := RuleGame.new(0,slot,Recorder.new())
	eq(g.zone.id,"snake_way")
	var story := RuleStory.new(g)
	var king: Dictionary = story.npcs().filter(func(n: Dictionary) -> bool: return n.id=="king_yemma")[0]
	ok(king.get("sit",false),"seated")
	ok(float(king.scale)>4.0,"giant")
	var station: Dictionary = story.zone.landmarks.filter(func(l: Dictionary) -> bool: return l.type=="checkin")[0]
	var d := Vector2(float(king.x)-float(station.x),float(king.z)-float(station.z))
	ok(d.length()<10.0,"behind the desk, not pushed away: %s" % d)
	ok(float(king.z)>float(station.z),"on the road side of the desk")
func test_additions_list_names_the_changed_zones() -> void:
	ok("snake_way" in RuleTables.table("godot_additions").zones)

func _road_game() -> Array:
	var schema := RuleSchema.new()
	var slot: Dictionary = schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.zone = "snake_way"
	var bus := Recorder.new()
	var g := RuleGame.new(0,slot,bus)
	var story := RuleStory.new(g,bus)
	return [g,story,bus]

func test_king_kae_planet_floats_above_the_end_of_the_road() -> void:
	var zone := RuleZone.new("snake_way")
	var planet: Dictionary = zone.landmarks.filter(func(l: Dictionary) -> bool: return l.type=="kaiplanet")[0]
	var road_end: Dictionary = zone.place(0,390)
	var up := float(planet.alt)
	var ahead := Vector2(float(planet.x)-float(road_end.x),float(planet.z)-float(road_end.z)).length()
	ok(up>40.0 and ahead<140.0,"above and just past the road's end (%.0f up, %.0f ahead)" % [up,ahead])
	ok(rad_to_deg(atan2(up,ahead))>25.0,"you look up to see it")

func test_flying_into_the_planet_lands_on_it_once_unlocked() -> void:
	var r := _road_game()
	var g: RuleGame = r[0]; var story: RuleStory = r[1]; var bus: Recorder = r[2]
	var portal: Dictionary = story.zone.def.portals[0]
	var at: Dictionary = story.zone.place(float(portal.x),float(portal.z))
	g.player.pos = Vector3(at.x,float(portal.y),at.z)
	story.update(1.0/60)
	eq(bus.count("travel"),0,"locked before the road quest is done")
	g.slot.story.unlocked.append("king_kai")
	story.update(1.0/60)
	eq(bus.count("travel"),1,"flies you to King Kae's planet")
	eq(bus.log.filter(func(e: Dictionary) -> bool: return e.event=="travel")[0].value.zone,"king_kai")
	story.update(1.0/60)
	eq(bus.count("travel"),1,"only once")
