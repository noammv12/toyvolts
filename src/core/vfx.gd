extends Node
## Effects: muzzle flashes, glowing tracers, impact sparks + puffs + decals, explosions
## (fireball, shockwave, smoke, debris, light), projectile trails, shell casings, camera
## shake requests. Autoload "Vfx". Textures are generated procedurally at start-up.
##
## Everything is POOLED: materials and process materials are created once and shared, nodes
## are recycled through per-kind free lists, and fades use GeometryInstance3D.transparency /
## Sprite3D.modulate so shared materials never get tweened. A shot allocates nothing.

signal shake(pos: Vector3, strength: float)   ## the local player converts this to camera trauma
signal screen_flash(color: Color, alpha: float, seconds: float)   ## the HUD paints this full-screen

const MAX_DECALS := 96
const POOL_SIZES := {
    "tracer": 24, "light": 8, "sprite": 48, "fireball": 4, "decal": 32, "mag": 6, "part": 36,
    "arc": 6,
    "p_casing": 12, "p_impact": 16, "p_impact_char": 8, "p_debris": 4, "p_sparks": 4,
    "trail_rocket": 4, "trail_grenade": 4,
}

## Per-surface impact flavour: what flies off, what the puff and the scorch mark look like,
## and what it sounds like. ArenaBase tags every body with one of these keys.
const SURFACES := {
    "plastic": {"puff": Color(0.85, 0.85, 0.88, 0.5), "decal": Color(0.12, 0.1, 0.09, 0.85),
        "soft": false, "sound": "impact_plastic"},
    "wood":    {"puff": Color(0.78, 0.62, 0.42, 0.5), "decal": Color(0.16, 0.1, 0.05, 0.8),
        "soft": false, "sound": "impact_wood"},
    "metal":   {"puff": Color(0.8, 0.82, 0.86, 0.4), "decal": Color(0.2, 0.2, 0.22, 0.7),
        "soft": false, "sound": "impact_metal"},
    "fabric":  {"puff": Color(0.9, 0.86, 0.8, 0.55), "decal": Color(0.18, 0.14, 0.12, 0.6),
        "soft": true, "sound": "impact_fabric"},
    "paper":   {"puff": Color(0.94, 0.92, 0.86, 0.5), "decal": Color(0.25, 0.22, 0.18, 0.7),
        "soft": true, "sound": "impact_paper"},
}

const PART_LIFE := 3.6         ## how long a burst toy's pieces lie on the floor
const PART_FADE := 0.5

var _radial: GradientTexture2D
var _ring: GradientTexture2D
var _smoke: ImageTexture
var _star: ImageTexture
var _part_meshes: Array[Mesh] = []
var _part_shape: BoxShape3D
var _part_phys: PhysicsMaterial
var _arc_mesh: ArrayMesh
var _chip_meshes := {}         ## surface -> the debris mesh the impact emitter draws
var _streak_mesh: BoxMesh
var _fireball_mesh: SphereMesh
var _spark_mesh: BoxMesh
var _char_spark_mesh: BoxMesh
var _debris_mesh: BoxMesh
var _casing_mesh: BoxMesh
var _mag_mesh: BoxMesh
var _trail_mesh := {}          ## rocket/grenade -> BoxMesh
var _mats := {}                ## key -> StandardMaterial3D (shared)
var _pmats := {}               ## kind -> ParticleProcessMaterial (shared)
var _free := {}                ## kind -> Array[Node]
var _pending: Array = []       ## [release_clock, node, kind]
var _clock := 0.0              ## scaled seconds since start
var _tweens := {}              ## node -> Tween
var _decals_live: Array[Decal] = []
var _decal_serial := 0
var _pool_stats := {"created": 0, "reused": 0}


