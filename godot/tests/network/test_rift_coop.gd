extends TestCase
func fighter() -> Dictionary:
	var schema:=RuleSchema.new()
	var slot:=schema.new_slot(schema.default_look(),1000)
	slot.zone="time_nexus";slot.level=2000
	for q: Dictionary in RuleTables.table("quests"):
		if q.get("main",false):slot.quests[q.id]={"status":"done","completions":1}
	return slot
func room() -> CoopRoom:
	var r:=CoopRoom.new({"code":"123456","members":{}})
	for id: String in ["owner","guest"]:
		ok(r.add(id,id,fighter()).get("ok",false))
		eq(r.command(id,"enter",[]),null)
	return r
func clear(r: CoopRoom) -> void:
	for guard: int in 8:
		if not r.rift_run.active():return
		var g: RuleGame=r.members.guest.game
		g.combat.sync()
		for e: Dictionary in g.combat.enemies.duplicate():g.combat.hit(e,e.maxHealth+100,g.player,true)
func test_rift_coop_owner_validation_shared_world_and_once_only_party_rewards() -> void:
	var r:=room()
	ok(r.command("guest","rift_start",["rp01_dark_crystal"]) is String)
	ok(r.command("owner","rift_start",["bogus"]) is String)
	eq(r.command("owner","rift_start",["rp01_dark_crystal"]),null)
	ok(r.rift_run.active())
	ok(is_same(r.members.owner.game.rift,r.members.guest.game.rift))
	ok(is_same(r.members.owner.game.combat.allies,r.members.guest.game.combat.allies))
	ok(is_same(r.members.owner.game.combat.enemies,r.members.guest.game.combat.enemies))
	ok(r.add("late","Late",fighter()).has("error"))
	ok(r.command("guest","travel",["time_nexus"]) is String)
	ok(r.command("guest","rift_abandon",[]) is String)
	var a: float=r.members.owner.game.slot.zeni
	var b: float=r.members.guest.game.slot.zeni
	clear(r)
	for id: String in ["owner","guest"]:
		var slot: Dictionary=r.members[id].game.slot
		near(slot.zeni,(a if id=="owner" else b)+50000)
		eq(slot.rift.cards.size(),2)
		eq(slot.rift.results.rp01_dark_crystal.clears,1)
		eq(r.saved.members[id].slot.rift.cards,slot.rift.cards,"both saved before callback")
		var frame:=r.snapshot(id)
		eq(frame.rift.status,"complete")
		ok(frame.zeniRevision>0)
		eq(frame.events.filter(func(e: Dictionary)->bool:return e.name=="riftMissionComplete").size(),1)
	r.rift_run.finish(true,"")
	near(r.members.owner.game.slot.zeni,a+50000)
func test_rift_coop_protection_failure_disconnect_and_timer_once_per_room() -> void:
	var r:=room()
	eq(r.command("owner","rift_start",["rp01_dark_crystal"]),null)
	r.step(.1)
	near(r.rift_run.run.timer,.1)
	var frame:=r.snapshot("guest")
	eq(frame.allies.size(),2)
	ok(frame.allies[0].pos is Dictionary,"JSON vector representation")
	ok(CoopCodec.entity(frame.allies[0]).pos is Vector3)
	var wallet: float=r.members.owner.game.slot.zeni
	r.remove("guest")
	eq(r.rift_run.run.status,"failed")
	near(r.members.owner.game.slot.zeni,wallet)
	ok(not r.members.owner.game.slot.rift.results.has("rp01_dark_crystal"))
	ok(not r.saved.members.owner.slot.rift.has("pending"))
	ok(r.snapshot("owner").events.any(func(e: Dictionary)->bool:return e.name=="riftMissionFailed"))
func test_rift_coop_cards_validate_and_ally_bonus_uses_every_fighter() -> void:
	var r:=room()
	var card: String="rp04_shard_emperor_hero" # ally health
	for m: Dictionary in r.members.values():m.game.slot.rift.cards.append(card)
	for id: String in ["owner","guest"]:
		eq(r.command(id,"hero_card",[card,0]),null)
		eq(r.saved.members[id].slot.rift.equipped[0],card)
	ok(r.command("guest","hero_card",[card,1.5]) is String)
	eq(r.command("owner","rift_start",["rp01_dark_crystal"]),null)
	near(r.rift_run.allies[0].maxHealth,32000*1.06,.001)
	ok(r.command("guest","hero_card",["",0]) is String)
	eq(r.command("owner","rift_abandon",[]),null)
	eq(r.command("owner","rift_hub",[]),null)
	for m: Dictionary in r.members.values():eq(m.game.current_region(),"time_nexus")
