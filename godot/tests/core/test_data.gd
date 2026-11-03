extends TestCase
# Data autoload: every data/*.json becomes a table; a broken file is reported, never fatal.

const FIXTURES := "res://tests/fixtures/data"

func _fresh() -> Node:
	var d: Node = load("res://core/data.gd").new()
	d.load_dir(FIXTURES)
	return d

func test_loads_tables() -> void:
	var d := _fresh()
	eq(d.quests.size(), 2, "quests")
	eq(d.forms["SSJ"]["name"], "Super Saiyar", "forms")
	d.free()

func test_broken_file_is_reported_not_fatal() -> void:
	var d := _fresh()
	ok(d.errors.size() == 1 and String(d.errors[0]).contains("broken.json"), "errors lists broken.json: %s" % [d.errors])
	eq(d.quests.size(), 2, "other tables still load")
	d.free()

func test_missing_table_is_empty() -> void:
	var d := _fresh()
	ok(d.moves.is_empty(), "moves is empty")
	ok(d.npcs is Array and d.npcs.is_empty(), "npcs is an empty Array")
	d.free()

func test_unknown_table_name() -> void:
	var d := _fresh()
	eq(d.table("nope"), null)
	eq(d.table("forms")["SSJ"]["multiplier"], 2.0, "table() reads by name")
	d.free()
