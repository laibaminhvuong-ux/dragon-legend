class_name CoopDiscovery
extends Node
signal found(url: String)
signal failed
const PORT := 8911
var udp: PacketPeerUDP
var code := ""
var elapsed := 0.0
var retry := 0.0
func search(invite: String) -> Error:
	code = invite
	udp = PacketPeerUDP.new()
	var error := udp.bind(0,"0.0.0.0")
	if error!=OK: return error
	udp.set_broadcast_enabled(true)
	udp.set_dest_address("255.255.255.255",PORT)
	udp.put_packet(("DL_FIND|"+code).to_utf8_buffer())
	return OK
func _process(dt: float) -> void:
	if udp==null: return
	elapsed += dt; retry += dt
	while udp.get_available_packet_count()>0:
		var packet := udp.get_packet()
		var address := udp.get_packet_ip()
		if packet.size()>80: continue
		var parts := packet.get_string_from_utf8().split("|")
		if parts.size()==3 and parts[0]=="DL_ROOM" and parts[1]==code and int(parts[2])>0 and int(parts[2])<65536:
			found.emit("ws://%s:%d" % [address,int(parts[2])]); return
	if retry>1:
		retry = 0; udp.set_dest_address("255.255.255.255",PORT); udp.put_packet(("DL_FIND|"+code).to_utf8_buffer())
	if elapsed>5: stop(); failed.emit()
func stop() -> void:
	if udp!=null: udp.close(); udp = null
func _exit_tree() -> void: stop()
