class_name FootPlacement
extends SkeletonModifier3D
# Bounded two-bone leg correction after authored animation and procedural poses.
# Reads terrain only. No physics root movement, collision or gameplay writes.
var terrain: RuleZone
var weight := 0.0
var _bones: Dictionary = {}
static func knee_target(hip: Vector3,ankle: Vector3,pole: Vector3,upper: float,lower: float) -> Vector3:
	var delta := ankle-hip
	var distance := clampf(delta.length(),0.0001,maxf(0.0002,upper+lower-0.0001))
	var axis := delta.normalized() if delta.length_squared()>0.000001 else Vector3.DOWN
	var bend := pole-axis*pole.dot(axis)
	if bend.length_squared()<0.0001: bend = axis.cross(Vector3.RIGHT)
	if bend.length_squared()<0.0001: bend = axis.cross(Vector3.UP)
	bend = bend.normalized()
	var along := (upper*upper-lower*lower+distance*distance)/(2*distance)
	return hip+axis*along+bend*sqrt(maxf(0,upper*upper-along*along))
func bone(sk: Skeleton3D,id: String) -> int:
	if not _bones.has(id): _bones[id] = sk.find_bone(id)
	return int(_bones[id])
func turn_to(sk: Skeleton3D,id: int,old_direction: Vector3,new_direction: Vector3) -> void:
	if old_direction.length_squared()<0.00001 or new_direction.length_squared()<0.00001: return
	var pose := sk.get_bone_global_pose(id)
	var delta := Quaternion(old_direction.normalized(),new_direction.normalized())
	var parent := sk.get_bone_parent(id)
	var parent_basis := sk.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var target := (parent_basis.inverse()*Basis(delta)*pose.basis).orthonormalized().get_rotation_quaternion()
	sk.set_bone_pose_rotation(id,sk.get_bone_pose_rotation(id).slerp(target,weight))
func _process_modification() -> void:
	var sk := get_skeleton()
	if terrain==null or weight<0.01 or sk==null or not sk.is_inside_tree(): return
	for side in ["L","R"]:
		var hip := bone(sk,"DEF-thigh."+side)
		var knee := bone(sk,"DEF-shin."+side)
		var foot := bone(sk,"DEF-foot."+side)
		if hip<0 or knee<0 or foot<0: continue
		var h := sk.get_bone_global_pose(hip).origin
		var k := sk.get_bone_global_pose(knee).origin
		var a := sk.get_bone_global_pose(foot).origin
		var world := sk.global_transform*a
		# Keep the foot bone's rest clearance above the sole.
		var clearance := sk.get_bone_global_rest(foot).origin.y*sk.global_transform.basis.get_scale().y
		var ground := terrain.height_at(world.x,world.z)+maxf(0.03,clearance)
		world.y += clampf(ground-world.y,-0.16,0.22)
		var target := sk.global_transform.affine_inverse()*world
		var desired_knee := knee_target(h,target,Vector3.BACK,h.distance_to(k),k.distance_to(a))
		turn_to(sk,hip,k-h,desired_knee-h)
		k = sk.get_bone_global_pose(knee).origin
		a = sk.get_bone_global_pose(foot).origin
		turn_to(sk,knee,a-k,target-k)
