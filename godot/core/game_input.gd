class_name GameInput
extends Node
# Per-session input for the fixed-step game (port of web/src/core/input.js's pressed/down/axis/look):
# a press is latched until a simulation step consumes it (end_tick), so a quick tap between two steps is never
# lost and never counted twice. Mouse look is captured while playing; the gamepad's right stick looks too.

const DEADZONE := 0.18
var capture := false: set = set_capture
var _pressed: Dictionary = {}
var _look := Vector2.ZERO
var last_device := "keyboard"

const ACTIONS := ["jump", "dash", "flight", "ascend", "descend", "charge", "melee", "block", "ki_blast", "beam", "transform",
	"lock_on", "interact", "menu", "radar", "base", "kaioken", "pause"]

func _init() -> void:
	if not InputMap.has_action("move_forward"):
		Controls.register()   # headless tools/tests run before the autoload's _ready

func set_capture(on: bool) -> void:
	capture = on
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE

func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and capture:
		_look += (e as InputEventMouseMotion).relative * 0.0025
		last_device = "keyboard"
	for a: String in ACTIONS:
		if e.is_action_pressed(a, false, true):
			_pressed[a] = true
			last_device = "gamepad" if (e is InputEventJoypadButton or e is InputEventJoypadMotion) else "keyboard"

## Simulates a press (touch controls, tests).
func press(action: String) -> void:
	_pressed[action] = true

func pressed(action: String) -> bool:
	return _pressed.get(action, false)

func down(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

## Consumes this step's presses.
func end_tick() -> void:
	_pressed.clear()

## Movement axis: x right+, y forward+ (keys + left stick).
func move_axis() -> Vector2:
	var v := Vector2(Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_forward") - Input.get_action_strength("move_back"))
	var pad := Vector2(_dz(Input.get_joy_axis(0, JOY_AXIS_LEFT_X)), -_dz(Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)))
	v += pad
	return v.limit_length(1.0)

## Camera look since the last call (radians), sensitivity and invert applied. Call once per frame.
func take_look(frame_dt: float) -> Vector2:
	var sens := float(Settings.get_value("mouseSensitivity"))
	var inv := -1.0 if Settings.get_value("invertY") else 1.0
	var pad := Vector2(_dz(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)) * 2.6, _dz(Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)) * 2.0) * frame_dt
	var out := Vector2((_look.x + pad.x) * sens, (_look.y + pad.y) * sens * inv)
	_look = Vector2.ZERO
	return out

## Adds look from a touch drag (radians).
func add_look(d: Vector2) -> void:
	_look += d

static func _dz(v: float) -> float:
	return 0.0 if absf(v) < DEADZONE else (v - signf(v) * DEADZONE) / (1.0 - DEADZONE)
