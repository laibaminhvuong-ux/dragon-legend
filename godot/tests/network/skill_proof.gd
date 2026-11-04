extends Node
## Two independent processes; real CoopHost/WebSocketPeer transport, isolated fixtures, no SaveStore writes.
const SAMPLES := ["KiBlast","EnergyWave","DestructoDisc","WolfFangFist","InstantTransmission","SpiritBomb"]
var args := {}
var host: CoopHost
var ws: WebSocketPeer
var started := 0
var owner_id := ""
var owner_actor := ""
var self_actor := ""
var stage := 0
var releases := {}
var shots := {}
var late_join := false
var localised_self := false
var sent := false
var finished := false
var host_casts := []
var send_hook: Callable
var game: RuleGame
func _ready() -> void:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--"):
			var pieces: PackedStringArray = value.substr(2).split("=",true,1)
			args[pieces[0]] = pieces[1] if pieces.size()>1 else "1"
	started = Time.get_ticks_msec()
	if args.get("mode")=="host": start_host()
	else: start_client()
func fixture() -> Dictionary:
	var schema := RuleSchema.new(); var slot := schema.new_slot(schema.default_look("Saiyan"),1000)
	slot.level = 2000; slot.moves = SAMPLES.duplicate(); return slot
func write_json(path: String,value: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: fail("Could not write proof artifact: "+path); return
	file.store_string(JSON.stringify(value,"  ")); file.close()
func fail(message: String,code: int = 1) -> void:
	if finished: return
	finished = true
	push_error(message)
	if args.has("report"): write_json(str(args.report),{"passed":false,"error":message,"pid":OS.get_process_id()})
	if host!=null: host.stop()
	if ws!=null: ws.close()
	get_tree().quit(code)
func start_host() -> void:
	host = CoopHost.new(); add_child(host); host.set_process(false)
	var error := host.start(int(args.get("port",18936)),false)
	if error!=OK: fail("Loopback listener unavailable: "+error_string(error),78); return
	var reply := host.service.authenticate("owner","127.0.0.1",{"type":"join","version":CoopCodec.VERSION,"code":host.code,"token":CoopCodec.secret(),"slot_index":0,"name":"Proof host","slot":fixture()},Time.get_ticks_msec()/1000.0)
	if reply.get("type")!="welcome": fail("Host fixture authentication failed"); return
	owner_id = host.service.sessions.owner.identity
	game = host.service.rooms[host.code].members[owner_id].game
	owner_actor = game.player.id
	host.service.receive("owner",{"type":"command","name":"enter","args":[]},Time.get_ticks_msec()/1000.0)
	game.combat.begin_skill("EnergyWave","prepare")
	host.service.rooms[host.code].members[owner_id].input.beam = true
	write_json(str(args.ready),{"code":host.code,"port":host.port,"actor":owner_actor,"pid":OS.get_process_id()})
func start_client() -> void:
	var ready: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(args.ready)))
	if not ready is Dictionary: fail("Missing host handshake"); return
	owner_actor = str(ready.actor)
	ws = WebSocketPeer.new(); ws.inbound_buffer_size = 2097152; ws.max_queued_packets = 64
	if ws.connect_to_url("ws://127.0.0.1:%d" % int(ready.port))!=OK: fail("Could not connect loopback WebSocket")
func send(value: Dictionary) -> void:
	if send_hook.is_valid(): send_hook.call(value)
	else: ws.send_text(JSON.stringify(value))
func _process(dt: float) -> void:
	if finished: return
	if Time.get_ticks_msec()-started>25000: fail("Proof timeout: stage %d releases=%s shots=%s late=%s self=%s" % [stage,releases.keys(),shots.keys(),late_join,localised_self]); return
	if host!=null: host_step(dt)
	elif ws!=null: client_step()
func host_step(dt: float) -> void:
	host.service.sessions.owner.last = Time.get_ticks_msec()/1000.0
	var room: CoopRoom = host.service.rooms[host.code]
	var friends: Array = room.members.keys().filter(func(id: String) -> bool: return id!=owner_id)
	if not friends.is_empty():
		var friend: Dictionary = room.members[friends[0]]
		if int(friend.sequence)>=stage+1:
			if stage>=SAMPLES.size():
				finished = true
				write_json(str(args.report),{"passed":true,"pid":OS.get_process_id(),"actor":owner_actor,"casts":host_casts,"late_join_prepare":true})
				host.stop(); await get_tree().create_timer(.2).timeout; get_tree().quit(0); return
			game.combat.cancel_skill("proof_next_sample"); game.combat.beam_held = false; game.combat.beam_time = 0
			room.members[owner_id].input.beam = false
			game.player.ki = game.player.maxKi; game.player.health = game.player.maxHealth
			var target: Dictionary = game.combat.enemies[0]
			target.health = 1000000000.0; target.maxHealth = target.health; target.stun = 0.0; target.provoked = false
			target.pos = game.player.pos+Vector3(0,0,2.5 if SAMPLES[stage]=="WolfFangFist" else 12); target.home = target.pos
			game.player.lockTarget = target.id; game.player.stun = 0.0
			if not game.combat.fire(SAMPLES[stage]): fail("Host failed to cast "+SAMPLES[stage]); return
			var cast := {"move_id":SAMPLES[stage],"sequence":game.combat.skill.action_sequence,"seed":game.combat.skill.seed}
			if SAMPLES[stage]=="WolfFangFist":
				for field: String in ["combo_step","combo_length","strike","finisher"]: cast[field] = game.combat.skill[field]
			host_casts.append(cast); stage += 1
	host._process(dt)
