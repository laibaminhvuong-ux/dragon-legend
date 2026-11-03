class_name TestCase
extends RefCounted
# Base for headless tests: every method named test_* runs. Assertions record failures instead of throwing,
# so one test reports all its problems. Methods listed in opt_in() run only when the filter equals their token.

var failures: Array[String] = []

func opt_in() -> Dictionary:
	return {}

func eq(actual: Variant, expected: Variant, msg := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%sexpected %s, got %s" % [_prefix(msg), var_to_str(expected), var_to_str(actual)])

func ok(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%scondition is false" % _prefix(msg))

func near(a: float, b: float, eps := 1e-6, msg := "") -> void:
	if absf(a - b) > eps:
		failures.append("%sexpected %s ± %s, got %s" % [_prefix(msg), b, eps, a])

func _prefix(msg: String) -> String:
	return msg + ": " if msg != "" else ""
