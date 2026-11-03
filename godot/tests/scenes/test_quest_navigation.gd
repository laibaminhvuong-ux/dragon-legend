extends TestCase
func test_direction_marker_clamps_all_edges_and_handles_behind_camera() -> void:
	var viewport := Vector2(1280,720)
	for point: Vector2 in [Vector2(-1000,400),Vector2(3000,200),Vector2(400,-900),Vector2(700,3000)]:
		var marker := QuestDirection.place_marker(point,viewport,false)
		ok(marker.edge)
		ok(marker.position.x>=89 and marker.position.x<=1191)
		ok(marker.position.y>=109 and marker.position.y<=611)
	var center := QuestDirection.place_marker(viewport/2,viewport,true)
	ok(center.edge)
	near(center.position.x,90.0,0.001,"behind-camera target is pushed to screen edge")
	ok(center.direction.is_finite())
	var singular := QuestDirection.place_marker(Vector2(INF,INF),viewport,false)
	ok(singular.position.is_finite() and singular.edge)
	var visible := QuestDirection.place_marker(Vector2(400,300),viewport,false)
	ok(not visible.edge)
func test_quest_buttons_select_rule_objective_from_menu_and_hud() -> void:
	if Data.races.is_empty(): Data.load_dir("res://data")
	var g := RuleGame.new(0,RuleSchema.new().new_slot(RuleSchema.new().default_look("Saiyan")),Events)
	var p := PlaySession.new()
	p.game = g
	p.story = RuleStory.new(g,Events)
	var q: Dictionary = p.story.quests[0]
	g.slot.quests[q.id] = {"status":"active","step":0,"count":0,"t":0.0,"collected":[],"completions":0}
	# The UI needs no world mesh to select a quest.
	var hud := Hud.new(p)
	hud._slow_update()
	var row: VBoxContainer = hud._tracker.get_child(0)
	var button: Button = row.get_child(0)
	# Avoid writing any real slot during this isolated test.
	p.slot_index = -1
	button.pressed.emit()
	eq(p.story.tracked_id,q.id)
	var menu := RpgMenu.new(p)
	menu._tab_quests()
	ok("Quests" in RpgMenu.TABS)
	ok(menu._box.get_child_count()>0)
	hud.free()
	menu.free()
	p.free()
