#!/usr/bin/env bash
# Regenerate .godot (imports + global class cache). The headless editor sometimes lingers, so guard it.
cd "$(dirname "$0")/.." || exit 2
timeout 400 ./tools/godot.sh --headless --path . --import > .godot_import.log 2>&1
code=$?
taskkill //F //IM Godot_v4.7.2-stable_win64.exe //T >/dev/null 2>&1
grep -iE "error|warning|script" .godot_import.log | grep -viE "update_scripts_classes|first_scan|progress" | head -20
echo "import exit=$code (124 = guard timeout, fine if the cache was written)"
