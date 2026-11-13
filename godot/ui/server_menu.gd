class_name ServerMenu
extends Control
var main: Node
var host: CoopHost
var router: CheckBox
var host_address: Label
var client: CoopClient
var game_root: CoopPlayRoot
var panel: VBoxContainer
var message: Label
var invite: LineEdit
var address: LineEdit
var nickname: LineEdit
var fighters: OptionButton
var enter: Button
var code_label: Label
var actions: Array[Button] = []
var router_warning: Label
var consent_layer: Control
var consent_remember: CheckBox
func _init(m: Node) -> void:
	main = m; name = "Server"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var shade := ColorRect.new(); shade.color = Color(0.02,0.03,0.06,0.98); shade.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(center)
	var box := PanelContainer.new(); box.custom_minimum_size.x = 650; center.add_child(box)
	panel = VBoxContainer.new(); panel.add_theme_constant_override("separation",12); box.add_child(panel)
	panel.add_child(UiKit.label("Server","HeaderLarge"))
	panel.add_child(UiKit.label("Private co-op for up to 8 friends. Choose your fighter slot. The room closes when its owner leaves.","Muted",true))
	fighters = OptionButton.new()
	for i in SaveStore.SLOTS:
		var slot: Variant = SaveStore.load_slot(i)
		if slot is Dictionary: fighters.add_item("Slot %d · %s · Level %d" % [i+1,str(Data.races.get(str(slot.race),{}).get("name",slot.race)),int(slot.level)],i)
	panel.add_child(fighters)
	nickname = LineEdit.new(); nickname.placeholder_text = "Your name"; nickname.text = "Friend"; nickname.max_length = 24; panel.add_child(nickname)
	invite = LineEdit.new(); invite.placeholder_text = "Six-digit invite code"; invite.max_length = 6; panel.add_child(invite)
	# Privacy/safety (2026-11-13): UPnP is off by default and explains that it opens a port to the Internet.
	router = CheckBox.new(); router.text = "Map router port with UPnP when I create a server (opens TCP 8910 to the Internet)"; router.button_pressed = false; panel.add_child(router)
	router_warning = UiKit.label("Warning: while you host, this asks your router to open TCP port 8910 on your public Internet address. Anyone on the Internet can then reach the game's server port (they still need the six-digit code to join). Leave it off for same-network play; the mapping is removed when the room closes.","Muted",true)
	router_warning.add_theme_color_override("font_color",Color(1.0,0.72,0.3)); router_warning.visible = false; panel.add_child(router_warning)
	router.toggled.connect(func(on: bool) -> void: router_warning.visible = on)
	var row := HBoxContainer.new(); panel.add_child(row)
	for mode: String in ["join","create"]:
		var button := UiKit.button("Join server" if mode=="join" else "Create server",func() -> void: connect_server(mode),true)
		actions.append(button); row.add_child(button)
	code_label = UiKit.label("","HeaderLarge"); code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(code_label)
	var copy := UiKit.button("Copy invite code",func() -> void:
		if client!=null and client.code!="": DisplayServer.clipboard_set(client.code))
	panel.add_child(copy)
	enter = UiKit.button("Enter server",start_play,true); enter.disabled = true; panel.add_child(enter)
	message = UiKit.label("On the same network, join with the code. Internet friends also need the owner's host address and a reachable TCP port.","Muted",true); panel.add_child(message)
	panel.add_child(UiKit.label("Host address (optional on the same Wi-Fi / LAN)","Muted"))
	address = LineEdit.new(); address.placeholder_text = "ws://host-address:8910 or leave blank for LAN discovery"; panel.add_child(address)
	host_address = UiKit.label("","Muted",true); panel.add_child(host_address)
	panel.add_child(UiKit.label("Internet play needs router/firewall access to TCP 8910; automatic setup depends on the router. Direct ws:// traffic is unencrypted; use a VPN or a trusted wss:// proxy for secure Internet play.","Muted",true))
	panel.add_child(UiKit.button("Back",func() -> void:
		if client!=null: client.close()
		if host!=null: host.stop()
		queue_free()))
