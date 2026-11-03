extends TestCase
# Stage 7 Task 5: save codes round-trip (and the web game's codes import), bad codes are rejected without
# touching the saves, rebinding replaces an action's key, and the menu screens build.

var _old := ""

func _use_temp() -> void:
	_old = SaveStore.path
	SaveStore.path = "user://test_menus_profile.json"
	for i in 3: SaveStore.delete_slot(i)

func _restore() -> void:
	for i in 3: SaveStore.delete_slot(i)
	SaveStore.path = _old

func test_save_code_round_trip() -> void:
	_use_temp()
	SaveStore.create_slot(1, RuleSchema.new().default_look("Namekian"))
	var code := SaveStore.export_code()
	ok(code.begins_with("DL1:"), "code has the web game's prefix")
	SaveStore.delete_slot(1)
	eq(SaveStore.load_slot(1), null, "slot emptied")
	var r := SaveStore.import_code(code)
	ok(r.ok, "import ok")
	eq(SaveStore.load_slot(1).race, "Namekian", "fighter restored")
	_restore()

func test_bad_code_keeps_the_saves() -> void:
	_use_temp()
	SaveStore.create_slot(0, RuleSchema.new().default_look("Saiyan"))
	var r := SaveStore.import_code("DL1:@@@not base64")
	ok(not r.ok and str(r.error) != "", "rejected: %s" % r.get("error", ""))
	eq(SaveStore.load_slot(0).race, "Saiyan", "existing fighter untouched")
	ok(not SaveStore.import_code("hello").ok, "no prefix rejected")
	_restore()

func test_rebinding() -> void:
	Controls.register()
	var before := UiKit.key_name("jump")
	Controls.apply_overrides({"jump": ["key:%d" % KEY_J]})
	eq(UiKit.key_name("jump"), "J", "jump rebound to J")
	var pads := InputMap.action_get_events("jump").filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	ok(not pads.is_empty(), "gamepad binding kept")
	Controls.register()
	eq(UiKit.key_name("jump"), before, "reset to the default")

func test_screens_build() -> void:
	var host := Node.new()
	var s := SlotSelect.new(host)
	ok(s.get_child_count() > 0, "slot select")
	var c := Creator.new(host, 0)
	eq(c.look.race, "Saiyan", "creator starts on the first race")
	c._randomize()
	ok(Data.races.has(c.look.race), "randomized race is valid")
	var pm := PauseMenu.new(host, true)
	for t: String in ["settings", "controls"]:
		pm.tab = t
		pm.draw()
	s.free(); c.free(); pm.free(); host.free()
