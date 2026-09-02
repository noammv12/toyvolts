class_name Quality
extends RefCounted
## Quality presets: what each tier turns on or off. Game.apply_quality() pushes the current
## preset into the arena's Environment + sun, the root viewport and the RenderingServer
## globals. "none" leaves everything exactly as authored (used for the benchmark baseline).
##
## Cost ladder (most expensive first, measured on the dev RTX 3050 with tools/bench.sh):
## SDFGI > SSIL > volumetric fog > SSAO > 4x MSAA > sun shadow range/softness > outline normals.

const LEVELS := ["low", "medium", "high"]

const PRESETS := {
    "low": {
        "scale": 0.66, "scale_mode": Viewport.SCALING_3D_MODE_FSR, "msaa": Viewport.MSAA_DISABLED, "fxaa": true,
        "sdfgi": false, "ssil": false, "ssao": false, "fog": false, "glow": true,
        "ambient_energy": 0.9, "sun_energy_mult": 0.95,
        "shadow_distance": 48.0, "shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "shadow_size": 2048,
        "shadow_blend": false, "shadow_blur": 1.0, "soft_shadows": RenderingServer.SHADOW_QUALITY_HARD,
        "outline_normals": false, "lod_threshold": 4.0,
    },
    "medium": {
        "scale": 0.8, "scale_mode": Viewport.SCALING_3D_MODE_FSR2, "msaa": Viewport.MSAA_DISABLED, "fxaa": false,
        "sdfgi": false, "ssil": false, "ssao": true, "fog": true, "glow": true,
        "ambient_energy": 1.0, "sun_energy_mult": 0.95,
        "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW,
        "fog_volume_size": 32, "fog_volume_depth": 48, "fog_filter": false,
        "shadow_distance": 50.0, "shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "shadow_size": 4096,
        "shadow_blend": false, "shadow_blur": 1.0, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW,
        "outline_normals": true, "lod_threshold": 2.0,
    },
    "high": {
        "scale": 1.0, "scale_mode": Viewport.SCALING_3D_MODE_BILINEAR, "msaa": Viewport.MSAA_4X, "fxaa": false,
        "sdfgi": true, "ssil": true, "ssao": true, "fog": true, "glow": true,
        "ambient_energy": 0.65, "sun_energy_mult": 1.0,
        "ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
        "fog_volume_size": 64, "fog_volume_depth": 64, "fog_filter": true,
        "shadow_distance": 80.0, "shadow_mode": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "shadow_size": 4096,
        "shadow_blend": true, "shadow_blur": 1.2, "soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_LOW,
        "outline_normals": true, "lod_threshold": 1.0,
    },
}


static func is_level(level: String) -> bool:
    return LEVELS.has(level)


static func preset(level: String) -> Dictionary:
    return PRESETS.get(level, PRESETS["high"])


static func lower(level: String) -> String:
    var i := LEVELS.find(level)
    return LEVELS[maxi(0, i - 1)] if i >= 0 else "low"


static func label(level: String) -> String:
    return level.capitalize()


static func scale_mode_name(mode: int) -> String:
    match mode:
        Viewport.SCALING_3D_MODE_FSR:
            return "fsr1"
        Viewport.SCALING_3D_MODE_FSR2:
            return "fsr2"
        _:
            return "bilinear"


## First-launch guess from the GPU name and class; a 2-second frame-time probe in the first
## match can still lower it one step (Game._probe_quality).
static func detect() -> String:
    var name := RenderingServer.get_video_adapter_name().to_lower()
    var type := RenderingServer.get_video_adapter_type()
    if type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU or type == RenderingDevice.DEVICE_TYPE_CPU \
            or type == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
        return "low"
    if name.is_empty():
        return "medium"
    for tag in ["rtx 50", "rtx 40", "rtx 30", "rx 9", "rx 7", "rx 6800", "rx 6900", "arc b", "arc a7"]:
        if name.contains(tag):
            return "high"
    for tag in ["rtx 20", "gtx 16", "rx 6", "rx 5", "arc a", "quadro"]:
        if name.contains(tag):
            return "medium"
    for tag in ["gtx", "rx 4", "rx 5", "vega", "iris", "uhd", "intel", "mx", "radeon(tm)", "radeon graphics"]:
        if name.contains(tag):
            return "low"
    return "medium"


static func apply_environment(level: String, env: Environment, sun: DirectionalLight3D) -> void:
    if level == "none" or env == null:
        return
    var p := preset(level)
    env.sdfgi_enabled = p.sdfgi
    env.ssil_enabled = p.ssil
    env.ssao_enabled = p.ssao
    env.volumetric_fog_enabled = p.fog
    env.glow_enabled = p.glow
    env.ambient_light_energy = p.ambient_energy
    if sun != null:
        if not sun.has_meta("base_energy"):
            sun.set_meta("base_energy", sun.light_energy)
        sun.light_energy = sun.get_meta("base_energy") * p.sun_energy_mult
        sun.directional_shadow_max_distance = p.shadow_distance
        sun.directional_shadow_mode = p.shadow_mode
        sun.directional_shadow_blend_splits = p.shadow_blend
        sun.shadow_blur = p.shadow_blur


static func apply_viewport(level: String, vp: Viewport, scale: float) -> void:
    if level == "none" or vp == null:
        return
    var p := preset(level)
    scale = clampf(scale, 0.5, 1.0)
    vp.scaling_3d_scale = scale
    vp.scaling_3d_mode = p.scale_mode if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
    vp.fsr_sharpness = 0.2
    vp.msaa_3d = p.msaa
    vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
    vp.mesh_lod_threshold = p.lod_threshold


## RenderingServer-wide knobs (they are not per Environment).
static func apply_global(level: String) -> void:
    if level == "none":
        return
    var p := preset(level)
    RenderingServer.directional_shadow_atlas_set_size(p.shadow_size, true)
    RenderingServer.directional_soft_shadow_filter_set_quality(p.soft_shadows)
    if p.ssao:
        RenderingServer.environment_set_ssao_quality(p.ssao_quality, true, 0.5, 2, 50.0, 300.0)
    if p.fog:
        RenderingServer.environment_set_volumetric_fog_volume_size(p.fog_volume_size, p.fog_volume_depth)
        RenderingServer.environment_set_volumetric_fog_filter_active(p.fog_filter)
