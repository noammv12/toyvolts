class_name Arsenal
extends Node
## Owns the seven weapon slots of one Character and performs attacks.
## Controllers (player input, bot brain) only set `trigger`, `alt` and call select()/reload().
## Draws are short and presses during a draw are buffered: fire / alt pressed while the weapon
## comes up execute the tick it is up; a select mid-draw retargets the draw instantly.

signal weapon_changed(slot: int, data: WeaponData)
signal fired(data: WeaponData)
signal hit_confirmed(killed: bool, headshot: bool)
signal melee_swung(heavy: bool)
signal reload_started()

const MASK_HIT := Character.LAYER_WORLD | Character.LAYER_CHARACTER | Character.LAYER_TARGET
const SHOT_SOUND := {2: "rifle_shot", 3: "shotgun_shot", 4: "sniper_shot", 5: "gatling_shot",
    6: "bazooka_launch", 7: "grenade_launch"}
const FLASH_SIZE := {2: 0.7, 3: 1.1, 4: 0.9, 5: 0.6, 6: 1.3, 7: 0.8}
const WEAPON_SCALE := 1.3   ## toy guns are oversized (and it keeps them visible past the big head)
const READY_EPS := 0.0005    ## draw countdown snaps to 0 below this (60 Hz float drift)
const LOWER_TIME := 0.07     ## the outgoing weapon drops for this long before the new one rises
const ARC_TILT_DEG := 65.0   ## how far the muzzle points down at the bottom of the arc
const ARC_DROP := 0.32       ## metres the model sits below the grip at the bottom of the arc

static var spread_scale := 1.0   ## tests set 0 for deterministic shots

var character: Character
var cosmetic := false            ## client: play every effect, apply no damage (the server does)
var states: Array[WeaponState] = []
var slot := 2
var previous_slot := 1
var swap_left := 0.0
var trigger := false
var alt := false
var aiming := false
var scope_level := 0             ## sniper: 0 off, 1 = zoom_fov, 2 = zoom_fov / 2

var _trigger_was := false
var _alt_was := false
var _buffer_fire := false        ## trigger pressed during the draw: fires the tick the draw ends
var _buffer_alt := false
var _models: Array[Node3D] = []
var _model_tween: Tween
var _spin_was := false
var _outgoing := -1              ## slot whose model is still lowering (first LOWER_TIME of a draw)
var _arc_active := false


func _ready() -> void:
    character = get_parent() as Character
    for d in WeaponDB.all():
        states.append(WeaponState.new(d))
    # the Figure (a sibling) builds its rig in the Character's _ready, after ours: defer
    _build_models.call_deferred()
    _show_model.call_deferred(slot)


func _figure() -> Figure:
    return character.get_node_or_null("Figure") as Figure


func current() -> WeaponState:
    return states[slot - 1]


func data() -> WeaponData:
    return current().data


func select(new_slot: int) -> void:
    if new_slot < 1 or new_slot > 7 or new_slot == slot:
        return
    current().cancel_reload()   # swap-cancel: reload AND recovery are dropped
    current().cooldown = 0.0    # (Microvolts: fire, swap out, swap back = faster than the fire interval)
    Game.trace("select:%d" % new_slot)
    _outgoing = slot if swap_left <= 0.0 else -1   # mid-draw retarget: nothing to lower
    previous_slot = slot
    slot = new_slot
    swap_left = data().swap_time
    aiming = false
    scope_level = 0
    _buffer_fire = false   # presses belonged to the draw we just abandoned
    _buffer_alt = false
    _show_model(slot)
    Sfx.play("weapon_change", character.center(), -4.0)
    weapon_changed.emit(slot, data())


## World props that react to hits live in the "shootable" group (on the collider or one of
## its parents) and implement on_shot(by, pos, dir, weapon).
static func shootable_of(collider: Object) -> Node:
    var n := collider as Node
    var depth := 0
    while n != null and depth < 4:
        if n.is_in_group("shootable") and n.has_method("on_shot"):
            return n
        n = n.get_parent()
        depth += 1
    return null


func select_previous() -> void:
    select(previous_slot)


func select_offset(offset: int) -> void:
    select(wrapi(slot + offset, 1, 8))


