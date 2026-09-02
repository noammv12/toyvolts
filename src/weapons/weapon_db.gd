class_name WeaponDB
extends RefCounted
## The seven weapons, seeded from the Microvolts wiki stats and design/plan.md.
## Tuned by feel afterwards. Slot order is fixed: keys 1-7.

static var _all: Array[WeaponData] = []


static func all() -> Array[WeaponData]:
    if _all.is_empty():
        _all = _build()
    return _all


static func for_slot(slot: int) -> WeaponData:
    return all()[slot - 1]


static func _make(props: Dictionary) -> WeaponData:
    var d := WeaponData.new()
    for key in props:
        d.set(key, props[key])
    return d


static func _build() -> Array[WeaponData]:
    var list: Array[WeaponData] = []
    list.append(_make({
        slot = 1, display_name = "Melee", kind = WeaponData.Kind.MELEE, auto = true,
        damage = 20.0, fire_interval = 0.35, heavy_damage = 45.0, heavy_interval = 0.8,
        clip_size = 0, reserve = 0, melee_range = 1.8, melee_arc_deg = 70.0,
        run_speed_mult = 1.15, extra_jumps = 1, knockback = 5.0, kick_deg = 0.0,
        swap_time = 0.18, color = Color(0.55, 0.36, 0.2),
    }))
    list.append(_make({
        slot = 2, display_name = "Rifle", kind = WeaponData.Kind.HITSCAN, auto = true,
        damage = 9.0, headshot_mult = 1.5, spread_deg = 1.2, fire_interval = 0.1,
        clip_size = 30, reserve = 120, reload_time = 1.6,
        zoom_fov = 52.0, zoom_sens_mult = 0.7, kick_deg = 0.25,
        swap_time = 0.25, color = Color(0.3, 0.42, 0.62),
    }))
    list.append(_make({
        slot = 3, display_name = "Shotgun", kind = WeaponData.Kind.HITSCAN, auto = false,
        damage = 9.0, headshot_mult = 1.3, pellets = 8, spread_deg = 7.0, fire_interval = 0.9,
        clip_size = 3, reserve = 12, reload_time = 1.4,
        falloff_start = 8.0, falloff_end = 20.0, falloff_min = 0.3,
        kick_deg = 1.6, knockback = 4.0, swap_time = 0.3, color = Color(0.72, 0.3, 0.22),
    }))
    list.append(_make({
        slot = 4, display_name = "Sniper", kind = WeaponData.Kind.HITSCAN, auto = false,
        damage = 110.0, headshot_mult = 2.0, spread_deg = 3.0, fire_interval = 1.5,
        clip_size = 5, reserve = 20, reload_time = 2.2,
        zoom_fov = 18.0, zoom_sens_mult = 0.25, scope_overlay = true, unscoped_damage_mult = 0.5,
        kick_deg = 3.0, knockback = 6.0, swap_time = 0.35, color = Color(0.2, 0.4, 0.28),
    }))
    list.append(_make({
        slot = 5, display_name = "Gatling", kind = WeaponData.Kind.HITSCAN, auto = true,
        damage = 6.0, headshot_mult = 1.5, spread_deg = 4.0, fire_interval = 0.055,
        clip_size = 120, reserve = 0, reload_time = 3.0,
        spin_up = 0.45, heat_per_shot = 1.0 / 108.0, heat_cool_per_s = 0.35,
        run_speed_mult = 0.8, kick_deg = 0.12, knockback = 0.6,
        swap_time = 0.45, color = Color(0.5, 0.35, 0.65),
    }))
    list.append(_make({
        slot = 6, display_name = "Bazooka", kind = WeaponData.Kind.PROJECTILE, auto = false,
        damage = 40.0, fire_interval = 1.2, clip_size = 3, reserve = 9, reload_time = 2.0,
        projectile_speed = 24.0, projectile_gravity = 0.0,
        splash_radius = 3.0, splash_damage = 55.0, fuse_time = 0.0,
        kick_deg = 2.5, knockback = 7.0, swap_time = 0.4, color = Color(0.45, 0.5, 0.3),
    }))
    list.append(_make({
        slot = 7, display_name = "Grenade Launcher", kind = WeaponData.Kind.PROJECTILE, auto = false,
        damage = 0.0, fire_interval = 0.7, clip_size = 4, reserve = 12, reload_time = 1.8,
        projectile_speed = 19.0, projectile_gravity = 14.0,
        splash_radius = 2.5, splash_damage = 50.0, fuse_time = 2.0, bounciness = 0.45,
        detonate_on_character = true,
        kick_deg = 1.0, knockback = 6.0, swap_time = 0.35, color = Color(0.2, 0.55, 0.55),
    }))
    return list
