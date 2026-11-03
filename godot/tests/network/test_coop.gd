extends TestCase
func fighter(level: int = 1) -> Dictionary:
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.level = level
	return slot
func join_message(code: String,token: String,slot: Dictionary) -> Dictionary:
	return {"type":"join","version":CoopCodec.VERSION,"token":token,"code":code,"slot_index":0,"slot":slot,"name":"Friend"}
func test_six_digit_codes_and_imported_best_fighter_progress() -> void:
	var service := CoopService.new()
	var code := service.create_room()
	ok(CoopCodec.code_valid(code))
	var slot := fighter(2000)
	slot.forms = ["SSJ","SSJBlue"]
	slot.moves = ["Kamehameha"]
	slot.quests = {"m01_arrival":{"status":"done","completions":1}}
	var reply := service.authenticate("owner","local",join_message(code,CoopCodec.secret(),slot),0)
	eq(reply.type,"welcome")
	var frame := service.snapshot("owner")
	eq(int(frame.slot.level),2000)
	ok("SSJBlue" in frame.slot.forms)
	eq(frame.slot.quests.m01_arrival.status,"done")
	ok(not frame.has("token"))
	service.shutdown()
func test_owner_shutdown_invalidates_code_and_friend_disconnect_keeps_room() -> void:
	var service := CoopService.new()
	var code := service.create_room()
	for id: String in ["owner","friend"]:
		eq(service.authenticate(id,id,join_message(code,CoopCodec.secret(),fighter()),0).type,"welcome")
	service.drop_peer("friend")
	ok(service.rooms.has(code))
	service.shutdown()
	eq(service.sessions.size(),0)
	eq(service.authenticate("new","new",join_message(code,CoopCodec.secret(),fighter()),1).type,"error")
func test_rate_limit_room_isolation_capacity_and_invalid_inputs() -> void:
	var service := CoopService.new()
	var code := service.create_room()
	var token := CoopCodec.secret()
	for i in 13: service.authenticate("bad","bad",join_message("000000",token,fighter()),0)
	ok(service.authenticate("bad","bad",join_message(code,token,fighter()),1).message.contains("Too many"))
	for i in 8:
		eq(service.authenticate(str(i),str(i),join_message(code,CoopCodec.secret(),fighter()),2).type,"welcome")
	eq(service.authenticate("full","full",join_message(code,CoopCodec.secret(),fighter()),2).type,"error")
	var cleaned := CoopCodec.intents({"move_x":99,"move_z":"NaN","health":99999,"position":{"x":99999},"melee":"yes"})
	near(cleaned.move_x,1)
	near(cleaned.move_z,0)
	ok(not cleaned.melee)
	ok(not cleaned.has("health") and not cleaned.has("position"))
	service.shutdown()
func test_friends_share_enemies_and_server_awards_team_quest_kill_credit() -> void:
	var service := CoopService.new()
	var code := service.create_room()
	for id: String in ["one","two"]:
		service.authenticate(id,id,join_message(code,CoopCodec.secret(),fighter()),0)
		service.receive(id,{"type":"command","name":"enter","args":[]},0)
	var room: CoopRoom = service.rooms[code]
	var values: Array = room.members.values()
	var a: RuleGame = values[0].game
	var b: RuleGame = values[1].game
	ok(is_same(a.combat.enemies,b.combat.enemies))
	b.player.pos = a.player.pos+Vector3(1,0,0)
	var enemy: Dictionary = a.combat.enemies[0]
	enemy.pos = a.player.pos+Vector3(0,0,1.8)
	enemy.home = enemy.pos
	var before_a: float = a.slot.xp
	var before_b: float = b.slot.xp
	a.combat.hit(enemy,enemy.health+1,a.player,true)
	ok(a.slot.xp>before_a)
	ok(b.slot.xp>before_b)
	near(b.combat.enemies[0].health,0)
	var health: float = b.player.health
	a.combat.hit(b.player,5,enemy)
	ok(b.player.health<health)
	service.shutdown()
func test_command_validation_rejects_unearned_forms_and_arbitrary_calls() -> void:
	var service := CoopService.new()
	var code := service.create_room()
	service.authenticate("one","one",join_message(code,CoopCodec.secret(),fighter()),0)
	var result := service.receive("one",{"type":"command","name":"form","args":["Beast"]},0)
	eq(result.type,"error")
	eq(service.receive("one",{"type":"command","name":"add_xp","args":[99999]},0).type,"error")
	service.receive("one",{"type":"input","sequence":1,"intents":{"move_x":1,"position":{"x":5000}}},0)
	var identity: String = service.sessions.one.identity
	near(service.rooms[code].members[identity].input.move_x,1)
	service.step(1.0/60,1)
	near(service.rooms[code].members[identity].input.move_x,0)
	service.shutdown()
func test_protocol_vectors_roundtrip_and_urls() -> void:
	var e := {"pos":Vector3(1,2,3),"vel":Vector3.ZERO,"health":100}
	var packet: Dictionary = JSON.parse_string(JSON.stringify(CoopCodec.json_value(e)))
	eq(CoopCodec.entity(packet).pos,Vector3(1,2,3))
	ok(CoopCodec.endpoint_valid("ws://192.168.1.2:8910"))
	ok(CoopCodec.endpoint_valid("wss://friends.example"))
	ok(not CoopCodec.endpoint_valid("file:///tmp/game"))
	ok(not CoopCodec.code_valid("12345"))
	ok(not CoopCodec.code_valid("１２３４５６"))
func test_all_races_import_and_malformed_saves_are_rejected() -> void:
	for race: String in RuleTables.table("race_order"):
		var slot := RuleSchema.new().new_slot(RuleSchema.new().default_look(race))
		ok(CoopCodec.import_valid(slot),race)
	var invalid := fighter()
	invalid.quests = {"m01_arrival":{"status":"active","step":999999}}
	ok(not CoopCodec.import_valid(invalid))
	invalid = fighter(); invalid.appearance.face = []
	ok(not CoopCodec.import_valid(invalid))
	invalid = fighter(); invalid.stats.Strength = "oops"
	ok(not CoopCodec.import_valid(invalid))
func test_late_joiner_arrives_near_owner_without_losing_fighter_progress() -> void:
	var service := CoopService.new(); var code := service.create_room()
	service.authenticate("owner","owner",join_message(code,CoopCodec.secret(),fighter(1500)),0)
	var room: CoopRoom = service.rooms[code]
	var owner: RuleGame = room.members.values()[0].game
	owner.player.pos += Vector3(15,0,10)
	var imported := fighter(2000); imported.zone = "namek"; imported.forms = ["SSJBlue"]
	service.authenticate("friend","friend",join_message(code,CoopCodec.secret(),imported),0)
	var frame := service.snapshot("friend")
	eq(frame.map,owner.zone.id)
	eq(int(frame.slot.level),2000)
	ok("SSJBlue" in frame.slot.forms)
	ok(RuleRuntime.vector(frame.player.pos).distance_to(owner.player.pos)<3)
	service.shutdown()
