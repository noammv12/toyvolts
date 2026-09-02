class_name PartyManager
extends Node
## The birthday room's brain: owns the checklist (candles, balloons, pinata, gifts), the
## effects node, the music, the finale and the reset, and mirrors every prop through Net
## events (index-based, like capsules) so friends who join see the same party.

signal changed()
signal finale_started()
signal reset_done()

const FINALE_SECONDS := 15.0
const PINATA_CAPSULE_BASE := 60

var candles: Array[PartyCandle] = []
var balloons: Array[PartyBalloon] = []
var gifts: Array[PartyGift] = []
var pinata: PartyPinata
var cannons: Array[PartyCannon] = []
var fx: PartyFx
var cake_top := Vector3(0, 5.6, 0)
var corners: Array[Vector3] = []
var finale_active := false
var finale_seconds := FINALE_SECONDS
var finales := 0
var music: AudioStreamPlayer
var _capsules: Array[ItemCapsule] = []
var _finale_serial := 0


func _ready() -> void:
    add_to_group("party")
    fx = PartyFx.new()
    fx.name = "Fx"
    add_child(fx)
    var stream := Sfx._streams.get("party_theme") as AudioStreamWAV
    if stream != null:
        var loop := stream.duplicate() as AudioStreamWAV
        loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
        loop.loop_begin = 0
        loop.loop_end = loop.data.size() / 2
        music = AudioStreamPlayer.new()
        music.stream = loop
        music.volume_db = -11.0
        music.autoplay = false
        add_child(music)
        if not Game.headless:
            music.play()


# ---- registration (the map calls these while it builds) -------------------------------

func add_candle(c: PartyCandle) -> void:
    c.index = candles.size()
    candles.append(c)
    c.blown_out.connect(_on_candle)


func add_balloon(b: PartyBalloon) -> void:
    b.index = balloons.size()
    balloons.append(b)
    b.popped.connect(_on_balloon)


func add_gift(g: PartyGift) -> void:
    g.index = gifts.size()
    gifts.append(g)
    g.opened.connect(_on_gift)


func set_pinata(p: PartyPinata) -> void:
    pinata = p
    p.hit.connect(_on_pinata_hit)
    p.burst.connect(_on_pinata_burst)


func add_cannon(c: PartyCannon) -> void:
    c.index = cannons.size()
    cannons.append(c)


# ---- checklist ------------------------------------------------------------------------

func counts() -> Dictionary:
    var out := 0
    for c in candles:
        if not c.lit:
            out += 1
    var popped := 0
    for b in balloons:
        if b.is_popped:
            popped += 1
    var opened := 0
    for g in gifts:
        if g.is_open:
            opened += 1
    var pin_burst := pinata != null and pinata.is_burst
    return {"candles": out, "candles_total": candles.size(), "balloons": popped, "balloons_total": balloons.size(),
        "pinata": pin_burst, "pinata_hits": pinata.hits if pinata != null else 0,
        "pinata_total": PartyPinata.HITS_TO_BURST, "gifts": opened, "gifts_total": gifts.size(),
        "done": out == candles.size() and popped == balloons.size() and pin_burst and opened == gifts.size()
            and not candles.is_empty()}


func status_line() -> String:
    var c := counts()
    return "PARTY   candles %d/%d   |   balloons %d/%d   |   pinata %s   |   gifts %d/%d" % [
        c.candles, c.candles_total, c.balloons, c.balloons_total,
        "done" if c.pinata else "%d/%d" % [c.pinata_hits, c.pinata_total], c.gifts, c.gifts_total]


func _on_candle(c: PartyCandle) -> void:
    Net.party_event("candle", c.index, 0, 0, Vector3.ZERO)
    _after_change()


func _on_balloon(b: PartyBalloon) -> void:
    Net.party_event("balloon", b.index, 1, 0, Vector3.ZERO)
    _after_change()


func _on_pinata_hit(p: PartyPinata, hits: int) -> void:
    if not p.is_burst:
        Net.party_event("pinata", 0, hits, 0, Vector3(p._vel.y, 0.0, -p._vel.x).normalized())
    changed.emit()


func _on_pinata_burst(p: PartyPinata) -> void:
    Net.party_event("pinata", 0, 100, 0, Vector3.ZERO)
    _spawn_pinata_capsules(p.body_position())
    _after_change()


func _on_gift(g: PartyGift, by: Character) -> void:
    Net.party_event("gift", g.index, 1, Net._id_of(by), Vector3.ZERO)
    _after_change()


func _after_change() -> void:
    changed.emit()
    if Net.is_authority() and Game.mode == "party" and not finale_active and counts().done:
        Net.party_event("finale", 0, 1, 0, Vector3.ZERO)
        start_finale()


## The pinata's candy includes real item capsules (same spots on every peer).
func _spawn_pinata_capsules(at: Vector3) -> void:
    var offsets := [Vector3(2.5, 0, 1.5), Vector3(-2.5, 0, 1.5), Vector3(1.5, 0, -2.5), Vector3(-1.5, 0, -2.5)]
    for i in offsets.size():
        var cap := ItemCapsule.new()
        cap.net_index = PINATA_CAPSULE_BASE + i
        cap.kind = "health" if i % 2 == 0 else "ammo"
        cap.position = Vector3(at.x, 0.3, at.z) + offsets[i]
        get_parent().add_child(cap)
        _capsules.append(cap)


# ---- finale ----------------------------------------------------------------------------

