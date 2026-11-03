extends TestCase
# Controls: every game action exists with the same default keys as the JS game.

func test_actions_and_default_keys() -> void:
	var c: Node = load("res://core/controls.gd").new()
	c.register()
	var expect := {"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "jump": KEY_SPACE,
		"dash": KEY_Q, "flight": KEY_F, "ascend": KEY_SPACE, "descend": KEY_CTRL, "charge": KEY_C, "ki_blast": KEY_E,
		"beam": KEY_R, "transform": KEY_T, "lock_on": KEY_TAB, "interact": KEY_G, "menu": KEY_M, "radar": KEY_V,
		"base": KEY_B, "kaioken": KEY_K, "pause": KEY_ESCAPE}
	for action in expect:
		ok(InputMap.has_action(action), "action %s exists" % action)
		var keys: Array = []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				keys.append(e.physical_keycode)
		ok(expect[action] in keys, "%s is bound to %s (has %s)" % [action, OS.get_keycode_string(expect[action]), keys])
	for action in ["melee", "block"]:
		var buttons: Array = []
		for e in InputMap.action_get_events(action):
			if e is InputEventMouseButton:
				buttons.append(e.button_index)
		ok((MOUSE_BUTTON_LEFT if action == "melee" else MOUSE_BUTTON_RIGHT) in buttons, "%s on the mouse" % action)
	c.free()
