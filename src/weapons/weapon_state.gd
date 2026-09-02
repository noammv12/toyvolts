class_name WeaponState
extends RefCounted
## Runtime state of one weapon slot: ammo, cooldown, reload, spin-up, heat.
## Pure logic (no nodes) so it is unit-testable headless.

var data: WeaponData
var clip := 0
var reserve := 0
var cooldown := 0.0         ## seconds until the next shot is allowed
var reload_left := 0.0      ## > 0 while reloading
var spin := 0.0             ## 0..1 gatling barrel spin
var heat := 0.0             ## 0..1, overheats at 1
var overheated := false
var combo := 0              ## melee light-attack combo index (0 horizontal, 1 upward, 2 overhead)
var combo_left := 0.0       ## seconds until the combo drops back to the first swing
var holstered := 0.0        ## seconds this weapon has been out of the hand (auto-reload timer)

## A weapon you are not holding reloads itself from reserve, taking this many times its hand
## reload. Slow enough that swapping to reload is still a choice, not a free trick.
const HOLSTER_RELOAD := 1.5


func _init(weapon: WeaponData) -> void:
    data = weapon
    refill()


func refill() -> void:
    clip = data.clip_size
    reserve = data.reserve
    reload_left = 0.0
    heat = 0.0
    overheated = false
    spin = 0.0
    cooldown = 0.0
    combo = 0
    combo_left = 0.0
    holstered = 0.0


## `in_hand` false = holstered: the clip tops itself up from reserve after HOLSTER_RELOAD x
## reload_time out of the hand (no animation, no sound: it just is full when you come back).
func tick(delta: float, trigger_held: bool, in_hand := true) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    if in_hand:
        holstered = 0.0
    else:
        holstered += delta
        if holstered >= data.reload_time * HOLSTER_RELOAD and can_reload():
            _finish_reload()
            holstered = 0.0
    if combo_left > 0.0:
        combo_left -= delta
        if combo_left <= 0.0:
            combo = 0
    if reload_left > 0.0:
        reload_left -= delta
        if reload_left <= 0.0:
            _finish_reload()
    if data.spin_up > 0.0:
        var target := 1.0 if (trigger_held and not overheated and not is_reloading()) else 0.0
        spin = move_toward(spin, target, delta / data.spin_up)
    if data.heat_per_shot > 0.0 and (not trigger_held or overheated):
        heat = maxf(0.0, heat - data.heat_cool_per_s * delta)
        if overheated and heat <= 0.35:
            overheated = false


func is_reloading() -> bool:
    return reload_left > 0.0


func uses_ammo() -> bool:
    return data.clip_size > 0


func has_ammo() -> bool:
    return not uses_ammo() or clip > 0


func ready_to_fire() -> bool:
    if cooldown > 0.0 or is_reloading() or overheated:
        return false
    if data.spin_up > 0.0 and spin < 0.999:
        return false
    return has_ammo()


func consume_shot() -> void:
    cooldown = data.fire_interval
    if uses_ammo():
        clip -= 1
    if data.heat_per_shot > 0.0:
        heat += data.heat_per_shot
        if heat >= 1.0:
            heat = 1.0
            overheated = true


func can_reload() -> bool:
    return uses_ammo() and clip < data.clip_size and reserve > 0 and not is_reloading()


func start_reload() -> bool:
    if not can_reload():
        return false
    reload_left = data.reload_time
    return true


## Swap-cancel: leaving the weapon mid-reload drops the reload without refunding time.
func cancel_reload() -> void:
    reload_left = 0.0


func reload_progress() -> float:
    if not is_reloading():
        return 0.0
    return 1.0 - reload_left / data.reload_time


func _finish_reload() -> void:
    var need := data.clip_size - clip
    var take := mini(need, reserve)
    clip += take
    reserve -= take
    reload_left = 0.0
