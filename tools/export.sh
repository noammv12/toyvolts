#!/usr/bin/env bash
# Export a self-contained Windows build to build/ToyVolts/ and zip it to build/ToyVolts-win64.zip
cd "$(dirname "$0")/.." || exit 2
rm -rf build/ToyVolts && mkdir -p build/ToyVolts
timeout 600 ./tools/godot.sh --headless --path . --export-release "Windows Desktop" "build/ToyVolts/ToyVolts.exe" > build/export.log 2>&1
code=$?
grep -iE "error|warning|savepack|done" build/export.log | grep -viE "Godot Engine|https://" | head -20
ls -la build/ToyVolts
cat > build/ToyVolts/README.txt <<'TXT'
ToyVolts - toy arena shooter (Windows 64-bit)

Run ToyVolts.exe. Needs a GPU with Vulkan support (any GeForce GTX 900+/RTX, Radeon RX 400+, Intel Iris Xe or newer).
If it will not start, try ToyVolts.exe --rendering-driver d3d12

Controls: WASD move, Space jump (double jump with melee), LMB fire, RMB aim / heavy swing, R reload,
1-7 or mouse wheel or Q switch weapon, Tab scoreboard, Esc pause / settings.

Online: title screen > Online > Host (port 7777) or Join ip:port. Friends over the internet: NET.md.
Dedicated server: ToyVolts.exe --headless -- --server --port=7777 --map=diner --mode=ctb --bots=3
TXT
cp tools/NET.md build/ToyVolts/NET.md
rm -f build/ToyVolts-win64.zip
python -c "
import zipfile, os
z = zipfile.ZipFile('build/ToyVolts-win64.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=6)
for root, _, files in os.walk('build/ToyVolts'):
    for f in files:
        p = os.path.join(root, f)
        z.write(p, os.path.relpath(p, 'build'))
z.close()
print('zip', os.path.getsize('build/ToyVolts-win64.zip') // 1024 // 1024, 'MB')
"
echo "export exit=$code"
