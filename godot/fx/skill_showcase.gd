extends Node3D
## Isolated VFX/audio audition stage. No save or combat instance is opened.
var director := SkillDirector.new()
var ids: Array = []
var index := 0
var elapsed := 0.0
var stage := -1
var caption := Label.new()
var playing := true
var variation := 0
var hold_audition := false
var quick_tap := false
var fighter: Fighter
var cast_serial := 0
func _ready() -> void:
	fighter = Fighter.create(RuleSchema.new().default_look("Saiyan")); add_child(fighter); fighter.rotation.y = PI
	add_child(director); director.bind(null,func(_id: String) -> Fighter: return fighter,"high")
	ids = SkillCatalog.all().keys()
	var camera := Camera3D.new(); add_child(camera); camera.position = Vector3(8,6,10); camera.look_at(Vector3(0,2,-5)); camera.current = true
	var environment := WorldEnvironment.new(); var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR; settings.background_color = Color("121a29")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; settings.ambient_light_color = Color.WHITE; settings.ambient_light_energy = .5
	settings.glow_enabled = true; environment.environment = settings; add_child(environment)
	var floor_mesh := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(30,30); floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new(); floor_material.albedo_color = Color("242c39"); floor_material.roughness = .9; floor_mesh.material_override = floor_material; add_child(floor_mesh)
	var canvas := CanvasLayer.new(); add_child(canvas); canvas.add_child(caption); caption.position = Vector2(24,24); caption.add_theme_font_size_override("font_size",22)
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.is_action_pressed("ui_right"): select(1)
	if event.is_action_pressed("ui_left"): select(-1)
	if event is InputEventKey and event.keycode==KEY_H: hold_audition = not hold_audition
	if event is InputEventKey and event.keycode==KEY_Q: quick_tap = not quick_tap; select(0)
	if event is InputEventKey and event.keycode==KEY_V:
		variation = (variation+1)%3; select(0)
	if event.is_action_pressed("ui_accept"): playing = not playing; director.set_paused(not playing)
func select(delta: int) -> void:
	index = posmod(index+delta,ids.size()); elapsed = 0; stage = -1; director.clear(); fighter.position = Vector3.ZERO
func _process(dt: float) -> void:
	if not playing or ids.is_empty(): return
	elapsed += dt
	var id: String = ids[index]; var recipe := SkillCatalog.get_skill(id)
	var gather_time := .02 if quick_tap else 2.0
	fighter.presentation = {"skillHoldPose":recipe.pose if stage<=0 else "","skillHold":1.0 if stage<=0 else 0.0,"skillReleasePose":recipe.pose if stage>=1 else ""}
	fighter.update(dt,{"speed":0,"onGround":true,"attackSerial":cast_serial,"attackKind":recipe.kind})
	caption.text = "%d / %d  %s\n%s · %s · %s\n← / → select   Space pause   V sound variant   H hold loop   Q quick tap   Auto advances every 6 seconds\nOriginal designed audio; review on speakers/headphones." % [index+1,ids.size(),recipe.name,recipe.geometry,recipe.pose,recipe.availability]
	var packet := {"move_id":id,"actor_id":"audition","action_sequence":index,"seed":index+variation,"origin":Vector3(0,2,0),"from":Vector3(0,2,0),"to":Vector3(0,2,-10),"pos":Vector3(0,2,0),"direction":Vector3.FORWARD,"socket":recipe.phases.prepare.socket if stage<=0 else recipe.socket,"color":recipe.accent}
	if stage<0:
		stage = 0; packet.phase = "prepare"; director.handle_event("attack",packet)
	if stage==0:
		packet.phase = "prepare"; packet.charge = minf(1,elapsed/2); director.update_actor_states([{"skillState":packet}])
	if elapsed>=gather_time and stage==0 and not hold_audition:
		stage = 1; cast_serial += 1; packet.phase = "release"; packet.socket = recipe.socket; director.handle_event("attack",packet)
		if recipe.delivery=="instant_ray": director.handle_event("beam",packet)
	if stage==1 and recipe.delivery=="projectile":
		packet.pos = Vector3(0,2,-minf(10,(elapsed-gather_time)*12)); director.sync_projectiles([{"id":"sample","move_id":id,"pos":packet.pos,"presentation":packet}])
	if elapsed>=gather_time+1 and stage==1:
		stage = 2; director.sync_projectiles([]); packet.phase = "impact"; packet.pos = Vector3(0,2,-10); director.handle_event("damage",packet)
	if elapsed>gather_time+4 and not hold_audition: select(1)
