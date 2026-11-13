extends TestCase
# The updater only mounts a patch that is newer than the built-in game; versions compare numerically.

func test_version_order() -> void:
	var U: GDScript = load("res://core/updater.gd")
	ok(U.newer("0.0.10", "0.0.9"), "10 > 9 numerically")
	ok(U.newer("v0.1.0", "0.0.3"), "leading v ignored")
	ok(not U.newer("0.0.3", "0.0.3"), "same version is not newer")
	ok(not U.newer("0.0.2", "0.0.3"), "older is not newer")
	ok(U.newer("1.0", "0.9.9"), "missing parts count as zero")

func test_built_version_matches_the_project() -> void:
	eq(str(ProjectSettings.get_setting("application/config/version")), GameVersion.VERSION, "project.godot and version.gd agree")

## Privacy: the game contacts GitHub only after the player chose "on"; a newer pack is offered, never fetched on its own.
func test_update_check_needs_the_players_consent() -> void:
	var old: Variant = Settings.get_value("updateCheck")
	for v in ["", "off", "bogus"]:
		Settings.set_value("updateCheck", v)
		eq(Updater.choice() if v != "bogus" else Updater.choice(), v if v != "bogus" else "", "choice '%s' is stored (unknown values fall back to unasked)" % v)
	Settings.set_value("updateCheck", "")
	var U: Node = load("res://core/updater.gd").new()
	U.check()
	ok(U._http == null, "no request is made before the player agrees")
	ok(U._pending_url == "", "nothing is queued for download")
	U.free()
	Settings.set_value("updateCheck", old if old != null else "")
