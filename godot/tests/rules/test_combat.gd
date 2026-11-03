extends "res://tests/rules/game_case.gd"
func test_melee_cooldowns_guard_break_and_kill_rewards_once() -> void:
	var g := fresh()
	var e: Dictionary = target(g)
	var before: float = e.health
	tick(g,{"melee":true})
	ok(e.health<before)
	var after: float = e.health
	tick(g,{"melee":true})
	near(e.health,after)
	e.blocking = true
	g.combat.hit(e,10,g.player,true)
	eq(e.blocking,false)
	e.health = 1
	var zeni: float = g.slot.zeni
	g.combat.hit(e,100,g.player)
	eq(e.health,0.0)
	ok(g.slot.zeni>zeni)
	var reward: float = g.slot.zeni
	g.combat.hit(e,100,g.player)
	near(g.slot.zeni,reward)
	eq(g.events.count("enemyDefeated"),1)
func test_blast_trajectory_colour_cost_and_cooldown() -> void:
	var g := fresh()
	var e: Dictionary = target(g,8)
	g.customize_appearance({"kiColorHex":"#12ab34"})
	var before: float = e.health
	tick(g,{"ki_blast":true})
	eq(g.combat.projectiles.size(),1)
	eq(g.combat.projectiles[0].color,0x12ab34)
	ok(g.player.ki<g.player.maxKi)
	tick(g,{"ki_blast":true})
	eq(g.combat.projectiles.size(),1)
	tick(g,{},25)
	ok(e.health<before)
	eq(g.combat.projectiles.size(),0)
func test_beam_release_and_low_ki_rejection() -> void:
	var g := fresh()
	var e: Dictionary = target(g,9)
	tick(g,{"beam":true},60)
	near(e.health,e.maxHealth)
	ok(g.combat.snapshot().beamCharge>0)
	tick(g)
	ok(e.health<e.maxHealth)
	ok(g.combat.snapshot().beamCd>0)
	g.player.ki = 0
	ok(not g.combat.fire("KiBlast"))
func test_guard_shield_and_enemy_ai_leash_altitude() -> void:
	var a := fresh()
	var b := fresh()
	target(a)
	target(b)
	tick(a,{},46)
	tick(b,{"block":true},46)
	ok(a.player.maxHealth-a.player.health>0)
	ok(b.player.maxHealth-b.player.health<a.player.maxHealth-a.player.health)
	var e: Dictionary = target(b)
	b.player.pos.y = 30
	b.player.flying = true
	e.health *= 0.5
	var health: float = b.player.health
	tick(b,{},60)
	near(b.player.health,health)
	ok(e.health>e.maxHealth*0.5)
func test_death_respawn_preserves_progress_and_unlock_validation() -> void:
	var g := fresh()
	var e: Dictionary = target(g)
	g.slot.quests.example = {"status":"active"}
	g.player.health = 1
	g.combat.hit(g.player,100,e)
	eq(g.player.health,0.0)
	ok(g.combat.snapshot().respawn>0)
	tick(g,{},185)
	ok(g.player.health>0)
	ok(g.slot.quests.has("example"))
	ok(not g.combat.set_technique("UltraInstinctAvatar"))
	ok(g.select_form("SSJ")!=null)
func test_lock_target_vertical_aim_and_disposal_of_stale_encounters() -> void:
	var g := fresh()
	var e: Dictionary = target(g,9)
	e.pos.y += 4
	tick(g,{"lock_on":true})
	eq(g.player.lockTarget,e.id)
	var aim: Dictionary = g.combat.aim_state()
	ok(aim.locked)
	ok(aim.dir.y>0)
	near(aim.dir.length(),1,0.00001)
	e.health = 0
	tick(g)
	eq(g.player.lockTarget,null)
