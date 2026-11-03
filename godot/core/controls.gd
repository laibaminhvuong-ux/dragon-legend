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

func _fresh(action: String) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
