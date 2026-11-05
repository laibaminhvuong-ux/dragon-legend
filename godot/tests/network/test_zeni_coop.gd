extends "res://tests/network/zeni_case.gd"
func test_guest_to_guest_then_guest_to_owner_and_owner_to_guest_all_work() -> void:
	var service := setup(); var r := room(service)
	ok(send(service,"guest",pid(service,"other"),5000).is_empty())
	near(game(service,"guest").slot.zeni,5000); near(game(service,"other").slot.zeni,15000)
	r.time += 1
	ok(send(service,"guest",pid(service,"owner"),1000).is_empty())
	ok(send(service,"owner",pid(service,"guest"),2500).is_empty())
	near(game(service,"owner").slot.zeni,8500); near(game(service,"guest").slot.zeni,6500)
	near(game(service,"other").slot.zeni,15000)
	for member: String in ["owner","guest","other"]:
		near(r.saved.members[identity(service,member)].slot.zeni,game(service,member).slot.zeni)
	service.shutdown()
func test_invalid_commands_are_atomic_and_do_not_consume_success_rate_limit() -> void:
	var service := setup(); var before := wallets(service)
	for amount: Variant in [null,true,false,"5",[],{},0,-10,1.1,NAN,INF,-INF,1000000001,10001]:
		eq(send(service,"guest",pid(service,"other"),amount).type,"error",str(amount)); eq(wallets(service),before)
	for target: Variant in [pid(service,"guest"),"missing",null,12,{},[]]:
		eq(send(service,"guest",target,1).type,"error"); eq(wallets(service),before)
	for args: Array in [[],[pid(service,"other")],[pid(service,"other"),1,"unexpected"]]:
		eq(service.receive("guest",{"type":"command","name":"give_zeni","args":args},0).type,"error")
	ok(send(service,"guest",pid(service,"other"),1).is_empty())
	service.shutdown()
func test_overflow_and_malformed_live_balances_cannot_debit_the_sender() -> void:
	var service := setup(); var r := room(service)
	for invalid: Variant in [RuleZeniTransfer.MAX_BALANCE,NAN,INF,-1,12.5,"10"]:
		game(service,"other").slot.zeni = invalid
		var original_sender: Variant = game(service,"guest").slot.zeni
		var original_saved: Variant = r.saved.members[identity(service,"guest")].slot.zeni
		eq(send(service,"guest",pid(service,"other"),1).type,"error")
		eq(game(service,"guest").slot.zeni,original_sender); eq(r.saved.members[identity(service,"guest")].slot.zeni,original_saved)
		eq(int(r.members[identity(service,"guest")].zeniRevision),0)
	game(service,"other").slot.zeni = 0
	game(service,"guest").slot.zeni = RuleZeniTransfer.MAX_TRANSFER
	ok(send(service,"guest",pid(service,"other"),float(RuleZeniTransfer.MAX_TRANSFER)).is_empty())
	near(game(service,"guest").slot.zeni,0); near(game(service,"other").slot.zeni,RuleZeniTransfer.MAX_TRANSFER)
	service.shutdown()
func test_sender_rate_limit_is_independent_with_one_second_boundary() -> void:
	var service := setup(); var r := room(service)
	ok(send(service,"guest",pid(service,"other"),1).is_empty())
	var before := wallets(service)
	eq(send(service,"guest",pid(service,"owner"),1).type,"error"); eq(wallets(service),before)
	ok(send(service,"other",pid(service,"owner"),1).is_empty(),"receiver is free to send immediately")
	r.time += .999
	eq(send(service,"guest",pid(service,"other"),1).type,"error")
	r.time += .001
	ok(send(service,"guest",pid(service,"owner"),1).is_empty())
	service.shutdown()
