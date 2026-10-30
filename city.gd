extends Node3D

# Grid city: 3x3 blocks, centre block is a plaza with a landmark.
const BLOCK := 50.0
const DEPTH := 10.0
const ROAD_W := 15.0
const PITCH := 65.0
const GRID := 3
const HALF := 105.0

const PedScript := preload("res://ped.gd")

const CAR_COLORS := [Color(0.9, 0.9, 0.9), Color(0.65, 0.66, 0.7), Color(0.08, 0.08, 0.1), Color(0.7, 0.12, 0.12), Color(0.15, 0.25, 0.6)]
const VehicleScript := preload("res://vehicle.gd")
const VEHICLE_MODELS := {
    "humvee": {"path": "res://assets/models/vehicle_humvee.glb", "scale": 1.0, "flip": true, "collider": Vector3(2.5, 2.2, 4.7)},
    "truck": {"path": "res://assets/models/vehicle_truck.glb", "scale": 0.37, "flip": true, "collider": Vector3(4.0, 3.3, 7.5)},
}
const RICKSHAW_COLORS := [Color(0.95, 0.8, 0.1), Color(0.1, 0.5, 0.2), Color(0.15, 0.3, 0.7)]

const SHADER := """
shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.8, 0.75, 0.65);
uniform float half_h = 6.0;
uniform float brick = 0.0;
uniform float use_tex = 0.0;
uniform float tex_scale = 0.4;
uniform float tint = 0.5;
uniform sampler2D wall_tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 lpos;
varying vec3 lnorm;

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

void vertex() {
    lpos = VERTEX;
    lnorm = NORMAL;
}

void fragment() {
    vec3 col = base_color;
    float yy = lpos.y + half_h;
    float h0 = abs(lnorm.x) > 0.5 ? lpos.z : lpos.x;
    vec3 wt = texture(wall_tex, vec2(h0, yy) * tex_scale).rgb;
    if (abs(lnorm.y) < 0.5) {
        float h = lpos.x;
        if (abs(lnorm.x) > 0.5) {
            h = lpos.z;
        }
        float n = vnoise(vec2(h, yy) * 0.7) * 0.6 + vnoise(vec2(h, yy) * 3.1) * 0.4;
        col *= 0.82 + 0.34 * n;
        if (use_tex > 0.5) {
            col = mix(wt, wt * base_color * 2.0, tint) * (0.9 + 0.2 * n);
        } else if (brick > 0.5) {
            float by = yy / 0.12;
            float brow = floor(by);
            float bx = h / 0.3 + 0.5 * mod(brow, 2.0);
            float mortar = max(step(fract(by), 0.1), step(fract(bx), 0.07));
            col = mix(col * 0.8, vec3(0.72, 0.69, 0.64), mortar * 0.7);
        }
        float fy = yy / 3.2;
        float row = floor(fy);
        float fr = fract(fy);
        float fx = h / 3.0;
        float cell = floor(fx);
        float fc = fract(fx);
        if (row < 0.5) {
            float stripe = step(0.5, fract(yy * 4.0));
            col = vec3(0.4, 0.41, 0.45) * (0.8 + 0.2 * stripe) * (0.85 + 0.3 * n);
        } else {
            float fmask = step(0.2, fc) * step(fc, 0.8) * step(0.25, fr) * step(fr, 0.83);
            float gmask = step(0.26, fc) * step(fc, 0.74) * step(0.31, fr) * step(fr, 0.77);
            float lit = step(0.8, hash21(vec2(cell, row)));
            vec3 gcol = mix(vec3(0.1, 0.14, 0.2), vec3(0.45, 0.55, 0.65), fr);
            gcol = mix(gcol, vec3(0.9, 0.75, 0.45), lit * 0.8);
            col = mix(col, vec3(0.55, 0.55, 0.54), fmask);
            col = mix(col, gcol, gmask);
            col *= 1.0 - 0.25 * step(fr, 0.07);
        }
        col *= 0.7 + 0.3 * smoothstep(0.0, 4.0, yy);
    } else if (lnorm.y > 0.5) {
        col = vec3(0.35, 0.35, 0.34) * (0.85 + 0.3 * vnoise(lpos.xz * 0.6));
    }
    ALBEDO = col;
    ROUGHNESS = 0.9;
}
"""

const ROAD_SHADER := """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.13, 0.13, 0.14);
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
    float n = vnoise(wpos.xz * 0.5) * 0.5 + vnoise(wpos.xz * 2.5) * 0.3 + hash21(floor(wpos.xz * 16.0)) * 0.2;
    ALBEDO = base * (0.7 + 0.6 * n);
    ROUGHNESS = 0.95;
}
"""

const TILE_SHADER := """
shader_type spatial;
uniform vec3 base : source_color = vec3(0.55, 0.54, 0.52);
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
    vec2 g = wpos.xz / 1.2;
    vec2 f = fract(g);
    float seam = max(step(f.x, 0.04), step(f.y, 0.04));
    float n = vnoise(wpos.xz * 0.8) * 0.5 + hash21(floor(g)) * 0.25 + 0.25;
    vec3 col = base * (0.8 + 0.35 * n);
    col = mix(col, col * 0.6, seam);
    ALBEDO = col;
    ROUGHNESS = 0.9;
}
"""

