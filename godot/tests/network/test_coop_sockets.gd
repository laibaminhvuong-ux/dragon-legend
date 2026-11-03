extends TestCase
func opt_in() -> Dictionary:
	return {"test_two_real_websocket_peers_join_play_and_owner_closes":"coop-sockets"}
func test_two_real_websocket_peers_join_play_and_owner_closes() -> void:
	var host := CoopHost.new()
	var result := host.start(18910,false)
	eq(result,OK,"requires local socket permissions")
	if result!=OK: host.free(); return
	var peers: Array[WebSocketPeer] = []
	var code := host.code
	for i in 2:
		var ws := WebSocketPeer.new()
		eq(ws.connect_to_url("ws://127.0.0.1:18910"),OK)
		peers.append(ws)
	var sent := [false,false]
	var joined := [false,false]
	for i in 1000:
		host._process(0.005)
		for p in 2:
			var ws := peers[p]; ws.poll()
			if ws.get_ready_state()==WebSocketPeer.STATE_OPEN and not sent[p]:
				ws.send_text(JSON.stringify({"type":"join","version":CoopCodec.VERSION,"token":CoopCodec.secret(),"code":code,"slot_index":0,"name":"Friend","slot":RuleSchema.new().new_slot(RuleSchema.new().default_look("Saiyan"))}))
				sent[p] = true
			while ws.get_available_packet_count()>0:
				var reply: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if reply is Dictionary and reply.get("type")=="welcome": joined[p] = true
		if joined[0] and joined[1]: break
		OS.delay_msec(2)
	ok(joined[0] and joined[1],"two actual WebSocket handshakes and authenticated joins")
	for ws in peers:
		ws.send_text(JSON.stringify({"type":"command","name":"enter","args":[]}))
		ws.send_text(JSON.stringify({"type":"input","sequence":1,"intents":{"move_x":1,"sprint":true}}))
	var frames: Array = [{},{}]
	for i in 120:
		host._process(0.005)
		for index in 2:
			var ws := peers[index]; ws.poll()
			while ws.get_available_packet_count()>0:
				var reply: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
				if reply is Dictionary and reply.get("type")=="snapshot": frames[index] = reply
		OS.delay_msec(2)
	for frame: Dictionary in frames:
		ok(not frame.is_empty(),"real socket receives authoritative gameplay snapshots")
		if not frame.is_empty(): ok(frame.friends.size()==1,"each peer sees the other active fighter")
	host.stop()
	ok(not host.running and host.service.rooms.is_empty())
	for ws in peers: ws.poll(); ws.close()
	host.free()