func test_room_wide_roster_cross_map_transfers_disconnect_and_isolation() -> void:
	var service := setup(); var r := room(service)
	var receiver := game(service,"other")
	receiver.slot.zone = "namek"; receiver.zone = RuleGame.get_zone("namek")
	r.members[identity(service,"guest")].active = true; r.members[identity(service,"other")].active = true
	var snapshot := service.snapshot("guest")
	eq(snapshot.players.size(),3); eq(snapshot.friends.size(),0,"friends still render only on the same map")
	ok(send(service,"guest",pid(service,"other"),5).is_empty())
	var other_service := setup(); var foreign: String = pid(other_service,"guest")
	r.time += 1
	eq(send(service,"guest",foreign,1).type,"error")
	var gone: String = pid(service,"other"); service.drop_peer("other")
	eq(send(service,"guest",gone,1).type,"error")
	eq(service.snapshot("guest").players.size(),2)
	other_service.shutdown(); service.shutdown()
func test_private_receipts_and_notifications_replicate_with_revision_and_stable_ids() -> void:
	var service := setup(); var r := room(service)
	for value: Dictionary in r.members.values(): value.events.clear()
	ok(send(service,"guest",pid(service,"other"),5000).is_empty())
	var sender: Dictionary = JSON.parse_string(JSON.stringify(service.snapshot("guest")))
	var receiver: Dictionary = JSON.parse_string(JSON.stringify(service.snapshot("other")))
	var observer := service.snapshot("owner")
	var sent: Array = sender.events.filter(func(e: Dictionary) -> bool: return e.name=="zeniTransfer")
	var received: Array = receiver.events.filter(func(e: Dictionary) -> bool: return e.name=="zeniTransfer")
	eq(sent.size(),1); eq(received.size(),1); eq(sent[0].data,received[0].data)
	eq(sent[0].data.from_id,pid(service,"guest")); eq(sent[0].data.to_id,pid(service,"other"))
	eq(sent[0].data.from_name,"Bình"); eq(int(sent[0].data.amount),5000)
	var local := CoopCodec.localize_event(sent[0].data,str(sender.self))
	eq(local.from_id,sent[0].data.from_id); eq(local.to_id,sent[0].data.to_id)
	eq(int(sender.zeniRevision),1); eq(int(receiver.zeniRevision),1); eq(int(observer.zeniRevision),0)
	eq(observer.events.filter(func(e: Dictionary) -> bool: return e.name in ["notify","zeniTransfer"]).size(),0)
	ok(sender.events.any(func(e: Dictionary) -> bool: return e.name=="notify" and e.data.text=="Sent 5,000 zeni to Chi"))
	ok(receiver.events.any(func(e: Dictionary) -> bool: return e.name=="notify" and e.data.text=="Bình sent you 5,000 zeni"))
	service.shutdown()
func test_full_effect_queues_do_not_drop_transfer_receipts() -> void:
	var service := setup(); var r := room(service)
	for peer: String in ["guest","other"]:
		for i in 96: r.members[identity(service,peer)].events.append({"name":"attack","data":{"index":i}})
	ok(send(service,"guest",pid(service,"other"),1).is_empty())
	for peer: String in ["guest","other"]:
		var snapshot := service.snapshot(peer)
		ok(snapshot.events.size()<=96)
		ok(snapshot.events.any(func(e: Dictionary) -> bool: return e.name=="zeniTransfer"))
		eq(int(snapshot.zeniRevision),1)
	service.shutdown()
class ObserveCommit extends RefCounted:
	var inspect: Callable
	var observed := []
	func emit_named(_name: String,_payload: Dictionary) -> void: observed.append(inspect.call())
func test_no_event_callback_observes_only_one_updated_wallet() -> void:
	var service := setup(); var observer := ObserveCommit.new()
	observer.inspect = func() -> Array: return wallets(service)
	game(service,"guest").events = observer; game(service,"other").events = observer
	ok(send(service,"guest",pid(service,"other"),5000).is_empty())
	eq(observer.observed.size(),2)
	for state: Array in observer.observed:
		near(state[1][0],5000); near(state[1][1],5000); near(state[2][0],15000); near(state[2][1],15000)
	observer.inspect = Callable(); service.shutdown()
