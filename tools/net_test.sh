#!/usr/bin/env bash
# Two-process loopback smoke test: a headless host and a headless client on 127.0.0.1 play a
# Capture the Battery round on the Diner with bots. Both quit after $SECONDS_RUN seconds; the
# logs must show the handshake, the spawns, snapshots flowing and a shot from the client that
# the host confirmed. Exit code 0 = green.
#   PORT=7790 SECONDS_RUN=20 tools/net_test.sh
cd "$(dirname "$0")/.." || exit 2
PORT=${PORT:-7790}
SECONDS_RUN=${SECONDS_RUN:-22}
mkdir -p captures
rm -f captures/net_host.log captures/net_client.log

timeout $((SECONDS_RUN + 40)) ./tools/godot.sh --headless --path . -- --host --port=$PORT --map=diner --mode=ctb --bots=2 \
    --difficulty=easy --quit_after=$SECONDS_RUN > captures/net_host.log 2>&1 &
host_pid=$!
# let the host open the port and load the map before the client knocks
for i in $(seq 1 40); do
    grep -q "\[net\] hosting" captures/net_host.log 2>/dev/null && break
    sleep 0.5
done
sleep 4
timeout $((SECONDS_RUN + 40)) ./tools/godot.sh --headless --path . -- --join=127.0.0.1:$PORT --net_smoke \
    --quit_after=$((SECONDS_RUN - 6)) > captures/net_client.log 2>&1 &
client_pid=$!
wait $client_pid
wait $host_pid

fail=0
check() {
    if grep -q -- "$2" "$1"; then
        echo "PASS  $(basename "$1"): $3"
    else
        echo "FAIL  $(basename "$1"): $3   (missing /$2/)"
        fail=1
    fi
}
check captures/net_host.log   "\[net\] hosting on port $PORT"        "host opened the port"
check captures/net_host.log   "\[net\] match starting: diner ctb"     "host started the match"
check captures/net_host.log   "\[net\] peer [0-9]* registered as"     "client registered"
check captures/net_host.log   "\[net\] spawned C[0-9]* (.*) for peer" "host spawned the client's toy"
check captures/net_client.log "\[net\] connected to server as peer"   "client connected"
check captures/net_client.log "\[net\] match starting: diner ctb"     "client received the match start"
check captures/net_client.log "\[net\] spawned C[0-9]* (.*) (local)"  "client spawned its own toy"
check captures/net_client.log "\[net\] spawned C-1"                   "client sees the host's bots"
check captures/net_client.log "\[net\] first snapshot"                "snapshots flow"
check captures/net_host.log   "\[net\] hit: C[0-9]*"                  "a client shot hit on the host"
check captures/net_client.log "\[net\] hit_confirmed"                 "client got the hit confirmation"
check captures/net_host.log   "\[net\] rewind [0-9]* ticks"          "host rewound the client's shot (lag compensation)"
if grep -qE "SCRIPT ERROR|ERROR: .*rpc|Parse Error" captures/net_host.log captures/net_client.log; then
    grep -E "SCRIPT ERROR|ERROR: .*rpc|Parse Error" captures/net_host.log captures/net_client.log | head -5
    fail=1
fi

# ---- phase 2: a whole (short) match over the wire: first kill ends it, the host restarts it,
# everyone respawns; the client must see the end banner, the restart and its respawn.
PORT2=$((PORT + 1))
timeout $((SECONDS_RUN + 40)) ./tools/godot.sh --headless --path . -- --host --port=$PORT2 --map=toy_room --mode=ffa --bots=2     --difficulty=hard --score_limit=1 --quit_after=$SECONDS_RUN > captures/net_host2.log 2>&1 &
host_pid=$!
for i in $(seq 1 40); do
    grep -q "\[net\] hosting" captures/net_host2.log 2>/dev/null && break
    sleep 0.5
done
sleep 4
timeout $((SECONDS_RUN + 40)) ./tools/godot.sh --headless --path . -- --join=127.0.0.1:$PORT2 --net_smoke     --quit_after=$((SECONDS_RUN - 6)) > captures/net_client2.log 2>&1 &
client_pid=$!
wait $client_pid
wait $host_pid
check captures/net_client2.log "\[net\] spawned C[0-9]* (.*) (local)" "phase 2: client spawned"
check captures/net_client2.log "\[net\] match ended: .* WINS"        "phase 2: client saw the match end"
check captures/net_client2.log "\[net\] match restarted"             "phase 2: client saw the restart"
check captures/net_client2.log "\[net\] respawn C"                   "phase 2: client saw respawns"
check captures/net_client2.log "\[net\] fell apart C"                "phase 2: client plays the fall-apart"
if grep -qE "SCRIPT ERROR|ERROR: .*rpc|Parse Error" captures/net_host2.log captures/net_client2.log; then
    grep -E "SCRIPT ERROR|ERROR: .*rpc|Parse Error" captures/net_host2.log captures/net_client2.log | head -5
    fail=1
fi
# ---- phase 3: Lalu's birthday room over the wire: the host blows a candle, pops a balloon,
# opens a gift and bursts the pinata by itself (--party_smoke); the client must mirror every
# prop, see the five guests and get its own toy in the party.
PORT3=$((PORT + 2))
timeout $((SECONDS_RUN + 40)) ./tools/godot.sh --headless --path . -- --host --port=$PORT3 --map=lalu_party --mode=party --bots=5     --difficulty=easy --party_smoke --quit_after=$SECONDS_RUN > captures/net_host3.log 2>&1 &
host_pid=$!
for i in $(seq 1 40); do
    grep -q "\[net\] hosting" captures/net_host3.log 2>/dev/null && break
    sleep 0.5
done
sleep 4
timeout $((SECONDS_RUN + 40)) ./tools/godot.sh --headless --path . -- --join=127.0.0.1:$PORT3 --net_smoke     --quit_after=$((SECONDS_RUN - 6)) > captures/net_client3.log 2>&1 &
client_pid=$!
wait $client_pid
wait $host_pid
check captures/net_host3.log   "\[net\] match starting: lalu_party party" "phase 3: host started the party"
check captures/net_client3.log "\[net\] spawned C[0-9]* (.*) (local)"    "phase 3: client spawned at the party"
check captures/net_client3.log "\[net\] spawned C-5"                      "phase 3: client sees all five guests"
check captures/net_client3.log "\[net\] party candle 0 -> 0"              "phase 3: client mirrors the candle"
check captures/net_client3.log "\[net\] party balloon 0 -> 1"             "phase 3: client mirrors the balloon"
check captures/net_client3.log "\[net\] party gift 2 -> 1"                "phase 3: client mirrors the gift"
check captures/net_client3.log "\[net\] party pinata 0 -> 100"            "phase 3: client mirrors the pinata burst"
check captures/net_client3.log "\[net\] party kpop 0 -> 1"                "phase 3: client mirrors the K-pop show"
check captures/net_host3.log   "\[party\] smoke done"                     "phase 3: host finished its checklist run"
if grep -qE "SCRIPT ERROR|ERROR: .*rpc|Parse Error" captures/net_host3.log captures/net_client3.log; then
    grep -E "SCRIPT ERROR|ERROR: .*rpc|Parse Error" captures/net_host3.log captures/net_client3.log | head -5
    fail=1
fi
echo "net_test exit=$fail"
exit $fail
