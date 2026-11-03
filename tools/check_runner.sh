#!/usr/bin/env bash
# The test runner must report broken test files (syntax errors, scripts that aren't TestCase) as FAIL and exit 1
# within seconds, never hang. Runs the runner on godot/tests/fixtures/runner.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT:-$HOME/.cache/godot/Godot_v4.7.2-stable_linux.x86_64}"
"$G" --headless --path "$ROOT/godot" --import >/dev/null 2>&1
out=$(timeout 60 "$G" --headless --path "$ROOT/godot" -s res://tests/run_all.gd -- --dir=res://tests/fixtures/runner 2>&1); code=$?
echo "$out" | grep "^ok\|^FAIL\|passed"
[ $code -eq 124 ] && { echo "RUNNER HUNG"; exit 1; }
echo "$out" | grep -q "^FAIL.*test_broken_syntax" && echo "$out" | grep -q "^FAIL.*test_not_testcase" && [ $code -eq 1 ] && { echo "runner check ok"; exit 0; }
echo "runner check FAILED (exit $code)"; exit 1
