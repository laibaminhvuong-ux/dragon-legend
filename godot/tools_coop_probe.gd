# Dev: two separate game processes over the real network.
#   host:  godot --headless --path godot -s res://tools_coop_probe.gd -- --host --seconds=40 --codefile=<path>
#   join:  godot --headless --path godot -s res://tools_coop_probe.gd -- --join=<code> [--url=ws://ip:8910]
# The joiner finds the host by its six-digit code (LAN discovery) unless --url is given, joins with a fighter,
# enters play, moves, and checks the authoritative snapshots show the host's fighter.
extends SceneTree

var args := {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var eq := a.find("=")
			args[a.substr(2, eq - 2) if eq > 0 else a.substr(2)] = a.substr(eq + 1) if eq > 0 else "1"
	if args.has("host"): _host()
	else: _join()

func _host() -> void:
	var host := CoopHost.new()
	root.add_child(host)
	var err := host.start(CoopHost.PORT, false)
	print("HOST start ", error_string(err), " code ", host.code, " addresses ", host.addresses)
	if args.has("codefile"):
		var f := FileAccess.open(str(args.codefile), FileAccess.WRITE); f.store_string(host.code); f.close()
	# the owner joins its own room in-process, like the game does, so the friend sees a fighter
	var owner := WebSocketPeer.new()
	owner.connect_to_url("ws://127.0.0.1:%d" % CoopHost.PORT)
	var sent := false
	var t := 0.0
	while t < float(args.get("seconds", "40")):
		await process_frame
		t += get_root().get_process_delta_time()
		owner.poll()
		if owner.get_ready_state() == WebSocketPeer.STATE_OPEN and not sent:
			owner.send_text(JSON.stringify({"type":"join","version":CoopCodec.VERSION,"token":CoopCodec.secret(),"code":host.code,"slot_index":0,"name":"Owner","slot":RuleSchema.new().new_slot(RuleSchema.new().default_look("Saiyan"))}))
			owner.send_text(JSON.stringify({"type":"command","name":"enter","args":[]}))
			sent = true
		while owner.get_available_packet_count() > 0: owner.get_packet()
	print("HOST rooms open ", host.service.rooms.size())
	host.stop()
	print("HOST stopped")
	quit()

func _join() -> void:
	var code := str(args.join)
	var url := str(args.get("url", ""))
	if url == "":
		var d := CoopDiscovery.new()
		root.add_child(d)
		print("JOIN discovery ", error_string(d.search(code)))
		var got: Array = []
		d.found.connect(func(u: String) -> void: got.append(u))
		d.failed.connect(func() -> void: got.append(""))
		while got.is_empty():
			await process_frame
		url = got[0]
		print("JOIN discovered ", url if url != "" else "NOTHING")
		if url == "": quit(1); return
	var ws := WebSocketPeer.new()
	ws.connect_to_url(url)
	var state := "connecting"
	var t0 := Time.get_ticks_msec()
	var snapshots := 0
	var friends := 0
	while Time.get_ticks_msec() - t0 < 15000:
		await process_frame
		ws.poll()
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN and state == "connecting":
			ws.send_text(JSON.stringify({"type":"join","version":CoopCodec.VERSION,"token":CoopCodec.secret(),"code":code,"slot_index":1,"name":"Friend","slot":RuleSchema.new().new_slot(RuleSchema.new().default_look("Namekian"))}))
			state = "joining"
		while ws.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if not m is Dictionary: continue
			if m.get("type") == "welcome" and state == "joining":
				state = "playing"
				print("JOIN welcomed after ", Time.get_ticks_msec() - t0, " ms")
				ws.send_text(JSON.stringify({"type":"command","name":"enter","args":[]}))
			elif m.get("type") == "snapshot":
				snapshots += 1
				friends = maxi(friends, (m.get("friends", []) as Array).size())
				if snapshots % 20 == 0:
					ws.send_text(JSON.stringify({"type":"input","sequence":snapshots,"intents":{"move_z":1,"sprint":true}}))
			elif m.get("type") == "error":
				print("JOIN error ", m)
		if snapshots >= 120: break
	print("JOIN result state=", state, " snapshots=", snapshots, " friends_seen=", friends)
	ws.close()
	quit(0 if state == "playing" and snapshots > 0 and friends >= 1 else 1)
