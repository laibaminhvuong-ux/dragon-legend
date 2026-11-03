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
