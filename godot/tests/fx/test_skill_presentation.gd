extends TestCase
func director() -> SkillDirector:
	var node := SkillDirector.new()
	Engine.get_main_loop().root.add_child(node)
	node.bind(null,Callable(),"low")
	return node
func packet(sequence: int = 1) -> Dictionary:
	return {"move_id":"Kamehameha","actor_id":"friend","action_sequence":sequence,"phase":"prepare","seed":15,"origin":Vector3(2,3,4),"color":0x12ab34}
func test_catalogue_covers_every_move_and_sound_phase() -> void:
	eq(SkillCatalog.all().size(),28)
	for id: String in RuleTables.table("moves"):
		var profile := SkillCatalog.get_skill(id)
		ok(not profile.is_empty(),id)
		ok(profile.socket in RuleTables.table("skill_presentation").sockets,id)
		for phase: String in ["prepare","release","impact"]:
			ok(CombatAudio.bank().has(profile.phases[phase].audio),id+phase)
	ok(not SkillCatalog.active("GodKi")); ok(not SkillCatalog.active("FusionDance"))
	eq(SkillCatalog.get_skill("SpiritBomb").delivery,"instant_ray")
func test_cast_dedup_stale_cancellation_and_pause_cleanup() -> void:
	var node := director()
	var event := packet(2); event.event_id = "one"
	node.handle_event("attack",event); node.handle_event("attack",event)
	eq(node.effects.size(),1); eq(node.charging.size(),1); ok(node.audio.loops.size()<=1)
	var old := packet(1); old.phase = "cancel"
	node.handle_event("attack",old); eq(node.charging.size(),1)
	node.set_paused(true); near(node.effects[0].age,0)
	node._process(1); near(node.effects[0].age,0)
	old.action_sequence = 2; node.handle_event("attack",old)
	eq(node.charging.size(),0); eq(node.audio.loops.size(),0)
	node.clear(); eq(node.effects.size(),0); node.free()
func test_every_shape_builds_and_effect_budget_is_bounded() -> void:
	var node := director()
	for id: String in SkillCatalog.all():
		var event := packet(); event.move_id = id; event.phase = "release"; event.from = Vector3.ZERO; event.to = Vector3(0,0,20)
		var effect := node.spawn_effect(SkillCatalog.get_skill(id),event,"release",Vector3.ZERO)
		ok(effect.parts.size()>0,id)
		ok(effect.parts.size()<=12,id)
		effect.advance(.1)
	ok(node.effects.size()<=12)
	node.clear(); node.free()
func test_projectiles_follow_authoritative_positions_and_disappear() -> void:
	var node := director()
	var row := {"id":"friend:1","move_id":"KiBlast","pos":Vector3(1,2,3),"presentation":packet()}
	node.sync_projectiles([row]); eq(node.shots.size(),1)
	row.pos = Vector3(4,5,6); node.sync_projectiles([row])
	eq(node.shots["friend:1"].position,Vector3(4,5,6))
	node.sync_projectiles([]); eq(node.shots.size(),0); node.free()
func test_charge_late_join_and_audio_voice_limits() -> void:
	var node := director()
	node.update_actor_states([{"skillState":packet()}]); eq(node.charging.size(),1)
	node.update_actor_states([]); eq(node.charging.size(),0)
	for i in 35: node.audio.play_cue("hit",Vector3.ZERO,1,i)
	ok(node.audio.voices.size()<=CombatAudio.MAX_VOICES)
	for i in 12: node.audio.start_loop(str(i),"wave_charge",Vector3.ZERO,i)
	ok(node.audio.loops.size()<=CombatAudio.MAX_LOOPS)
	node.free()

class FakeBus extends Node:
	signal attack(packet: Dictionary)
	signal beam(packet: Dictionary)
	signal damage(packet: Dictionary)
	signal avatar_strike(packet: Dictionary)
func test_typed_bus_binding_closed_cast_and_new_snapshot_recipe() -> void:
	var bus := FakeBus.new(); var node := director()
	node.bind(bus,Callable(),"low")
	bus.attack.emit(packet(1)); eq(node.charging.size(),1)
	var release := packet(1); release.phase = "release"
	bus.attack.emit(release); eq(node.charging.size(),0)
	bus.attack.emit(packet(1)); eq(node.charging.size(),0)
	node.update_actor_states([{"skillState":packet(2)}]); eq(node.charging.size(),1)
	var next := packet(3); next.move_id = "DestructoDisc"
	node.update_actor_states([{"skillState":next}])
	eq(node.charging.friend.profile.id,"DestructoDisc")
	node.unbind(); eq(node._connections.size(),0)
	node.clear(); node.free(); bus.free()

func test_kaioken_overlay_does_not_cancel_a_held_skill() -> void:
	var node := director(); node.handle_event("attack",packet(1))
	var overlay := packet(2); overlay.move_id = "Kaioken"; overlay.phase = "release"
	node.handle_event("attack",overlay); eq(node.charging.size(),1)
	var release := packet(1); release.phase = "release"
	node.handle_event("attack",release); eq(node.charging.size(),0)
	node.clear(); node.free()
