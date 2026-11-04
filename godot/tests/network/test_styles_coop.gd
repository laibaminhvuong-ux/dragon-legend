extends TestCase
func fighter(style: String = "turtle") -> Dictionary:
	var schema := RuleSchema.new(); var slot := schema.new_slot(schema.default_look(),1000)
	slot.style = style; slot.level = 100; return slot
func joined(service: CoopService,code: String,id: String,style: String = "turtle") -> Dictionary:
	return service.authenticate(id,id,{"type":"join","version":CoopCodec.VERSION,"code":code,"token":CoopCodec.secret(),"slot_index":0,"name":id,"slot":fighter(style)},0)
func command(service: CoopService,id: String,style: Variant) -> Dictionary:
	return service.receive(id,{"type":"command","name":"set_style","args":[style]},0)
func test_style_commands_are_authoritative_validated_and_refused_during_strikes() -> void:
	var service := CoopService.new(); var code := service.create_room()
	eq(joined(service,code,"owner").type,"welcome")
	var identity: String = service.sessions.owner.identity
	var game: RuleGame = service.rooms[code].members[identity].game
	for invalid: Variant in ["unknown",4,{},null,[],true]:
		eq(command(service,"owner",invalid).type,"error"); eq(game.player.style,"turtle")
	ok(command(service,"owner","brawler").is_empty()); eq(game.player.style,"brawler")
	game.combat.update(.01,{"melee":true})
	eq(command(service,"owner","speedster").type,"error"); eq(game.slot.style,"brawler")
	game.combat.update(.6,{})
	ok(command(service,"owner","speedster").is_empty()); eq(game.player.style,"speedster")
	var snapshot := service.snapshot("owner")
	eq(snapshot.player.style,"speedster"); eq(snapshot.slot.style,"speedster"); eq(snapshot.combat.style,"speedster")
	service.receive("owner",{"type":"input","sequence":1,"intents":{"style":"brawler","damage_scale":10000}},0)
	eq(game.player.style,"speedster","untrusted intents cannot change style or tuning")
	service.shutdown()
func test_late_join_keeps_independent_fighter_styles_and_localises_all_move_fields() -> void:
	var service := CoopService.new(); var code := service.create_room()
	eq(joined(service,code,"owner","brawler").type,"welcome")
	service.receive("owner",{"type":"command","name":"enter","args":[]},0)
	var room: CoopRoom = service.rooms[code]
	var game: RuleGame = room.members[service.sessions.owner.identity].game
	var enemy: Dictionary = game.combat.enemies[0]
	enemy.pos = game.player.pos+Vector3(0,0,1.5); enemy.home = enemy.pos
	enemy.health = 1000000000.0; enemy.maxHealth = enemy.health; enemy.stun = 10.0
	game.combat.update(.01,{"melee":true})
	eq(joined(service,code,"friend","crane").type,"welcome")
	var late: Dictionary = JSON.parse_string(JSON.stringify(service.snapshot("friend")))
	eq(late.player.style,"crane"); eq(late.friends[0].player.style,"brawler")
	eq(late.friends[0].player.skillState.move,"brawler_wide_hook")
	game.combat.melee_cd = 0; game.combat.update(.1,{"melee":true})
	var owner := service.snapshot("owner"); var friend := service.snapshot("friend")
	var attacks: Array = owner.events.filter(func(e: Dictionary) -> bool: return e.name=="attack" and e.data.get("phase")=="release")
	var raw: Dictionary = attacks.back().data
	var self_event := CoopCodec.localize_event(raw,str(owner.self))
	var remote_event := CoopCodec.localize_event(raw,str(friend.self))
	eq(self_event.actor_id,"player"); eq(remote_event.actor_id,game.player.id)
	for key: String in ["style","move","combo_move","combo_step","strike","finisher","chain_window","lunge","strike_duration","seed","event_id"]:
		eq(self_event[key],raw[key]); eq(remote_event[key],raw[key])
	var damage_events: Array = friend.events.filter(func(e: Dictionary) -> bool: return e.name=="damage")
	ok(not damage_events.is_empty())
	var damage: Dictionary = CoopCodec.localize_event(damage_events.back().data,str(friend.self))
	for key: String in ["knockback","launch","stagger","hitstop","style","move"]: ok(damage.has(key),key)
	service.shutdown()
func test_coop_import_rejects_invalid_explicit_style_but_accepts_legacy_default() -> void:
	for value: Variant in ["unknown",{},false,4,[]]:
		var bad := fighter(); bad.style = value; ok(not CoopCodec.import_valid(bad))
	var legacy := fighter(); legacy.erase("style"); ok(CoopCodec.import_valid(legacy))
	for id: String in RuleStyles.all(): ok(CoopCodec.import_valid(fighter(id)))
func test_game_mirror_sends_the_exact_menu_command_without_predicting_style() -> void:
	var connection := FakeConnection.new()
	var mirror := CoopGameMirror.new(0,fighter(),null); mirror.connection = weakref(connection)
	eq(mirror.set_style("crane"),null)
	eq(connection.messages,[{"name":"set_style","args":["crane"]}])
	eq(mirror.player.style,"turtle")
class FakeConnection extends RefCounted:
	var messages := []
	func command(name: String,args: Array) -> void: messages.append({"name":name,"args":args})
