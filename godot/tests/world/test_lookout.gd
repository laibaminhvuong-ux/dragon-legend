extends TestCase
# Kamu's Lookout floats in the sky (user report 2026-11-05: "can't leave the Lookout"): nothing to stand on past the
# platform's edge, the way down to Korrin Tower never fires on the platform, and falling off the edge reaches it.

func _portal(zone: RuleZone) -> Dictionary:
	return (zone.def.portals as Array).filter(func(p: Dictionary) -> bool: return p.zone == "korrin_tower")[0]

func _inside(p: Dictionary, v: Vector3) -> bool:
	return v.distance_to(Vector3(float(p.x), float(p.y), float(p.z))) <= float(p.r)

func test_the_lookout_floats_and_stepping_off_lands_at_korrin_tower() -> void:
	var zone := RuleZone.new("kamu_lookout")
	var p := _portal(zone)
	ok(zone.height_at(0, -18) > -1.0, "the platform is solid where you arrive")
	ok(zone.height_at(60, 0) < -100.0 and zone.height_at(0, 80) < -100.0, "nothing to stand on past the edge")
	for x in range(-40, 41, 4):
		for z in range(-40, 41, 4):
			if Vector2(x, z).length() <= 40.0:
				ok(not _inside(p, Vector3(x, zone.height_at(x, z) + 6.0, z)), "standing or jumping on the platform at (%d, %d) stays" % [x, z])
	for a in 12:
		var dir := Vector2.from_angle(a * TAU / 12.0) * 44.0
		ok(_inside(p, Vector3(dir.x, -90.0, dir.y)), "falling off the edge (%.0f, %.0f) reaches Korrin Tower" % [dir.x, dir.y])
	ok(zone.kill_y != null and float(zone.kill_y) < -90.0, "the safety net is below the way down")
