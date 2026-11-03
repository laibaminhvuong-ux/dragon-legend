class_name CutscenePlayer
extends Control
# Boss cutscenes (port of web/src/ui/cutscene.js): letterbox bars, the speaker's name and line typed out with
# their voice, and a camera over the listener's shoulder framing whoever is talking. The game is frozen while it
# plays (idle animation keeps going). Jump / Interact / click = next line (or finish typing), Pause = skip.

const CPS := 55.0
var scene: Dictionary = {}
var i := 0
var typed := 0.0
var cut := true
var actor: Callable          # speaker -> {pos: Vector3, scale: float} or {}
var on_end: Callable
var _who: Label
var _line: Label
var _hint: Label
var _top: ColorRect
var _bottom: ColorRect
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO

func _init() -> void:
	name = "Cutscene"
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = ColorRect.new(); _top.color = Color.BLACK
	_top.anchor_right = 1.0; _top.anchor_bottom = 0.12
	add_child(_top)
	_bottom = ColorRect.new(); _bottom.color = Color(0, 0, 0, 0.92)
	_bottom.anchor_top = 0.74; _bottom.anchor_right = 1.0; _bottom.anchor_bottom = 1.0
	add_child(_bottom)
	var v := VBoxContainer.new()
	v.anchor_left = 0.12; v.anchor_right = 0.88; v.anchor_top = 0.05; v.anchor_bottom = 0.95
	_bottom.add_child(v)
	_who = UiKit.label("", "HeaderMedium")
	_who.add_theme_font_size_override("font_size", 28)
	v.add_child(_who)
	_line = UiKit.label("", "", true)
	_line.add_theme_font_size_override("font_size", 24)
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_line)
	_hint = UiKit.label("", "Muted")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)
	visible = false

var active: bool:
	get: return not scene.is_empty()

func play(s: Dictionary, actor_fn: Callable, finished: Callable = Callable()) -> void:
	if (s.get("lines", []) as Array).is_empty():
		if finished.is_valid(): finished.call()
		return
	scene = s; actor = actor_fn; on_end = finished; i = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_show()

func _show() -> void:
	var l: Dictionary = scene.lines[i]
	_who.text = str(l.get("name", ""))
	_who.add_theme_color_override("font_color", Color("#8fd0ff") if str(l.get("speaker", "")) == "you" else UiKit.ACCENT.lightened(0.2))
	Voices.say(str(l.get("name", "")), str(l.get("text", "")))
	typed = 0.0
	_line.text = ""
	_hint.text = "%s / click: next · %s: skip · %d / %d" % [UiKit.key_name("jump"), UiKit.key_name("pause"), i + 1, (scene.lines as Array).size()]
	cut = true

func next() -> void:
	var text := str(scene.lines[i].get("text", ""))
	if typed < text.length():
		typed = text.length()
		_line.text = text
		return
	i += 1
	if i >= (scene.lines as Array).size():
		end()
		return
	_show()

func end() -> void:
	var done := on_end
	scene = {}
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Voices.stop()
	if done.is_valid(): done.call()

func handle_input(gi: GameInput) -> void:
	if not active:
		return
	if gi.pressed("pause"):
		end()
	elif gi.pressed("jump") or gi.pressed("interact"):
		next()

func _gui_input(e: InputEvent) -> void:
	if active and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		next()
		accept_event()

## Overrides the camera for this frame (call after the follow camera).
func drive_camera(cam: Camera3D, dt: float) -> void:
	if not active:
		return
	var text := str(scene.lines[i].get("text", ""))
	if typed < text.length():
		typed = minf(text.length(), typed + dt * CPS)
		_line.text = text.substr(0, int(typed))
	var l: Dictionary = scene.lines[i]
	var speaker := str(l.get("speaker", ""))
	var S: Dictionary = actor.call(speaker)
	var O: Dictionary = actor.call(str(scene.get("enemy", "")) if speaker == "you" else "you")
	if S.is_empty() or O.is_empty():
		return
	var s: Vector3 = S.pos + Vector3(0, 1.55 * float(S.scale), 0)
	var o: Vector3 = O.pos + Vector3(0, 1.55 * float(O.scale), 0)
	var d := Vector3(s.x - o.x, 0, s.z - o.z)
	if d.length_squared() < 0.01: d = Vector3(0, 0, 1)
	d = d.normalized()
	var side := Vector3(-d.z, 0, d.x)
	var big := maxf(float(S.scale), 1.0)
	var dist := Vector2(s.x - o.x, s.z - o.z).length()
	var closer := maxf(0.0, dist - 4.5 - big)
	var want := o + d * (closer - 2.2 - big * 0.6) + side * (1.1 + minf(1.2, closer * 0.15)) + Vector3(0, 0.35 + big * 0.25 + minf(2.2, closer * 0.3), 0)
	var look := s + Vector3(0, -0.1 * big, 0)
	if cut:
		_cam_pos = want; _cam_look = look; cut = false
	else:
		var k := 1.0 - exp(-dt * 2.5)
		_cam_pos = _cam_pos.lerp(want, k); _cam_look = _cam_look.lerp(look, k)
	cam.position = _cam_pos
	if not _cam_pos.is_equal_approx(_cam_look):
		cam.transform = cam.transform.looking_at(_cam_look, Vector3.UP)
