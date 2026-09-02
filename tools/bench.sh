#!/usr/bin/env bash
# Frame-time benchmark per quality preset (needs a window: not headless).
# Usage: tools/bench.sh [low medium high] [-- extra godot user args, e.g. --scale=0.66]
#   GODOT_ARGS="--gpu-index 1" tools/bench.sh low   # engine args (pick the iGPU on a hybrid laptop)
cd "$(dirname "$0")/.." || exit 2
presets=()
extra=()
while [ $# -gt 0 ]; do
    if [ "$1" = "--" ]; then shift; extra=("$@"); break; fi
    presets+=("$1"); shift
done
[ ${#presets[@]} -eq 0 ] && presets=(low medium high)
mkdir -p captures
printf "%-8s %-9s %-9s %-9s %-6s %-9s %-9s\n" preset avg p99 max fps gpu cpu
for q in "${presets[@]}"; do
    timeout 120 ./tools/godot.sh $GODOT_ARGS --path . -- --bench --quality="$q" --mode=ffa --bots=5 "${extra[@]}" > "captures/bench_$q.log" 2>&1
    line=$(grep "\[bench\] total" "captures/bench_$q.log")
    if [ -z "$line" ]; then echo "$q: no result (see captures/bench_$q.log)"; continue; fi
    avg=$(echo "$line" | sed -E 's/.*avg= *([0-9.]+)ms.*/\1/')
    p99=$(echo "$line" | sed -E 's/.*p99= *([0-9.]+)ms.*/\1/')
    mx=$(echo "$line" | sed -E 's/.*max= *([0-9.]+)ms.*/\1/')
    fps=$(echo "$line" | sed -E 's/.*fps= *([0-9]+).*/\1/')
    gpu=$(echo "$line" | sed -E 's/.*gpu= *([0-9.]+)ms.*/\1/')
    cpu=$(echo "$line" | sed -E 's/.*cpu= *([0-9.]+)ms.*/\1/')
    printf "%-8s %-9s %-9s %-9s %-6s %-9s %-9s\n" "$q" "${avg}ms" "${p99}ms" "${mx}ms" "$fps" "${gpu}ms" "${cpu}ms"
    grep "\[bench\] setup" "captures/bench_$q.log" | sed 's/\[bench\] setup/         /'
    grep "\[bench\] total" "captures/bench_$q.log" | sed -E 's/.*hitches=([0-9]+).*/          hitches=\1 (frames over 33 ms)/'
done