func connect_server(mode: String,consented: bool = false) -> void:
	if fighters.item_count==0: message.text = "Create a fighter slot first, then return to Server."; return
	# A join sends the chosen fighter to another machine: ask first (creating keeps it on this machine).
	if mode=="join" and not consented:
		var key := CoopConsent.server_key(address.text,invite.text)
		if not CoopConsent.remembered(key): ask_consent(key); return
	if client!=null: client.close(); remove_child(client); client.queue_free()
	if host!=null: host.stop(); host.queue_free(); host = null
	client = CoopClient.new(); add_child(client)
	client.failed.connect(func(text: String) -> void:
		message.text = text
		for button in actions: button.disabled = false)
	client.welcomed.connect(func(code: String) -> void:
		code_label.text = code
		message.text = "Room ready. Share the six-digit code. Your fighter's level, forms and quests are carried over."
		enter.disabled = false
		for button in actions: button.disabled = true)
	var url := address.text.strip_edges()
	var code := invite.text.strip_edges()
	if mode=="create":
		host = CoopHost.new(); add_child(host)
		var listen_error := host.start(CoopHost.PORT,router.button_pressed)
		if listen_error!=OK:
			message.text = "Could not open TCP 8910. Check the firewall or whether another game is already hosting."; return
		client.local_host = weakref(host)
		code = host.code
		host_address.text = "Local host address: "+(", ".join(host.addresses) if not host.addresses.is_empty() else "127.0.0.1:8910")
		host.address_ready.connect(func(ip: String) -> void: host_address.text = "Internet host address: "+ip)
	client.consent = mode=="join"
	var error := client.begin(url,"join",code,fighters.get_selected_id(),nickname.text.strip_edges())
	if error!="":
		message.text = error
		if host!=null: host.stop()
		return
	message.text = "Connecting…"
	for button in actions: button.disabled = true
func ask_consent(key: String) -> void:
	if consent_layer!=null: consent_layer.queue_free()
	consent_layer = Control.new(); consent_layer.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(consent_layer)
	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT); consent_layer.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_preset(Control.PRESET_FULL_RECT); consent_layer.add_child(center)
	var box := PanelContainer.new(); box.custom_minimum_size.x = 600; center.add_child(box)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation",12); box.add_child(col)
	col.add_child(UiKit.label("Share this fighter with the host?","HeaderLarge"))
	col.add_child(UiKit.label(CoopConsent.summary(address.text,nickname.text.strip_edges()),"",true))
	consent_remember = CheckBox.new(); consent_remember.text = "Don't ask again for this server"; consent_remember.button_pressed = false; col.add_child(consent_remember)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); col.add_child(row)
	row.add_child(UiKit.button("Cancel",func() -> void:
		consent_layer.queue_free(); consent_layer = null
		message.text = "Join cancelled. Nothing was sent."))
	row.add_child(UiKit.button("Accept and join",func() -> void:
		if consent_remember.button_pressed: CoopConsent.remember(key)
		consent_layer.queue_free(); consent_layer = null
		connect_server("join",true),true))
func start_play() -> void:
	if client==null or not client.connected or client.latest.is_empty(): message.text = "Waiting for the server world…"; return
	visible = false
	if get_parent() is Control: get_parent().visible = false
	var backdrop: Node = main.get("menu")
	if backdrop is Node3D: backdrop.visible = false
	game_root = CoopPlayRoot.new(); main.add_child(game_root)
	game_root.left.connect(func() -> void:
		visible = true
		if get_parent() is Control: get_parent().visible = true
		if backdrop is Node3D:
			backdrop.visible = true
			var camera := backdrop.get_node_or_null("Camera") as Camera3D
			if camera!=null: camera.make_current()
		enter.disabled = true
		for button in actions: button.disabled = false
		message.text = "Left the server. Your fighter progress is saved. If you were the owner, the room is now closed.")
	game_root.begin(client)

func _exit_tree() -> void:
	if host!=null: host.stop()
