extends TestCase
func fighter(level: int = 1) -> Dictionary:
	var schema := RuleSchema.new()
	var slot := schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.level = level
	return slot
func join_message(code: String,token: String,slot: Dictionary) -> Dictionary:
	return {"type":"join","version":CoopCodec.VERSION,"token":token,"code":code,"slot_index":0,"slot":slot,"name":"Friend"}

func test_cast_state_and_move_context_survive_host_snapshot_and_json() -> void:
	var service := CoopService.new(); var code := service.create_room()
	for id: String in ["owner","friend"]:
		service.authenticate(id,id,join_message(code,CoopCodec.secret(),fighter()),0)
	var room: CoopRoom = service.rooms[code]
	var owner_id: String = service.sessions.owner.identity
	var friend_id: String = service.sessions.friend.identity
	room.members[owner_id].active = true; room.members[friend_id].active = true
	var g: RuleGame = room.members[owner_id].game
	g.combat.update(.1,{"beam":true})
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(service.snapshot("friend")))
	eq(snapshot.friends.size(),1)
	eq(snapshot.friends[0].player.skillState.move_id,"EnergyWave")
	var event: Dictionary = snapshot.events.filter(func(row: Dictionary) -> bool: return row.name=="attack" and row.data.get("phase")=="prepare")[0].data
	var localized := CoopCodec.localize_event(event,g.player.id)
	eq(localized.actor_id,"player"); eq(localized.event_id,event.event_id)
	eq(localized.origin,RuleRuntime.vector(event.origin))
	g.combat.fire("KiBlast")
	var shot: Dictionary = service.snapshot("friend").projectiles[0]
	eq(shot.move_id,"KiBlast"); eq(shot.presentation.actor_id,g.player.id)
	ok(not shot.has("owner")); service.shutdown()
