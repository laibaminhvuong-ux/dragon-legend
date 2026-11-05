class_name RuleMovement
extends RefCounted
var tuning: Dictionary = RuleTables.table("movement")
## User request 2026-11-03: Shift (intent "sprint") runs / flies at full speed; without it you walk or cruise.
## Callers that leave "sprint" out keep full speed (bots, tests, the classic parity traces).
const WALK_SPEED := 2.3
const FLY_CRUISE := 0.4
## Rocket boost (user request 2026-11-04, intent "boost" = Q): launch like a rocket, then fly BOOST_MULT x full flight
## speed for BOOST_TIME seconds (free, like flight). Q again ends it; BOOST_COOLDOWN after.
const BOOST_TIME := 20.0
const BOOST_MULT := 2.6
const BOOST_COOLDOWN := 6.0
const LAUNCH_TIME := 0.55
const LAUNCH_SPEED := 24.0
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
	entity.boostCooldown = maxf(0,float(entity.get("boostCooldown",0))-dt)
	entity.boostRemaining = maxf(0,float(entity.get("boostRemaining",0))-dt)
	entity.boostLaunch = maxf(0,float(entity.get("boostLaunch",0))-dt)
	if not can_move and entity.boostRemaining>0:
		entity.boostRemaining = 0.0
		entity.boostCooldown = BOOST_COOLDOWN
	if can_move and it.get("boost",false):
		if entity.boostRemaining>0:   # Q again: stop boosting, keep flying
			entity.boostRemaining = 0.0
			entity.boostLaunch = 0.0
			entity.boostCooldown = BOOST_COOLDOWN
		elif entity.boostCooldown==0:
			entity.boostRemaining = BOOST_TIME
			entity.boostLaunch = LAUNCH_TIME if entity.onGround else 0.2
			entity.boostSerial = int(entity.get("boostSerial",0))+1
			entity.flying = true
			entity.onGround = false
			entity.charging = false
	if can_move and it.get("flight",false):
		entity.flying = not entity.flying
		entity.vel.y = 0.0
		if entity.flying:
			entity.onGround = false
	if entity.flying and not can_move:
		entity.flying = false
		entity.vel.y = minf(0,entity.vel.y)
	# charge on the ground or while flying (user request 2026-11-03: hover in place to power up), not mid-jump or dashing
	entity.charging = can_move and it.get("charge",false) and (entity.flying or entity.onGround) and entity.dashRemaining==0
	if entity.charging and entity.boostRemaining>0:   # stopping to power up ends the boost
		entity.boostRemaining = 0.0
		entity.boostCooldown = BOOST_COOLDOWN
	if not entity.flying and entity.boostRemaining>0:   # landed / flight toggled off
		entity.boostRemaining = 0.0
		entity.boostCooldown = BOOST_COOLDOWN
	entity.boosting = entity.boostRemaining>0
	if entity.charging:
		RuleKi.add_ki(entity,m.chargeRate*(entity.maxKi/100.0)*dt)
	if can_move and it.get("dash",false) and not entity.charging and entity.dashCooldown==0 and RuleKi.try_spend_ki(entity,m.dashCost*ki_scale):
		entity.dashRemaining = m.dashDuration
		entity.dashCooldown = m.dashCooldown
		entity.dashX = wish.x if length>0 else sin(entity.yaw)
		entity.dashZ = wish.y if length>0 else cos(entity.yaw)
	entity.dashing = entity.dashRemaining>0
	entity.blocking = can_move and it.get("block",false) and not entity.dashing and not entity.charging
	var fast: bool = bool(it.get("sprint", true))
	entity.sprinting = fast and length > 0.05 and can_move
	var speed: float = (m.flightSpeed if fast else m.flightSpeed * FLY_CRUISE) if entity.flying else (entity.runSpeed if fast else minf(WALK_SPEED, entity.runSpeed))
	if entity.boosting:
		speed = m.flightSpeed*BOOST_MULT
		if length<0.05:   # no keys: keep rocketing the way you face
			wish = Vector2(sin(entity.yaw),cos(entity.yaw))
			length = 1.0
	var target: Vector2 = wish*speed if can_move and not entity.charging else Vector2.ZERO
	var accel: float = m.groundAccel*(1.0 if entity.onGround or entity.flying else m.airControl)*dt*(2.2 if entity.boosting else 1.0)
	entity.vel.x += clampf(target.x-entity.vel.x,-accel,accel)
	entity.vel.z += clampf(target.y-entity.vel.z,-accel,accel)
	if can_move and not entity.charging and length>0.05:
		entity.yaw = turn_towards(entity.yaw,atan2(wish.x,wish.y),m.turnSpeed*dt)
	if entity.flying:
		var steer: float = clampf(float(it.get("fly_pitch",0)),-1,1) if can_move and not entity.charging else 0.0
		var climb: float = 0.0 if entity.charging else (float(it.get("ascend",false))-float(it.get("descend",false)))*m.flightAscend
		var vmax: float = m.flightSpeed*(BOOST_MULT if entity.boosting else 1.0)
		entity.vel.y = clampf(climb+steer*vmax*0.85,-vmax,vmax)
		if entity.boostLaunch>0:   # the launch: a blast straight up that eases into the boost
			entity.vel.y = maxf(entity.vel.y,LAUNCH_SPEED*(entity.boostLaunch/LAUNCH_TIME+0.25))
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
	var floor_y: float = zone.ground_at(x,z) if zone.has_method("ground_at") else zone.height_at(x,z)
	if entity.pos.y<=floor_y:
		entity.pos.y = floor_y
		if entity.vel.y<0:
			entity.vel.y = 0.0
		if entity.flying and it.get("descend",false):
			entity.flying = false
		entity.onGround = not entity.flying
	else:
		entity.onGround = false
