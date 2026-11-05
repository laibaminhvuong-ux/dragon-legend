extends TestCase
func opt_in() -> Dictionary:
	return {"test_real_guest_can_transfer_to_another_connected_player":"zeni-sockets"}
func test_real_guest_can_transfer_to_another_connected_player() -> void:
	var host := CoopHost.new()
	var result := host.start(18938,false)
	eq(result,OK,"requires unrestricted local socket access")
	if result!=OK: host.free(); return
	var peers: Array[WebSocketPeer] = []
	for i in 2:
		var socket := WebSocketPeer.new(); socket.inbound_buffer_size = 2097152
		eq(socket.connect_to_url("ws://127.0.0.1:18938"),OK); peers.append(socket)
	var sent := [false,false]; var ids := ["",""]
	for frame in 1000:
		host._process(.005)
		for i in 2:
			var socket := peers[i]; socket.poll()
			if socket.get_ready_state()==WebSocketPeer.STATE_OPEN and not sent[i]:
				var schema := RuleSchema.new(); var slot := schema.new_slot(schema.default_look(),1000); slot.zeni = 10000
				socket.send_text(JSON.stringify({"type":"join","version":CoopCodec.VERSION,"code":host.code,"token":CoopCodec.secret(),"slot_index":0,"slot":slot,"name":"Guest%d" % i})); sent[i] = true
			while socket.get_available_packet_count()>0:
				var message: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
				if message is Dictionary and message.get("type")=="welcome": ids[i] = message.self
		if ids[0]!="" and ids[1]!="": break
		OS.delay_msec(2)
	ok(ids[0]!="" and ids[1]!="","both real peers authenticate")
	if ids[0]=="" or ids[1]=="":
		host.stop(); host.free(); return
	# The SECOND guest sends, so there is no assumption that only the first member/owner can send.
	peers[1].send_text(JSON.stringify({"type":"command","name":"give_zeni","args":[ids[0],5000]}))
	var frames: Array = [{},{}]; var receipts := [false,false]
	for tick in 1000:
		host._process(.005)
		for i in 2:
			var socket := peers[i]; socket.poll()
			while socket.get_available_packet_count()>0:
				var message: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
				if message is Dictionary and message.get("type")=="snapshot":
					frames[i] = message
					for event: Dictionary in message.events:
						if event.name=="zeniTransfer":
							eq(event.data.from_id,ids[1]); eq(event.data.to_id,ids[0]); eq(int(event.data.amount),5000); receipts[i] = true
		if receipts[0] and receipts[1]: break
		OS.delay_msec(2)
	for i in 2:
		ok(receipts[i],"peer received a real socket transfer receipt")
		if not frames[i].is_empty():
			near(frames[i].slot.zeni,15000 if i==0 else 5000)
			eq(int(frames[i].zeniRevision),1)
	host.stop()
	for socket in peers: socket.poll(); socket.close()
	host.free()
