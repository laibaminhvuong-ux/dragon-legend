class_name RuleCollision
extends RefCounted
static func resolve(entity: Dictionary,zone: RefCounted,previous: Vector3) -> void:
	if not entity.flying and entity.onGround:
		var rise: float = zone.height_at(entity.pos.x,entity.pos.z)-previous.y
		if rise>0.05 and zone.normal_at(entity.pos.x,entity.pos.z).y<0.62:
			entity.pos.x = previous.x
			entity.pos.z = previous.z
			entity.pos.y = maxf(previous.y,zone.height_at(previous.x,previous.z))
			entity.vel.x = 0.0
			entity.vel.z = 0.0
	for c: Dictionary in zone.props().near(entity.pos.x,entity.pos.z,0.35):
		if entity.pos.y>c.top:
			continue
		var dx: float = entity.pos.x-c.x
		var dz: float = entity.pos.z-c.z
		var distance: float = maxf(0.000001,sqrt(dx*dx+dz*dz))
		var minimum: float = c.radius+0.35
		if distance>=minimum:
			continue
		var nx: float = dx/distance
		var nz: float = dz/distance
		entity.pos.x = c.x+nx*minimum
		entity.pos.z = c.z+nz*minimum
		var inward: float = entity.vel.x*nx+entity.vel.z*nz
		if inward<0:
			entity.vel.x -= inward*nx
			entity.vel.z -= inward*nz
