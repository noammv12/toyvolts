extends Node
## Visual verification loop: run the game with
##   tools/godot.sh --path . -- --screenshot=<abs path>.png [--frames=45] [--yaw=deg] [--pitch=deg]
## It waits N frames, saves the rendered frame and quits.


func _ready() -> void:
    if Game.has_arg("screenshot"):
        _capture(Game.arg("screenshot"), int(Game.arg("frames", "45")))


func _capture(path: String, frames: int) -> void:
    for i in frames:
        await get_tree().process_frame
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    var abs_path := ProjectSettings.globalize_path(path)
    DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
    var err := img.save_png(abs_path)
    if err == OK:
        print("[capture] saved ", abs_path, " ", img.get_size())
    else:
        print("[capture] FAILED err=", err, " path=", abs_path)
    get_tree().quit()
