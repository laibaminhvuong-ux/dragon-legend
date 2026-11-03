class_name RuleMovement
extends RefCounted
var tuning: Dictionary = RuleTables.table("movement")
static func turn_towards(a: float,b: float,step: float) -> float:
	var delta: float = fposmod(b-a+PI,TAU)-PI
	return b if absf(delta)<=step else a+signf(delta)*step
func step(entity: Dictionary,it: Dictionary,dt: float,zone: RefCounted) -> void:
	if not is_finite(dt) or dt<=0:
		return
	var m: Dictionary = tuning
	var ki_scale: float = entity.get("kiCostScale",entity.maxKi/100.0)
	var wish := Vector2(float(it.get("move_x",0)),float(it.get("move_z",0)))
	var length: float = wish.length()
	if length>1:
		wish /= length
	var can_move: bool = entity.get("stun",0)<=0 and entity.health!=0
	entity.dashCooldown = maxf(0,float(entity.get("dashCooldown",0))-dt)
	entity.dashRemaining = maxf(0,float(entity.get("dashRemaining",0)))
	if not can_move:
		entity.dashRemaining = 0.0
	if can_move and it.get("flight",false):
		entity.flying = not entity.flying
		entity.vel.y = 0.0
		if entity.flying:
			entity.onGround = false
	if entity.flying and not can_move:
		entity.flying = false
		entity.vel.y = minf(0,entity.vel.y)
	entity.charging = can_move and it.get("charge",false) and not entity.flying and entity.onGround and entity.dashRemaining==0
	if entity.charging:
		RuleKi.add_ki(entity,m.chargeRate*(entity.maxKi/100.0)*dt)
	if can_move and it.get("dash",false) and not entity.charging and entity.dashCooldown==0 and RuleKi.try_spend_ki(entity,m.dashCost*ki_scale):
		entity.dashRemaining = m.dashDuration
		entity.dashCooldown = m.dashCooldown
		entity.dashX = wish.x if length>0 else sin(entity.yaw)
		entity.dashZ = wish.y if length>0 else cos(entity.yaw)
	entity.dashing = entity.dashRemaining>0
	entity.blocking = can_move and it.get("block",false) and not entity.dashing and not entity.charging
	var speed: float = m.flightSpeed if entity.flying else entity.runSpeed
	var target: Vector2 = wish*speed if can_move and not entity.charging else Vector2.ZERO
	var accel: float = m.groundAccel*(1.0 if entity.onGround or entity.flying else m.airControl)*dt
	entity.vel.x += clampf(target.x-entity.vel.x,-accel,accel)
	entity.vel.z += clampf(target.y-entity.vel.z,-accel,accel)
	if can_move and not entity.charging and length>0.05:
		entity.yaw = turn_towards(entity.yaw,atan2(wish.x,wish.y),m.turnSpeed*dt)
	if entity.flying:
		var steer: float = clampf(float(it.get("fly_pitch",0)),-1,1) if can_move and not entity.charging else 0.0
		entity.vel.y = clampf((float(it.get("ascend",false))-float(it.get("descend",false)))*m.flightAscend+steer*m.flightSpeed*0.85,-m.flightSpeed,m.flightSpeed)
	else:
		if entity.onGround and it.get("jump",false) and can_move and not entity.charging:
			entity.vel.y = m.jumpSpeed
			entity.onGround = false
		entity.vel.y -= m.gravity*zone.gravity*dt
	var dash_dt: float = minf(dt,entity.dashRemaining)
	entity.pos.x += float(entity.get("dashX",0))*m.dashSpeed*dash_dt+entity.vel.x*(dt-dash_dt)
	entity.pos.z += float(entity.get("dashZ",0))*m.dashSpeed*dash_dt+entity.vel.z*(dt-dash_dt)
	if entity.dashing:
		entity.vel.x = entity.dashX*m.dashSpeed
		entity.vel.z = entity.dashZ*m.dashSpeed
	entity.dashRemaining = maxf(0,entity.dashRemaining-dt)
	entity.pos.y += entity.vel.y*dt
	var half: float = zone.size/2-1
	var x: float = clampf(entity.pos.x,-half,half)
	var z: float = clampf(entity.pos.z,-half,half)
	if x!=entity.pos.x:
		entity.vel.x = 0.0
	if z!=entity.pos.z:
		entity.vel.z = 0.0
	entity.pos.x = x
	entity.pos.z = z
	var floor_y: float = zone.height_at(x,z)
	if entity.pos.y<=floor_y:
		entity.pos.y = floor_y
		if entity.vel.y<0:
			entity.vel.y = 0.0
		if entity.flying and it.get("descend",false):
			entity.flying = false
		entity.onGround = not entity.flying
	else:
		entity.onGround = false