func _ready() -> void:
    _radial = _gradient_tex([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
    _ring = _gradient_tex([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.6, 0.8, 1.0])
    _smoke = _smoke_tex()
    _star = _star_tex()
    _build_part_meshes()
    _arc_mesh = _build_arc_mesh()
    _build_chip_meshes()
    _streak_mesh = BoxMesh.new()
    _streak_mesh.size = Vector3(0.07, 0.07, 1.0)
    _fireball_mesh = SphereMesh.new()
    _fireball_mesh.radius = 1.0
    _fireball_mesh.height = 2.0
    _fireball_mesh.radial_segments = 24
    _fireball_mesh.rings = 12
    _spark_mesh = BoxMesh.new()
    _spark_mesh.size = Vector3(0.05, 0.05, 0.12)
    _spark_mesh.material = _particle_mat(Color(1.0, 0.85, 0.5), 2.5)
    _char_spark_mesh = BoxMesh.new()
    _char_spark_mesh.size = Vector3(0.05, 0.05, 0.12)
    _char_spark_mesh.material = _particle_mat(Color(1.0, 0.4, 0.35), 1.5)
    _debris_mesh = BoxMesh.new()
    _debris_mesh.size = Vector3(0.18, 0.18, 0.18)
    _debris_mesh.material = _particle_mat(Color(0.35, 0.3, 0.28), 0.0)
    _casing_mesh = BoxMesh.new()
    _casing_mesh.size = Vector3(0.04, 0.04, 0.09)
    _casing_mesh.material = _particle_mat(Color(0.85, 0.7, 0.3), 0.0)
    _mag_mesh = BoxMesh.new()
    _mag_mesh.size = Vector3(0.075, 0.16, 0.05)
    _mag_mesh.material = _particle_mat(Color(0.2, 0.2, 0.24), 0.0)
    for rocket in [true, false]:
        var mesh := BoxMesh.new()
        mesh.size = Vector3.ONE * (0.16 if rocket else 0.09)
        mesh.material = _particle_mat(Color(0.75, 0.72, 0.7) if rocket else Color(0.6, 0.6, 0.6), 0.0)
        _trail_mesh[rocket] = mesh
    # shared particle process materials
    _pmats["p_casing"] = _pmat(Vector3(0.7, 1.2, 0), 25.0, 1.8, 3.0, Vector3(0, -12, 0), 1.0)
    _pmats["p_casing"].angular_velocity_min = -600.0
    _pmats["p_casing"].angular_velocity_max = 600.0
    _pmats["p_impact"] = _pmat(Vector3.UP, 55.0, 3.0, 7.5, Vector3(0, -14, 0), 0.9)
    # fabric and paper do not spark: the bits drift instead of flying
    _pmats["p_impact_soft"] = _pmat(Vector3.UP, 70.0, 1.2, 3.0, Vector3(0, -4.5, 0), 2.2)
    _pmats["p_impact_char"] = _pmat(Vector3.UP, 55.0, 3.0, 7.5, Vector3(0, -14, 0), 0.9)
    _pmats["p_debris"] = _pmat(Vector3.UP, 180.0, 5.0, 12.0, Vector3(0, -18, 0), 0.6)
    _pmats["p_debris"].angular_velocity_min = -400.0
    _pmats["p_debris"].angular_velocity_max = 400.0
    _pmats["p_sparks"] = _pmat(Vector3.UP, 180.0, 6.0, 14.0, Vector3(0, -10, 0), 1.5)
    for rocket in [true, false]:
        var pm := _pmat(Vector3.UP, 180.0, 0.2, 0.6, Vector3(0, 0.8, 0), 2.0)
        pm.scale_min = 0.6
        pm.scale_max = 1.4
        pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
        pm.emission_sphere_radius = 0.06
        _pmats["trail_rocket" if rocket else "trail_grenade"] = pm
    for kind in POOL_SIZES:
        _free[kind] = []
        for i in POOL_SIZES[kind]:
            _free[kind].append(_make(kind))


func _process(delta: float) -> void:
    _clock += delta   # scaled game time: effects and their release agree during hitstop/slow-mo
    if _pending.is_empty():
        return
    var i := 0
    while i < _pending.size():
        var entry: Array = _pending[i]
        if _clock >= entry[0]:
            _release(entry[1], entry[2])
            _pending.remove_at(i)
        else:
            i += 1


# ---- public ---------------------------------------------------------------------

## Spawns one of every effect far below the map so their shaders/pipelines compile before
## the first real shot (avoids a hitch on first use).
func warm_up() -> void:
    var p := Vector3(0, -60, 0)
    tracer(p, p + Vector3(0, 0, 3))
    tracer(p, p + Vector3(0, 0, 3), Color(0.6, 0.9, 1.0))
    muzzle_flash(p, Vector3.FORWARD)
    casing(p, Vector3.RIGHT)
    mag_drop(p + Vector3(0, 0.4, 0), Vector3.RIGHT, p.y)
    jump_puff(p)
    star_pop(p)
    assemble(p, Color(0.9, 0.5, 0.3))
    swing_arc(p, Vector3.FORWARD, 0)
    shockwave(p, 1.5)
    smoke_wisp(p, Vector3.FORWARD)
    steam_burst(p, Vector3.FORWARD)
    backblast(p, Vector3.FORWARD)
    bounce_spark(p, Vector3.UP)
    fall_apart(p, Color(0.9, 0.5, 0.3))
    for key in SURFACES:
        impact(p, Vector3.UP, false, key)
    impact(p, Vector3.UP, true)
    explosion(p, 2.0)
    var probe := Node3D.new()
    add_child(probe)
    probe.global_position = p
    var t1 := trail(probe, true)
    var t2 := trail(probe, false)
    get_tree().create_timer(1.5).timeout.connect(func() -> void:
        release_trail(t1)
        release_trail(t2)
        probe.queue_free())


## warm_up() stages every effect far below the map so its pipelines compile before the first
## real one; those rehearsals must stay silent.
func _audible(pos: Vector3) -> bool:
    return pos.y > -50.0


func pool_stats() -> Dictionary:
    return _pool_stats


## A short glowing streak that flies from the muzzle to the hit point (reads well even when
## seen from behind the shooter, unlike a full-length line).
func tracer(from: Vector3, to: Vector3, color := Color(1.0, 0.85, 0.45)) -> void:
    var length := from.distance_to(to)
    if length < 0.3:
        return
    var streak_len := minf(1.6, length * 0.6)
    var mi := _acquire("tracer") as MeshInstance3D
    mi.material_override = _glow_mat(color, 4.0)
    mi.transparency = 0.0
    var dir := (to - from).normalized()
    var start := from + dir * streak_len * 0.5
    var end := to - dir * streak_len * 0.5
    mi.global_position = start
    mi.look_at(to, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
    mi.scale = Vector3(1, 1, streak_len)
    var speed := 140.0
    var fly := maxf(length - streak_len, 0.1) / speed
    var tw := _tween(mi)
    tw.tween_property(mi, "global_position", end, fly)
    tw.tween_property(mi, "transparency", 1.0, 0.04)
    _release_after(mi, "tracer", fly + 0.06)


## `lit` off for very fast weapons: at 18 rounds a second the flash lights overlap and wash
## the shooter out completely.
func muzzle_flash(pos: Vector3, dir := Vector3.ZERO, size := 0.7, lit := true) -> void:
    if lit:
        var light := _acquire("light") as OmniLight3D
        light.light_color = Color(1.0, 0.75, 0.4)
        light.light_energy = 6.0
        light.omni_range = 5.0
        light.global_position = pos
        _release_after(light, "light", 0.07)
    var flash := _sprite(_radial, Color(1.0, 0.8, 0.45, 1.0), size * randf_range(0.8, 1.2), true)
    flash.global_position = pos + dir * 0.15
    flash.rotation.z = randf() * TAU
    _release_after(flash, "sprite", 0.07)
    var core := _sprite(_radial, Color(1.0, 1.0, 0.9, 1.0), size * 0.4, true)
    core.global_position = pos + dir * 0.2
    _release_after(core, "sprite", 0.07)


## A soft smoke puff that grows, rises `rise` metres and fades over `seconds` (candles, pops).
func puff(pos: Vector3, color: Color, size: float, rise: float, seconds: float) -> void:
    var p := _sprite(_smoke, color, size, false)
    p.global_position = pos
    p.rotation.z = randf() * TAU
    var tw := _tween(p).set_parallel(true)
    tw.tween_property(p, "scale", Vector3.ONE * 2.6, seconds).set_ease(Tween.EASE_OUT)
    tw.tween_property(p, "global_position", pos + Vector3(0, rise, 0), seconds)
    tw.tween_property(p, "modulate:a", 0.0, seconds).set_delay(seconds * 0.2)
    _release_after(p, "sprite", seconds + 0.1)


## Air-jump / landing cue: a dust ring on the floor under the feet. `size` scales with the
## impact. The quad is laid FLAT (rotated -90 about X, like the explosion shockwave) and spun
## about its own normal: left upright it stands in the floor and reads as a hard-edged card.
func jump_puff(pos: Vector3, size := 1.0) -> void:
    var puff := _sprite(_smoke, Color(1.0, 1.0, 1.0, 0.55), 0.6 * size, false)
    puff.global_position = pos
    puff.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    puff.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
    var tw := _tween(puff).set_parallel(true)
    tw.tween_property(puff, "scale", Vector3(2.4, 2.4, 1.0), 0.3).set_ease(Tween.EASE_OUT)
    tw.tween_property(puff, "modulate:a", 0.0, 0.3)
    _release_after(puff, "sprite", 0.35)


## Reload flourish: the spent magazine falls out of the gun, tumbles and clatters on the floor.
func mag_drop(pos: Vector3, right: Vector3, floor_y: float) -> void:
    var mag := _acquire("mag") as MeshInstance3D
    mag.transparency = 0.0
    mag.global_position = pos
    mag.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.3, 0.3))
    var land := pos + right * randf_range(0.08, 0.26) + Vector3(0, 0, 0)
    land.y = minf(floor_y, pos.y - 0.05)
    var fall := clampf(sqrt(maxf(0.05, pos.y - land.y)) * 0.42, 0.18, 0.7)
    var tw := _tween(mag)
    tw.set_parallel(true)
    tw.tween_property(mag, "global_position:x", land.x, fall)
    tw.tween_property(mag, "global_position:z", land.z, fall)
    tw.tween_property(mag, "global_position:y", land.y, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_property(mag, "rotation", mag.rotation + Vector3(randf_range(2.5, 5.0), 0.0, randf_range(-3.0, 3.0)), fall)
    tw.set_parallel(false)
    tw.tween_callback(func() -> void: Sfx.play("mag_drop", land, 0.0, 0.2))
    tw.tween_interval(1.0)
    tw.tween_property(mag, "transparency", 1.0, 0.4)
    _release_after(mag, "mag", fall + 1.5)


func casing(pos: Vector3, right: Vector3) -> void:
    var p := _acquire("p_casing") as GPUParticles3D
    p.global_position = pos
    # aim the burst along `right` (+ up) by rotating the emitter: the shared material's
    # direction is +X-ish, so look from the casing origin along the ejection axis
    var axis := (right + Vector3.UP * 0.2).normalized()
    p.global_basis = Basis.looking_at(axis, Vector3.UP if absf(axis.y) < 0.99 else Vector3.RIGHT) \
        * Basis(Vector3.UP, deg_to_rad(90.0))
    _release_after(p, "p_casing", 1.4)


## A bullet landing. On a toy it is always the same red spark; on the map, `surface` picks
## what flies off, the colour of the puff and the mark, and the sound (see SURFACES).
func impact(pos: Vector3, normal: Vector3, on_character: bool, surface := "plastic") -> void:
    var kind := "p_impact_char" if on_character else "p_impact"
    var look: Dictionary = SURFACES.get(surface, SURFACES["plastic"])
    var sparks := _acquire(kind) as GPUParticles3D
    if not on_character:
        # swapping a shared mesh / process material reference costs nothing and keeps one
        # emitter pool for every surface
        sparks.draw_pass_1 = _chip_meshes.get(surface, _chip_meshes["plastic"])
        sparks.process_material = _pmats["p_impact_soft" if look.soft else "p_impact"]
    sparks.global_position = pos
    var up := Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
    # process material direction is +Y: orient +Y along the surface normal
    sparks.global_basis = Basis.looking_at(normal, up) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
    _release_after(sparks, kind, 0.6)
    var puff := _sprite(_smoke, look.puff if not on_character else Color(1.0, 0.5, 0.45, 0.5), 0.35, false)
    puff.global_position = pos + normal * 0.08
    puff.rotation.z = randf() * TAU
    var tw := _tween(puff).set_parallel(true)
    tw.tween_property(puff, "scale", Vector3.ONE * 2.2, 0.35).set_ease(Tween.EASE_OUT)
    tw.tween_property(puff, "modulate:a", 0.0, 0.35)
    _release_after(puff, "sprite", 0.4)
    if not on_character:
        _decal(pos, normal, 0.22, look.decal)
        Sfx.play(look.sound, pos, -6.0, 0.12)


## What a body is made of, as tagged by the arena (see ArenaBase._tag_surface).
static func surface_of(collider: Object) -> String:
    var n := collider as Node
    return n.get_meta("surface", "plastic") if n != null else "plastic"


## The Microvolts signature: a killed toy bursts into plastic parts that bounce, settle and
## fade. Pieces sit on collision layer 0 / mask WORLD, so they never push a toy and shots pass
## straight through the pile. The piece count follows the quality preset.
func fall_apart(at: Vector3, color: Color, crouched := false) -> void:
    Game.trace("fall_apart")
    var origin := at + Vector3(0, 0.55 if crouched else 0.8, 0)
    var count: int = Quality.preset(Game.quality).get("fx_parts", 10)
    var light_color := color.lightened(0.35)
    for i in count:
        var part := _acquire("part") as RigidBody3D
        var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.1, 1.0), randf_range(-1.0, 1.0)).normalized()
        part.freeze = true
        part.global_transform = Transform3D(
            Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)),
            origin + dir * 0.22)
        var mesh := part.get_node("Mesh") as MeshInstance3D
        mesh.mesh = _part_meshes[i % _part_meshes.size()]
        mesh.material_override = _solid_mat(light_color if i % 3 == 0 else color)
        mesh.transparency = 0.0
        part.freeze = false
        part.linear_velocity = dir * randf_range(2.6, 6.0) + Vector3(0, randf_range(1.6, 4.0), 0)
        part.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
        var tw := _tween(mesh)
        tw.tween_interval(PART_LIFE - PART_FADE)
        tw.tween_property(mesh, "transparency", 1.0, PART_FADE)
        _release_after(part, "part", PART_LIFE)
    puff(origin, Color(1.0, 1.0, 1.0, 0.28), 0.7, 0.45, 0.4)
    if _audible(origin):
        Sfx.play("toy_break", origin)
        Sfx.play("part_clatter", origin, -2.0, 0.2)