func reload() -> void:
    if current().start_reload():
        Game.trace("reload:%d" % slot)
        reload_started.emit()
        _reload_feedback()


func _reload_feedback() -> void:
    Sfx.play("reload", character.center())
    var f := _figure()
    if f:
        f.play_action("reload", data().reload_time)


## Client puppets: the server says this toy fired from `origin` along `dir`.
func fire_remote(new_slot: int, origin: Vector3, dir: Vector3) -> void:
    if new_slot != slot:
        select(new_slot)
    swap_left = 0.0
    character.set_aim_ray(origin, dir)
    var s := current()
    if s.data.kind == WeaponData.Kind.MELEE:
        _melee(s, s.data.damage, s.data.fire_interval, false)
    else:
        _fire(s)


func melee_remote(heavy: bool) -> void:
    if slot != 1:
        select(1)
    swap_left = 0.0
    var s := current()
    _melee(s, s.data.heavy_damage if heavy else s.data.damage, s.data.heavy_interval if heavy else s.data.fire_interval, heavy)


func reload_remote() -> void:
    _reload_feedback()


func refill_all() -> void:
    for s in states:
        s.refill()


## Ammo capsule: add `fraction` of every weapon's max reserve (gatling: belt). False if full.
func top_up_reserves(fraction: float) -> bool:
    var took := false
    for s in states:
        if not s.uses_ammo():
            continue
        if s.data.reserve > 0:
            var add := mini(int(ceil(s.data.reserve * fraction)), s.data.reserve - s.reserve)
            if add > 0:
                s.reserve += add
                took = true
        else:
            var add := mini(int(ceil(s.data.clip_size * fraction)), s.data.clip_size - s.clip)
            if add > 0:
                s.clip += add
                took = true
    return took


## Current zoom FOV for the camera, or 0 when not zoomed.
func zoom_fov() -> float:
    var d := data()
    if d.scope_overlay:
        return 0.0 if scope_level == 0 else (d.zoom_fov if scope_level == 1 else d.zoom_fov * 0.5)
    return d.zoom_fov if aiming else 0.0


func _process(delta: float) -> void:
    # Guns always point where the character aims; melee keeps the hand's own orientation.
    var m := current_model()
    if m == null or character == null or not character.alive:
        return
    if slot == 5:
        var barrels := m.get_node_or_null("Barrels") as Node3D
        if barrels:
            barrels.rotation.z += delta * current().spin * 30.0
    # draw arc: the old weapon drops for LOWER_TIME, then the new one rises into the aim pose
    var d := data()
    var arc := 0.0            # 0 = up and aimed, 1 = bottom of the arc
    var shown := m
    if swap_left > 0.0 and d.swap_time > 0.0:
        var elapsed := d.swap_time - swap_left
        var lower := minf(LOWER_TIME, d.swap_time * 0.35)
        if _outgoing >= 1 and elapsed < lower and _models.size() >= _outgoing:
            shown = _models[_outgoing - 1]
            arc = elapsed / lower
        else:
            var q := clampf((elapsed - lower) / maxf(d.swap_time - lower, 0.01), 0.0, 1.0)
            arc = (1.0 - q) * (1.0 - q)   # ease out: fast rise, settles at the top
        _arc_active = true
    elif _arc_active:
        _arc_active = false
        _outgoing = -1
        m.position = Vector3.ZERO
    for i in _models.size():
        _models[i].visible = _models[i] == shown
    _pose_model(shown, arc)


## Aim pose plus the arc offset (tilted down and dropped by `arc`, 0..1).
func _pose_model(m: Node3D, arc: float) -> void:
    var kind: WeaponData.Kind = WeaponDB.for_slot(_models.find(m) + 1).kind if _models.has(m) else data().kind
    if kind == WeaponData.Kind.MELEE:
        m.rotation = Vector3(deg_to_rad(-90.0 - ARC_TILT_DEG * arc), 0.0, 0.0)   # blade up along the forearm
    else:
        var dir := character.aim_dir()
        var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
        var basis := Basis.looking_at(dir, up)
        m.global_basis = basis.rotated(basis.x, -deg_to_rad(ARC_TILT_DEG) * arc)
    if arc > 0.0:
        m.position = Vector3(0, -ARC_DROP * arc, 0.12 * arc)


