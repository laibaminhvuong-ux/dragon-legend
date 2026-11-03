extends TestCase
func test_two_bone_solver_preserves_lengths_and_chooses_forward_knee() -> void:
	for foot: Vector3 in [Vector3(0,-0.9,0),Vector3(0.1,-0.7,0.1),Vector3(0,-0.001,0),Vector3(0,-5,0)]:
		var knee := FootPlacement.knee_target(Vector3.ZERO,foot,Vector3.BACK,0.5,0.5)
		ok(knee.is_finite())
		near(knee.length(),0.5,0.0002)
		if foot.length()<1 and foot.length()>0.01: near(knee.distance_to(foot),0.5,0.0002)
		ok(knee.z>=-0.0001)
func test_secondary_spring_is_frame_rate_independent_and_settles() -> void:
	var slow := Vector2.ZERO
	var fast := Vector2.ZERO
	for i in 30: slow = MotionStyle.spring(slow.x,slow.y,1,1.0/30)
	for i in 120: fast = MotionStyle.spring(fast.x,fast.y,1,1.0/120)
	near(slow.x,fast.x,0.00001)
	ok(slow.x>0.99 and slow.x<=1.00001)
	for i in 120: fast = MotionStyle.spring(fast.x,fast.y,0,1.0/60)
	ok(absf(fast.x)<0.00001)
func test_cast_hold_jump_and_foot_layer_cancel_in_flight() -> void:
	var f := Fighter.create({"race":"Saiyan"})
	for i in 30: f.update(1.0/60,{"beamCharge":0.8})
	eq(f.anim.state,"cast")
	for i in 30: f.update(1.0/60,{"onGround":false,"flying":true})
	eq(f.anim.state,"fly")
	ok(f.feet.weight<0.01)
	f.update(1.0/60,{"onGround":false,"vy":4})
	var air: AnimationNodeAnimation = f.anim._bt.get_node("a_air")
	eq(String(air.animation),"Jump_Start")
	f.update(1.0/60,{"onGround":false,"vy":-4})
	eq(String(air.animation),"Jump")
	for i in 30: f.update(1.0/60,{"onGround":true})
	ok(f.feet.weight>0.9)
	f.free()
class Flat extends RuleZone:
	func _init() -> void: super("earth_plains")
	func height_at(_x: float,_z: float) -> float: return 0.08
func test_foot_modifier_runs_on_real_rig_and_preserves_bone_rotations() -> void:
	var f := Fighter.create({"race":"Human"})
	(Engine.get_main_loop() as SceneTree).root.add_child(f)
	f.set_terrain(Flat.new())
	for i in 30: f.update(1.0/60,{"onGround":true})
	f.anim.mod._process_modification()
	f.feet._process_modification()
	for side in ["L","R"]:
		for name: String in ["DEF-thigh.","DEF-shin.","DEF-foot."]:
			var id := f.skeleton.find_bone(name+side)
			ok(id>=0)
			ok(f.skeleton.get_bone_global_pose(id).origin.is_finite())
			near(f.skeleton.get_bone_pose_rotation(id).length(),1.0,0.0001)
	f.get_parent().remove_child(f)
	f.free()
