extends "res://tests/network/zeni_case.gd"
func test_both_selected_fighters_are_written_immediately_and_survive_disk_reload() -> void:
	var service := setup()
	game(service,"guest").slot.story.flags.note = "Việt Nam 龙"
	game(service,"other").slot.quests.transfer_kept = {"status":"done"}
	var old := SaveStore.path
	var path := "user://zeni_pair_%d.json" % Time.get_ticks_usec(); SaveStore.path = path
	var sender := CoopClient.new(); sender.slot_index = 0; sender.connected = true
	var receiver := CoopClient.new(); receiver.slot_index = 1; receiver.connected = true
	ok(send(service,"guest",pid(service,"other"),5000).is_empty())
	var sender_frame := service.snapshot("guest"); var receiver_frame := service.snapshot("other")
	# No five-second wait and no close() required to commit either received snapshot.
	sender.accept_snapshot(sender_frame); receiver.accept_snapshot(receiver_frame)
	near(SaveStore.load_slot(0).zeni,5000); near(SaveStore.load_slot(1).zeni,15000)
	var disk: Node = load("res://core/save_store.gd").new(); disk.path = path
	near(disk.load_slot(0).zeni,5000); near(disk.load_slot(1).zeni,15000)
	eq(disk.load_slot(0).story.flags.note,"Việt Nam 龙"); eq(disk.load_slot(1).quests.transfer_kept.status,"done")
	near(room(service).saved.members[identity(service,"guest")].slot.zeni,5000)
	near(room(service).saved.members[identity(service,"other")].slot.zeni,15000)
	disk.free(); sender.free(); receiver.free(); service.shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); SaveStore.path = old
func test_failed_local_write_retries_revision_and_reports_the_failure() -> void:
	var service := setup(); var old := SaveStore.path
	var suffix := str(Time.get_ticks_usec())
	var good_path := "user://zeni_recover_"+suffix+".json"
	SaveStore.path = "user://missing_zeni_dir_"+suffix+"/profile.json"
	var client := CoopClient.new(); client.slot_index = 0
	var errors := []; client.failed.connect(func(message: String) -> void: errors.append(message))
	ok(send(service,"guest",pid(service,"other"),1).is_empty())
	var frame := service.snapshot("guest")
	client.accept_snapshot(frame)
	eq(client._saved_zeni_revision,0); eq(errors.size(),1)
	client.accept_snapshot(frame); eq(errors.size(),1)
	SaveStore.path = good_path
	client.accept_snapshot(frame)
	eq(client._saved_zeni_revision,1); near(SaveStore.load_slot(0).zeni,9999)
	near(game(service,"other").slot.zeni,10001,.000001,"host pair remains committed during a remote disk retry")
	client.free(); service.shutdown(); DirAccess.remove_absolute(ProjectSettings.globalize_path(good_path)); SaveStore.path = old
class CountClient extends CoopClient:
	var writes := 0
	var succeeds := true
	func save_progress() -> bool:
		writes += 1; return succeeds
func test_receipt_events_are_not_required_for_revision_saves_and_repeats_do_not_write_again() -> void:
	var client := CountClient.new()
	var frame := {"zeniRevision":1,"slot":{"zeni":100},"events":[]}
	client.accept_snapshot(frame); eq(client.writes,1); eq(client._saved_zeni_revision,1)
	client.accept_snapshot(frame); eq(client.writes,1)
	frame.zeniRevision = 2; client.accept_snapshot(frame); eq(client.writes,2)
	client.free()
class FakeConnection extends RefCounted:
	var connected := true
	var latest := {"self":"self","players":[{"id":"self","name":"Me"},{"id":"friend:b","name":"Bình"},{"id":"friend:c","name":"Chi"}]}
	var sent := []
	func command(name: String,args: Array) -> void: sent.append({"name":name,"args":args})
func test_mirror_menu_api_lists_all_other_players_and_sends_without_predicting() -> void:
	var connection := FakeConnection.new()
	var mirror := CoopGameMirror.new()
	mirror.connection = weakref(connection)
	eq(mirror.zeni_recipients(),[{"id":"friend:b","name":"Bình"},{"id":"friend:c","name":"Chi"}])
	var before: Variant = mirror.slot.zeni
	eq(mirror.give_zeni("friend:c",5000),null)
	eq(connection.sent,[{"name":"give_zeni","args":["friend:c",5000]}]); eq(mirror.slot.zeni,before)
	ok(mirror.give_zeni("friend:c",1.5) is String); eq(connection.sent.size(),1)
	connection.connected = false
	eq(mirror.give_zeni("friend:c",1),"Join a server to send zeni"); eq(mirror.zeni_recipients(),[])
	connection = null
	eq(mirror.give_zeni("friend:c",1),"Join a server to send zeni")
func test_client_scene_forwards_receipt_to_the_typed_event_bus() -> void:
	var service := setup(); ok(send(service,"guest",pid(service,"other"),5).is_empty())
	var frame := service.snapshot("guest"); frame.friends = []
	var session := CoopPlaySession.new()
	var mirror := CoopGameMirror.new(-1,RuleSchema.new().normalize(frame.slot),Events)
	mirror.combat = CoopGameMirror.CombatMirror.new(mirror,Events)
	mirror.kaioken = CoopGameMirror.KaiokenMirror.new(mirror)
	session.game = mirror; session.story = CoopStoryMirror.new(mirror,Events)
	var received := []
	var callback := func(receipt: Dictionary) -> void: received.append(receipt)
	Events.zeni_transfer.connect(callback)
	session.apply_frame(frame)
	Events.zeni_transfer.disconnect(callback)
	eq(received.size(),1); eq(received[0].from_id,pid(service,"guest")); eq(received[0].to_id,pid(service,"other"))
	session.free(); service.shutdown()
func test_owner_local_transport_immediately_saves_received_and_sent_zeni() -> void:
	var old := SaveStore.path; var path := "user://zeni_local_%d.json" % Time.get_ticks_usec(); SaveStore.path = path
	var schema := RuleSchema.new(); var slot := schema.new_slot(schema.default_look(),1000); slot.zeni = 10000
	ok(SaveStore.save_slot(0,slot))
	var host := CoopHost.new(); host.running = true; host.code = host.service.create_room()
	var client := CoopClient.new(); client.slot_index = 0; client.local_host = weakref(host)
	client.backup_directory = "user://zeni_backup_%d" % Time.get_ticks_usec()
	eq(client.begin("","join",host.code,0,"Owner"),"")
	var response := host.service.authenticate("guest","guest",{"type":"join","version":CoopCodec.VERSION,"code":host.code,"token":CoopCodec.secret(),"slot_index":0,"slot":slot,"name":"Guest"},0)
	eq(response.type,"welcome")
	var r: CoopRoom = host.service.rooms[host.code]
	var owner_game: RuleGame = r.members[host.service.sessions.owner.identity].game
	var guest_game: RuleGame = r.members[host.service.sessions.guest.identity].game
	ok(host.service.receive("guest",{"type":"command","name":"give_zeni","args":[owner_game.player.id,2000]},0).is_empty())
	client._process(.11); near(SaveStore.load_slot(0).zeni,12000); eq(client._saved_zeni_revision,1)
	client.command("give_zeni",[guest_game.player.id,500])
	client._process(.11); near(SaveStore.load_slot(0).zeni,11500); eq(client._saved_zeni_revision,2)
	near(guest_game.slot.zeni,8500)
	var backup_path: String = client.backup_directory
	client.close(); client.free(); host.free()
	for file: String in DirAccess.get_files_at(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path+"/"+file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); SaveStore.path = old