## Respawn: a beam of light, a ring on the ground, and the toy pops back into existence.
func assemble(pos: Vector3, color: Color) -> void:
    Game.trace("assemble")
    # a soft column of light: a stretched additive radial, not a box (a box reads as a slab)
    var beam := _sprite(_radial, Color(color.lightened(0.55), 0.85), 1.3, true)
    beam.global_position = pos + Vector3(0, 1.3, 0)
    beam.scale = Vector3(0.55, 2.3, 1.0)
    var bt := _tween(beam).set_parallel(true)
    bt.tween_property(beam, "scale", Vector3(0.26, 2.9, 1.0), 0.4).set_ease(Tween.EASE_OUT)
    bt.tween_property(beam, "modulate:a", 0.0, 0.4).set_delay(0.08)
    _release_after(beam, "sprite", 0.45)
    var ring := _sprite(_ring, Color(color.lightened(0.4), 0.9), 1.4, true)
    ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    ring.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    ring.global_position = pos + Vector3(0, 0.08, 0)
    ring.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    var rt := _tween(ring).set_parallel(true)
    rt.tween_property(ring, "scale", Vector3(2.2, 2.2, 1.0), 0.4).set_ease(Tween.EASE_OUT)
    rt.tween_property(ring, "modulate:a", 0.0, 0.4)
    _release_after(ring, "sprite", 0.45)
    jump_puff(pos + Vector3(0, 0.06, 0), 1.2)
    if _audible(pos):
        Sfx.play("assemble", pos + Vector3(0, 0.8, 0))


