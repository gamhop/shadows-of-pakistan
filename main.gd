extends Node3D

const WALK_SPEED := 4.5
const RUN_SPEED := 9.5
const GRAVITY := 20.0
const STICK_RADIUS := 170.0
const RUN_RADIUS := 110.0

const Cities := preload("res://cities.gd")
const CityScript := preload("res://city.gd")
const AvatarScript := preload("res://avatar.gd")
const ModelAvatarScript := preload("res://model_avatar.gd")

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.18, 0.38, 0.75);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.72, 0.82);
uniform vec3 ground_color : source_color = vec3(0.3, 0.4, 0.3);
uniform float cloud_cover = 0.45;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void sky() {
    vec3 d = EYEDIR;
    float h = d.y;
    vec3 col;
    if (h > 0.0) {
        col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));
        col = mix(col, horizon_color * 1.05, exp(-h * 6.0) * 0.5);
        vec2 uv = d.xz / (h + 0.18) * 1.4;
        float n = vnoise(uv) * 0.55 + vnoise(uv * 2.3) * 0.3 + vnoise(uv * 5.1) * 0.15;
        float c = smoothstep(1.0 - cloud_cover, 1.25 - cloud_cover, n);
        c *= smoothstep(0.0, 0.15, h);
        vec3 ccol = mix(vec3(0.72, 0.75, 0.83), vec3(1.0, 0.98, 0.94), n);
        col = mix(col, ccol, c * 0.85);
        if (LIGHT0_ENABLED) {
            float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
            col += LIGHT0_COLOR * (pow(s, 600.0) * 3.0 + pow(s, 12.0) * 0.25);
        }
    } else {
        col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
    }
    COLOR = col;
}
"""

const GROUND_SHADER := """
shader_type spatial;
uniform vec3 col_a : source_color = vec3(0.2, 0.3, 0.16);
uniform vec3 col_b : source_color = vec3(0.24, 0.35, 0.19);
uniform float use_detail = 0.0;
uniform sampler2D detail : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
    float n = vnoise(wpos.xz * 0.12) * 0.6 + vnoise(wpos.xz * 0.9) * 0.4;
    float g = hash21(floor(wpos.xz * 5.0));
    float dt = texture(detail, wpos.xz * 0.25).r * 0.6 + texture(detail, wpos.xz * 0.031).r * 0.4;
    float dk = mix(1.0, 0.45 + 0.7 * dt, use_detail);
    ALBEDO = mix(col_a, col_b, n) * (0.85 + 0.3 * g) * dk;
    ROUGHNESS = 1.0;
}
"""

var player: CharacterBody3D
var ground: StaticBody3D
var cam: Camera3D
var cam_pivot: Node3D
var ui: Control
var stick := Vector2.ZERO
var stick_touch := -1
var look_touch := -1
var run_touch := -1
var run_on := false
var cam_yaw := 0.0
var cam_pitch := -0.12
var health := 100.0
var stamina := 100.0
var exhausted := false

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var ground_mat: ShaderMaterial
var city: Node3D
var survival: CanvasLayer
var combat: CanvasLayer
var city_idx := 0
var avatar: Node3D


func _ready() -> void:
    _make_world()
    _make_player()
    survival = preload("res://survival.gd").new()
    add_child(survival)
    combat = preload("res://combat.gd").new()
    add_child(combat)
    _make_ui()
    add_child(preload("res://settings_menu.gd").new())
    add_child(preload("res://build_label.gd").new())
    add_child(preload("res://audio.gd").new())
    add_child(preload("res://city_menu.gd").new())
    load_city(0)


func load_city(idx: int) -> void:
    var all: Array = Cities.get_all()
    city_idx = clampi(idx, 0, all.size() - 1)
    var t: Dictionary = all[city_idx]
    if city:
        remove_child(city)
        city.queue_free()
    city = CityScript.new()
    city.set("cfg", t)
    add_child(city)
    _apply_theme(t)
    var spawn: Vector3 = city.get("spawn")
    player.position = spawn
    player.velocity = Vector3.ZERO
    cam_yaw = 0.0
    cam_pitch = -0.12
    var lines: Array = city.get("lines")
    survival.call("respawn", lines, int(t["seed"]) + 1)
    combat.call("respawn", lines, int(t["seed"]) + 2)
    survival.call("_show_toast", str(t["name"]))


func _apply_theme(t: Dictionary) -> void:
    var horizon: Color = t["horizon"]
    sky_mat.set_shader_parameter("top_color", t["sky_top"])
    sky_mat.set_shader_parameter("horizon_color", horizon)
    env.fog_light_color = horizon
    env.fog_density = float(t["fog"]) * 0.7
    env.ambient_light_color = t["ambient"]
    sun.light_color = t["sun_color"]
    sun.rotation_degrees = t["sun_rot"]
    ground_mat.set_shader_parameter("col_a", t["ground_a"])
    ground_mat.set_shader_parameter("col_b", t["ground_b"])


func _make_world() -> void:
    var horizon := Color(0.62, 0.72, 0.82)
    var sky_shader := Shader.new()
    sky_shader.code = SKY_SHADER
    sky_mat = ShaderMaterial.new()
    sky_mat.shader = sky_shader
    sky_mat.set_shader_parameter("top_color", Color(0.18, 0.38, 0.75))
    sky_mat.set_shader_parameter("horizon_color", horizon)
    sky_mat.set_shader_parameter("ground_color", Color(0.3, 0.4, 0.3))
    var sky := Sky.new()
    sky.sky_material = sky_mat
    sky.radiance_size = Sky.RADIANCE_SIZE_32
    env = Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.45, 0.5, 0.6)
    env.ambient_light_energy = 0.85
    env.ambient_light_sky_contribution = 0.35
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_white = 6.0
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.1
    env.adjustment_saturation = 1.12
    env.fog_enabled = true
    env.fog_light_color = horizon
    env.fog_density = 0.012
    env.fog_sun_scatter = 0.15
    env.fog_aerial_perspective = 0.15
    env.fog_sky_affect = 0.6
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-68, -30, 0)
    sun.light_color = Color(1.0, 0.95, 0.85)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.shadow_blur = 1.4
    sun.shadow_bias = 0.03
    sun.shadow_normal_bias = 1.0
    sun.directional_shadow_max_distance = 40.0
    add_child(sun)

    var shader := Shader.new()
    shader.code = GROUND_SHADER
    ground_mat = ShaderMaterial.new()
    ground_mat.shader = shader
    if ResourceLoader.exists("res://assets/tex/ground_detail_diff.jpg"):
        ground_mat.set_shader_parameter("detail", load("res://assets/tex/ground_detail_diff.jpg"))
        ground_mat.set_shader_parameter("use_detail", 1.0)
    ground = _add_box(Vector3(0, -0.5, 0), Vector3(700, 1, 700), Color.WHITE, ground_mat)


func _add_box(pos: Vector3, size: Vector3, color: Color, mat: Material = null) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    if mat == null:
        var sm := StandardMaterial3D.new()
        sm.albedo_color = color
        mat = sm
    bm.material = mat
    mesh.mesh = bm
    body.add_child(mesh)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    col.shape = shape
    body.add_child(col)
    add_child(body)
    return body


func _make_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0, 0.1, 0)
    add_child(player)

    var ma := ModelAvatarScript.new()
    if ma.call("setup"):
        avatar = ma
    else:
        ma.free()
        avatar = AvatarScript.new()
        avatar.call("configure", {
            "kameez": Color(0.88, 0.88, 0.82),
            "shalwar": Color(0.88, 0.88, 0.82),
            "skin": Color(0.78, 0.58, 0.44),
            "headwear": 1,
            "beard": true,
        })
    player.add_child(avatar)

    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.4
    shape.height = 1.8
    col.shape = shape
    col.position.y = 0.9
    player.add_child(col)

    cam_pivot = Node3D.new()
    add_child(cam_pivot)
    cam = Camera3D.new()
    cam.fov = 60.0
    cam.far = 400.0
    var arm := SpringArm3D.new()
    arm.spring_length = 5.0
    arm.margin = 0.2
    var arm_shape := SphereShape3D.new()
    arm_shape.radius = 0.3
    arm.shape = arm_shape
    arm.add_excluded_object(player.get_rid())
    cam_pivot.add_child(arm)
    arm.add_child(cam)


func _physics_process(delta: float) -> void:
    cam_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0.0)
    var dir := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, cam_yaw)
    var moving := dir.length() > 0.1
    if not moving:
        run_on = false
    var running := run_on and moving and not exhausted
    if running:
        stamina = maxf(stamina - 18.0 * delta, 0.0)
        if stamina <= 0.0:
            exhausted = true
    else:
        stamina = minf(stamina + 15.0 * delta, 100.0)
        if exhausted and stamina >= 20.0:
            exhausted = false
    var speed := RUN_SPEED if running else WALK_SPEED
    cam.fov = lerpf(cam.fov, 70.0 if running else 60.0, 6.0 * delta)
    player.velocity.x = dir.x * speed
    player.velocity.z = dir.z * speed
    if player.is_on_floor():
        player.velocity.y = 0.0
    else:
        player.velocity.y -= GRAVITY * delta
    player.move_and_slide()
    avatar.call("animate", Vector2(player.velocity.x, player.velocity.z).length(), running, delta)
    ground.position.x = player.position.x
    ground.position.z = player.position.z
    if moving:
        var target := atan2(-dir.x, -dir.z)
        player.rotation.y = lerp_angle(player.rotation.y, target, 12.0 * delta)
    cam_pivot.global_position = player.global_position + Vector3(0, 1.6, 0)


func _process(_delta: float) -> void:
    if ui:
        ui.queue_redraw()


func _stick_base() -> Vector2:
    return Vector2(300.0, get_viewport().get_visible_rect().size.y - 300.0)


func _run_base() -> Vector2:
    var vp := get_viewport().get_visible_rect().size
    return Vector2(vp.x - 280.0, vp.y - 240.0)


func _make_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.draw.connect(_draw_ui)


func _draw_ui() -> void:
    var c := _stick_base()
    ui.draw_circle(c, STICK_RADIUS, Color(1, 1, 1, 0.15))
    ui.draw_circle(c + stick * STICK_RADIUS, 70.0, Color(1, 1, 1, 0.5))

    var r := _run_base()
    var rcol := Color(1, 0.6, 0.2, 0.55) if run_on else Color(1, 1, 1, 0.2)
    ui.draw_circle(r, RUN_RADIUS, rcol)
    ui.draw_string(ThemeDB.fallback_font, r + Vector2(-100, 16), "RUN", HORIZONTAL_ALIGNMENT_CENTER, 200, 48)

    ui.draw_rect(Rect2(140, 50, 500, 26), Color(0, 0, 0, 0.45))
    ui.draw_rect(Rect2(140, 50, 500.0 * health / 100.0, 26), Color(0.85, 0.15, 0.15))
    var scol := Color(0.6, 0.5, 0.3) if exhausted else Color(0.95, 0.8, 0.2)
    ui.draw_rect(Rect2(140, 88, 500, 20), Color(0, 0, 0, 0.45))
    ui.draw_rect(Rect2(140, 88, 500.0 * stamina / 100.0, 20), scol)


func _input(event: InputEvent) -> void:
    var vp := get_viewport().get_visible_rect().size
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if stick_touch == -1 and t.position.distance_to(_stick_base()) < STICK_RADIUS * 1.8:
                stick_touch = t.index
                _update_stick(t.position)
            elif run_touch == -1 and t.position.distance_to(_run_base()) < RUN_RADIUS * 1.4:
                run_on = not run_on
            elif look_touch == -1 and t.position.x > vp.x * 0.4:
                look_touch = t.index
        else:
            if t.index == stick_touch:
                stick_touch = -1
                stick = Vector2.ZERO
            elif t.index == run_touch:
                run_touch = -1
            elif t.index == look_touch:
                look_touch = -1
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == stick_touch:
            _update_stick(d.position)
        elif d.index == look_touch:
            cam_yaw -= d.relative.x * 0.005 * float(Engine.get_meta("cam_sens", 1.0))
            cam_pitch = clampf(cam_pitch - d.relative.y * 0.004 * float(Engine.get_meta("cam_sens", 1.0)), -0.55, 0.2)


func _update_stick(pos: Vector2) -> void:
    stick = ((pos - _stick_base()) / STICK_RADIUS).limit_length(1.0)
