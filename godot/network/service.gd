class_name CoopService
extends RefCounted
var rooms: Dictionary = {}
var sessions: Dictionary = {}
var attempts: Dictionary = {}
var max_rooms := 1
func fail(text: String) -> Dictionary: return {"type":"error","message":text}
func authenticate(connection: String,address: String,message: Dictionary,now: float) -> Dictionary:
	if sessions.has(connection): return fail("Already connected to a private server.")
	if not attempts.has(address) and attempts.size()>=256: return fail("Too many connection attempts. Try again later.")
	var bucket: Dictionary = attempts.get(address,{"time":now,"count":0})
	if now-bucket.time>=60: bucket = {"time":now,"count":0}
	bucket.count += 1; attempts[address] = bucket
	if bucket.count>12: return fail("Too many attempts. Try again in a minute.")
	var version: Variant = message.get("version")
	if not (version is int or version is float) or version!=CoopCodec.VERSION: return fail("Update the game to join this server.")
	var token := str(message.get("token",""))
	var index: Variant = message.get("slot_index")
	if not CoopCodec.token_valid(token) or not (index is int or index is float) or index<0 or index>=RuleSchema.SLOT_COUNT or index!=floor(index): return fail("Invalid fighter identity.")
	if not message.get("slot") is Dictionary or message.slot.is_empty(): return fail("Select an existing fighter slot first.")
	var identity := (token+":"+str(int(index))).sha256_text()
	if not CoopCodec.import_valid(message.slot): return fail("That fighter save is invalid. Load or repair the slot in solo play first.")
	var code := str(message.get("code",""))
	if str(message.get("type",""))=="create":
		return fail("Only the owner can create this session.")
	elif str(message.get("type",""))=="join":
		if not CoopCodec.code_valid(code): return fail("Enter exactly six digits.")
		if not rooms.has(code): return fail("That room is closed or its invite code is incorrect.")
	else: return fail("Choose Join server or Create server.")
	var room: CoopRoom = rooms[code]
	if room.saved.members.size()>=64 and not room.saved.members.has(identity): return fail("This server has reached its saved-fighter limit.")
	var joined := room.add(identity,str(message.get("name","Friend")),message.slot)
	if joined.has("error"): return fail(joined.error)
	sessions[connection] = {"room":code,"identity":identity,"last":now,"window":now,"packets":0}
	return {"type":"welcome","code":code,"self":joined.id,"limit":CoopRoom.LIMIT}
func receive(connection: String,message: Dictionary,now: float) -> Dictionary:
	if not sessions.has(connection): return fail("Join a private server first.")
	var session: Dictionary = sessions[connection]
	if now-session.window>=1: session.window = now; session.packets = 0
	session.packets += 1
	if session.packets>90: return fail("Sending commands too quickly.")
	session.last = now
	var room: CoopRoom = rooms[session.room]
	var identity: String = session.identity
	match str(message.get("type","")):
		"input":
			if message.get("intents") is Dictionary and (message.get("sequence") is int or message.get("sequence") is float) and is_finite(float(message.sequence)) and absf(message.sequence)<9007199254740991: room.input_for(identity,message.intents,int(message.sequence))
		"command":
			var args: Variant = message.get("args",[])
			if not args is Array: return fail("Invalid command arguments.")
			var error: Variant = room.command(identity,str(message.get("name","")),args)
			if error!=null: return fail(str(error))
		"ping": return {"type":"pong"}
		_: return fail("Unknown request.")
	return {}
func drop_peer(connection: String) -> bool:
	if not sessions.has(connection): return true
	var session: Dictionary = sessions[connection]
	var room: CoopRoom = rooms[session.room]
	room.remove(session.identity)
	sessions.erase(connection)
	return true
func step(dt: float,now: float) -> void:
	for connection: String in sessions:
		var session: Dictionary = sessions[connection]
		if now-session.last>0.4: rooms[session.room].members[session.identity].input = CoopCodec.intents({})
	for room: CoopRoom in rooms.values(): room.step(dt)
func snapshot(connection: String) -> Dictionary:
	var session: Dictionary = sessions[connection]
	return rooms[session.room].snapshot(session.identity)
func create_room() -> String:
	var bytes := Crypto.new().generate_random_bytes(4)
	var code := "%06d" % (bytes.decode_u32(0)%1000000)
	rooms.clear()
	rooms[code] = CoopRoom.new({"version":CoopCodec.VERSION,"code":code,"members":{},"worlds":{}})
	return code
func shutdown() -> void:
	sessions.clear()
	rooms.clear()
