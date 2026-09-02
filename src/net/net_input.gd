class_name NetInput
extends RefCounted
## Server-side controller for a remote human's Character: a small jitter buffer of decoded input
## packets, one consumed per physics tick (two when we fall behind, the last one repeated when
## starved). Discrete actions travel as counters so a lost packet cannot eat a jump or a swap.

const MAX_QUEUE := 6
const CATCH_UP_ABOVE := 3

var queue: Array = []
var last: Dictionary = {}
var last_seq := 0           ## seq of the newest input applied (acked in snapshots)
var packets := 0
var _newest_pushed := -1
var _jump_seq := -1
var _select_seq := -1
var _reload_seq := -1
var _primed := false


func push(i: Dictionary) -> void:
    if i.is_empty():
        return
    if _newest_pushed >= 0 and int(i.seq) <= _newest_pushed:
        return   # out of order / duplicate
    _newest_pushed = int(i.seq)
    packets += 1
    queue.append(i)
    while queue.size() > MAX_QUEUE:
        queue.pop_front()


## Character hook: apply this tick's input.
func feed(c: Character, _delta: float) -> void:
    var n := 2 if queue.size() > CATCH_UP_ABOVE else 1
    var i: Dictionary = last
    for k in n:
        if not queue.is_empty():
            var next: Dictionary = queue.pop_front()
            if k > 0:
                _apply(c, next)   # catching up: apply the skipped one too so its edges count
            i = next
    if i.is_empty():
        return
    _apply(c, i)
    last = i


func _apply(c: Character, i: Dictionary) -> void:
    last_seq = int(i.seq)
    if not _primed:
        # first packet: adopt the counters without firing the edges they encode
        _primed = true
        _jump_seq = int(i.jump_seq)
        _select_seq = int(i.select_seq)
        _reload_seq = int(i.reload_seq)
    c.yaw = i.yaw
    c.pitch = i.pitch
    c.set_aim_ray(i.aim_origin, i.aim_dir)
    if not c.alive:
        c.wish_dir = Vector3.ZERO
        c.arsenal.trigger = false
        c.arsenal.alt = false
        _jump_seq = int(i.jump_seq)
        _select_seq = int(i.select_seq)
        _reload_seq = int(i.reload_seq)
        return
    c.wish_dir = (i.wish as Vector3).limit_length(1.0)
    c.arsenal.trigger = i.trigger
    c.arsenal.alt = i.alt
    if int(i.jump_seq) != _jump_seq:
        _jump_seq = int(i.jump_seq)
        c.jump_pressed = true
    if int(i.select_seq) != _select_seq:
        _select_seq = int(i.select_seq)
        for arg in [int(i.select_a), int(i.select_b)]:
            if arg >= 1 and arg <= 7:
                c.arsenal.select(arg)
    if int(i.reload_seq) != _reload_seq:
        _reload_seq = int(i.reload_seq)
        c.arsenal.reload()