const DASH_SHADER := """
shader_type spatial;
uniform float use_x = 0.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float t = mix(wpos.z, wpos.x, use_x);
    if (fract(t / 6.0) > 0.45) { discard; }
    ALBEDO = vec3(0.95, 0.85, 0.2);
}
"""

var cfg: Dictionary = {}
var lines: Array = []
var spawn := Vector3(0, 0.1, 32.5)

var rng := RandomNumberGenerator.new()
var building_shader: Shader
var black_mat: StandardMaterial3D
var mat_cache: Dictionary = {}
var shops: Array = []
var palette: Array = []


func _ready() -> void:
    rng.seed = int(cfg["seed"])
    shops = cfg["shops"]
    palette = cfg["colors"]
    building_shader = Shader.new()
    building_shader.code = SHADER
    black_mat = _mat(Color(0.05, 0.05, 0.05))
    for k in GRID + 1:
        lines.append((k - GRID / 2.0) * PITCH)
    _build_roads()
    _build_blocks()
    _build_border_walls()
    _build_poles_and_cables()
    _build_trees()
    _build_vehicles()
    _build_trash()
    _build_pedestrians()
    if cfg["mountains"]:
        _build_mountains()
    _build_carts()


func _mat(color: Color) -> StandardMaterial3D:
    if mat_cache.has(color):
        return mat_cache[color]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    mat_cache[color] = m
    return m


var tex_cache: Dictionary = {}
var last_vehicle: Node3D


func _tex(tname: String) -> Texture2D:
    if tex_cache.has(tname):
        return tex_cache[tname]
    var path := "res://assets/tex/" + tname + ".jpg"
    var t: Texture2D = null
    if ResourceLoader.exists(path):
        t = load(path) as Texture2D
    tex_cache[tname] = t
    return t


func _pbr_mat(tname: String, scale: float, tint: Color, tint_amt: float) -> StandardMaterial3D:
    var key := "pbr_" + tname + str(scale) + str(tint)
    if mat_cache.has(key):
        return mat_cache[key]
    var d := _tex(tname + "_diff")
    if d == null:
        return null
    var m := StandardMaterial3D.new()
    m.albedo_texture = d
    m.albedo_color = Color.WHITE.lerp(tint, tint_amt)
    var n := _tex(tname + "_nor")
    if n != null:
        m.normal_enabled = true
        m.normal_texture = n
    var r := _tex(tname + "_rough")
    if r != null:
        m.roughness_texture = r
    m.roughness = 1.0
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(scale, scale, scale)
    mat_cache[key] = m
    return m


func _shader_mat(code: String, color: Color) -> ShaderMaterial:
    var key := code.hash()
    var ck := str(key) + str(color)
    if mat_cache.has(ck):
        return mat_cache[ck]
    var sh := Shader.new()
    sh.code = code
    var m := ShaderMaterial.new()
    m.shader = sh
    m.set_shader_parameter("base", color)
    mat_cache[ck] = m
    return m


func _tmat(tname: String, tint: Color, scale: float, fallback: Color) -> StandardMaterial3D:
    var key := "tm_" + tname + str(tint) + str(scale)
    if mat_cache.has(key):
        return mat_cache[key]
    var d := _tex(tname)
    if d == null:
        return _mat(fallback)
    var m := StandardMaterial3D.new()
    m.albedo_texture = d
    m.albedo_color = tint
    m.roughness = 0.85
    m.uv1_triplanar = true
    m.uv1_scale = Vector3(scale, scale, scale)
    mat_cache[key] = m
    return m


func _lm(c: Color) -> StandardMaterial3D:
    return _tmat("concrete_3_diff", Color.WHITE.lerp(c, 0.8), 0.3, c)


func _plaza_mat() -> Material:
    var m: Material = _pbr_mat("tile_2", 0.3, cfg["plaza"], 0.12)
    if m == null:
        m = _shader_mat(TILE_SHADER, cfg["plaza"])
    return m


func _near_road(t: float) -> bool:
    for i in lines.size():
        var c: float = lines[i]
        if absf(t - c) < 10.5:
            return true
    return false


func _mesh_box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D = null, no_shadow: bool = false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    bm.material = mat
    mi.mesh = bm
    mi.position = pos
    if no_shadow:
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if parent:
        parent.add_child(mi)
    else:
        add_child(mi)
    return mi


