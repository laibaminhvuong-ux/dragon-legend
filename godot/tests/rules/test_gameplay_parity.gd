extends "res://tests/rules/game_case.gd"
class Flat extends RefCounted:
	var size: float = 1000
	var gravity: float = 1
	func height_at(_x: float,_z: float) -> float: return 0.0
func test_movement_traces_match_javascript_oracle() -> void:
	var map: Dictionary = {"moveX":"move_x","moveZ":"move_z","flyPitch":"fly_pitch"}
	for c: Dictionary in RuleTables.table("parity").movement:
		var e: Dictionary = {"pos":Vector3.ZERO,"vel":Vector3.ZERO,"yaw":0.0,"onGround":true,"health":100,"ki":80.0,"maxKi":100,"kiCostScale":1,"runSpeed":8,"flying":false,"stun":0}
		var it: Dictionary = {}
		for key: String in c.intents:
			it[map.get(key,key)] = c.intents[key]
		var movement := RuleMovement.new()
		for i: int in int(c.frames):
			movement.step(e,it,1.0/60,Flat.new())
		for key: String in ["pos","vel"]:
			ok(e[key].distance_to(RuleRuntime.vector(c.expected[key]))<0.0002,"JS movement "+key)
		# Flight no longer drains Ki (user tuning 2026-11-03), so flight traces only keep at least the JS Ki.
		if c.intents.has("flight") or bool(c.expected.flying):
			ok(float(e.ki)>=float(c.expected.ki)-0.00001,"ki without flight drain")
		else:
			near(e.ki,c.expected.ki,0.00001,"ki")
		for key: String in ["yaw","dashRemaining","dashCooldown"]:
			near(e.get(key,0),c.expected.get(key,0),0.00001,key)
		for key: String in ["flying","charging","dashing","blocking","onGround"]:
			eq(e[key],c.expected[key],key)
func test_display_names_keep_ordinary_words_and_replace_characters() -> void:
	eq(RuleRuntime.rename_text("Hit him with Frost Armor at the Gas station."),"Hit him with Frost Armor at the Gas station.")
	ok(RuleRuntime.rename_text("Goku and Vegeta")!="Goku and Vegeta")

func test_melee_damage_and_guard_cost_match_javascript_oracle() -> void:
	for c: Dictionary in RuleTables.table("parity").damage:
		var g := fresh(c.race,int(c.level))
		var e: Dictionary = target(g)
		e.health = 1000000.0
		e.maxHealth = e.health
		e.stun = 100.0
		e.blocking = c.blocked
		g.combat.update(1.0/60,{"melee":true})
		near(1000000.0-e.health,c.damage)
		near(e.ki,c.ki)