func _physics_process(delta: float) -> void:
    if character == null or not character.alive:
        trigger = false
        alt = false
    for i in states.size():
        states[i].tick(delta, trigger and i == slot - 1)
    if swap_left > 0.0:
        swap_left = maxf(0.0, swap_left - delta)
        if swap_left <= READY_EPS:
            swap_left = 0.0

    var s := current()
    var d := s.data
    var trigger_edge := trigger and not _trigger_was
    var alt_edge := alt and not _alt_was
    var drawing := swap_left > 0.0
    if drawing:
        # remember presses; they execute the tick the weapon is up
        if trigger_edge:
            _buffer_fire = true
        if alt_edge:
            _buffer_alt = true
    var fire_press := (trigger_edge or _buffer_fire) and not drawing
    var alt_press := (alt_edge or _buffer_alt) and not drawing
    if not drawing:
        _buffer_fire = false
        _buffer_alt = false

    if d.scope_overlay:
        # quickscope: scope in the last frames of the draw, or the tick it completes when buffered
        if (alt_edge and drawing and swap_left <= 0.12) or alt_press:
            scope_level = (scope_level + 1) % 3
            Sfx.play("weapon_change", character.center(), -6.0, 0.0)
            _buffer_alt = false
        aiming = scope_level > 0
    else:
        aiming = alt and d.zoom_fov > 0.0 and not drawing

    if not drawing:
        var want_fire := (trigger and d.auto) or fire_press
        if want_fire:
            if s.ready_to_fire():
                _fire(s)
            elif s.uses_ammo() and s.clip == 0:
                if s.reserve > 0:
                    reload()
                elif fire_press:
                    Sfx.play("empty_click", character.center())
        if d.kind == WeaponData.Kind.MELEE and alt_press and s.ready_to_fire():
            _melee(s, d.heavy_damage, d.heavy_interval, true)
        if d.spin_up > 0.0:
            var spinning := trigger and not s.overheated
            if spinning and not _spin_was:
                Sfx.play("gatling_spin", character.center())
            if s.overheated and s.heat >= 0.999 and not _spin_was:
                Sfx.play("overheat", character.center())
            _spin_was = spinning
    _trigger_was = trigger
    _alt_was = alt


func _fire(s: WeaponState) -> void:
    var d := s.data
    Game.trace("fire:%d" % slot)
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
    if d.kind != WeaponData.Kind.MELEE:
        Sfx.play(SHOT_SOUND.get(slot, "rifle_shot"), muzzle_position())
        if not d.auto:
            var f := _figure()
            if f:
                f.play_action("fire", minf(d.fire_interval, 0.45))
    fired.emit(d)
    character.apply_kick(d.kick_deg)


func _fire_hitscan(d: WeaponData) -> void:
    var ray := character.get_aim_ray()
    var origin: Vector3 = ray.origin
    var base_dir: Vector3 = ray.dir
    var scoped := aiming and d.scope_overlay
    var spread := 0.0 if scoped else d.spread_deg
    var dmg_scale := d.unscoped_damage_mult if (d.scope_overlay and not scoped) else 1.0
    var muzzle := muzzle_position()
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
            if target and not cosmetic:
                var head := int(hit.shape) == Character.HEAD_SHAPE_INDEX
                var dist := muzzle.distance_to(hit.position)
                var dmg := d.damage * dmg_scale * _falloff(d, dist) * (d.headshot_mult if head else 1.0)
                var result := target.take_damage(dmg, character, hit.position, dir * d.knockback / d.pellets, head)
                if result.applied:
                    hit_confirmed.emit(result.killed, head)
            elif target == null and not cosmetic:
                var prop := shootable_of(hit.collider)
                if prop != null:
                    prop.on_shot(character, hit.position, dir, d)
                    hit_confirmed.emit(false, false)
            Vfx.impact(hit.position, hit.normal, target != null)
        Vfx.tracer(muzzle, end, Color(1.0, 0.85, 0.45) if slot != 4 else Color(0.6, 0.9, 1.0))
    var m := current_model()
    var right: Vector3 = m.global_transform.basis.x if m else Vector3.RIGHT
    Vfx.muzzle_flash(muzzle, base_dir, FLASH_SIZE.get(slot, 0.7))
    if slot != 5 or randf() < 0.5:
        Vfx.casing(muzzle - base_dir * 0.45, right)


