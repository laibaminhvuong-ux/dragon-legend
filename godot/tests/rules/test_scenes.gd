extends "res://tests/rules/game_case.gd"
const Scenes = preload("res://rules/cutscene_rules.gd")
const Tutorial = preload("res://rules/tutorial_rules.gd")
func test_boss_scenes_range_once_and_save_persistence() -> void:
	var g := fresh()
	var director := Scenes.new(g.slot)
	for enemy: String in director.story_bosses:
		ok(not director.scene_lines(enemy,"before").is_empty())
		ok(not director.scene_lines(enemy,"after").is_empty())
	var enemy: String = director.story_bosses.keys()[0]
	var e: Dictionary = {"key":enemy,"boss":true,"x":25,"z":0,"name":"Boss"}
	eq(director.before_for([e],Vector3.ZERO),null)
	e.x = 23
	ok(director.before_for([e],Vector3.ZERO)!=null)
	eq(Scenes.new(g.slot).before_for([e],Vector3.ZERO),null)
	ok(director.after_for(enemy)!=null)
	eq(director.after_for(enemy),null)
	eq(director.after_for("patrol_earth_plains"),null)
func test_all_fourteen_tutorial_steps_require_actions_and_persist() -> void:
	var g := fresh()
	var t := Tutorial.new(g.slot)
	var p: Dictionary = g.player
	ok(t.active)
	eq(t.update(0.1,{},p),null)
	t.look(1.3)
	eq(t.update(0.1,{},p),"look")
	p.pos.x += 7
	eq(t.update(0.1,{},p),"move")
	eq(t.update(0.1,{"jump":true},p),"jump")
	eq(t.update(0.1,{"dash":true},p),"dash")
	p.flying = true
	eq(t.update(1.6,{},p),"fly")
	p.flying = false
	p.onGround = true
	eq(t.update(0.1,{},p),"land")
	for i: int in 3:
		p.attackSerial += 1
		t.update(0.1,{},p)
	eq(t.step.id,"blast")
	eq(t.update(0.1,{"ki_blast":true},p),"blast")
	t.update(0.1,{"beam":true},p)
	eq(t.update(0.1,{},p),"beam")
	eq(t.update(1.6,{"charge":true},p),"charge")
	eq(t.update(1.1,{"block":true},p),"guard")
	eq(t.update(0.1,{"lock_on":true},p),"lock")
	t.note("talk")
	eq(t.update(0.1,{},p),"talk")
	eq(t.update(10.1,{},p),"menu")
	ok(not t.active)
	ok(not Tutorial.new(g.slot).active)
	t.restart()
	ok(t.active)
	t.skip()
	eq(g.slot.story.flags.tutorial,"skipped")
	ok(not Tutorial.new(fresh("Saiyan",2).slot).active)
