extends Node3D
# Open this scene and press F6 to review without loading or changing a save/world.
const DURATION := 4.0
const TITLES := ["1 · Combo weight and recovery", "2 · Directional hit and heavy stagger", "3 · Run, stop and land", "4 · Base Ki charge and colour", "5 · Beam preparation and release", "6 · Transformation surge", "7 · Flight, dash and landing", "8 · Instinct / Ego / Legendary personality"]
var fighters: Array[Fighter] = []
var label: Label
var elapsed := 0.0
var stage := -1
var serial := 1
var last_beat := -1
var beam: MeshInstance3D
var audio: CombatAudio
func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101b32")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8c9df")
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40,-35,0); add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(24,0.1,18); floor_mesh.mesh = box
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("28394b"); floor_mesh.material_override = mat
	floor_mesh.position.y = -0.1; add_child(floor_mesh)
	for i in 3:
		var f := Fighter.create({"race":"Saiyan","hair":"Spiky","outfit":"TurtleGi","outfitTint":i,"kiColorHex":"#30c9ff"})
		add_child(f); fighters.append(f)
	var camera := Camera3D.new(); camera.position = Vector3(7,4.0,10); add_child(camera); camera.look_at(Vector3(0,1,0)); camera.make_current()
	var overlay := CanvasLayer.new(); add_child(overlay)
	label = Label.new(); label.position = Vector2(24,24); label.add_theme_font_size_override("font_size",24); overlay.add_child(label)
	audio = CombatAudio.new(); add_child(audio)
	beam = MeshInstance3D.new()
	var cylinder := CylinderMesh.new(); cylinder.top_radius = 0.12; cylinder.bottom_radius = 0.2; cylinder.height = 4
	beam.mesh = cylinder
	var energy := ShaderMaterial.new(); energy.shader = preload("res://fx/shaders/energy.gdshader")
	beam.material_override = energy; beam.set_instance_shader_parameter("energy_color",Color("30c9ff")); beam.set_instance_shader_parameter("strength",1.5)
	add_child(beam); beam.visible = false
func _process(dt: float) -> void:
	elapsed += dt
	var next := int(elapsed/DURATION)%TITLES.size()
	var t := fmod(elapsed,DURATION)
	if next!=stage:
		stage = next; last_beat = -1
		for i in fighters.size():
			fighters[i].set_form("")
			fighters[i].presentation.clear()
		label.text = TITLES[stage]+"\nPresentation preview · loops automatically · no save changes"
	var a := {"attackSerial":serial}
	fighters[0].position = Vector3(-2,0,0)
	fighters[1].position = Vector3(2,0,0)
	fighters[0].rotation.y = PI/2; fighters[1].rotation.y = -PI/2
	fighters[2].position = Vector3(0,0,-3)
	fighters[2].visible = stage==7
	beam.visible = false
	match stage:
		0:
			var beat := int(t/0.7)
			if beat!=last_beat:
				last_beat = beat; serial += 1
				var fx := CombatFlourish.create("arc",Color("c9edff")); add_child(fx); fx.position = fighters[0].position+Vector3.UP; fx.rotation.y = PI/2
				audio.play_cue("whoosh",fx.position)
			a.attackSerial = serial; a.attackKind = ["jab","cross","hook","leg kick"][beat%4]
			fighters[1].presentation = {"hitWeight":0.35,"hitSide":0.5,"reactionSerial":serial}
		1:
			a.hurt = true; a.hitWeight = 1.0; a.hitSide = -0.8; a.reactionSerial = int(t/0.8)
		2:
			a.speed = 8.0 if t<2 else 0.0
			a.onGround = t>1.8
			a.vy = -8.0 if t<1.8 else 0.0
		3: a.charging = true
		4:
			a.beamCharge = minf(1,t/1.8) if t<2 else 0.0
			a.aimPitch = 0.12
			if t>=2 and last_beat<0:
				last_beat = 1; serial += 1; audio.play_cue("beam",fighters[0].position)
			a.attackSerial = serial; a.attackKind = "beam"
			beam.visible = t>=2 and t<2.45
			beam.position = Vector3(0,1.2,0); beam.rotation.z = PI/2
		5:
			if t>1 and last_beat<0:
				last_beat = 1; fighters[0].set_form("SSJBlue")
				var fx := CombatFlourish.create("surge",Color("30c9ff")); add_child(fx); fx.position = fighters[0].position
				audio.play_cue("surge",fx.position)
		6:
			a.flying = t<2.8; a.onGround = t>=2.8; a.speed = 12.0 if t>1 and t<2.5 else 0.0
			a.dashing = t>2 and t<2.3; a.dashSide = 0.7
			a.vy = 5.0 if t<0.7 else -7.0 if t>2.5 else 0.0
		7:
			fighters[0].set_form("UIPerfected"); fighters[1].set_form("UltraEgo"); fighters[2].set_form("LegendarySSJ")
	fighters[0].update(dt,a)
	fighters[1].update(dt,{"hurt":stage==0,"onGround":true,"attackSerial":0})
	fighters[2].update(dt,{"charging":stage==7})
	audio.update_player(a,fighters[0].position,minf(1,t/2))
