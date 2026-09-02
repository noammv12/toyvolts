class_name NetInterp
extends RefCounted
## Snapshot history for one remote toy plus the render clock that walks through it. Puppets are
## drawn DELAY_TICKS behind the newest snapshot so there are always two samples to blend;
## when packets stall we extrapolate at most MAX_EXTRAPOLATE ticks, then hold.

const DELAY_TICKS := 5.0        ## ~83 ms at 60 Hz
const MAX_EXTRAPOLATE := 3.0
const MAX_HISTORY := 40
const RESYNC_TICKS := 10.0      ## clock error beyond this snaps instead of easing

var render_tick := -1.0
var _samples: Array = []        ## [tick, state] ascending


func push(tick: int, state: Dictionary) -> void:
    if not _samples.is_empty() and tick <= _samples[-1][0]:
        return   # late or duplicate packet
    _samples.append([tick, state])
    while _samples.size() > MAX_HISTORY:
        _samples.pop_front()


func has_samples() -> bool:
    return not _samples.is_empty()


func latest_tick() -> int:
    return _samples[-1][0] if not _samples.is_empty() else -1


func latest_state() -> Dictionary:
    return _samples[-1][1] if not _samples.is_empty() else {}


## Move the render clock by `delta_ticks`, easing toward (latest - DELAY_TICKS).
func advance(delta_ticks: float) -> void:
    if _samples.is_empty():
        return
    var target := float(latest_tick()) - DELAY_TICKS
    if render_tick < 0.0 or absf(target - render_tick) > RESYNC_TICKS:
        render_tick = target
    else:
        render_tick += delta_ticks
        render_tick += (target - render_tick) * 0.08
    render_tick = clampf(render_tick, float(_samples[0][0]), float(latest_tick()) + MAX_EXTRAPOLATE)


## The blended state at the render clock.
func sample() -> Dictionary:
    return sample_at(render_tick)


func sample_at(t: float) -> Dictionary:
    if _samples.is_empty():
        return {}
    if _samples.size() == 1 or t <= _samples[0][0]:
        return _samples[0][1].duplicate()
    var last: Array = _samples[-1]
    if t >= last[0]:
        # extrapolate along the last velocity, discrete fields from the last sample
        var s: Dictionary = last[1].duplicate()
        var over := minf(t - last[0], MAX_EXTRAPOLATE) / 60.0
        s.pos = last[1].pos + last[1].vel * over
        return s
    for i in range(_samples.size() - 1):
        var a: Array = _samples[i]
        var b: Array = _samples[i + 1]
        if t >= a[0] and t <= b[0]:
            var span := float(b[0] - a[0])
            var f: float = 0.0 if span <= 0.0 else (t - a[0]) / span
            return lerp_state(a[1], b[1], f)
    return last[1].duplicate()


static func lerp_state(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
    var s: Dictionary = b.duplicate()      # discrete fields from the later sample
    s.pos = a.pos.lerp(b.pos, f)
    s.vel = a.vel.lerp(b.vel, f)
    s.yaw = lerp_angle(a.yaw, b.yaw, f)
    s.pitch = lerpf(a.pitch, b.pitch, f)
    return s