func test_rift_mirror_commands_do_not_predict_rewards_or_spawn_ai() -> void:
	var client:=CoopClient.new();client.connected=true
	var mirror:=CoopGameMirror.new(0,fighter())
	mirror.connection=weakref(client)
	var wallet: float=mirror.slot.zeni
	eq(mirror.start_rift_mission("rp01_dark_crystal"),null)
	near(mirror.slot.zeni,wallet)
	eq(mirror.slot.rift.cards,[])
	ok(not mirror.rift.active())
	client.latest={"rift":{"id":"rp01_dark_crystal","timer":5.0,"status":"active"}}
	eq(mirror.active_rift_mission().timer,5.0)
	client.free()
func test_rift_coop_locked_or_downed_fighter_prevents_launch_without_partial_travel() -> void:
	var r:=room()
	r.members.guest.game.slot.quests.erase(RuleTables.table("rift_missions").unlock_quest)
	ok(r.command("owner","rift_start",["rp01_dark_crystal"]) is String)
	ok(r.rift_run==null)
	for m: Dictionary in r.members.values():eq(m.game.current_region(),"time_nexus")
	r.members.guest.game.slot.quests[RuleTables.table("rift_missions").unlock_quest]={"status":"done","completions":1}
	r.members.guest.game.player.health=0
	ok(r.command("owner","rift_start",["rp01_dark_crystal"]) is String)
	ok(r.rift_run==null)
	r.members.guest.game.player.health=r.members.guest.game.player.maxHealth
	eq(r.members.owner.game.start_rift_mission("rp01_dark_crystal"),null,"server game API routes through room")
	ok(r.rift_run.active())
	ok(r.members.guest.game.abandon_rift_mission() is String)
	eq(r.members.owner.game.abandon_rift_mission(),null)
	eq(r.members.owner.game.enter_rift_hub(),null)
	for m: Dictionary in r.members.values():eq(m.game.current_region(),"time_nexus")

func test_rift_coop_client_completion_revision_saves_cards_and_stars_to_disk() -> void:
	var r:=room()
	eq(r.command("owner","rift_start",["rp01_dark_crystal"]),null)
	clear(r)
	var old_path: String=SaveStore.path
	SaveStore.path="user://rift_coop_%d.json" % Time.get_ticks_usec()
	var client:=CoopClient.new();client.slot_index=0
	var frame: Dictionary=JSON.parse_string(JSON.stringify(r.snapshot("guest")))
	client.accept_snapshot(frame)
	var saved_slot: Dictionary=SaveStore.load_slot(0)
	eq(saved_slot.rift.cards.size(),2)
	eq(int(saved_slot.rift.results.rp01_dark_crystal.stars),3)
	near(saved_slot.zeni,r.members.guest.game.slot.zeni)
	ok(client._saved_zeni_revision>0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path))
	SaveStore.path=old_path
	client.free()
func test_rift_room_discards_private_pending_preserves_world_and_prioritizes_receipts() -> void:
	var r:=CoopRoom.new({"code":"123456","members":{}})
	var imported:=fighter();imported.zone="earth_plains";imported.rift.pending="rp01_dark_crystal"
	for id: String in ["owner","guest"]:
		ok(r.add(id,id,imported).get("ok",false))
		ok(not r.members[id].game.rift.active(),"offline pending cannot create a private room mission")
		eq(r.command(id,"enter",[]),null)
	var original: Dictionary=r.members.owner.game.combat.enemies[0]
	original.health=17.0
	eq(r.members.owner.game.enter_rift_hub(),null)
	eq(r.command("owner","rift_start",["rp01_dark_crystal"]),null)
	for m: Dictionary in r.members.values():
		m.events.clear()
		for i: int in 96:m.events.append({"name":"attack","data":{}})
	clear(r)
	ok(r.members.owner.game.combat.enemies.has(original),"pre-mission world restored")
	near(original.health,17)
	for id: String in ["owner","guest"]:
		var frame:=r.snapshot(id)
		ok(frame.events.any(func(e: Dictionary)->bool:return e.name=="riftMissionComplete"),"completion survives a full FX queue")
