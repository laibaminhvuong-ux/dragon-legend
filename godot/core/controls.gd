extends Node
# Autoload "Controls": registers the game's input actions with the same default keys as the JS game
# (web/src/core/input.js DEFAULT_BINDINGS). One table, so rebinding later edits one place.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE], "dash": [KEY_Q], "flight": [KEY_F], "ascend": [KEY_SPACE], "descend": [KEY_CTRL],
	"charge": [KEY_C], "ki_blast": [KEY_E], "beam": [KEY_R], "transform": [KEY_T], "lock_on": [KEY_TAB],
	"interact": [KEY_G], "menu": [KEY_M], "radar": [KEY_V], "base": [KEY_B], "kaioken": [KEY_K], "pause": [KEY_ESCAPE],
}
const MOUSE := {"melee": MOUSE_BUTTON_LEFT, "block": MOUSE_BUTTON_RIGHT}
# Gamepad: the JS standard-mapping buttons (Pad0..Pad15) in Godot's numbering; the triggers are axes.
const PAD := {
	"jump": JOY_BUTTON_A, "ascend": JOY_BUTTON_A, "dash": JOY_BUTTON_B, "melee": JOY_BUTTON_X, "flight": JOY_BUTTON_Y,
	"block": JOY_BUTTON_LEFT_SHOULDER, "ki_blast": JOY_BUTTON_RIGHT_SHOULDER, "menu": JOY_BUTTON_BACK, "pause": JOY_BUTTON_START,
	"descend": JOY_BUTTON_LEFT_STICK, "lock_on": JOY_BUTTON_RIGHT_STICK, "transform": JOY_BUTTON_DPAD_UP, "interact": JOY_BUTTON_DPAD_DOWN,
	"kaioken": JOY_BUTTON_DPAD_LEFT, "radar": JOY_BUTTON_DPAD_RIGHT,
}
const PAD_AXES := {"charge": JOY_AXIS_TRIGGER_LEFT, "beam": JOY_AXIS_TRIGGER_RIGHT}

func _ready() -> void:
	register()

## Adds every action (idempotent: existing actions are reset to the defaults).
func register() -> void:
	for action: String in KEYS:
		_fresh(action)
		for key: int in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = key
			InputMap.action_add_event(action, e)
	for action: String in MOUSE:
		_fresh(action)
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE[action]
		InputMap.action_add_event(action, m)
	for action: String in PAD:
		var j := InputEventJoypadButton.new()
		j.button_index = PAD[action]
		InputMap.action_add_event(action, j)
	for action: String in PAD_AXES:
		var ja := InputEventJoypadMotion.new()
		ja.axis = PAD_AXES[action]; ja.axis_value = 1.0
		InputMap.action_add_event(action, ja)

func _fresh(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
