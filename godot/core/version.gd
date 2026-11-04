class_name GameVersion
extends RefCounted
# The game's version (bumped by the integrator on each release; continues the web game's numbering).
const VERSION := "0.0.6"

## The version running now: a downloaded update, or the built-in one.
static func current() -> String:
	var u: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Updater") if Engine.get_main_loop() is SceneTree else null
	return str(u.call("version")) if u != null else VERSION
