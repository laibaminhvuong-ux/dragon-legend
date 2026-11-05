extends TestCase
func setup() -> CoopService:
	var service := CoopService.new(); var code := service.create_room()
	for connection: String in ["owner","guest","other"]:
		var schema := RuleSchema.new(); var slot := schema.new_slot(schema.default_look(),1000); slot.zeni = 10000
		var response := service.authenticate(connection,connection,{"type":"join","version":CoopCodec.VERSION,"token":CoopCodec.secret(),"code":code,"slot_index":0,"slot":slot,"name":{"owner":"Owner","guest":"Bình","other":"Chi"}[connection]},0)
		eq(response.type,"welcome")
	return service
func room(service: CoopService) -> CoopRoom: return service.rooms[service.sessions.owner.room]
func identity(service: CoopService,connection: String) -> String: return service.sessions[connection].identity
func game(service: CoopService,connection: String) -> RuleGame: return room(service).members[identity(service,connection)].game
func pid(service: CoopService,connection: String) -> String: return game(service,connection).player.id
func send(service: CoopService,connection: String,target: Variant,amount: Variant) -> Dictionary:
	return service.receive(connection,{"type":"command","name":"give_zeni","args":[target,amount]},0)
func wallets(service: CoopService) -> Array:
	var out := []
	for member: String in ["owner","guest","other"]:
		out.append([game(service,member).slot.zeni,room(service).saved.members[identity(service,member)].slot.zeni,int(room(service).members[identity(service,member)].zeniRevision)])
	return out
