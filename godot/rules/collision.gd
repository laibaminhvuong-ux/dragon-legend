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
	if zone.has_method("ceiling") and entity.pos.y>zone.ceiling():   # interiors: no flying through the roof
		entity.pos.y = zone.ceiling()
		entity.vel.y = minf(0.0,entity.vel.y)
	for c: Dictionary in zone.props().near(entity.pos.x,entity.pos.z,0.35):
		if entity.pos.y>c.top:
			continue
		if c.has("hw"):
			_box(entity,c)
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

## Pushes an entity (radius 0.35) out of an oriented box {x, z, rot, hw, hd} along the shallowest side.
static func _box(entity: Dictionary,c: Dictionary) -> void:
	var r: float = c.rot
	var cs := cos(r); var sn := sin(r)
	var dx: float = entity.pos.x-c.x
	var dz: float = entity.pos.z-c.z
	var lx := dx*cs-dz*sn
	var lz := dx*sn+dz*cs
	var ex: float = float(c.hw)+0.35
	var ez: float = float(c.hd)+0.35
	if absf(lx)>=ex or absf(lz)>=ez:
		return
	var px := ex-absf(lx)
	var pz := ez-absf(lz)
	var nl := Vector2(signf(lx) if lx!=0.0 else 1.0,0.0) if px<pz else Vector2(0.0,signf(lz) if lz!=0.0 else 1.0)
	if px<pz: lx = nl.x*ex
	else: lz = nl.y*ez
	# back to world: (lx, lz) -> world offset (inverse of the rotation above)
	entity.pos.x = c.x+lx*cs+lz*sn
	entity.pos.z = c.z-lx*sn+lz*cs
	var n := Vector2(nl.x*cs+nl.y*sn,-nl.x*sn+nl.y*cs)
	var inward: float = entity.vel.x*n.x+entity.vel.z*n.y
	if inward<0:
		entity.vel.x -= inward*n.x
		entity.vel.z -= inward*n.y