## Melee: a ribbon that follows the blade through the swing. `kind` 0 = horizontal,
## 1 = upward diagonal, 2 = overhead -- the same order as Arsenal.COMBO_SWINGS.
func swing_arc(origin: Vector3, forward: Vector3, kind: int) -> void:
    var mi := _acquire("arc") as MeshInstance3D
    var flat := Vector3(forward.x, 0.0, forward.z)
    if flat.length_squared() < 0.0001:
        flat = Vector3.FORWARD
    flat = flat.normalized()
    # the ribbon is authored around its local +X, so turn it a further 90 degrees to centre
    # the sweep on the way the toy is facing
    var yaw := atan2(-flat.x, -flat.z) + PI * 0.5
    match kind:
        0:   # horizontal: the ribbon lies flat and sweeps across
            mi.rotation = Vector3(-PI * 0.5, yaw, 0.0)
        1:   # upward diagonal
            mi.rotation = Vector3(0.0, yaw, deg_to_rad(-35.0))
        _:   # overhead chop
            mi.rotation = Vector3(0.0, yaw, deg_to_rad(80.0))
    mi.global_position = origin + flat * 0.25
    mi.transparency = 0.0
    _tween(mi).tween_property(mi, "transparency", 1.0, 0.16)
    _release_after(mi, "arc", 0.2)


## A ring that races out along the floor (heavy melee, big landings).
func shockwave(pos: Vector3, radius: float, color := Color(1.0, 0.95, 0.8)) -> void:
    var ring := _sprite(_ring, Color(color, 0.85), radius * 0.7, true)
    ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    ring.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    ring.global_position = pos
    ring.rotation = Vector3(-PI * 0.5, randf() * TAU, 0.0)
    var tw := _tween(ring).set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(2.6, 2.6, 1.0), 0.3).set_ease(Tween.EASE_OUT)
    tw.tween_property(ring, "modulate:a", 0.0, 0.3)
    _release_after(ring, "sprite", 0.35)


