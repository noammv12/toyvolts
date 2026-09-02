class_name NetHistory
extends RefCounted
## Lag compensation: the host keeps the last TICKS server ticks of one toy's hitbox pose
## (position, yaw, crouch) so a client's hitscan shot can be judged against the world that
## client was looking at when it fired. Pure data, unit-tested headless.

const TICKS := 15
const MAX_REWIND_TICKS := 12    ## 200 ms at 60 Hz: older views are clamped, not honoured

var _entries: Array = []        ## [tick, pos, yaw, crouch] ascending


func record(tick: int, pos: Vector3, yaw: float, crouch: bool) -> void:
    if not _entries.is_empty() and tick <= _entries[-1][0]:
        return
    _entries.append([tick, pos, yaw, crouch])
    while _entries.size() > TICKS:
        _entries.pop_front()


func size() -> int:
    return _entries.size()


func oldest_tick() -> int:
    return _entries[0][0] if not _entries.is_empty() else -1


func newest_tick() -> int:
    return _entries[-1][0] if not _entries.is_empty() else -1


## The pose at `tick` (nearest recorded tick, clamped to the ring). Empty if nothing recorded.
func at(tick: int) -> Dictionary:
    if _entries.is_empty():
        return {}
    var best: Array = _entries[0]
    for e in _entries:
        if absi(e[0] - tick) < absi(best[0] - tick):
            best = e
    return {"tick": best[0], "pos": best[1], "yaw": best[2], "crouch": best[3]}


## Which tick the host rewinds to for a shooter that saw the world at `view_tick` while the
## host is at `now`: never further back than MAX_REWIND_TICKS, never into the future.
static func rewind_tick(view_tick: int, now: int) -> int:
    return clampi(view_tick, now - MAX_REWIND_TICKS, now)
