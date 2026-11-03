extends TestCase
# Checks the runner itself: a passing test passes, and a failing one is reported (only when asked for).

func opt_in() -> Dictionary:
	return {"test_fails_on_purpose": "selftest_fail"}

func test_passes() -> void:
	eq(1, 1)

func test_fails_on_purpose() -> void:
	eq(1, 2, "this test must fail")
