class_name CoopHost
extends Node
signal closed
signal address_ready(address: String)
const PORT := 8910
var service := CoopService.new()
var tcp := TCPServer.new()
var udp: PacketPeerUDP
var peers: Dictionary = {}
var running := false
var code := ""
var port := PORT
var addresses: Array = []
var next_id := 0
var accumulator := 0.0
var broadcast := 0.0
var upnp: UPNP
var _mapping_task := -1
var _external := ""
var _renew := 0.0
func start(listen_port: int = PORT,map_router: bool = false) -> Error:
	port = listen_port
	var error := tcp.listen(port,"0.0.0.0")
	if error!=OK: return error
	code = service.create_room()
	udp = PacketPeerUDP.new()
	if udp.bind(CoopDiscovery.PORT,"0.0.0.0")!=OK: udp.close(); udp = null
	for ip: String in IP.get_local_addresses():
		if ip.is_valid_ip_address() and ":" not in ip and not ip.begins_with("127."): addresses.append("ws://%s:%d" % [ip,port])
	running = true
	if map_router: _mapping_task = WorkerThreadPool.add_task(_map_router)
	return OK
func _map_router() -> void:
	upnp = UPNP.new()
	if upnp.discover(2000,2)!=UPNP.UPNP_RESULT_SUCCESS: return
	if upnp.add_port_mapping(port,port,"Dragon Legend private co-op","TCP",3600)==UPNP.UPNP_RESULT_SUCCESS:
		var ip := upnp.query_external_address()
		if ip.is_valid_ip_address(): _external = "ws://%s:%d" % [ip,port]
func _process(dt: float) -> void:
	if not running: return
	_renew += dt
	if _renew>1800 and _external!="" and _mapping_task<0:
		_renew = 0; _mapping_task = WorkerThreadPool.add_task(_map_router)
	var now := Time.get_ticks_msec()/1000.0
	if _mapping_task>=0 and WorkerThreadPool.is_task_completed(_mapping_task):
		WorkerThreadPool.wait_for_task_completion(_mapping_task); _mapping_task = -1
		if _external!="": address_ready.emit(_external)
	if udp!=null:
		var packets := 0
		while udp.get_available_packet_count()>0 and packets<32:
			packets += 1
			var packet := udp.get_packet(); var ip := udp.get_packet_ip(); var reply_port := udp.get_packet_port()
			if packet.size()<32 and packet.get_string_from_utf8()=="DL_FIND|"+code:
				udp.set_dest_address(ip,reply_port); udp.put_packet(("DL_ROOM|%s|%d" % [code,port]).to_utf8_buffer())
	while tcp.is_connection_available():
		var stream := tcp.take_connection()
		if peers.size()>=16: stream.disconnect_from_host(); continue
		var ws := WebSocketPeer.new(); ws.inbound_buffer_size = CoopCodec.MAX_PACKET; ws.outbound_buffer_size = 2097152; ws.max_queued_packets = 16
		if ws.accept_stream(stream)!=OK: continue
		next_id += 1; peers[str(next_id)] = {"socket":ws,"address":stream.get_connected_host(),"born":now}
	for id: String in peers.keys():
		var peer: Dictionary = peers[id]; var ws: WebSocketPeer = peer.socket
		ws.poll()
		if ws.get_ready_state()==WebSocketPeer.STATE_CLOSED or now-peer.born>15 and not service.sessions.has(id):
			service.drop_peer(id); ws.close(); peers.erase(id); continue
		var count := 0
		while ws.get_available_packet_count()>0 and count<16:
			count += 1
			var packet := ws.get_packet()
			if packet.size()>CoopCodec.MAX_PACKET or not ws.was_string_packet(): ws.close(1009,"Invalid packet"); break
			var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
			if not message is Dictionary: ws.close(1007,"Invalid message"); break
			var reply := service.receive(id,message,now) if service.sessions.has(id) else service.authenticate(id,peer.address,message,now)
			if not reply.is_empty(): ws.send_text(JSON.stringify(reply))
		if service.sessions.has(id) and now-service.sessions[id].last>30: ws.close(1000,"Connection timed out")
	accumulator = minf(0.1,accumulator+maxf(0,dt))
	while accumulator>=1.0/60: service.step(1.0/60,now); accumulator -= 1.0/60
	broadcast += dt
	if broadcast>=0.1:
		broadcast = 0
		for id: String in service.sessions:
			if peers.has(id) and peers[id].socket.get_ready_state()==WebSocketPeer.STATE_OPEN:
				if peers[id].socket.send_text(JSON.stringify(service.snapshot(id)))!=OK: peers[id].socket.close(1013,"Connection too slow")
func stop() -> void:
	if not running: return
	running = false
	for id: String in peers:
		var ws: WebSocketPeer = peers[id].socket
		if service.sessions.has(id): ws.send_text(JSON.stringify(service.snapshot(id)))
		ws.send_text(JSON.stringify({"type":"server_closed"})); ws.close(1001,"Owner left the server"); ws.poll()
	peers.clear(); tcp.stop()
	if udp!=null: udp.close(); udp = null
	if _mapping_task>=0: WorkerThreadPool.wait_for_task_completion(_mapping_task); _mapping_task = -1
	if upnp!=null and _external!="": upnp.delete_port_mapping(port,"TCP")
	service.shutdown(); code = ""
	closed.emit()
func _exit_tree() -> void: stop()
