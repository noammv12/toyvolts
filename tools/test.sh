#!/usr/bin/env bash
# Headless test run with a hang guard. Exit code = test result.
cd "$(dirname "$0")/.." || exit 2
timeout 90 ./tools/godot.sh --headless --path . --quit-after 3000 res://tests/test_runner.tscn > tests/last_run.log 2>&1
code=$?
grep -viE "^$|Godot Engine v|https://godotengine" tests/last_run.log
echo "exit=$code"
exit $code
