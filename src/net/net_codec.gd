class_name NetCodec
extends RefCounted
## Byte packing for the two hot packets: a client's input tick (client -> server, 60 Hz) and the
## server's world snapshot (server -> clients, 60 Hz). Pure functions, unit-tested headless.
##
## Input (48 bytes): seq u32, yaw f32, pitch f32, wish x/z i8 (x127), buttons u8
## (1 trigger, 2 alt, 4 jump held, 8 crouch), jump_seq u8, select_seq u8, select a/b u8
## (0 = none), reload_seq u8, aim origin f32 x3, aim dir f32 x3, view_tick u32 (the server
## tick the client was rendering: lag compensation rewinds hitboxes to it).
## Snapshot: tick u32, time_left f32, count u8, then per toy (47 bytes): net_id i32,
## pos f32 x3, vel f32 x3, yaw f32, pitch f32, slot u8, hp u8, flags u8 (1 alive, 2 on floor,
## 4 carrying, 8|16 scope level, 32 aiming), clip u8, reserve u16, ack_seq u32, jumps_used u8.

const FLAG_TRIGGER := 1
const FLAG_ALT := 2
const FLAG_JUMP := 4
const FLAG_CROUCH := 8

const SNAP_ALIVE := 1
const SNAP_FLOOR := 2
const SNAP_CARRYING := 4
const SNAP_SCOPE_SHIFT := 3      ## bits 3-4
const SNAP_AIMING := 32
const SNAP_CROUCH := 64


static func encode_input(i: Dictionary) -> PackedByteArray:
    var b := StreamPeerBuffer.new()
    b.put_u32(int(i.seq))
    b.put_float(i.yaw)
    b.put_float(i.pitch)
    var wish: Vector3 = i.wish
    b.put_8(int(roundf(clampf(wish.x, -1.0, 1.0) * 127.0)))
    b.put_8(int(roundf(clampf(wish.z, -1.0, 1.0) * 127.0)))
    var flags := 0
    if i.trigger:
        flags |= FLAG_TRIGGER
    if i.alt:
        flags |= FLAG_ALT
    if i.get("jump", false):
        flags |= FLAG_JUMP
    if i.get("crouch", false):
        flags |= FLAG_CROUCH
    b.put_u8(flags)
    b.put_u8(int(i.jump_seq) & 0xFF)
    b.put_u8(int(i.select_seq) & 0xFF)
    b.put_u8(int(i.get("select_a", 0)))
    b.put_u8(int(i.get("select_b", 0)))
    b.put_u8(int(i.reload_seq) & 0xFF)
    var o: Vector3 = i.aim_origin
    var d: Vector3 = i.aim_dir
    for v in [o.x, o.y, o.z, d.x, d.y, d.z]:
        b.put_float(v)
    b.put_u32(int(i.get("view_tick", 0)))
    return b.data_array


static func decode_input(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() < 48:
        return {}
    var b := StreamPeerBuffer.new()
    b.data_array = bytes
    var out := {}
    out.seq = b.get_u32()
    out.yaw = b.get_float()
    out.pitch = b.get_float()
    var wx := b.get_8() / 127.0
    var wz := b.get_8() / 127.0
    out.wish = Vector3(wx, 0.0, wz)
    var flags := b.get_u8()
    out.trigger = (flags & FLAG_TRIGGER) != 0
    out.alt = (flags & FLAG_ALT) != 0
    out.jump = (flags & FLAG_JUMP) != 0
    out.crouch = (flags & FLAG_CROUCH) != 0
    out.jump_seq = b.get_u8()
    out.select_seq = b.get_u8()
    out.select_a = b.get_u8()
    out.select_b = b.get_u8()
    out.reload_seq = b.get_u8()
    out.aim_origin = Vector3(b.get_float(), b.get_float(), b.get_float())
    out.aim_dir = Vector3(b.get_float(), b.get_float(), b.get_float())
    out.view_tick = b.get_u32()
    return out


## `toys`: Array of Dictionaries {net_id, pos, vel, yaw, pitch, slot, hp, alive, on_floor,
## carrying, scope, aiming, clip, reserve, ack_seq, jumps_used}.
static func encode_snapshot(tick: int, time_left: float, toys: Array) -> PackedByteArray:
    var b := StreamPeerBuffer.new()
    b.put_u32(tick)
    b.put_float(time_left)
    b.put_u8(mini(toys.size(), 255))
    for t in toys.slice(0, 255):
        b.put_32(int(t.net_id))
        var p: Vector3 = t.pos
        var v: Vector3 = t.vel
        for f in [p.x, p.y, p.z, v.x, v.y, v.z, t.yaw, t.pitch]:
            b.put_float(f)
        b.put_u8(int(t.slot))
        b.put_u8(clampi(int(ceil(t.hp)), 0, 255))
        var flags := 0
        if t.alive:
            flags |= SNAP_ALIVE
        if t.on_floor:
            flags |= SNAP_FLOOR
        if t.carrying:
            flags |= SNAP_CARRYING
        flags |= (clampi(int(t.scope), 0, 3) << SNAP_SCOPE_SHIFT)
        if t.aiming:
            flags |= SNAP_AIMING
        if t.get("crouch", false):
            flags |= SNAP_CROUCH
        b.put_u8(flags)
        b.put_u8(clampi(int(t.clip), 0, 255))
        b.put_u16(clampi(int(t.reserve), 0, 65535))
        b.put_u32(int(t.ack_seq))
        b.put_u8(clampi(int(t.jumps_used), 0, 255))
    return b.data_array


static func decode_snapshot(bytes: PackedByteArray) -> Dictionary:
    if bytes.size() < 9:
        return {}
    var b := StreamPeerBuffer.new()
    b.data_array = bytes
    var out := {}
    out.tick = b.get_u32()
    out.time_left = b.get_float()
    var n := b.get_u8()
    if bytes.size() < 9 + n * 47:
        return {}
    var toys: Array = []
    for i in n:
        var t := {}
        t.net_id = b.get_32()
        t.pos = Vector3(b.get_float(), b.get_float(), b.get_float())
        t.vel = Vector3(b.get_float(), b.get_float(), b.get_float())
        t.yaw = b.get_float()
        t.pitch = b.get_float()
        t.slot = b.get_u8()
        t.hp = float(b.get_u8())
        var flags := b.get_u8()
        t.alive = (flags & SNAP_ALIVE) != 0
        t.on_floor = (flags & SNAP_FLOOR) != 0
        t.carrying = (flags & SNAP_CARRYING) != 0
        t.scope = (flags >> SNAP_SCOPE_SHIFT) & 3
        t.aiming = (flags & SNAP_AIMING) != 0
        t.crouch = (flags & SNAP_CROUCH) != 0
        t.clip = b.get_u8()
        t.reserve = b.get_u16()
        t.ack_seq = b.get_u32()
        t.jumps_used = b.get_u8()
        toys.append(t)
    out.toys = toys
    return out
