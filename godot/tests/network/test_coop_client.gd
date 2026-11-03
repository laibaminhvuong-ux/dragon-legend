extends TestCase
var _old := ""
func setup_slot() -> CoopClient:
	_old = SaveStore.path
	SaveStore.path = "user://test_coop_profile.json"
	SaveStore.delete_slot(0)
	SaveStore.create_slot(0,RuleSchema.new().default_look("Saiyan"))
	var slot: Dictionary = SaveStore.load_slot(0)
	slot.level = 2000; slot.forms = ["SSJ","SSJBlue"]; slot.quests = {"m01_arrival":{"status":"done","completions":1}}
	SaveStore.save_slot(0,slot)
	var client := CoopClient.new()
	client.backup_directory = "user://test_coop_backups"
	return client
func cleanup(client: CoopClient,host: CoopHost) -> void:
	client.close(); client.free(); host.stop(); host.free()
	SaveStore.delete_slot(0); SaveStore.path = _old
	if DirAccess.dir_exists_absolute("user://test_coop_backups"):
		for file: String in DirAccess.get_files_at("user://test_coop_backups"):
			DirAccess.remove_absolute("user://test_coop_backups/"+file)
		DirAccess.remove_absolute("user://test_coop_backups")
func test_owner_direct_transport_import_save_and_shutdown_without_sockets() -> void:
	var client := setup_slot()
	var host := CoopHost.new()
	host.running = true; host.code = host.service.create_room()
	client.local_host = weakref(host)
	eq(client.begin("","join",host.code,0,"Owner"),"")
	client._process(0.11)
	eq(int(client.latest.slot.level),2000)
	client.command("enter")
	var member: String = host.service.sessions.owner.identity
	host.service.rooms[host.code].members[member].game.add_zeni(123)
	host.service.step(1.0/60,Time.get_ticks_msec()/1000.0)
	client._process(0.11)
	var zeni: float = client.latest.slot.zeni
	client.close()
	ok(not host.running)
	eq(host.service.sessions.size(),0)
	near(SaveStore.load_slot(0).zeni,zeni)
	ok(not DirAccess.get_files_at("user://test_coop_backups").is_empty())
	cleanup(client,host)
func test_client_mirror_commands_do_not_grant_unearned_rewards() -> void:
	var client := setup_slot()
	var host := CoopHost.new(); host.running = true; host.code = host.service.create_room()
	client.local_host = weakref(host); client.begin("","join",host.code,0,"Owner"); client._process(0.11)
	var mirror := CoopGameMirror.new(-1,client.latest.slot)
	mirror.connection = weakref(client)
	var hp: float = mirror.player.health
	var xp: float = mirror.slot.xp
	mirror.select_form("Beast")
	near(mirror.player.health,hp)
	near(mirror.slot.xp,xp)
	cleanup(client,host)
func test_online_scene_uses_server_snapshots_and_friends() -> void:
	if Data.camera.is_empty(): Data.load_dir("res://data")
	var client := setup_slot()
	var host := CoopHost.new(); host.running = true; host.code = host.service.create_room()
	client.local_host = weakref(host); client.begin("","join",host.code,0,"Owner"); client.command("enter"); client._process(0.11)
	var gi := GameInput.new()
	var session := CoopPlaySession.new(); session.add_child(gi)
	(Engine.get_main_loop() as SceneTree).root.add_child(session)
	ok(session.start_online(client,client.latest,gi))
	session.apply_frame(client.latest)
	session.step(1.0/60); session.render(1.0/60,1)
	eq(int(session.game.slot.level),2000)
	ok(session.game is CoopGameMirror)
	session.shutdown(); session.get_parent().remove_child(session); session.free()
	cleanup(client,host)

func test_server_menu_exposes_fighter_picker_join_and_create() -> void:
	var client := setup_slot()
	var host := CoopHost.new()
	var main := Node.new()
	var menu := ServerMenu.new(main)
	ok(menu.fighters.item_count>0)
	eq(menu.actions[0].text,"Join server")
	eq(menu.actions[1].text,"Create server")
	eq(menu.invite.max_length,6)
	ok(menu.enter.disabled)
	menu.free(); main.free()
	cleanup(client,host)