## Gatling barrels above 70% heat: a thin wisp that curls up and away.
func smoke_wisp(pos: Vector3, dir: Vector3) -> void:
    var w := _sprite(_smoke, Color(0.72, 0.72, 0.75, 0.3), 0.22, false)
    w.global_position = pos
    w.rotation.z = randf() * TAU
    var tw := _tween(w).set_parallel(true)
    tw.tween_property(w, "scale", Vector3.ONE * 2.4, 0.7).set_ease(Tween.EASE_OUT)
    tw.tween_property(w, "global_position", pos + dir * 0.3 + Vector3(0, 0.55, 0), 0.7)
    tw.tween_property(w, "modulate:a", 0.0, 0.7).set_delay(0.1)
    _release_after(w, "sprite", 0.75)


## Overheat: a fast white burst of steam out of the barrels.
func steam_burst(pos: Vector3, dir: Vector3) -> void:
    for i in 4:
        var s := _sprite(_smoke, Color(1.0, 1.0, 1.0, 0.55), 0.3, false)
        s.global_position = pos
        s.rotation.z = randf() * TAU
        var away := (dir + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.7), randf_range(-0.5, 0.5))).normalized()
        var tw := _tween(s).set_parallel(true)
        tw.tween_property(s, "scale", Vector3.ONE * 2.8, 0.55).set_ease(Tween.EASE_OUT)
        tw.tween_property(s, "global_position", pos + away * 1.1, 0.55).set_ease(Tween.EASE_OUT)
        tw.tween_property(s, "modulate:a", 0.0, 0.55).set_delay(0.08)
        _release_after(s, "sprite", 0.6)
    if _audible(pos):
        Sfx.play("steam", pos)


## Bazooka: the exhaust that blows out behind the shooter on launch.
func backblast(pos: Vector3, dir: Vector3) -> void:
    for i in 3:
        var s := _sprite(_smoke, Color(0.78, 0.74, 0.7, 0.45), 0.4, false)
        s.global_position = pos
        s.rotation.z = randf() * TAU
        var away := (dir + Vector3(randf_range(-0.35, 0.35), randf_range(-0.15, 0.35), randf_range(-0.35, 0.35))).normalized()
        var tw := _tween(s).set_parallel(true)
        tw.tween_property(s, "scale", Vector3.ONE * 3.0, 0.5).set_ease(Tween.EASE_OUT)
        tw.tween_property(s, "global_position", pos + away * 1.5, 0.5).set_ease(Tween.EASE_OUT)
        tw.tween_property(s, "modulate:a", 0.0, 0.5).set_delay(0.06)
        _release_after(s, "sprite", 0.55)
    if _audible(pos):
        Sfx.play("backblast", pos, -2.0)


## A grenade skipping off the floor: just the sparks, no decal (they bounce a lot).
func bounce_spark(pos: Vector3, normal: Vector3) -> void:
    var sparks := _acquire("p_impact") as GPUParticles3D
    sparks.global_position = pos
    var up := Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
    sparks.global_basis = Basis.looking_at(normal, up) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
    _release_after(sparks, "p_impact", 0.5)


## Headshot / combo finisher: a four-point sparkle that pops and fades.
func star_pop(pos: Vector3, color := Color(1.0, 0.95, 0.55), size := 0.85) -> void:
    var s := _sprite(_star, color, size, true)
    s.global_position = pos
    s.scale = Vector3(0.4, 0.4, 0.4)
    s.rotation.z = randf_range(-0.4, 0.4)
    var tw := _tween(s).set_parallel(true)
    tw.tween_property(s, "scale", Vector3(1.4, 1.4, 1.4), 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.08)
    _release_after(s, "sprite", 0.4)


func explosion(pos: Vector3, radius: float) -> void:
    Game.trace("explosion")
    # fireball
    var mi := _acquire("fireball") as MeshInstance3D
    mi.global_position = pos
    mi.scale = Vector3.ONE * 0.2
    mi.transparency = 0.2
    var tw := _tween(mi).set_parallel(true)
    tw.tween_property(mi, "scale", Vector3.ONE * radius * 0.6, 0.16).set_ease(Tween.EASE_OUT)
    tw.tween_property(mi, "transparency", 1.0, 0.28)
    _release_after(mi, "fireball", 0.3)
    # shockwave ring
    var ring := _sprite(_ring, Color(1.0, 0.85, 0.6, 0.9), radius * 0.6, true)
    ring.axis = Vector3.AXIS_Y
    ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    ring.material_override.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    ring.global_position = pos + Vector3(0, 0.15, 0)
    ring.rotation.x = -PI * 0.5
    var rt := _tween(ring).set_parallel(true)
    rt.tween_property(ring, "scale", Vector3.ONE * radius * 1.4 / (radius * 0.6), 0.35).set_ease(Tween.EASE_OUT)
    rt.tween_property(ring, "modulate:a", 0.0, 0.35)
    _release_after(ring, "sprite", 0.4)
    # light
    var light := _acquire("light") as OmniLight3D
    light.light_color = Color(1.0, 0.6, 0.3)
    light.light_energy = 14.0
    light.omni_range = radius * 4.0
    light.global_position = pos
    _tween(light).tween_property(light, "light_energy", 0.0, 0.4)
    _release_after(light, "light", 0.42)
    # smoke puffs
    for i in 6:
        var puff := _sprite(_smoke, Color(0.3, 0.28, 0.27, 0.7), radius * 0.35, false)
        puff.global_position = pos + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.6), randf_range(-0.5, 0.5)) * radius * 0.5
        puff.rotation.z = randf() * TAU
        var pt := _tween(puff).set_parallel(true)
        pt.tween_property(puff, "scale", Vector3.ONE * 3.5, 1.1).set_ease(Tween.EASE_OUT)
        pt.tween_property(puff, "global_position", puff.global_position + Vector3(0, radius * 0.9, 0), 1.1)
        pt.tween_property(puff, "modulate:a", 0.0, 1.1).set_delay(0.15)
        _release_after(puff, "sprite", 1.3)
    # debris + sparks
    var debris := _acquire("p_debris") as GPUParticles3D
    debris.global_position = pos
    debris.global_basis = Basis.IDENTITY
    _release_after(debris, "p_debris", 1.6)
    var sparks := _acquire("p_sparks") as GPUParticles3D
    sparks.global_position = pos
    sparks.global_basis = Basis.IDENTITY
    _release_after(sparks, "p_sparks", 0.8)
    _decal(pos, Vector3.UP, radius * 0.9, Color(0.08, 0.07, 0.06, 0.8), true)
    shake.emit(pos, clampf(radius / 2.5, 0.4, 1.2))


