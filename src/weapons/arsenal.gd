class_name Arsenal
extends Node
## Owns the seven weapon slots of one Character and performs attacks.
## Controllers (player input, bot brain) only set `trigger`, `alt` and call select()/reload().

signal weapon_changed(slot: int, data: WeaponData)
signal fired(data: WeaponData)
signal hit_confirmed(killed: bool, headshot: bool)

const MASK_HIT := Character.LAYER_WORLD | Character.LAYER_CHARACTER

static var spread_scale := 1.0   ## tests set 0 for deterministic shots

var character: Character
var states: Array[WeaponState] = []
var slot := 2
var previous_slot := 1
var swap_left := 0.0
var trigger := false
var alt := false
var aiming := false

var _trigger_was := false
var _alt_was := false
var _models: Array[Node3D] = []
var _model_tween: Tween


func _ready() -> void:
    character = get_parent() as Character
    for d in WeaponDB.all():
        states.append(WeaponState.new(d))
    _build_models()
    _show_model(slot)


func current() -> WeaponState:
    return states[slot - 1]


func data() -> WeaponData:
    return current().data


func select(new_slot: int) -> void:
    if new_slot < 1 or new_slot > 7 or new_slot == slot:
        return
    current().cancel_reload()   # swap-cancel
    previous_slot = slot
    slot = new_slot
    swap_left = data().swap_time
    aiming = false
    _show_model(slot)
    weapon_changed.emit(slot, data())


func select_previous() -> void:
    select(previous_slot)


func select_offset(offset: int) -> void:
    select(wrapi(slot + offset, 1, 8))


func reload() -> void:
    current().start_reload()


func refill_all() -> void:
    for s in states:
        s.refill()


func _physics_process(delta: float) -> void:
    if character == null or not character.alive:
        trigger = false
        alt = false
    for i in states.size():
        states[i].tick(delta, trigger and i == slot - 1)
    swap_left = maxf(0.0, swap_left - delta)

    var s := current()
    var d := s.data
    aiming = alt and d.zoom_fov > 0.0 and swap_left <= 0.0
    if swap_left <= 0.0:
        var want_fire := trigger and (d.auto or not _trigger_was)
        if want_fire:
            if s.ready_to_fire():
                _fire(s)
            elif s.uses_ammo() and s.clip == 0:
                s.start_reload()
        if d.kind == WeaponData.Kind.MELEE and alt and not _alt_was and s.ready_to_fire():
            _melee(s, d.heavy_damage, d.heavy_interval, true)
    _trigger_was = trigger
    _alt_was = alt


func _fire(s: WeaponState) -> void:
    var d := s.data
    match d.kind:
        WeaponData.Kind.MELEE:
            _melee(s, d.damage, d.fire_interval, false)
        WeaponData.Kind.HITSCAN:
            s.consume_shot()
            _fire_hitscan(d)
            _recoil_model()
        WeaponData.Kind.PROJECTILE:
            s.consume_shot()
            _fire_projectile(d)
            _recoil_model()
    fired.emit(d)
    character.apply_kick(d.kick_deg)


func _fire_hitscan(d: WeaponData) -> void:
    var ray := character.get_aim_ray()
    var origin: Vector3 = ray.origin
    var base_dir: Vector3 = ray.dir
    var scoped := aiming and d.scope_overlay
    var spread := 0.0 if scoped else d.spread_deg
    var dmg_scale := d.unscoped_damage_mult if (d.scope_overlay and not scoped) else 1.0
    var muzzle := character.muzzle_position()
    var space := character.get_world_3d().direct_space_state
    for p in d.pellets:
        var dir := _apply_spread(base_dir, spread)
        var query := PhysicsRayQueryParameters3D.create(
            origin, origin + dir * d.range_m, MASK_HIT, [character.get_rid()])
        var hit := space.intersect_ray(query)
        var end := origin + dir * d.range_m
        if hit:
            end = hit.position
            var target := hit.collider as Character
            if target:
                var head := int(hit.shape) == Character.HEAD_SHAPE_INDEX
                var dist := muzzle.distance_to(hit.position)
                var dmg := d.damage * dmg_scale * _falloff(d, dist) * (d.headshot_mult if head else 1.0)
                var result := target.take_damage(dmg, character, hit.position, dir * d.knockback / d.pellets, head)
                if result.applied:
                    hit_confirmed.emit(result.killed, head)
            Vfx.impact(hit.position, hit.normal, target != null)
        Vfx.tracer(muzzle, end)
    Vfx.muzzle_flash(muzzle)


