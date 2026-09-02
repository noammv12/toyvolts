extends Node
## Sound bank + player pools. Autoload "Sfx".
##   Sfx.play("rifle_shot", pos)      positional (pool of AudioStreamPlayer3D)
##   Sfx.play_ui("hit_marker")         non-positional (HUD / local player feedback)
##   Sfx.attach_loop("rocket_loop", node)  looping emitter that follows a node

const DIRS := ["res://assets/sfx/", "res://assets/sfx/kenney/", "res://assets/sfx/party/"]
const POOL_3D := 28
const POOL_UI := 10

const GAIN := {   # per-sound dB trims
    "rifle_shot": -6.0, "shotgun_shot": -3.0, "sniper_shot": -2.0, "gatling_shot": -9.0,
    "bazooka_launch": -3.0, "grenade_launch": -5.0, "explosion": 2.0, "grenade_bounce": -8.0,
    "melee_swing": -8.0, "melee_hit": -4.0, "hit_marker": -10.0, "headshot": -8.0, "kill": -6.0,
    "death": -4.0, "reload": -8.0, "empty_click": -10.0, "vial_pickup": -6.0, "respawn": -8.0,
    "overheat": -8.0, "swap": -10.0, "hurt": -6.0, "footstep": -16.0, "ui_click": -10.0,
    "rocket_loop": -12.0, "gatling_spin": -12.0,
    "jump_a": -12.0, "jump_b": -12.0, "jump_c": -12.0, "land": -12.0, "weapon_change": -10.0,
    # party
    "balloon_pop": -4.0, "squeak": -8.0, "cheer": -6.0, "pinata_hit": -4.0, "pinata_burst": -2.0,
    "gift_open": -6.0, "boing": -8.0, "coin": -10.0, "firework_launch": -8.0, "firework_burst": -3.0,
    "candle_out": -8.0, "confetti_pop": -6.0, "party_horn": -6.0, "fanfare": -4.0,
    "woof": -1.0, "chirp": -7.0,
}

var _streams := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_i := 0
var enabled := true


func _ready() -> void:
    for dir_path in DIRS:
        var dir := DirAccess.open(dir_path)
        if dir == null:
            continue
        for f in dir.get_files():
            # Exported builds list "foo.wav.import" instead of "foo.wav" (the source
            # file is not packed, only its import remap). Strip the suffix so the
            # extension check and load() work outside the editor.
            f = f.trim_suffix(".import").trim_suffix(".remap")
            var ext := f.get_extension().to_lower()
            if ext in ["wav", "ogg", "mp3"]:
                var stream := load(dir_path + f) as AudioStream
                if stream:
                    _streams[f.get_basename()] = stream
    for i in POOL_3D:
        var p := AudioStreamPlayer3D.new()
        p.max_distance = 70.0
        p.unit_size = 6.0
        p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
        p.max_db = 3.0
        add_child(p)
        _pool.append(p)
    for i in POOL_UI:
        var p := AudioStreamPlayer.new()
        add_child(p)
        _ui_pool.append(p)


func has(name: String) -> bool:
    return _streams.has(name)


func play(name: String, pos: Vector3, volume_db := 0.0, pitch_jitter := 0.06) -> AudioStreamPlayer3D:
    if not enabled or not _streams.has(name):
        return null
    var p := _pool[_pool_i]
    _pool_i = (_pool_i + 1) % _pool.size()
    Game.trace("sfx:" + name)
    p.stop()
    p.stream = _streams[name]
    p.global_position = pos
    p.volume_db = GAIN.get(name, 0.0) + volume_db
    p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
    p.play()
    return p


func play_ui(name: String, volume_db := 0.0, pitch_jitter := 0.03) -> AudioStreamPlayer:
    if not enabled or not _streams.has(name):
        return null
    var p := _ui_pool[_ui_i]
    _ui_i = (_ui_i + 1) % _ui_pool.size()
    p.stop()
    p.stream = _streams[name]
    p.volume_db = GAIN.get(name, 0.0) + volume_db
    p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
    p.play()
    return p


## Looping emitter parented to `node`; caller frees it (or it dies with the node).
func attach_loop(name: String, node: Node3D, volume_db := 0.0) -> AudioStreamPlayer3D:
    if not enabled or not _streams.has(name):
        return null
    var p := AudioStreamPlayer3D.new()
    p.stream = _streams[name]
    p.max_distance = 50.0
    p.unit_size = 5.0
    p.volume_db = GAIN.get(name, 0.0) + volume_db
    p.autoplay = true
    node.add_child(p)
    p.play()
    p.finished.connect(p.play)   # loop regardless of stream loop flags
    return p


func pick(names: Array[String]) -> String:
    return names[randi() % names.size()]