## Continuous smoke trail behind a projectile (+ a flame sprite for rockets). Returns the
## pooled rig, parented to `node`; the owner must hand it back with release_trail() before
## it frees itself.
func trail(node: Node3D, rocket: bool) -> Node3D:
    var kind := "trail_rocket" if rocket else "trail_grenade"
    var rig := _acquire(kind) as Node3D
    if rig.get_parent() != node:
        rig.reparent(node, false)
    rig.position = Vector3.ZERO
    rig.rotation = Vector3.ZERO
    var p := rig.get_node("Smoke") as GPUParticles3D
    p.emitting = false
    p.emitting = true
    return rig


func release_trail(rig: Node3D) -> void:
    if rig == null or not is_instance_valid(rig):
        return
    var kind: String = rig.get_meta("kind", "trail_grenade")
    var p := rig.get_node("Smoke") as GPUParticles3D
    p.emitting = false
    if rig.get_parent() != self:
        rig.reparent(self, false)
    rig.global_position = Vector3(0, -100, 0)
    _release_after(rig, kind, 0.8)   # let the last puffs die out before reuse


# ---- pool core --------------------------------------------------------------------

func _make(kind: String) -> Node:
    _pool_stats.created += 1
    var n: Node
    match kind:
        "tracer":
            var mi := MeshInstance3D.new()
            mi.mesh = _streak_mesh
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            n = mi
        "fireball":
            var mi := MeshInstance3D.new()
            mi.mesh = _fireball_mesh
            var mat := _glow_mat(Color(1.0, 0.6, 0.2, 0.8), 3.5)
            mat.rim_enabled = true
            mat.rim = 1.0
            mat.rim_tint = 0.2
            mi.material_override = mat
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            n = mi
        "arc":
            var mi := MeshInstance3D.new()
            mi.mesh = _arc_mesh
            mi.material_override = _arc_mat()
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            n = mi
        "part":
            var rb := RigidBody3D.new()
            rb.collision_layer = 0                       # nothing collides WITH a piece...
            rb.collision_mask = Character.LAYER_WORLD    # ...and a piece only hits the map
            rb.mass = 0.16
            rb.gravity_scale = 1.5
            rb.physics_material_override = _part_phys
            rb.freeze = true
            var cs := CollisionShape3D.new()
            cs.shape = _part_shape
            rb.add_child(cs)
            var pm := MeshInstance3D.new()
            pm.name = "Mesh"
            pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            rb.add_child(pm)
            n = rb
        "mag":
            var mi := MeshInstance3D.new()
            mi.mesh = _mag_mesh
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            n = mi
        "light":
            var l := OmniLight3D.new()
            l.shadow_enabled = false
            n = l
        "sprite":
            var s := Sprite3D.new()
            s.shaded = false
            s.double_sided = true
            s.transparent = true
            s.render_priority = 2
            s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            n = s
        "decal":
            var d := Decal.new()
            d.texture_albedo = _radial
            d.cull_mask = 1   # world only
            d.albedo_mix = 1.0
            d.upper_fade = 0.6
            d.lower_fade = 0.6
            n = d
        "p_casing":
            n = _gpu(1, 1.1, _pmats[kind], _casing_mesh)
        "p_impact":
            n = _gpu(12, 0.35, _pmats[kind], _spark_mesh)
        "p_impact_char":
            n = _gpu(16, 0.35, _pmats[kind], _char_spark_mesh)
        "p_debris":
            n = _gpu(22, 1.3, _pmats[kind], _debris_mesh)
        "p_sparks":
            n = _gpu(30, 0.5, _pmats[kind], _spark_mesh)
        "trail_rocket", "trail_grenade":
            var rocket := kind == "trail_rocket"
            var rig := Node3D.new()
            rig.set_meta("kind", kind)
            var p := _gpu(40 if rocket else 24, 0.7 if rocket else 0.5, _pmats[kind], _trail_mesh[rocket], false)
            p.name = "Smoke"
            p.explosiveness = 0.0
            p.local_coords = false
            p.emitting = false
            rig.add_child(p)
            if rocket:
                var flame := _sprite_node(_radial, Color(1.0, 0.6, 0.25, 0.95), 0.45, true)
                flame.position = Vector3(0, 0, 0.35)
                rig.add_child(flame)
            n = rig
    n.set_meta("kind", kind)
    add_child(n)
    _hide(n)
    return n