func _fire_projectile(d: WeaponData) -> void:
    var ray := character.get_aim_ray()
    var muzzle := character.muzzle_position()
    var space := character.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
        ray.origin, ray.origin + ray.dir * 200.0, MASK_HIT, [character.get_rid()])
    var hit := space.intersect_ray(query)
    var target_point: Vector3 = hit.position if hit else ray.origin + ray.dir * 200.0
    var dir: Vector3 = ray.dir
    if (target_point - ray.origin).dot(ray.dir) > 1.5:
        dir = (target_point - muzzle).normalized()
    var p := Projectile.new()
    p.setup(d, character, dir * d.projectile_speed)
    character.get_parent().add_child(p)
    p.global_position = muzzle
    Vfx.muzzle_flash(muzzle)


func _melee(s: WeaponState, dmg: float, interval: float, heavy: bool) -> void:
    s.cooldown = interval
    s.combo = 0 if heavy else (s.combo + 1) % 3
    var d := s.data
    var origin := character.center()
    var forward: Vector3 = character.get_aim_ray().dir
    for node in character.get_tree().get_nodes_in_group("characters"):
        var other := node as Character
        if other == null or other == character or not other.alive:
            continue
        var to: Vector3 = other.center() - origin
        var dist := to.length()
        if dist > d.melee_range + 0.35:
            continue
        if dist > 0.01 and rad_to_deg(forward.angle_to(to)) > d.melee_arc_deg:
            continue
        var impulse := forward * (d.knockback if heavy else d.knockback * 0.3)
        if heavy:
            impulse += Vector3.UP * 2.5
        var result := other.take_damage(dmg, character, other.center(), impulse, false)
        if result.applied:
            hit_confirmed.emit(result.killed, false)
            Vfx.impact(other.center() - forward * 0.3, -forward, true)
    _swing_model(heavy)
    if not heavy:
        fired.emit(d)


func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
    var a := deg_to_rad(spread_deg) * spread_scale
    if a <= 0.0:
        return dir
    var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
    var basis := Basis.looking_at(dir, up)
    var ang := randf() * TAU
    var r := sqrt(randf()) * a
    var local := Vector3(sin(r) * cos(ang), sin(r) * sin(ang), -cos(r))
    return (basis * local).normalized()


func _falloff(d: WeaponData, dist: float) -> float:
    if d.falloff_end <= 0.0 or d.falloff_end <= d.falloff_start:
        return 1.0
    var t := clampf((dist - d.falloff_start) / (d.falloff_end - d.falloff_start), 0.0, 1.0)
    return lerpf(1.0, d.falloff_min, t)


# ---- placeholder view models -------------------------------------------------

func _build_models() -> void:
    if character == null:
        return
    for d in WeaponDB.all():
        var m := WeaponModels.build(d)
        m.visible = false
        character.get_node("WeaponHolder").add_child(m)
        _models.append(m)


func _show_model(which: int) -> void:
    for i in _models.size():
        _models[i].visible = (i == which - 1)
    if _models.size() >= which and which >= 1:
        var m := _models[which - 1]
        m.position = Vector3(0, -0.25, 0.1)
        m.rotation = Vector3.ZERO
        _kill_tween()
        _model_tween = m.create_tween()
        _model_tween.tween_property(m, "position", Vector3.ZERO, data().swap_time) \
            .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _recoil_model() -> void:
    if _models.is_empty():
        return
    var m := _models[slot - 1]
    _kill_tween()
    m.position = Vector3(0, 0.01, 0.09)
    _model_tween = m.create_tween()
    _model_tween.tween_property(m, "position", Vector3.ZERO, 0.09).set_ease(Tween.EASE_OUT)


func _swing_model(heavy: bool) -> void:
    if _models.is_empty():
        return
    var m := _models[slot - 1]
    _kill_tween()
    m.rotation_degrees.x = 70.0 if heavy else 45.0
    _model_tween = m.create_tween()
    _model_tween.tween_property(m, "rotation_degrees:x", -25.0, 0.1 if heavy else 0.07)
    _model_tween.tween_property(m, "rotation_degrees:x", 0.0, 0.25)


func _kill_tween() -> void:
    if _model_tween and _model_tween.is_valid():
        _model_tween.kill()
