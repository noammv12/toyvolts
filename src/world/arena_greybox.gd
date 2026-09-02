extends ArenaBase
## Greybox arena at toy scale (a 1.8 m figure in a 48 m room). Flat floor, box cover, ramps.
## Used by the deterministic weapon tests; the Toy Room is the real map.

const COL_FLOOR := Color(0.88, 0.85, 0.78)
const COL_WALL := Color(0.6, 0.72, 0.86)
const COL_PLATFORM := Color(0.55, 0.8, 0.6)
const COL_RAMP := Color(0.5, 0.74, 0.56)
const COL_CRATE := Color(0.95, 0.62, 0.24)
const COL_CRATE2 := Color(0.9, 0.45, 0.3)
const COL_PILLAR := Color(0.75, 0.6, 0.9)
const COL_TABLE := Color(0.62, 0.42, 0.28)

const ROOM := 48.0
const WALL_H := 6.0


func _build() -> void:
    spawns = [
        Vector3(0, 0.2, 18), Vector3(0, 0.2, -20), Vector3(20, 0.2, 0), Vector3(-20, 0.2, 0),
        Vector3(18, 0.2, 18), Vector3(-18, 0.2, -18), Vector3(18, 0.2, -18), Vector3(-18, 0.2, 18),
    ]
    player_start = Vector3(0, 0.2, 18)
    dummy_spots = [Vector3(5, 0.2, 8), Vector3(0, 2.7, 0), Vector3(-12, 0.2, -6)]

    var half := ROOM * 0.5
    _box(Vector3(0, -0.5, 0), Vector3(ROOM, 1, ROOM), COL_FLOOR, Vector3.ZERO, true)
    _box(Vector3(0, WALL_H * 0.5, -half - 0.5), Vector3(ROOM + 2, WALL_H, 1), COL_WALL)
    _box(Vector3(0, WALL_H * 0.5, half + 0.5), Vector3(ROOM + 2, WALL_H, 1), COL_WALL)
    _box(Vector3(-half - 0.5, WALL_H * 0.5, 0), Vector3(1, WALL_H, ROOM + 2), COL_WALL)
    _box(Vector3(half + 0.5, WALL_H * 0.5, 0), Vector3(1, WALL_H, ROOM + 2), COL_WALL)

    _box(Vector3(0, 1.25, 0), Vector3(8, 2.5, 8), COL_PLATFORM)
    var angle := atan(2.5 / 6.0)
    var ramp_len := sqrt(2.5 * 2.5 + 6.0 * 6.0) + 0.4
    _box(Vector3(7.0, 1.25 - 0.2, 0), Vector3(ramp_len, 0.4, 4), COL_RAMP, Vector3(0, 0, -angle))
    _box(Vector3(-7.0, 1.25 - 0.2, 0), Vector3(ramp_len, 0.4, 4), COL_RAMP, Vector3(0, 0, angle))

    for c in [
        Vector3(10, 1, 10), Vector3(12, 1, 10), Vector3(11, 3, 10),
        Vector3(-10, 1, -10), Vector3(-12, 1, -10), Vector3(-11, 3, -10),
        Vector3(14, 1, -14), Vector3(-14, 1, 14),
    ]:
        _box(c, Vector3(2, 2, 2), COL_CRATE)
    for c in [
        Vector3(6, 0.5, 14), Vector3(7, 0.5, 14), Vector3(6.5, 1.5, 14),
        Vector3(-6, 0.5, -14), Vector3(-7, 0.5, -14),
        Vector3(16, 0.5, 2), Vector3(-16, 0.5, -2),
    ]:
        _box(c, Vector3(1, 1, 1), COL_CRATE2)

    for p in [Vector3(16, 0, 16), Vector3(-16, 0, 16), Vector3(16, 0, -16), Vector3(-16, 0, -16)]:
        _box(p + Vector3(0, 2.5, 0), Vector3(1.5, 5, 1.5), COL_PILLAR)

    var table := Vector3(0, 0, -16)
    _box(table + Vector3(0, 3.2, 0), Vector3(10, 0.6, 6), COL_TABLE)
    for leg in [Vector3(4.5, 0, 2.5), Vector3(-4.5, 0, 2.5), Vector3(4.5, 0, -2.5), Vector3(-4.5, 0, -2.5)]:
        _box(table + leg + Vector3(0, 1.45, 0), Vector3(0.6, 2.9, 0.6), COL_TABLE)
    _box(table + Vector3(7.0, 0.5, 0), Vector3(2, 1, 2), COL_CRATE)
    _box(table + Vector3(9.0, 1.0, 0), Vector3(2, 2, 2), COL_CRATE)
    _box(table + Vector3(11.0, 1.5, 0), Vector3(2, 3, 2), COL_CRATE)
