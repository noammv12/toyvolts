class_name WeaponData
extends Resource
## Tuning record for one of the seven weapon slots. Values live in WeaponDB.

enum Kind { MELEE, HITSCAN, PROJECTILE }

@export var slot := 1
@export var display_name := ""
@export var kind := Kind.HITSCAN
@export var auto := true            ## hold to keep firing
@export var damage := 10.0          ## per pellet / direct hit / melee light swing
@export var headshot_mult := 1.5
@export var pellets := 1
@export var spread_deg := 0.0       ## cone half-angle from the hip
@export var fire_interval := 0.1    ## seconds between shots (or swings)
@export var clip_size := 30         ## 0 = no ammo (melee)
@export var reserve := 120
@export var reload_time := 1.6
@export var range_m := 200.0
@export var falloff_start := 0.0    ## metres; 0 = no falloff
@export var falloff_end := 0.0
@export var falloff_min := 1.0      ## damage multiplier at falloff_end
@export var swap_time := 0.25       ## draw time after switching to this weapon
@export var swap_cancel := false    ## switching away drops the recovery (Microvolts: shotgun, bazooka, launcher only)
@export var kick_deg := 0.3         ## camera recoil per shot
@export var knockback := 0.0        ## impulse on the target (m/s)
@export var color := Color.WHITE    ## placeholder model tint

# secondary fire
@export var zoom_fov := 0.0         ## 0 = no zoom; else camera FOV while aiming
@export var zoom_sens_mult := 1.0
@export var scope_overlay := false
@export var unscoped_damage_mult := 1.0

# gatling
@export var spin_up := 0.0          ## seconds to reach full spin before the first shot
@export var heat_per_shot := 0.0    ## overheats at 1.0
@export var heat_cool_per_s := 0.0

# projectile
@export var projectile_speed := 0.0
@export var projectile_gravity := 0.0
@export var splash_radius := 0.0
@export var splash_damage := 0.0
@export var fuse_time := 0.0        ## 0 = detonate on any contact
@export var bounciness := 0.0
@export var detonate_on_character := true

# melee
@export var melee_range := 1.8
@export var melee_arc_deg := 70.0
@export var heavy_damage := 45.0
@export var heavy_interval := 0.8

# movement while equipped
@export var run_speed_mult := 1.0
@export var extra_jumps := 0
