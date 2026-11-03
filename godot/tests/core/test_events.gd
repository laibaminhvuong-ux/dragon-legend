extends TestCase
# Events autoload: a signal bus with the JS game's event names and payloads.

var got: Array = []

func _bus() -> Node:
	return load("res://core/events.gd").new()

func test_notify() -> void:
	var e := _bus()
	e.notify.connect(func(text: String) -> void: got.append(text))
	e.notify.emit("Back to base form.")
	eq(got, ["Back to base form."])
	e.free()

func test_emit_named_maps_js_names() -> void:
	var e := _bus()
	e.quest_accepted.connect(func(id: String, title: String) -> void: got.append([id, title]))
	e.levelup.connect(func(level: int, gained: int) -> void: got.append([level, gained]))
	e.stats.connect(func(hud: Dictionary) -> void: got.append(hud))
	e.emit_named("questAccepted", {"id": "m01_arrival", "title": "A Saiyar Arrives"})
	e.emit_named("levelup", {"level": 12, "gained": 2})
	e.emit_named("stats", {"level": 12})
	eq(got, [["m01_arrival", "A Saiyar Arrives"], [12, 2], {"level": 12}])
	e.free()

func test_unknown_name_warns() -> void:
	var e := _bus()
	e.emit_named("nope", {})  # a warning, not a crash
	ok(true)
	e.free()

func test_combat_events_pass_through() -> void:
	var e := _bus()
	e.attack.connect(func(d: Dictionary) -> void: got.append(["attack", d]))
	e.damage.connect(func(d: Dictionary) -> void: got.append(["damage", d]))
	e.beam.connect(func(d: Dictionary) -> void: got.append(["beam", d]))
	e.avatar_strike.connect(func(d: Dictionary) -> void: got.append(["avatar", d]))
	var at := {"kind": "KiBlast", "from": Vector3(1, 2, 3)}
	e.emit_named("attack", at)
	e.emit_named("damage", {"amount": 12})
	e.emit_named("beam", {"to": Vector3.ZERO})
	e.emit_named("avatarStrike", {"target": "e1"})
	eq(got, [["attack", at], ["damage", {"amount": 12}], ["beam", {"to": Vector3.ZERO}], ["avatar", {"target": "e1"}]])
	e.free()
