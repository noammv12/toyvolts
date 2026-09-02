extends Node
## Visual verification loop: run the game with
##   tools/godot.sh --path . -- --screenshot=<abs path>.png [--frames=45|"40,60,80"]
##       [--freeze_on=fire|explode|hit] [--freeze_delay=3]
## It waits N frames, saves the rendered frame(s) and quits. With --freeze_on the scene is
## paused a few frames after the event so short-lived effects can be captured deliberately.

var _frozen := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if Game.has_arg("freeze_on"):
        _arm_freeze(Game.arg("freeze_on"), int(Game.arg("freeze_delay", "3")))
    if Game.has_arg("fxtest"):
        _fx_test(int(Game.arg("fxtest", "30")))
    if Game.has_arg("screenshot"):
        _capture(Game.arg("screenshot"), Game.arg("frames", "45"))


## Stages every effect a few metres in front of the player and freezes the scene.
func _fx_test(at_frame: int) -> void:
    var player: Player = null
    while player == null:
        await get_tree().process_frame
        player = get_tree().get_first_node_in_group("player") as Player
    for i in at_frame:
        await get_tree().process_frame
    var eye := player.eye()
    var f := player.facing()
    var r := f.cross(Vector3.UP)
    var base := eye + f * 5.0
    Vfx.muzzle_flash(base + r * -2.5, f, 0.9)
    Vfx.tracer(base + r * -1.2 + Vector3(0, -0.5, 0), base + r * -1.2 + Vector3(0, -0.5, 0) + f * 6.0)
    Vfx.impact(base + r * 0.0 + Vector3(0, -0.3, 0), -f, false)
    Vfx.impact(base + r * 1.2 + Vector3(0, -0.3, 0), -f, true)
    Vfx.casing(base + r * -2.0 + Vector3(0, -0.6, 0), r)
    Vfx.explosion(base + f * 4.0 + r * 3.0 + Vector3(0, -1.0, 0), 2.5)
    # persistent probes: plain sprite, noise sprite, additive sprite, glow streak
    var s1 := Sprite3D.new()
    s1.texture = Vfx._radial
    s1.pixel_size = 1.5 / 64.0
    s1.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s1.modulate = Color(1, 0.5, 0.2)
    Vfx.add_child(s1)
    s1.global_position = base + r * -3.5 + Vector3(0, 1.0, 0)
    var s2 := Vfx._billboard(Vfx._smoke, Color(0.3, 0.3, 0.3, 0.9), 1.5, false)
    Vfx.add_child(s2)
    s2.global_position = base + r * -2.0 + Vector3(0, 1.0, 0)
    var s3 := Vfx._billboard(Vfx._radial, Color(1.0, 0.8, 0.45, 1.0), 1.5, true)
    Vfx.add_child(s3)
    s3.global_position = base + r * -0.5 + Vector3(0, 1.0, 0)
    var streak := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.07, 0.07, 1.6)
    streak.mesh = box
    streak.material_override = Vfx._glow_mat(Color(1.0, 0.85, 0.45), 4.0)
    Vfx.add_child(streak)
    streak.global_position = base + r * 1.0 + Vector3(0, 1.0, 0)
    streak.rotation.y = 0.6
    print("[capture] smoke tex size ", Vfx._smoke.get_size(), " radial ", Vfx._radial.get_size())
    for i in 2:
        await get_tree().process_frame
    get_tree().paused = true
    print("[capture] fx test staged")


func _arm_freeze(kind: String, delay_frames: int) -> void:
    var player: Player = null
    while player == null:
        await get_tree().process_frame
        player = get_tree().get_first_node_in_group("player") as Player
    match kind:
        "fire":
            player.arsenal.fired.connect(func(_d: WeaponData) -> void: _freeze_soon(kind, delay_frames))
        "explode":
            Vfx.shake.connect(func(_p: Vector3, _s: float) -> void: _freeze_soon(kind, delay_frames))
        "hit":
            player.arsenal.hit_confirmed.connect(func(_k: bool, _h: bool) -> void: _freeze_soon(kind, delay_frames))


func _freeze_soon(kind: String, delay_frames: int) -> void:
    if _frozen:
        return
    _frozen = true
    for i in delay_frames:
        await get_tree().process_frame
    get_tree().paused = true
    print("[capture] frozen on ", kind)


## `frames` may be a single number or a comma list (e.g. "80,90,100"): one PNG per entry,
## suffixed with the frame number when more than one.
func _capture(path: String, frames_spec: String) -> void:
    var targets: Array[int] = []
    for part in frames_spec.split(","):
        if part.strip_edges() != "":
            targets.append(int(part))
    targets.sort()
    var frame := 0
    for target in targets:
        while frame < target:
            await get_tree().process_frame
            frame += 1
        await RenderingServer.frame_post_draw
        var img := get_viewport().get_texture().get_image()
        var abs_path := ProjectSettings.globalize_path(path)
        if targets.size() > 1:
            abs_path = abs_path.get_basename() + "_f%03d.png" % target
        DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
        var err := img.save_png(abs_path)
        if err == OK:
            print("[capture] saved ", abs_path, " ", img.get_size())
        else:
            print("[capture] FAILED err=", err, " path=", abs_path)
    get_tree().quit()