func _fire_projectile(d: WeaponData) -> void:
    var ray := character.get_aim_ray()
    var muzzle := muzzle_position()
    var space := character.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(
        ray.origin, ray.origin + ray.dir * 200.0, MASK_HIT, [character.get_rid()])
    var hit := space.intersect_ray(query)
    var target_point: Vector3 = hit.position if hit else ray.origin + ray.dir * 200.0
    var dir: Vector3 = ray.dir
    if (target_point - ray.origin).dot(ray.dir) > 1.5:
        dir = (target_point - muzzle).normalized()
    var p := Projectile.new()
    p.cosmetic = cosmetic
    p.setup(d, character, dir * d.projectile_speed)
    character.get_parent().add_child(p)
    p.global_position = muzzle
    Vfx.muzzle_flash(muzzle, dir, FLASH_SIZE.get(slot, 1.0))


func _melee(s: WeaponState, dmg: float, interval: float, heavy: bool) -> void:
    s.cooldown = interval
    s.combo = 0 if heavy else (s.combo + 1) % 3
    var d := s.data
    var origin := character.center()
    var forward: Vector3 = character.get_aim_ray().dir
    var flat := Vector3(forward.x, 0.0, forward.z).normalized()
    if character.is_on_floor():
        character.velocity += flat * (4.0 if heavy else 2.5)   # the little lunge every swing has
    Sfx.play("melee_swing", origin, 0.0 if heavy else -3.0, 0.1)
    melee_swung.emit(heavy)
    for node in character.get_tree().get_nodes_in_group("characters"):
        var other := node as Character
        if other == null or other == character or not other.alive or cosmetic:
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
            Sfx.play("melee_hit", other.center())
    if not cosmetic:
        for node in character.get_tree().get_nodes_in_group("shootable"):
            var prop := node as Node3D
            if prop == null or not prop.has_method("on_shot"):
                continue
            var to: Vector3 = prop.global_position - origin
            var dist := to.length()
            if dist > d.melee_range + 1.0 or (dist > 0.01 and rad_to_deg(forward.angle_to(to)) > d.melee_arc_deg):
                continue
            prop.on_shot(character, prop.global_position, forward, d)
            hit_confirmed.emit(false, false)
            Sfx.play("melee_hit", prop.global_position, -4.0)
    _swing_model(heavy)
    var f := _figure()
    if f:
        f.play_action("melee_heavy" if heavy else "melee_light", interval)
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
    var figure := character.get_node_or_null("Figure") as Figure
    var parent: Node3D = figure.grip if (figure and figure.grip) else character.get_node("WeaponHolder")
    for d in WeaponDB.all():
        var m := WeaponModels.build(d)
        m.visible = false
        m.scale = Vector3.ONE * WEAPON_SCALE
        parent.add_child(m)
        _models.append(m)


func current_model() -> Node3D:
    return _models[slot - 1] if _models.size() >= slot else null


## World-space point the shot visibly leaves from (the current weapon's barrel end).
func muzzle_position() -> Vector3:
    var m := current_model()
    if m == null:
        return character.global_position + Vector3(0, 1.0, 0)
    return m.global_transform * Vector3(0, 0, -0.7)


func _show_model(which: int) -> void:
    _kill_tween()
    if _models.is_empty():
        return
    var lowering := _outgoing >= 1 and swap_left > 0.0 and _models.size() >= _outgoing
    for i in _models.size():
        _models[i].visible = (i == (_outgoing - 1 if lowering else which - 1))
    if _models.size() >= which and which >= 1:
        _models[which - 1].position = Vector3(0, -ARC_DROP, 0.12)


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
    m.position = Vector3(0, 0, -0.08 if heavy else -0.05)
    _model_tween = m.create_tween()
    _model_tween.tween_property(m, "position", Vector3.ZERO, 0.2).set_ease(Tween.EASE_OUT)


func _kill_tween() -> void:
    if _model_tween and _model_tween.is_valid():
        _model_tween.kill()
