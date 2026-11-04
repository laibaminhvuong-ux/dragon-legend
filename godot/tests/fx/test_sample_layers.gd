extends TestCase
func director() -> SkillDirector:
	var node := SkillDirector.new()
	Engine.get_main_loop().root.add_child(node)
	node.bind(null,Callable(),"low")
	return node
func packet(sequence: int = 1) -> Dictionary:
	return {"move_id":"Kamehameha","actor_id":"friend","action_sequence":sequence,"phase":"prepare","seed":15,"origin":Vector3(2,3,4),"color":0x12ab34}

func test_six_sample_layers_quick_tap_gather_and_finisher_emphasis() -> void:
	var node := director()
	for id: String in ["KiBlast","EnergyWave","DestructoDisc","WolfFangFist","InstantTransmission","SpiritBomb"]:
		var profile := SkillCatalog.get_skill(id)
		ok(profile.layers.size()>=4,id)
		var event := packet(1); event.move_id = id; event.phase = "prepare"
		node.handle_event("attack",event)
		var gather: SkillEffect = node.charging.friend
		event.phase = "release"; event.hold_elapsed = 0.0
		node.handle_event("attack",event)
		ok(not node.charging.has("friend"),id)
		ok(node.effects.has(gather),"quick gather remains visible: "+id)
		ok(not gather.sustained); near(gather.duration,float(profile.hold_min))
		var effect := node.spawn_effect(profile,event.merged({"finisher":true}),"impact",Vector3.ZERO)
		ok(effect.power_scale>1); ok(effect.parts.size()<=12)
		node.clear()
	node.free()
func test_projectile_trail_and_direction_follow_host_without_repositioning_hits() -> void:
	var node := director()
	for id: String in ["KiBlast","DestructoDisc"]:
		var row := {"id":"shot","move_id":id,"pos":Vector3(4,5,6),"dir":Vector3.RIGHT,"presentation":packet()}
		node.sync_projectiles([row])
		var effect: SkillEffect = node.shots.shot
		eq(effect.position,row.pos); ok(effect.moving_parts.size()>=3)
		ok((effect.quaternion*Vector3.BACK).dot(Vector3.RIGHT)>.999)
		effect.advance(.1)
		ok((effect.quaternion*Vector3.BACK).dot(Vector3.RIGHT)>.999,"trail direction survives disc spin")
		node.sync_projectiles([])
	node.clear(); node.free()

func test_transfer_arrival_columns_stay_above_the_destination_floor() -> void:
	var node := director()
	var event := packet(); event.move_id = "InstantTransmission"; event.phase = "impact"; event.pos = Vector3(8,0,4)
	node.handle_event("attack",event)
	ok(not node.effects.is_empty()); near(node.effects[0].position.y,1.1)
	node.clear(); node.free()
