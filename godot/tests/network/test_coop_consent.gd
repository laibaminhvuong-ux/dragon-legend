extends TestCase
# Privacy (user rule 2026-11-13): a co-op join sends only the chosen fighter, only after explicit consent.
const PROFILE := "user://test_consent_profile.json"
const BACKUPS := "user://test_consent_backups"
const SETTINGS := "user://test_consent_settings.json"
var _old_profile := ""
var _old_settings := ""

func _setup() -> void:
	_old_profile = SaveStore.path; SaveStore.path = PROFILE
	SaveStore.delete_slot(0)
	SaveStore.create_slot(0,RuleSchema.new().default_look("Saiyan"))
	_old_settings = Settings.path; Settings.path = SETTINGS; Settings.load_file()

func _cleanup() -> void:
	SaveStore.delete_slot(0)
	if FileAccess.file_exists(PROFILE): DirAccess.remove_absolute(PROFILE)
	SaveStore.path = _old_profile
	if FileAccess.file_exists(SETTINGS): DirAccess.remove_absolute(SETTINGS)
	Settings.path = _old_settings; Settings.load_file()
	if DirAccess.dir_exists_absolute(BACKUPS):
		for file: String in DirAccess.get_files_at(BACKUPS): DirAccess.remove_absolute(BACKUPS+"/"+file)
		DirAccess.remove_absolute(BACKUPS)

func _leaky_slot() -> Dictionary:
	var slot: Dictionary = SaveStore.load_slot(0)
	slot.zone = "namek"; slot.position = {"x":1,"y":2,"z":3}; slot.mapSpace = "namek"
	slot.returnTo = {"zone":"namek","position":{"x":0,"y":0,"z":0},"yaw":0.0}
	slot.createdAt = 1234; slot.playedAt = 5678; slot.playTime = 99.0
	slot.debugPath = "C:/Users/Someone/Documents/secret.txt"; slot.home = "/home/someone/.config"; slot.file = "user://profile.json"
	return slot

func _assert_minimal(message: Dictionary) -> void:
	for key: Variant in message: ok(key in CoopCodec.JOIN_KEYS,"top-level key %s is whitelisted" % key)
	for key: Variant in message.slot: ok(key in CoopCodec.SLOT_KEYS,"slot key %s is whitelisted" % key)
	for key: String in CoopCodec.OWNER_SLOT_KEYS: ok(not message.slot.has(key),"%s is not sent to a remote host" % key)
	var text := JSON.stringify(message)
	for needle: String in ["user://","res://","C:/","C:\\\\","/home/","/Users/","secret.txt","debugPath"]:
		ok(not text.contains(needle),"payload has no path fragment "+needle)

func test_remote_join_is_refused_without_consent_and_sends_nothing() -> void:
	_setup()
	var client := CoopClient.new(); client.backup_directory = BACKUPS
	var error := client.begin("ws://127.0.0.1:1","join","123456",0,"Friend")
	ok(error.contains("Confirm"),"join without consent is refused: "+error)
	ok(client.pending.is_empty() and client.socket==null and client.discovery==null,"nothing queued or opened")
	ok(not DirAccess.dir_exists_absolute(BACKUPS) or DirAccess.get_files_at(BACKUPS).is_empty())
	SaveStore.save_slot(0,_leaky_slot())
	client.consent = true
	eq(client.begin("ws://127.0.0.1:1","join","123456",0,"Friend"),"")
	ok(not client.consent,"consent is one-shot")
	_assert_minimal(client.pending)
	eq(client.pending.name,"Friend")
	client.close(); client.free()
	_cleanup()

func test_join_payload_contains_only_whitelisted_keys_and_no_paths() -> void:
	_setup()
	var slot := _leaky_slot()
	var message := CoopCodec.join_message("join","123456",0,slot,"A name that is far too long for the room",CoopCodec.secret())
	_assert_minimal(message)
	eq(message.name.length(),24)
	ok(CoopCodec.import_valid(message.slot),"the minimal slot is still a valid fighter for the host")
	for key: String in CoopCodec.SLOT_KEYS: ok(message.slot.has(key),"needed field %s is kept" % key)
	var owner := CoopCodec.join_message("join","123456",0,slot,"Owner",CoopCodec.secret(),true)
	eq(owner.slot.zone,"namek")
	ok(not owner.slot.has("debugPath"),"unknown fields are dropped even for the owner")
	_cleanup()

