extends TestCase
# Checks the runner itself: a passing test passes, and a failing one is reported (only when asked for).

func opt_in() -> Dictionary:
	return {"test_fails_on_purpose": "selftest_fail", "test_crashes_on_purpose": "selftest_crash"}

func test_passes() -> void:
	eq(1, 1)

func test_fails_on_purpose() -> void:
	eq(1, 2, "this test must fail")

func test_crashes_on_purpose() -> void:
	var nothing: Object = null
	nothing.call("boom")  # a script error: the runner must report FAIL, not ok
