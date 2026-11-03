extends "res://tests/rules/game_case.gd"
func test_diagonal_speed_and_no_runtime_state_in_saves() -> void:
	var a := fresh()
	var b := fresh()
	tick(a,{"move_z":1},120)
	tick(b,{"move_x":1,"move_z":1},120)
	near(Vector2(b.player.vel.x,b.player.vel.z).length(),a.player.runSpeed,0.00001)
	var saved: Dictionary = a.to_save()
	ok(saved.position is Dictionary)
	ok(not saved.has("vel"))
	ok(not saved.has("dashRemaining"))
func test_dash_cost_direction_cooldown_and_stun_cancel() -> void:
	var g := fresh()
	var start: Vector3 = g.player.pos
	var cost: float = g.movement.tuning.dashCost*RuleGame.KI_COST_EASE
	tick(g,{"dash":true,"move_x":1})
	near(g.player.ki,g.player.maxKi-cost)
	ok(g.player.dashing)
	tick(g,{"dash":true,"move_x":1},9)
	near(g.player.ki,g.player.maxKi-cost)
	ok(g.player.pos.x-start.x>4)
	tick(g,{},3)
	eq(g.player.dashing,false)
	g.player.stun = 1.0
	tick(g,{"dash":true,"charge":true,"melee":true})
	eq(g.player.dashing,false)
	eq(g.player.charging,false)
func test_flight_pitch_hover_descent_and_no_ki_drain() -> void:
	var g := fresh()
	g.player.ki = 100
	tick(g,{"flight":true,"ascend":true})
	ok(g.player.flying)
	tick(g,{"fly_pitch":1,"move_z":1},45)
	var high: float = g.player.pos.y
	ok(high>8)
	tick(g,{},30)
	near(g.player.pos.y,high,0.0001)
	tick(g,{"fly_pitch":-1},20)
	ok(g.player.pos.y<high)
	g.player.ki = 0.0
	tick(g,{"charge":true})
	eq(g.player.flying,true,"empty ki doesn't end flight")
	eq(g.player.charging,true,"you can charge in the air too (user request 2026-11-03)")
	tick(g,{"flight":true})
	eq(g.player.flying,false)
	tick(g,{},10)
	ok(g.player.vel.y<0)
func test_charge_caps_pool_and_suppresses_movement_and_attack() -> void:
	var g := fresh()
	g.player.ki = 1
	tick(g,{"charge":true,"move_x":1,"melee":true},600)
	near(g.player.ki,g.player.maxKi)
	ok(g.player.charging)
	near(g.player.vel.length(),0)
	eq(g.player.attackSerial,0)
	tick(g)
	eq(g.player.charging,false)
func test_jump_gravity_bounds_and_restored_airborne_slot() -> void:
	var g := fresh()
	var ground: float = g.player.pos.y
	tick(g,{"jump":true})
	ok(g.player.pos.y>ground)
	ok(not g.player.onGround)
	tick(g,{},120)
	near(g.player.pos.y,g.zone.height_at(g.player.pos.x,g.player.pos.z),0.00001)
	g.player.pos = Vector3(0,30,0)
	var resumed := RuleGame.new(0,g.to_save())
	ok(not resumed.player.onGround)
	resumed.player.ki = 1
	tick(resumed,{"charge":true,"jump":true})
	ok(resumed.player.vel.y<0)
	ok(not resumed.player.charging)
	resumed.player.pos.x = resumed.zone.size
	tick(resumed)
	ok(resumed.player.pos.x<=resumed.zone.size/2-1)