func test_host_drops_unlisted_fields_from_remote_peers() -> void:
	_setup()
	var service := CoopService.new(); var code := service.create_room()
	var leaky := _leaky_slot()
	eq(service.authenticate("owner","local",{"type":"join","version":CoopCodec.VERSION,"token":CoopCodec.secret(),"code":code,"slot_index":0,"slot":leaky,"name":"Owner"},0).type,"welcome")
	eq(service.authenticate("7","10.0.0.2",{"type":"join","version":CoopCodec.VERSION,"token":CoopCodec.secret(),"code":code,"slot_index":0,"slot":leaky,"name":"Friend"},0).type,"welcome")
	var room: CoopRoom = service.rooms[code]
	var owner: Dictionary = room.saved.members[service.sessions.owner.identity].slot
	var friend: Dictionary = room.saved.members[service.sessions["7"].identity].slot
	eq(owner.zone,"namek")
	for slot: Dictionary in [owner,friend]: ok(not slot.has("debugPath") and not slot.has("home") and not slot.has("file"))
	ok(not friend.has("returnTo"),"a remote peer's return door is dropped")
	ok(friend.createdAt!=1234 and float(friend.playTime)==0.0,"remote dates/play time never reach the host")
	service.shutdown()
	_cleanup()

func test_client_keeps_its_own_dates_and_play_time_when_saving_host_progress() -> void:
	_setup()
	var client := CoopClient.new(); client.slot_index = 0
	client._local_private = {"createdAt":1234,"playTime":50.0}
	var hosted: Dictionary = SaveStore.load_slot(0); hosted.createdAt = 999999; hosted.playTime = 10.0; hosted.zeni = 4321
	client.latest = {"slot":hosted}
	ok(client.save_progress())
	var saved: Dictionary = SaveStore.load_slot(0)
	eq(int(saved.createdAt),1234); near(float(saved.playTime),60.0); near(float(saved.zeni),4321.0)
	client.free()
	_cleanup()

func test_dont_ask_again_is_per_server_and_kept_only_in_settings() -> void:
	_setup()
	eq(CoopConsent.server_key(" WS://Friend:8910 ",""),"ws://friend:8910")
	eq(CoopConsent.server_key("","123456"),"lan:123456")
	ok(not CoopConsent.remembered("ws://friend:8910"))
	CoopConsent.remember("ws://friend:8910")
	Settings.load_file()
	ok(CoopConsent.remembered("ws://friend:8910"),"stored in the player's own settings file")
	ok(not CoopConsent.remembered("ws://other:8910"),"only for that server")
	var text := CoopConsent.summary("ws://friend:8910","Bình")
	for needle: String in ["ws://friend:8910","Bình","zeni","no files","no other fighter slots"]: ok(text.contains(needle),"summary says "+needle)
	CoopConsent.forget_all(); ok(not CoopConsent.remembered("ws://friend:8910"))
	_cleanup()

func test_server_menu_asks_before_joining_and_upnp_is_off_with_warning() -> void:
	_setup()
	var main := Node.new()
	var menu := ServerMenu.new(main)
	ok(not menu.router.button_pressed,"UPnP is off by default")
	ok(menu.router.text.contains("8910") and menu.router_warning.text.contains("Internet"))
	ok(not menu.router_warning.visible)
	menu.router.button_pressed = true
	ok(menu.router_warning.visible,"the warning shows when UPnP is ticked")
	menu.invite.text = "123456"; menu.address.text = "ws://127.0.0.1:1"
	menu.connect_server("join")
	ok(menu.consent_layer!=null,"consent dialog is shown")
	ok(menu.client==null,"no connection before Accept")
	ok(not menu.consent_remember.button_pressed,"don't-ask-again starts unticked")
	menu.free(); main.free()
	_cleanup()
