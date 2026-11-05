class_name CoopClient
extends Node
signal welcomed(code: String)
signal frame(data: Dictionary)
signal failed(message: String)
signal disconnected
var local_host: WeakRef
var discovery: CoopDiscovery
var socket: WebSocketPeer
var pending: Dictionary = {}
var connected := false
var code := ""
var latest: Dictionary = {}
var backup_directory := "user://co_op_backups"
var slot_index := -1
var endpoint := ""
var _sent := false
var _sequence := 0
var _time := 0.0
var _ping := 0.0
var _save := 0.0
var _closing := false
var _saved_zeni_revision := 0
var _zeni_save_failed := false
func begin(url: String,mode: String,invite: String,index: int,name: String) -> String:
	if local_host==null and url!="" and not CoopCodec.endpoint_valid(url): return "Enter a valid ws:// or wss:// host address."
	if mode=="join" and not CoopCodec.code_valid(invite): return "Enter exactly six digits."
	var slot: Variant = SaveStore.load_slot(index)
	if not slot is Dictionary: return "Choose an existing fighter slot first."
	var token := CoopCodec.secret()
	if token=="": return "Could not save your private-server identity."
	DirAccess.make_dir_recursive_absolute(backup_directory)
	var backup := FileAccess.open(backup_directory+"/slot_%d_%d.json" % [index,int(Time.get_unix_time_from_system())],FileAccess.WRITE)
	if backup==null: return "Could not back up this fighter before joining."
	backup.store_string(JSON.stringify(slot)); backup.flush(); backup.close()
	slot_index = index
	endpoint = url
	pending = {"type":mode,"version":CoopCodec.VERSION,"token":token,"code":invite,"slot_index":index,"slot":slot,"name":name.left(24)}
	_time = 0; _sent = false; _closing = false
	_saved_zeni_revision = 0; _zeni_save_failed = false
	if local_host!=null:
		var reply: Dictionary = local_host.get_ref().service.authenticate("owner","127.0.0.1",pending,Time.get_ticks_msec()/1000.0)
		pending.clear()
		if reply.type=="error": return reply.message
		connected = true; code = str(reply.code)
		if is_inside_tree(): welcomed.emit.call_deferred(code)
		else: welcomed.emit(code)
	elif url=="":
		discovery = CoopDiscovery.new(); add_child(discovery)
		discovery.found.connect(func(found_url: String) -> void: discovery.stop(); _connect(found_url))
		discovery.failed.connect(func() -> void: failed.emit("No room with that code was found on this network. For Internet play, enter the owner's host address."))
		var error := discovery.search(invite)
		if error!=OK: return "LAN discovery is unavailable. Enter the owner's host address."
	else:
		var error := _connect(url)
		if error!=OK: return "Could not start the connection."
	return ""
func _process(dt: float) -> void:
	if local_host!=null:
		if connected and local_host.get_ref()!=null and local_host.get_ref().running:
			_time += dt
			if _time>0.1:
				accept_snapshot(local_host.get_ref().service.snapshot("owner"))
			_save += dt
			if _save>5: _save = 0; save_progress()
		return
	if socket==null: return
	_time += dt; _ping += dt; _save += dt
	socket.poll()
	var state := socket.get_ready_state()
	if state==WebSocketPeer.STATE_OPEN:
		if not _sent:
			socket.send_text(JSON.stringify(pending)); pending.clear(); _sent = true
		if _ping>5:
			_ping = 0; send({"type":"ping"})
		var count := 0
		while socket.get_available_packet_count()>0 and count<32:
			count += 1
			var raw := socket.get_packet()
			if raw.size()>2097152: close(); failed.emit("Server message was too large."); return
			var message: Variant = JSON.parse_string(raw.get_string_from_utf8())
			if not message is Dictionary: continue
			match message.get("type",""):
				"welcome": connected = true; code = str(message.code); welcomed.emit(code)
				"snapshot":
					accept_snapshot(message)
				"server_closed":
					save_progress(); close(); failed.emit("The owner left. This server is now closed."); disconnected.emit()
				"error": failed.emit(str(message.get("message","The server rejected that request.")))
	elif state==WebSocketPeer.STATE_CLOSED:
		socket = null; connected = false
		if not _closing: failed.emit("The owner left or the connection was lost. Your last received progress is saved.")
		save_progress(); disconnected.emit()
	if _time>15:
		close(); failed.emit("The owner did not respond. Check the host address, room code and router/firewall.")
## Both transports use the same persistence path. Failed writes keep the revision dirty for retry.
func accept_snapshot(data: Dictionary) -> void:
	latest = data; _time = 0
	var revision := int(data.get("zeniRevision",0))
	if revision>_saved_zeni_revision:
		if save_progress():
			_saved_zeni_revision = revision; _zeni_save_failed = false; _save = 0
		elif not _zeni_save_failed:
			_zeni_save_failed = true
			failed.emit("Your server zeni changed, but saving this fighter failed. Retrying with the next update.")
	elif _save>=5:
		save_progress(); _save = 0
	frame.emit(data)
func _connect(url: String) -> Error:
	endpoint = url
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 2097152; socket.outbound_buffer_size = 262144; socket.max_queued_packets = 32
	return socket.connect_to_url(url)
func send(message: Dictionary) -> void:
	if local_host!=null and connected and local_host.get_ref()!=null:
		var reply: Dictionary = local_host.get_ref().service.receive("owner",message,Time.get_ticks_msec()/1000.0)
		if reply.get("type")=="error": failed.emit(str(reply.message))
		return
	if socket!=null and socket.get_ready_state()==WebSocketPeer.STATE_OPEN: socket.send_text(JSON.stringify(message))
func command(name: String,args: Array = []) -> void: send({"type":"command","name":name,"args":args})
func inputs(it: Dictionary) -> void:
	_sequence += 1
	send({"type":"input","sequence":_sequence,"intents":it})
func save_progress() -> bool:
	if slot_index>=0 and latest.get("slot") is Dictionary:
		return SaveStore.save_slot(slot_index,RuleSchema.new().normalize(latest.slot))
	return false
func close() -> void:
	_closing = true
	if local_host!=null and local_host.get_ref()!=null and local_host.get_ref().service.sessions.has("owner"):
		latest = local_host.get_ref().service.snapshot("owner")
	save_progress()
	if discovery!=null: discovery.stop()
	if local_host!=null and local_host.get_ref()!=null: local_host.get_ref().stop()
	if socket!=null: socket.close(1000,"Leaving server")
	connected = false
func _exit_tree() -> void: close()