func _solid(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    body.add_child(cs)
    add_child(body)


func _cyl(pos: Vector3, top_r: float, bot_r: float, h: float, color: Color, segs: int = 16) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = top_r
    cm.bottom_radius = bot_r
    cm.height = h
    cm.radial_segments = segs
    cm.material = _mat(color)
    mi.mesh = cm
    mi.position = pos
    add_child(mi)
    return mi


func _dome(pos: Vector3, r: float, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 20
    sm.rings = 10
    sm.material = _mat(color)
    mi.mesh = sm
    mi.position = pos
    add_child(mi)


# ---------------------------------------------------------------- roads

func _build_roads() -> void:
    var length := GRID * PITCH + ROAD_W
    var road_mat: Material = _pbr_mat("road_2", 0.25, cfg["road"], 0.35)
    if road_mat == null:
        road_mat = _shader_mat(ROAD_SHADER, cfg["road"])
    var dash_shader := Shader.new()
    dash_shader.code = DASH_SHADER
    var dash_z := ShaderMaterial.new()
    dash_z.shader = dash_shader
    dash_z.set_shader_parameter("use_x", 0.0)
    var dash_x := ShaderMaterial.new()
    dash_x.shader = dash_shader
    dash_x.set_shader_parameter("use_x", 1.0)
    for i in lines.size():
        var c: float = lines[i]
        _mesh_box(Vector3(c, 0, 0), Vector3(10, 0.06, length), road_mat, null, true)
        _mesh_box(Vector3(0, 0, c), Vector3(length, 0.06, 10), road_mat, null, true)
        _mesh_box(Vector3(c, 0.034, 0), Vector3(0.18, 0.01, length), dash_z, null, true)
        _mesh_box(Vector3(0, 0.034, c), Vector3(length, 0.01, 0.18), dash_x, null, true)


# ---------------------------------------------------------------- blocks

func _build_blocks() -> void:
    var walk_mat: Material = _pbr_mat("concrete_1", 0.35, cfg["sidewalk"], 0.3)
    if walk_mat == null:
        walk_mat = _shader_mat(TILE_SHADER, cfg["sidewalk"])
    for i in GRID:
        for j in GRID:
            var bx := (i - 1) * PITCH
            var bz := (j - 1) * PITCH
            if i == 1 and j == 1:
                _build_plaza()
                continue
            var platform := Vector3(BLOCK + 5.0, 0.16, BLOCK + 5.0)
            _mesh_box(Vector3(bx, 0, bz), platform, walk_mat, null, true)
            _solid(Vector3(bx, 0, bz), platform)
            var edge := BLOCK / 2.0
            var mid := edge - DEPTH / 2.0
            # north and south strips run along x
            _strip(0, bx - edge, BLOCK, bz - mid, -1.0)
            _strip(0, bx - edge, BLOCK, bz + mid, 1.0)
            # west and east strips run along z (between the corners)
            _strip(1, bz - edge + DEPTH, BLOCK - 2.0 * DEPTH, bx - mid, -1.0)
            _strip(1, bz - edge + DEPTH, BLOCK - 2.0 * DEPTH, bx + mid, 1.0)


func _strip(axis: int, start: float, length: float, across: float, outward: float) -> void:
    var p := start
    var stop := start + length
    while p < stop - 1.0:
        var w := rng.randf_range(10.0, 16.0)
        if p + w > stop or stop - (p + w) < 6.0:
            w = stop - p
        var floors := rng.randi_range(2, 5)
        var h := floors * 3.2 + 0.4
        var mid := p + w / 2.0
        var size: Vector3
        var pos: Vector3
        if axis == 0:
            size = Vector3(w, h, DEPTH)
            pos = Vector3(mid, h / 2.0, across)
        else:
            size = Vector3(DEPTH, h, w)
            pos = Vector3(across, h / 2.0, mid)
        var mat := ShaderMaterial.new()
        mat.shader = building_shader
        mat.set_shader_parameter("base_color", palette[rng.randi() % palette.size()])
        mat.set_shader_parameter("half_h", h / 2.0)
        var is_brick := rng.randf() < float(cfg.get("brick", 0.4))
        mat.set_shader_parameter("brick", 1.0 if is_brick else 0.0)
        var pick := int(absf(pos.x * 7.0 + pos.z * 13.0)) % (4 if is_brick else 2)
        var wall := _tex(("brick_%d" if is_brick else "concrete_%d") % (pick + (1 if is_brick else 2)) + "_diff")
        if wall != null:
            mat.set_shader_parameter("wall_tex", wall)
            mat.set_shader_parameter("use_tex", 1.0)
            mat.set_shader_parameter("tex_scale", (0.7 if pick == 2 else 0.5) if is_brick else 0.35)
            mat.set_shader_parameter("tint", 0.25 if is_brick else 0.6)
        _mesh_box(pos, size, mat)
        _solid(pos, size)
        _add_sign(axis, outward, across, mid, w)
        if rng.randf() < 0.55:
            var tx := pos.x + rng.randf_range(-1.5, 1.5) if axis == 0 else pos.x + rng.randf_range(-2.0, 2.0)
            var tz := pos.z + rng.randf_range(-2.0, 2.0) if axis == 0 else pos.z + rng.randf_range(-1.5, 1.5)
            var tank := _cyl(Vector3(tx, h + 0.6, tz), 0.6, 0.6, 1.2, Color(0.08, 0.09, 0.1), 10)
            tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        p += w


func _add_sign(axis: int, outward: float, across: float, mid: float, w: float) -> void:
    var face := across + outward * (DEPTH / 2.0)
    var col := Color.from_hsv(rng.randf(), 0.7, 0.9)
    var plate_pos: Vector3
    var plate_size: Vector3
    var label_pos: Vector3
    var rot: float
    if axis == 0:
        plate_pos = Vector3(mid, 3.55, face + outward * 0.15)
        plate_size = Vector3(w * 0.8, 0.8, 0.3)
        label_pos = Vector3(mid, 3.55, face + outward * 0.32)
        rot = 180.0 if outward < 0.0 else 0.0
    else:
        plate_pos = Vector3(face + outward * 0.15, 3.55, mid)
        plate_size = Vector3(0.3, 0.8, w * 0.8)
        label_pos = Vector3(face + outward * 0.32, 3.55, mid)
        rot = -90.0 if outward < 0.0 else 90.0
    _mesh_box(plate_pos, plate_size, _mat(col), null, true)
    var awn_cols := [Color(0.72, 0.22, 0.18), Color(0.8, 0.7, 0.5), Color(0.2, 0.5, 0.5), Color(0.35, 0.3, 0.28)]
    var awn_c: Color = awn_cols[int(absf(mid * 3.0 + across)) % awn_cols.size()]
    if axis == 0:
        var aw := _mesh_box(Vector3(mid, 3.0, face + outward * 0.7), Vector3(w * 0.8, 0.05, 1.4), _mat(awn_c), null, true)
        aw.rotation_degrees.x = 12.0 * outward
    else:
        var aw2 := _mesh_box(Vector3(face + outward * 0.7, 3.0, mid), Vector3(1.4, 0.05, w * 0.8), _mat(awn_c), null, true)
        aw2.rotation_degrees.z = -12.0 * outward
    var label := Label3D.new()
    label.text = shops[rng.randi() % shops.size()]
    label.font_size = 64
    label.pixel_size = 0.01
    label.outline_size = 10
    label.position = label_pos
    label.rotation_degrees = Vector3(0, rot, 0)
    add_child(label)


func _build_border_walls() -> void:
    var mat := ShaderMaterial.new()
    mat.shader = building_shader
    mat.set_shader_parameter("base_color", cfg["wall"])
    mat.set_shader_parameter("half_h", 7.0)
    var wall_t := _tex("concrete_3_diff")
    if wall_t != null:
        mat.set_shader_parameter("wall_tex", wall_t)
        mat.set_shader_parameter("use_tex", 1.0)
        mat.set_shader_parameter("tex_scale", 0.3)
        mat.set_shader_parameter("tint", 0.5)
    var span := 2.0 * HALF + 4.0
    for s in [-1.0, 1.0]:
        var pz := Vector3(0, 7.0, s * (HALF + 1.0))
        _mesh_box(pz, Vector3(span, 14, 2), mat)
        _solid(pz, Vector3(span, 14, 2))
        var px := Vector3(s * (HALF + 1.0), 7.0, 0)
        _mesh_box(px, Vector3(2, 14, span), mat)
        _solid(px, Vector3(2, 14, span))


# ---------------------------------------------------------------- poles, trees

func _pole(x: float, z: float, along_x: bool) -> void:
    var wood := _mat(Color(0.25, 0.2, 0.15))
    _mesh_box(Vector3(x, 4.0, z), Vector3(0.25, 8.0, 0.25), wood)
    var arm := Vector3(0.15, 0.15, 2.0) if along_x else Vector3(2.0, 0.15, 0.15)
    _mesh_box(Vector3(x, 7.4, z), arm, wood, null, true)
    _solid(Vector3(x, 4.0, z), Vector3(0.25, 8.0, 0.25))


func _build_poles_and_cables() -> void:
    var cable := _mat(Color(0.05, 0.05, 0.05))
    var cable_len := 2.0 * HALF
    for i in lines.size():
        var c: float = lines[i]
        var off := 5.4
        var t := -HALF + 12.0
        while t < HALF - 8.0:
            if not _near_road(t):
                _pole(c + off, t, false)
                _pole(t, c + off, true)
            t += 30.0
        for o in [-0.8, 0.0, 0.8]:
            _mesh_box(Vector3(c + off + o, 7.45, 0), Vector3(0.04, 0.04, cable_len), cable, null, true)
            _mesh_box(Vector3(0, 7.45, c + off + o), Vector3(cable_len, 0.04, 0.04), cable, null, true)


func _tree(x: float, z: float) -> void:
    var trunk := _tmat("bark_diff", Color.WHITE, 0.9, Color(0.3, 0.2, 0.12))
    var leaf := _tmat("leaf_diff", cfg["leaf"], 0.8, cfg["leaf"])
    _mesh_box(Vector3(x, 1.5, z), Vector3(0.3, 3.0, 0.3), trunk)
    _solid(Vector3(x, 1.5, z), Vector3(0.3, 3.0, 0.3))
    var crown := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 1.4
    sm.height = 2.8
    sm.radial_segments = 12
    sm.rings = 6
    sm.material = leaf
    crown.mesh = sm
    crown.position = Vector3(x, 4.2, z)
    add_child(crown)


func _build_trees() -> void:
    for i in lines.size():
        var c: float = lines[i]
        for side in [-1.0, 1.0]:
            var t := -HALF + 8.0 + rng.randf_range(0.0, 10.0)
            while t < HALF - 8.0:
                if not _near_road(t):
                    _tree(c + side * 6.5, t)
                if t + 11.0 < HALF - 8.0 and not _near_road(t + 11.0):
                    _tree(t + 11.0, c + side * 6.5)
                t += rng.randf_range(26.0, 40.0)


# ---------------------------------------------------------------- vehicles

func _vehicle_body(pos: Vector3, size: Vector3, rot: float) -> CharacterBody3D:
    var body := CharacterBody3D.new()
    body.set_script(VehicleScript)
    body.set_meta("size", size)
    body.position = pos
    body.rotation.y = rot
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    cs.position.y = size.y / 2.0
    body.add_child(cs)
    add_child(body)
    last_vehicle = body
    return body


func _wheel(parent: Node3D, pos: Vector3, r: float, wd: float) -> void:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = wd
    cm.radial_segments = 12
    cm.material = black_mat
    mi.mesh = cm
    mi.rotation_degrees = Vector3(0, 0, 90)
    mi.position = pos
    parent.add_child(mi)


func _glass() -> StandardMaterial3D:
    if mat_cache.has("glass"):
        return mat_cache["glass"]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.07, 0.1, 0.13, 0.45)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 0.15
    m.metallic = 0.4
    mat_cache["glass"] = m
    return m


func _lamp(color: Color) -> StandardMaterial3D:
    var key := "lamp" + str(color)
    if mat_cache.has(key):
        return mat_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_cache[key] = m
    return m


func _tilt(mi: MeshInstance3D, deg_x: float) -> void:
    mi.rotation_degrees.x = deg_x


func _plate_label(parent: Node3D, pos: Vector3, text: String, facing_back: bool) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 40
    l.pixel_size = 0.004
    l.outline_size = 0
    l.modulate = Color(0.05, 0.05, 0.05)
    l.position = pos
    l.shaded = false
    if not facing_back:
        l.rotation_degrees = Vector3(0, 180, 0)
    parent.add_child(l)


func _make_car(pos: Vector3, rot: float) -> void:
    # Suzuki Mehran style hatchback. Front is -Z.
    var body := _vehicle_body(pos, Vector3(1.9, 1.5, 4.2), rot)
    var car_c: Color = CAR_COLORS[rng.randi() % CAR_COLORS.size()]
    var cm := _tmat("metal_diff", car_c, 0.6, car_c)
    var trim := _mat(Color(0.07, 0.07, 0.08))
    _mesh_box(Vector3(0, 0.62, 0), Vector3(1.55, 0.55, 3.5), cm, body)
    _mesh_box(Vector3(0, 0.95, -1.2), Vector3(1.5, 0.1, 1.0), cm, body)
    _mesh_box(Vector3(0, 1.22, 0.3), Vector3(1.45, 0.62, 1.9), cm, body)
    var ws := _mesh_box(Vector3(0, 1.22, -0.78), Vector3(1.38, 0.06, 0.8), _glass(), body, true)
    _tilt(ws, 40.0)
    var rw := _mesh_box(Vector3(0, 1.22, 1.35), Vector3(1.38, 0.06, 0.7), _glass(), body, true)
    _tilt(rw, -40.0)
    _mesh_box(Vector3(0, 1.26, 0.3), Vector3(1.485, 0.32, 1.6), _glass(), body, true)
    _mesh_box(Vector3(0, 0.42, -1.76), Vector3(1.62, 0.22, 0.14), trim, body)
    _mesh_box(Vector3(0, 0.42, 1.76), Vector3(1.62, 0.22, 0.14), trim, body)
    _mesh_box(Vector3(0, 0.7, -1.76), Vector3(0.7, 0.14, 0.04), trim, body, true)
    for sx in [-0.52, 0.52]:
        _mesh_box(Vector3(sx, 0.76, -1.76), Vector3(0.3, 0.16, 0.05), _lamp(Color(0.95, 0.92, 0.75)), body, true)
        _mesh_box(Vector3(sx, 0.78, 1.76), Vector3(0.26, 0.14, 0.05), _lamp(Color(0.8, 0.08, 0.06)), body, true)
    _mesh_box(Vector3(0, 0.42, -1.84), Vector3(0.46, 0.12, 0.02), _mat(Color(0.9, 0.9, 0.85)), body, true)
    for sx in [-0.78, 0.78]:
        for sz in [-1.1, 1.1]:
            _wheel(body, Vector3(sx, 0.31, sz), 0.31, 0.2)


func _make_model_vehicle(key: String, pos: Vector3, rot: float) -> bool:
    var info: Dictionary = VEHICLE_MODELS[key]
    var path: String = info["path"]
    if not ResourceLoader.exists(path):
        return false
    var scene := load(path) as PackedScene
    if scene == null:
        return false
    var inst := scene.instantiate() as Node3D
    if inst == null:
        return false
    var csize: Vector3 = info["collider"]
    var body := _vehicle_body(pos, csize, rot)
    var s: float = info["scale"]
    inst.scale = Vector3.ONE * s
    if info["flip"]:
        inst.rotation.y = PI
    body.add_child(inst)
    _limit_view(inst, 90.0)
    return true


func _limit_view(n: Node, dist: float) -> void:
    var g := n as GeometryInstance3D
    if g:
        g.visibility_range_end = dist
        g.visibility_range_end_margin = 5.0
    for ch in n.get_children():
        _limit_view(ch, dist)


func _make_rickshaw(pos: Vector3, rot: float) -> void:
    # Auto rickshaw: green body, yellow header, black hood. Front is -Z.
    var body := _vehicle_body(pos, Vector3(1.3, 2.0, 2.6), rot)
    var rick_c: Color = RICKSHAW_COLORS[rng.randi() % RICKSHAW_COLORS.size()]
    var top_c := Color(0.86, 0.66, 0.06)
    if rick_c.r > 0.5 and rick_c.g > 0.5:
        top_c = Color(0.0, 0.33, 0.14)
    var cm := _tmat("metal_diff", rick_c, 0.6, rick_c)
    var tm := _tmat("metal_diff", top_c, 0.6, top_c)
    var black := _mat(Color(0.06, 0.06, 0.06))
    var gray := _mat(Color(0.45, 0.45, 0.47))
    _mesh_box(Vector3(0, 0.62, 0.15), Vector3(1.15, 0.62, 2.1), cm, body)
    _mesh_box(Vector3(0, 0.78, -1.1), Vector3(0.85, 0.7, 0.5), cm, body)
    _mesh_box(Vector3(0, 0.55, 0.15), Vector3(1.17, 0.06, 1.4), _mat(Color(0.1, 0.3, 0.8)), body, true)
    var ws := _mesh_box(Vector3(0, 1.45, -0.98), Vector3(0.95, 0.75, 0.05), _glass(), body, true)
    _tilt(ws, 18.0)
    _mesh_box(Vector3(0, 1.95, -0.9), Vector3(1.05, 0.16, 0.45), tm, body)
    _mesh_box(Vector3(0, 2.0, 0.3), Vector3(1.25, 0.08, 1.95), black, body)
    for sx in [-0.56, 0.56]:
        _mesh_box(Vector3(sx, 1.45, -0.8), Vector3(0.05, 1.0, 0.05), gray, body, true)
        _mesh_box(Vector3(sx, 1.45, 1.1), Vector3(0.05, 1.0, 0.05), gray, body, true)
    _mesh_box(Vector3(0, 1.45, 1.15), Vector3(1.15, 0.9, 0.04), _mat(Color(0.15, 0.15, 0.16)), body, true)
    _mesh_box(Vector3(0, 1.0, 0.55), Vector3(0.95, 0.2, 0.5), _mat(Color(0.55, 0.08, 0.08)), body, true)
    _mesh_box(Vector3(0, 1.28, 0.85), Vector3(0.95, 0.45, 0.1), black, body, true)
    _mesh_box(Vector3(0, 0.64, -1.42), Vector3(0.5, 0.1, 0.7), black, body, true)
    _mesh_box(Vector3(0, 0.88, -1.37), Vector3(0.22, 0.12, 0.05), _lamp(Color(0.95, 0.92, 0.75)), body, true)
    _mesh_box(Vector3(0, 0.5, -1.38), Vector3(0.38, 0.18, 0.02), _mat(Color(0.95, 0.55, 0.05)), body, true)
    _plate_label(body, Vector3(0, 0.95, 1.2), "CNG", true)
    _wheel(body, Vector3(0, 0.3, -1.15), 0.3, 0.16)
    _wheel(body, Vector3(-0.6, 0.3, 0.75), 0.3, 0.2)
    _wheel(body, Vector3(0.6, 0.3, 0.75), 0.3, 0.2)


func _make_bike(pos: Vector3, rot: float) -> void:
    var body := _vehicle_body(pos, Vector3(0.6, 1.1, 1.9), rot)
    var bike_c := Color.from_hsv(rng.randf(), 0.6, 0.6)
    var cm := _tmat("metal_diff", bike_c, 0.8, bike_c)
    _mesh_box(Vector3(0, 0.65, 0), Vector3(0.4, 0.45, 1.3), cm, body)
    _mesh_box(Vector3(0, 0.95, 0.1), Vector3(0.35, 0.12, 0.6), black_mat, body)
    _wheel(body, Vector3(0, 0.3, -0.7), 0.3, 0.15)
    _wheel(body, Vector3(0, 0.3, 0.7), 0.3, 0.15)


func _build_vehicles() -> void:
    var traffic: float = cfg["traffic"]
    var offs := [3.8, 4.1, 4.4, 4.6, 5.3]
    var humvees := 0
    var trucks := 0
    for i in lines.size():
        var c: float = lines[i]
        for orient in 2:
            var t := -HALF + 14.0 + rng.randf_range(0.0, 8.0)
            while t < HALF - 14.0:
                if not _near_road(t):
                    var side := 1.0 if rng.randf() < 0.5 else -1.0
                    var kind := rng.randi() % 3
                    var roll := rng.randf()
                    if roll < 0.15 and humvees < 4:
                        kind = 3
                        humvees += 1
                    elif roll > 0.93 and trucks < 1:
                        kind = 4
                        trucks += 1
                    var off: float = offs[kind] * side
                    var pos: Vector3
                    var rot := 0.0
                    if orient == 0:
                        pos = Vector3(c + off, 0.03, t)
                    else:
                        pos = Vector3(t, 0.03, c + off)
                        rot = PI / 2.0
                    match kind:
                        0:
                            _make_car(pos, rot)
                        1:
                            _make_rickshaw(pos, rot)
                        2:
                            _make_bike(pos, rot)
                        3:
                            if not _make_model_vehicle("humvee", pos, rot):
                                _make_car(pos, rot)
                        4:
                            if not _make_model_vehicle("truck", pos, rot):
                                _make_car(pos, rot)
                t += rng.randf_range(17.0, 30.0) / traffic


# ---------------------------------------------------------------- hand carts

func _build_carts() -> void:
    var cloth := _mat(Color(0.7, 0.08, 0.08))
    var wood := _mat(Color(0.35, 0.24, 0.14))
    var fruit_cols := [Color(0.95, 0.75, 0.1), Color(0.9, 0.35, 0.1), Color(0.8, 0.1, 0.1), Color(0.35, 0.6, 0.15)]
    for n in 8:
        var c: float = lines[rng.randi() % lines.size()]
        var along := rng.randf_range(-HALF + 12.0, HALF - 12.0)
        if _near_road(along):
            continue
        var off := 5.6 if rng.randf() < 0.5 else -5.6
        var x := c + off
        var z := along
        var rot := 0.0
        if rng.randf() < 0.5:
            x = along
            z = c + off
            rot = PI / 2.0
        var root := Node3D.new()
        root.position = Vector3(x, 0.16, z)
        root.rotation.y = rot
        add_child(root)
        _mesh_box(Vector3(0, 0.85, 0), Vector3(0.9, 0.08, 1.6), wood, root)
        _mesh_box(Vector3(0, 0.95, 0), Vector3(1.0, 0.04, 1.7), cloth, root, true)
        for sx in [-0.45, 0.45]:
            for sz in [-0.7, 0.7]:
                _mesh_box(Vector3(sx, 0.42, sz), Vector3(0.06, 0.85, 0.06), wood, root, true)
        for k in 14:
            var f := MeshInstance3D.new()
            var sm := SphereMesh.new()
            sm.radius = 0.09
            sm.height = 0.18
            sm.radial_segments = 6
            sm.rings = 3
            sm.material = _mat(fruit_cols[rng.randi() % fruit_cols.size()])
            f.mesh = sm
            f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            f.position = Vector3(rng.randf_range(-0.38, 0.38), 1.06, rng.randf_range(-0.7, 0.7))
            root.add_child(f)
        _wheel(root, Vector3(-0.52, 0.3, 0.0), 0.3, 0.05)
        _wheel(root, Vector3(0.52, 0.3, 0.0), 0.3, 0.05)
        _solid(Vector3(x, 0.7, z), Vector3(1.1, 1.4, 1.8) if rot == 0.0 else Vector3(1.8, 1.4, 1.1))


# ---------------------------------------------------------------- trash

func _build_trash() -> void:
    var bag := _mat(Color(0.08, 0.1, 0.08))
    var bag2 := _mat(Color(0.55, 0.5, 0.4))
    for n in 36:
        var c: float = lines[rng.randi() % lines.size()]
        var along := rng.randf_range(-HALF + 6.0, HALF - 6.0)
        var off := rng.randf_range(5.3, 7.2)
        if rng.randf() < 0.5:
            off = -off
        var x := c + off
        var z := along
        if rng.randf() < 0.5:
            x = along
            z = c + off
        for j in rng.randi_range(2, 4):
            var mi := MeshInstance3D.new()
            var sm := SphereMesh.new()
            sm.radius = rng.randf_range(0.2, 0.35)
            sm.height = sm.radius * 1.6
            sm.radial_segments = 8
            sm.rings = 4
            sm.material = bag if rng.randf() < 0.6 else bag2
            mi.mesh = sm
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            mi.position = Vector3(x + rng.randf_range(-0.5, 0.5), 0.1 + sm.radius * 0.7, z + rng.randf_range(-0.5, 0.5))
            add_child(mi)


# ---------------------------------------------------------------- pedestrians

func _build_pedestrians() -> void:
    for n in 12:
        var c: float = lines[rng.randi() % lines.size()]
        var side := 1.0 if rng.randf() < 0.5 else -1.0
        var p: Node3D = PedScript.new()
        p.set("orient", rng.randi() % 2)
        p.set("line_c", c + side * 7.0)
        p.set("lo", -HALF + 10.0)
        p.set("hi", HALF - 10.0)
        p.set("t", rng.randf_range(-HALF + 10.0, HALF - 10.0))
        p.set("dir", 1.0 if rng.randf() < 0.5 else -1.0)
        p.set("seed_v", int(cfg["seed"]) * 10 + n)
        add_child(p)


# ---------------------------------------------------------------- mountains

func _build_mountains() -> void:
    var count := 18
    for i in count:
        var ang := TAU * float(i) / float(count) + rng.randf_range(-0.1, 0.1)
        var r := rng.randf_range(215.0, 250.0)
        var h := rng.randf_range(40.0, 85.0)
        var br := rng.randf_range(35.0, 60.0)
        var mi := _cyl(Vector3(cos(ang) * r, h / 2.0 - 1.0, sin(ang) * r), 1.0, br, h, cfg["mountain_col"], 7)
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- plaza + landmarks

func _build_plaza() -> void:
    var platform := Vector3(BLOCK + 5.0, 0.16, BLOCK + 5.0)
    _mesh_box(Vector3(0, 0, 0), platform, _plaza_mat(), null, true)
    _solid(Vector3(0, 0, 0), platform)
    for sx in [-20.0, 20.0]:
        for sz in [-20.0, 20.0]:
            _tree(sx, sz)
    var lc: Color = cfg["land_col"]
    match str(cfg["landmark"]):
        "clock":
            _lm_clock(lc)
        "minar":
            _lm_minar(lc)
        "mosque":
            _lm_mosque(lc)
        "gate":
            _lm_gate(lc)
        "fountain":
            _lm_fountain(lc)
        "shrine":
            _lm_shrine(lc)


func _lm_clock(c: Color) -> void:
    _mesh_box(Vector3(0, 1.1, 0), Vector3(8, 2, 8), _lm(c))
    _mesh_box(Vector3(0, 11, 0), Vector3(4, 18, 4), _lm(c))
    _mesh_box(Vector3(0, 21.5, 0), Vector3(5.4, 5.4, 5.4), _lm(c.darkened(0.15)))
    var face := _mat(Color(0.95, 0.95, 0.9))
    _mesh_box(Vector3(0, 21.5, 2.75), Vector3(3.6, 3.6, 0.1), face, null, true)
    _mesh_box(Vector3(0, 21.5, -2.75), Vector3(3.6, 3.6, 0.1), face, null, true)
    _mesh_box(Vector3(2.75, 21.5, 0), Vector3(0.1, 3.6, 3.6), face, null, true)
    _mesh_box(Vector3(-2.75, 21.5, 0), Vector3(0.1, 3.6, 3.6), face, null, true)
    var roof := _cyl(Vector3(0, 26.7, 0), 0.0, 3.9, 5.0, c.darkened(0.3), 4)
    roof.rotation_degrees.y = 45.0
    _solid(Vector3(0, 12, 0), Vector3(5, 24, 5))


func _lm_minar(c: Color) -> void:
    _cyl(Vector3(0, 0.9, 0), 5.5, 5.5, 1.6, c.darkened(0.1))
    _cyl(Vector3(0, 17, 0), 2.0, 3.2, 32.0, c)
    _cyl(Vector3(0, 33.2, 0), 2.8, 2.8, 0.8, c.darkened(0.2))
    _dome(Vector3(0, 33.6, 0), 2.4, Color(0.8, 0.7, 0.35))
    _solid(Vector3(0, 17, 0), Vector3(5, 34, 5))


func _lm_mosque(c: Color) -> void:
    _mesh_box(Vector3(0, 5, 0), Vector3(20, 10, 20), _lm(c))
    var roof := _cyl(Vector3(0, 15, 0), 0.0, 14.2, 10.0, c.darkened(0.05), 4)
    roof.rotation_degrees.y = 45.0
    _solid(Vector3(0, 5, 0), Vector3(20, 10, 20))
    for sx in [-13.0, 13.0]:
        for sz in [-13.0, 13.0]:
            _cyl(Vector3(sx, 16, sz), 0.9, 1.1, 32.0, c)
            _cyl(Vector3(sx, 33.5, sz), 0.0, 1.3, 3.0, c.darkened(0.2), 12)
            _solid(Vector3(sx, 16, sz), Vector3(2, 32, 2))


func _lm_gate(c: Color) -> void:
    for sx in [-7.0, 7.0]:
        _mesh_box(Vector3(sx, 7.0, 0), Vector3(4, 14, 4), _lm(c))
        _solid(Vector3(sx, 7.0, 0), Vector3(4, 14, 4))
    _mesh_box(Vector3(0, 15, 0), Vector3(18, 4, 4), _lm(c))
    _solid(Vector3(0, 15, 0), Vector3(18, 4, 4))
    for k in 5:
        _mesh_box(Vector3(-7.2 + k * 3.6, 17.6, 0), Vector3(1.8, 1.2, 4), _lm(c.darkened(0.15)))


func _lm_fountain(c: Color) -> void:
    _cyl(Vector3(0, 0.4, 0), 8.0, 8.0, 0.8, c)
    _cyl(Vector3(0, 0.55, 0), 7.0, 7.0, 0.8, Color(0.25, 0.5, 0.7))
    _cyl(Vector3(0, 3, 0), 0.8, 1.2, 6.0, c)
    _dome(Vector3(0, 6.2, 0), 1.6, c.lightened(0.1))
    _solid(Vector3(0, 1, 0), Vector3(14, 2, 14))


func _lm_shrine(c: Color) -> void:
    var wall := _lm(Color(0.9, 0.85, 0.72))
    _mesh_box(Vector3(0, 4, 0), Vector3(16, 8, 16), wall)
    _mesh_box(Vector3(0, 8.2, 0), Vector3(14, 0.5, 14), _lm(c))
    _dome(Vector3(0, 8.4, 0), 6.0, c)
    _solid(Vector3(0, 4, 0), Vector3(16, 8, 16))
    for sx in [-9.0, 9.0]:
        for sz in [-9.0, 9.0]:
            _mesh_box(Vector3(sx, 5, sz), Vector3(3, 10, 3), wall)
            _dome(Vector3(sx, 10, sz), 2.2, c)
            _solid(Vector3(sx, 5, sz), Vector3(3, 10, 3))