func start_finale() -> void:
    if finale_active:
        return
    finale_active = true
    finales += 1
    _finale_serial += 1
    var serial := _finale_serial
    finale_started.emit()
    Sfx.play_ui("fanfare", 0.0, 0.0)
    Sfx.play_ui("party_horn", -4.0, 0.05)
    Sfx.play("cheer", cake_top, 2.0, 0.05)
    fx.storm(cake_top, true)
    for node in get_tree().get_nodes_in_group("bots"):
        if node.has_method("party_cheer"):
            node.party_cheer(finale_seconds - 1.0)
    var lp := Game.local_player()
    if lp != null and lp.controller is PlayerController:
        lp.controller.cinematic(Vector3(cake_top.x, cake_top.y - 2.0, cake_top.z), finale_seconds - 1.5)
    _fireworks_show(serial)
    _end_finale_later(serial)


func _fireworks_show(serial: int) -> void:
    var spots: Array[Vector3] = corners.duplicate()
    spots.append(cake_top)
    var shots := int(finale_seconds * 1.4)
    for i in shots:
        await get_tree().create_timer(0.55, false).timeout
        if serial != _finale_serial or not is_inside_tree():
            return
        fx.firework(spots[i % spots.size()], PartyText.color(i))
        if i % 4 == 3:
            fx.confetti(cake_top + Vector3(0, 1.0, 0), Vector3.UP, 80.0, 120)


func _end_finale_later(serial: int) -> void:
    await get_tree().create_timer(finale_seconds, false).timeout
    if serial != _finale_serial or not is_inside_tree():
        return
    fx.storm(cake_top, false)
    if Net.is_authority():
        Net.party_event("reset", 0, 0, 0, Vector3.ZERO)
        reset_all()


func reset_all() -> void:
    _finale_serial += 1
    fx.storm(cake_top, false)
    for c in candles:
        c.set_lit(true, false)
    for b in balloons:
        b.inflate(false)
    if pinata != null:
        pinata.restore()
    for g in gifts:
        g.close()
    for cap in _capsules:
        if is_instance_valid(cap):
            cap.queue_free()
    _capsules.clear()
    finale_active = false
    Sfx.play("respawn", cake_top, 0.0, 0.0)
    fx.sparkle(cake_top)
    changed.emit()
    reset_done.emit()


# ---- network mirror ---------------------------------------------------------------------

## Client side: the host says a prop changed.
func apply_remote(kind: String, index: int, state: int, who: Character, pos: Vector3) -> void:
    match kind:
        "candle":
            if index >= 0 and index < candles.size():
                candles[index].set_lit(state == 1, true)
        "balloon":
            if index >= 0 and index < balloons.size():
                if state == 1:
                    balloons[index].pop(true)
                else:
                    balloons[index].inflate(true)
        "pinata":
            if pinata == null:
                return
            if state >= 100:
                if not pinata.is_burst:
                    pinata.do_burst(true)
                    _spawn_pinata_capsules(pinata.body_position())
            else:
                pinata.apply_hits(state, pos)
        "gift":
            if index >= 0 and index < gifts.size():
                if state == 1:
                    gifts[index].open_by(who, true)
                else:
                    gifts[index].close()
        "finale":
            start_finale()
        "reset":
            reset_all()
    print("[net] party %s %d -> %d" % [kind, index, state])
    changed.emit()


## Everything a late joiner needs, as _ev_party argument lists.
func remote_states() -> Array:
    var out: Array = []
    for c in candles:
        if not c.lit:
            out.append(["candle", c.index, 0, 0, Vector3.ZERO])
    for b in balloons:
        if b.is_popped:
            out.append(["balloon", b.index, 1, 0, Vector3.ZERO])
    if pinata != null:
        if pinata.is_burst:
            out.append(["pinata", 0, 100, 0, Vector3.ZERO])
        elif pinata.hits > 0:
            out.append(["pinata", 0, pinata.hits, 0, Vector3.ZERO])
    for g in gifts:
        if g.is_open:
            out.append(["gift", g.index, 1, Net._id_of(g.opener), Vector3.ZERO])
    if finale_active:
        out.append(["finale", 0, 1, 0, Vector3.ZERO])
    return out


## `--party_finish`: complete the whole checklist after a moment (finale captures).
func finish_all() -> void:
    await get_tree().create_timer(1.5, false).timeout
    if not is_inside_tree():
        return
    var who := Game.local_player()
    for c in candles:
        c.on_shot(who, c.flame_position(), Vector3.FORWARD, null)
    for b in balloons:
        b.on_shot(who, b.global_position, Vector3.FORWARD, null)
    for g in gifts:
        g.open_by(who, true)
    for i in PartyPinata.HITS_TO_BURST:
        pinata.on_shot(who, pinata.body_position(), Vector3(1, 0, 0), null)


## `--party_smoke`: the host works through the checklist by itself (loopback test).
func smoke() -> void:
    await get_tree().create_timer(3.0, false).timeout
    if not is_inside_tree():
        return
    candles[0].on_shot(null, candles[0].flame_position(), Vector3.FORWARD, null)
    await get_tree().create_timer(1.0, false).timeout
    balloons[0].on_shot(null, balloons[0].global_position, Vector3.FORWARD, null)
    await get_tree().create_timer(1.0, false).timeout
    gifts[2].open_by(Game.local_player(), true)
    for i in PartyPinata.HITS_TO_BURST:
        await get_tree().create_timer(0.3, false).timeout
        if not is_inside_tree():
            return
        pinata.on_shot(null, pinata.body_position(), Vector3(1, 0, 0), null)
    print("[party] smoke done: %s" % status_line())
