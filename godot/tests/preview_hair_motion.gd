extends SceneTree
# Dev-only GPU preview of hair secondary motion (Hair.Motion + hair_motion.gdshaderinc). Not a test case (no test_
# prefix, the runner skips it). A row of long-haired fighters (the last one cel-shaded, to check the ink outline) runs
# sideways past a camera that follows them, stops dead, then stands in a breeze. Saves one shot per phase:
#   <out>_rest.png (no wind, still), <out>_run.png (running +x: hair trails -x), <out>_stop.png (just stopped: swing
#   forward), <out>_wind.png (standing in a strength-1.2 wind blowing towards +x).
#   godot --path godot -s res://tests/preview_hair_motion.gd -- --out=C:/dir/hair

const LOOKS := [
	{"race": "Human", "female": true, "hair": "Long", "hairColor": 0, "outfit": "TurtleGi", "faceSeed": "hm1"},
	{"race": "Human", "female": true, "hair": "Ponytail", "hairColor": 2, "outfit": "TurtleGi", "faceSeed": "hm2"},
	{"race": "Saiyan", "hair": "LongSpiky", "hairColor": 0, "outfit": "TurtleGi"},
	{"race": "Human", "female": true, "hair": "TwinTails", "hairColor": 1, "outfit": "TurtleGi", "faceSeed": "hm3"},
	{"race": "Human", "female": true, "hair": "ShoulderStraight", "hairColor": 3, "outfit": "TurtleGi", "faceSeed": "hm4"},
	{"race": "Saiyan", "hair": "Spiky", "hairColor": 0, "outfit": "TurtleGi", "shading": "cel"},
]
const SPEED := 9.0

var out := "user://hair"
var fighters: Array[Fighter] = []
var cam: Camera3D
var rig: Node3D
var frame := 0
var phase := "rest"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	root.size = Vector2i(1600, 700)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.4, 0)
	root.add_child(sun)
	rig = Node3D.new()
	root.add_child(rig)
	for i in LOOKS.size():
		var f := Fighter.create(LOOKS[i])
		f.position = Vector3((i - LOOKS.size() * 0.5) * 1.5, 0, 0)   # a row seen side-on: everyone runs towards +x
		f.rotation.y = PI * 0.5
		rig.add_child(f)
		fighters.append(f)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2
	root.add_child(cam)
	WorldWind.ensure_globals()
	WorldWind.strength = 0.0

func _process(delta: float) -> bool:
	var dt := 1.0 / 60.0
	frame += 1
	var speed := 0.0
	if frame < 60: phase = "rest"
	elif frame < 150: phase = "run"; speed = SPEED
	elif frame < 160: phase = "stop"
	elif frame < 400:
		phase = "wind"
		WorldWind.dir = Vector2(1, 0); WorldWind.strength = 1.2; WorldWind.gust = 0.0
		WorldWind._push()
	rig.position.x += speed * dt
	WorldWind.advance(dt)
	for f in fighters:
		f.update(dt, {"speed": 0.0, "onGround": true})   # idle pose: only the hair differs between shots
	# side view, following the row; the column is spread along z, so look slightly from above at an angle
	cam.position = Vector3(rig.position.x - 1.6, 1.5, 6.0)
	cam.look_at(Vector3(rig.position.x - 1.6, 1.3, 0.0))
	cam.size = 4.3
	if frame in [58, 148, 158, 398]:
		var img := root.get_texture().get_image()
		img.save_png("%s_%s.png" % [out, phase])
		print("shot %s: hair offset %s" % [phase, fighters[0].hair_motion.offset if fighters[0].hair_motion != null else Vector3.ZERO])
	if frame >= 400:
		quit()
	return false