func client_step() -> void:
	ws.poll()
	if ws.get_ready_state()==WebSocketPeer.STATE_OPEN and not sent:
		var ready: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(args.ready)))
		send({"type":"join","version":CoopCodec.VERSION,"code":ready.code,"token":CoopCodec.secret(),"slot_index":0,"name":"Proof client","slot":fixture()}); sent = true
	while ws.get_available_packet_count()>0:
		var message: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if not message is Dictionary: fail("Non-JSON server packet"); return
		match message.get("type",""):
			"welcome": self_actor = str(message.self); send({"type":"command","name":"enter","args":[]})
			"error": fail("Server rejected client: "+str(message.get("message"))); return
			"snapshot": inspect_snapshot(message)
			"server_closed": complete_client(); return
	if ws.get_ready_state()==WebSocketPeer.STATE_CLOSED:
		if releases.size()==SAMPLES.size(): complete_client()
		else: fail("Transport closed before all sample casts arrived")
func inspect_snapshot(frame: Dictionary) -> void:
	for friend: Dictionary in frame.get("friends",[]):
		var state: Dictionary = friend.player.get("skillState",{})
		if friend.id==owner_actor and state.get("move_id")=="EnergyWave" and state.get("phase")=="prepare":
			if state.get("actor_id")!=owner_actor or not state.has("action_sequence") or not state.has("charge"): fail("Late-join cast lost its source context"); return
			late_join = true
			if stage==0:
				send({"type":"input","sequence":1,"intents":{"ki_blast":true}}); stage = 1
	for row: Dictionary in frame.get("projectiles",[]):
		var context: Dictionary = row.get("presentation",{})
		if context.get("actor_id")==owner_actor and row.get("move_id") in ["KiBlast","DestructoDisc"]:
			if not context.has("seed") or not context.has("action_sequence") or row.has("owner"): fail("Missing/unsafe projectile context"); return
			shots[row.move_id] = {"actor_id":context.actor_id,"sequence":context.action_sequence,"seed":context.seed}
	for event: Dictionary in frame.get("events",[]):
		var raw: Dictionary = event.data
		if event.name!="attack" or raw.get("phase")!="release": continue
		var local := CoopCodec.localize_event(raw,self_actor)
		if raw.get("actor_id")==self_actor:
			if local.actor_id!="player" or local.event_id!=raw.event_id: fail("Self identity localisation failed"); return
			localised_self = true
		if raw.get("actor_id")==owner_actor and raw.get("move_id") in SAMPLES:
			if local.actor_id!=owner_actor or local.id!=owner_actor or not local.origin is Vector3: fail("Remote actor localisation failed"); return
			releases[raw.move_id] = {"actor_id":local.actor_id,"sequence":raw.action_sequence,"event_id":raw.event_id,"seed":raw.seed}
			if raw.move_id=="WolfFangFist":
				for field: String in ["combo_step","combo_length","strike","finisher"]:
					if not raw.has(field): fail("Missing replicated combo field: "+field); return
					releases[raw.move_id][field] = raw[field]
	if stage>=1 and stage<=SAMPLES.size():
		var id: String = SAMPLES[stage-1]
		if releases.has(id) and (id not in ["KiBlast","DestructoDisc"] or shots.has(id)) and localised_self:
			send({"type":"input","sequence":stage+1,"intents":{}}); stage += 1
func complete_client() -> void:
	if releases.size()!=SAMPLES.size() or shots.size()!=2 or not late_join or not localised_self: fail("Incomplete transport evidence"); return
	finished = true
	write_json(str(args.report),{"passed":true,"pid":OS.get_process_id(),"self":self_actor,"host_actor":owner_actor,"releases":releases,"projectiles":shots,"late_join_skillState":late_join,"self_localisation":localised_self})
	ws.close(); get_tree().quit(0)