func _acquire(kind: String) -> Node:
    var list: Array = _free[kind]
    var n: Node
    if list.is_empty():
        n = _make(kind)
    else:
        n = list.pop_back()
        _pool_stats.reused += 1
    _kill_tween(n)
    if n is RigidBody3D:
        _kill_tween(n.get_node("Mesh"))   # the fade lives on the child, not on the body
    if n is Node3D:
        n.visible = true
        n.scale = Vector3.ONE
        n.rotation = Vector3.ZERO
    if n is GPUParticles3D:
        # Godot 4.7: restart() on a one-shot emitter leaves `emitting` false; toggling works.
        n.emitting = false
        n.emitting = true
    return n


func _release(n: Node, kind: String) -> void:
    if not is_instance_valid(n):
        return
    _kill_tween(n)
    _hide(n)
    _free[kind].append(n)


func _hide(n: Node) -> void:
    if n is GPUParticles3D:
        n.emitting = false
    if n is RigidBody3D:
        n.freeze = true                   # park it: a loose body would keep simulating at y -100
        n.linear_velocity = Vector3.ZERO
        n.angular_velocity = Vector3.ZERO
    if n is Node3D:
        n.visible = false
        n.position = Vector3(0, -100, 0)


func _release_after(n: Node, kind: String, seconds: float) -> void:
    _pending.append([_clock + seconds, n, kind])


func _tween(n: Node) -> Tween:
    _kill_tween(n)
    var tw := n.create_tween()
    _tweens[n] = tw
    return tw


func _kill_tween(n: Node) -> void:
    var tw: Tween = _tweens.get(n)
    if tw != null:
        if tw.is_valid():
            tw.kill()
        _tweens.erase(n)


## Pooled sprite configured for one use.
func _sprite(tex: Texture2D, color: Color, size: float, additive: bool) -> Sprite3D:
    var s := _acquire("sprite") as Sprite3D
    _configure_sprite(s, tex, color, size, additive)
    return s


## Unpooled sprite (debug / fx test).
func _billboard(tex: Texture2D, color: Color, size: float, additive: bool) -> Sprite3D:
    return _sprite_node(tex, color, size, additive)


func _sprite_node(tex: Texture2D, color: Color, size: float, additive: bool) -> Sprite3D:
    var s := Sprite3D.new()
    s.shaded = false
    s.double_sided = true
    s.transparent = true
    s.render_priority = 2
    s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _configure_sprite(s, tex, color, size, additive)
    return s


func _configure_sprite(s: Sprite3D, tex: Texture2D, color: Color, size: float, additive: bool) -> void:
    s.texture = tex
    s.modulate = color
    s.pixel_size = size / 64.0
    s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s.axis = Vector3.AXIS_Z
    s.no_depth_test = false
    s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
    s.material_override = _additive_mat(tex, color) if additive else null


func _additive_mat(tex: Texture2D, color: Color) -> StandardMaterial3D:
    var key := ["add", tex, Color(color.r, color.g, color.b)]
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.albedo_texture = tex
    m.vertex_color_use_as_albedo = true
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = 2.0
    _mats[key] = m
    return m


## Flat solid, shared per colour (the toy palette is 9 colours, so the cache is bounded).
func _solid_mat(color: Color) -> StandardMaterial3D:
    var key := ["solid", color]
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.75
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mats[key] = m
    return m


## The blade trail is a thin unlit ribbon: additive, double-sided (it is seen from both sides
## of the swing) and tinted by the vertex alpha baked into the mesh.
func _arc_mat() -> StandardMaterial3D:
    var key := ["arc"]
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.vertex_color_use_as_albedo = true
    m.albedo_color = Color(0.97, 0.99, 1.0)
    m.disable_receive_shadows = true
    _mats[key] = m
    return m


## A ribbon that sweeps an arc in the XY plane, facing +Z: inner edge opaque, outer edge
## transparent, so it reads as a blade trail rather than a solid fan.
func _build_arc_mesh() -> ArrayMesh:
    var segments := 14
    var span := deg_to_rad(115.0)
    var verts := PackedVector3Array()
    var cols := PackedColorArray()
    for i in segments + 1:
        var a := -span * 0.5 + span * float(i) / float(segments)
        var c := cos(a)
        var s := sin(a)
        var edge := 1.0 - absf(float(i) / float(segments) * 2.0 - 1.0)   # fades at both ends
        verts.append(Vector3(c * 0.55, s * 0.55, 0.0))
        cols.append(Color(1, 1, 1, 0.95 * edge))
        verts.append(Vector3(c * 2.0, s * 2.0, 0.0))
        cols.append(Color(1, 1, 1, 0.0))
    var idx := PackedInt32Array()
    for i in segments:
        var b := i * 2
        idx.append_array([b, b + 1, b + 2, b + 2, b + 1, b + 3])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


## One debris mesh per surface: splinters, fluff, flakes, shards, sparks.
func _build_chip_meshes() -> void:
    var specs := {
        "plastic": [Vector3(0.05, 0.05, 0.09), Color(0.86, 0.86, 0.9), 0.6],
        "wood": [Vector3(0.028, 0.028, 0.17), Color(0.6, 0.42, 0.24), 0.0],
        "metal": [Vector3(0.05, 0.05, 0.12), Color(1.0, 0.9, 0.55), 3.0],
        "fabric": [Vector3(0.06, 0.06, 0.06), Color(0.92, 0.88, 0.82), 0.0],
        "paper": [Vector3(0.075, 0.012, 0.075), Color(0.95, 0.93, 0.87), 0.0],
    }
    for key in specs:
        var spec: Array = specs[key]
        var mesh := BoxMesh.new()
        mesh.size = spec[0]
        mesh.material = _particle_mat(spec[1], spec[2])
        _chip_meshes[key] = mesh


