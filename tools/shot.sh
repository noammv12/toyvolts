#!/usr/bin/env bash
# Render one frame of the game to captures/<name>.png and quit. Extra args pass through (e.g. --yaw=30 --pitch=-15).
# Usage: tools/shot.sh <name> [--frames=N] [--yaw=deg] [--pitch=deg]
cd "$(dirname "$0")/.." || exit 2
name="${1:-shot}"; shift
mkdir -p captures
timeout 60 ./tools/godot.sh --path . -- "--screenshot=$(pwd -W)/captures/$name.png" "$@" > captures/last_run.log 2>&1
code=$?
grep -viE "^$|Godot Engine v|https://godotengine" captures/last_run.log
echo "exit=$code"