func _build_part_meshes() -> void:
    var box := BoxMesh.new()
    box.size = Vector3(0.17, 0.17, 0.17)
    var slab := BoxMesh.new()
    slab.size = Vector3(0.26, 0.09, 0.17)
    var cap := CapsuleMesh.new()
    cap.radius = 0.075
    cap.height = 0.3
    cap.radial_segments = 8
    cap.rings = 2
    var coil := TorusMesh.new()          # the spring inside the toy
    coil.inner_radius = 0.06
    coil.outer_radius = 0.13
    coil.rings = 10
    coil.ring_segments = 5
    _part_meshes = [box, cap, slab, box, coil, slab]
    _part_shape = BoxShape3D.new()
    _part_shape.size = Vector3(0.15, 0.15, 0.15)
    _part_phys = PhysicsMaterial.new()
    _part_phys.bounce = 0.42
    _part_phys.friction = 0.7


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
    var key := ["glow", color, energy]
    if _mats.has(key):
        return _mats[key]
    # (vertex colours carry the arc ribbon's fade; harmless for the other users)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = color
    m.emission_enabled = true
    m.emission = Color(color.r, color.g, color.b)
    m.emission_energy_multiplier = energy
    _mats[key] = m
    return m


func _particle_mat(color: Color, emission: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if emission > 0.0 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
    m.albedo_color = color
    m.vertex_color_use_as_albedo = true
    if emission > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emission
    return m


func _pmat(direction: Vector3, spread: float, v_min: float, v_max: float, gravity: Vector3, damping: float) -> ParticleProcessMaterial:
    var pm := ParticleProcessMaterial.new()
    pm.direction = direction
    pm.spread = spread
    pm.initial_velocity_min = v_min
    pm.initial_velocity_max = v_max
    pm.gravity = gravity
    pm.damping_min = damping
    pm.damping_max = damping * 1.5
    pm.scale_min = 0.7
    pm.scale_max = 1.3
    return pm


func _gpu(amount: int, lifetime: float, pm: ParticleProcessMaterial, mesh: Mesh, one_shot := true) -> GPUParticles3D:
    var p := GPUParticles3D.new()
    p.amount = amount
    p.lifetime = lifetime
    p.one_shot = one_shot
    p.explosiveness = 1.0 if one_shot else 0.0
    p.process_material = pm
    p.draw_pass_1 = mesh
    p.emitting = false
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return p


func _decal(pos: Vector3, normal: Vector3, size: float, color: Color, _floor_only := false) -> void:
    var d: Decal
    if _free["decal"].is_empty() and _decals_live.size() >= MAX_DECALS:
        d = _decals_live.pop_front()   # recycle the oldest
        _kill_tween(d)
    else:
        d = _acquire("decal") as Decal
    d.modulate = color
    d.size = Vector3(size, 0.4, size)
    d.global_position = pos + normal * 0.02
    var up := Vector3.UP if absf(normal.y) < 0.99 else Vector3.RIGHT
    d.global_basis = Basis.looking_at(normal, up) * Basis(Vector3.RIGHT, deg_to_rad(-90.0))
    _decals_live.append(d)
    _decal_serial += 1
    var serial := _decal_serial
    d.set_meta("serial", serial)
    get_tree().create_timer(18.0).timeout.connect(func() -> void:
        if not is_instance_valid(d) or d.get_meta("serial", -1) != serial:
            return
        var tw := _tween(d)
        tw.tween_property(d, "modulate:a", 0.0, 2.0)
        _decals_live.erase(d)
        _release_after(d, "decal", 2.05))


# ---- textures ---------------------------------------------------------------------

## Soft round smoke puff: value noise masked by a radial falloff.
func _smoke_tex() -> ImageTexture:
    var size := 96
    var noise := FastNoiseLite.new()
    noise.frequency = 0.07
    noise.fractal_octaves = 4
    noise.seed = 7
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var dx := (x + 0.5) / size - 0.5
            var dy := (y + 0.5) / size - 0.5
            var d := sqrt(dx * dx + dy * dy) * 2.0
            var falloff := clampf(1.0 - smoothstep(0.35, 1.0, d), 0.0, 1.0)
            var n := 0.55 + 0.45 * noise.get_noise_2d(x, y)
            img.set_pixel(x, y, Color(1, 1, 1, clampf(falloff * n * 1.4, 0.0, 1.0)))
    return ImageTexture.create_from_image(img)


## Four-point sparkle (headshots, combo finishers): an astroid, soft at the tips.
func _star_tex() -> ImageTexture:
    var size := 64
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for y in size:
        for x in size:
            var dx: float = absf((x + 0.5) / size - 0.5) * 2.0
            var dy: float = absf((y + 0.5) / size - 0.5) * 2.0
            var t := pow(dx, 0.42) + pow(dy, 0.42)
            var a := clampf(1.45 - t, 0.0, 1.0)
            img.set_pixel(x, y, Color(1, 1, 1, a * a))
    return ImageTexture.create_from_image(img)


func _gradient_tex(colors: Array, offsets: Array) -> GradientTexture2D:
    var g := Gradient.new()
    g.colors = PackedColorArray(colors)
    g.offsets = PackedFloat32Array(offsets)
    var t := GradientTexture2D.new()
    t.gradient = g
    t.width = 64
    t.height = 64
    t.fill = GradientTexture2D.FILL_RADIAL
    t.fill_from = Vector2(0.5, 0.5)
    t.fill_to = Vector2(1.0, 0.5)
    return t
