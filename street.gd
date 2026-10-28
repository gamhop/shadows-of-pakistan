extends Node3D

const BUILD_X := 7.5
const HALF_LEN := 80.0
const SHOP_NAMES := ["CHAI HOTEL", "BAKERY", "MOBILE CENTER", "KARYANA STORE", "TAILORS", "PHARMACY", "SWEETS", "BARBER", "GARMENTS", "FRUIT SHOP", "TYRE SHOP", "RESTAURANT"]
const BUILDING_COLORS := [Color(0.85, 0.8, 0.68), Color(0.6, 0.72, 0.8), Color(0.85, 0.65, 0.65), Color(0.8, 0.65, 0.3), Color(0.6, 0.35, 0.28), Color(0.65, 0.78, 0.6), Color(0.62, 0.62, 0.6), Color(0.88, 0.86, 0.82)]
const CAR_COLORS := [Color(0.9, 0.9, 0.9), Color(0.65, 0.66, 0.7), Color(0.08, 0.08, 0.1), Color(0.7, 0.12, 0.12), Color(0.15, 0.25, 0.6)]
const RICKSHAW_COLORS := [Color(0.95, 0.8, 0.1), Color(0.1, 0.5, 0.2), Color(0.15, 0.3, 0.7)]
const SHADER := """
shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.8, 0.75, 0.65);
uniform float half_h = 6.0;
varying vec3 lpos;
varying vec3 lnorm;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
    lpos = VERTEX;
    lnorm = NORMAL;
}

void fragment() {
    vec3 col = base_color;
    if (abs(lnorm.y) < 0.5) {
        float h = lpos.x;
        if (abs(lnorm.x) > 0.5) {
            h = lpos.z;
        }
        float fy = (lpos.y + half_h) / 3.2;
        float row = floor(fy);
        float fr = fract(fy);
        float fx = h / 3.0;
        float cell = floor(fx);
        float fc = fract(fx);
        if (row < 0.5) {
            float stripe = step(0.5, fract((lpos.y + half_h) * 4.0));
            col = vec3(0.45, 0.46, 0.5) * (0.8 + 0.2 * stripe);
        } else {
            float win = step(0.25, fc) * step(fc, 0.75) * step(0.3, fr) * step(fr, 0.78);
            float lit = step(0.72, hash(vec2(cell, row)));
            vec3 glass = mix(vec3(0.07, 0.09, 0.13), vec3(0.85, 0.7, 0.4), lit);
            col = mix(col, glass, win);
            col = col * (1.0 - 0.18 * step(fr, 0.07));
        }
    }
    ALBEDO = col;
    ROUGHNESS = 1.0;
}
"""

var rng := RandomNumberGenerator.new()
var building_shader: Shader
var black_mat: StandardMaterial3D


func _ready() -> void:
    rng.seed = 11
    building_shader = Shader.new()
    building_shader.code = SHADER
    black_mat = _mat(Color(0.05, 0.05, 0.05))
    _build_road()
    _build_buildings(-1)
    _build_buildings(1)
    _build_end_walls()
    _build_poles_and_cables()
    _build_trees()
    _build_vehicles()
    _build_trash()


func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    return m


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


func _build_road() -> void:
    _mesh_box(Vector3(0, 0, 0), Vector3(10, 0.06, HALF_LEN * 2), _mat(Color(0.13, 0.13, 0.14)), null, true)
    for side in [-1, 1]:
        _mesh_box(Vector3(side * 6.25, 0, 0), Vector3(2.5, 0.16, HALF_LEN * 2), _mat(Color(0.55, 0.54, 0.52)), null, true)
        _solid(Vector3(side * 6.25, 0, 0), Vector3(2.5, 0.16, HALF_LEN * 2))
        _mesh_box(Vector3(side * 4.7, 0.032, 0), Vector3(0.12, 0.01, HALF_LEN * 2), _mat(Color(0.9, 0.9, 0.9)), null, true)
    var sh := Shader.new()
    sh.code = "shader_type spatial;\nvarying float wz;\nvoid vertex() { wz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z; }\nvoid fragment() {\n  if (fract(wz / 6.0) > 0.45) { discard; }\n  ALBEDO = vec3(0.95, 0.85, 0.2);\n}\n"
    var sm := ShaderMaterial.new()
    sm.shader = sh
    _mesh_box(Vector3(0, 0.034, 0), Vector3(0.18, 0.01, HALF_LEN * 2), sm, null, true)


func _build_buildings(side: int) -> void:
    var z := -HALF_LEN
    while z < HALF_LEN - 1.0:
        var w := rng.randf_range(8.0, 14.0)
        if z + w > HALF_LEN or HALF_LEN - (z + w) < 5.0:
            w = HALF_LEN - z
        var floors := rng.randi_range(2, 5)
        var h := floors * 3.2 + 0.4
        var depth := 10.0
        var cx := side * (BUILD_X + depth / 2.0)
        var cz := z + w / 2.0
        var mat := ShaderMaterial.new()
        mat.shader = building_shader
        mat.set_shader_parameter("base_color", BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()])
        mat.set_shader_parameter("half_h", h / 2.0)
        _mesh_box(Vector3(cx, h / 2.0, cz), Vector3(depth, h, w), mat)
        _solid(Vector3(cx, h / 2.0, cz), Vector3(depth, h, w))
        _add_sign(side, cz, w)
        z += w


func _add_sign(side: int, cz: float, w: float) -> void:
    var x := side * (BUILD_X - 0.15)
    var col := Color.from_hsv(rng.randf(), 0.7, 0.9)
    _mesh_box(Vector3(x, 3.55, cz), Vector3(0.3, 0.8, w * 0.8), _mat(col), null, true)
    var label := Label3D.new()
    label.text = SHOP_NAMES[rng.randi() % SHOP_NAMES.size()]
    label.font_size = 64
    label.pixel_size = 0.01
    label.outline_size = 10
    label.position = Vector3(side * (BUILD_X - 0.32), 3.55, cz)
    label.rotation_degrees = Vector3(0, -side * 90.0, 0)
    add_child(label)


func _build_end_walls() -> void:
    for s in [-1, 1]:
        var mat := ShaderMaterial.new()
        mat.shader = building_shader
        mat.set_shader_parameter("base_color", Color(0.75, 0.6, 0.5))
        mat.set_shader_parameter("half_h", 7.0)
        var pos := Vector3(0, 7.0, s * (HALF_LEN + 0.5))
        _mesh_box(pos, Vector3(36, 14, 1), mat)
        _solid(pos, Vector3(36, 14, 1))


func _build_poles_and_cables() -> void:
    var wood := _mat(Color(0.25, 0.2, 0.15))
    var cable := _mat(Color(0.05, 0.05, 0.05))
    for side in [-1, 1]:
        var x: float = side * 5.4
        var z := -HALF_LEN + 10.0
        while z < HALF_LEN:
            _mesh_box(Vector3(x, 4.0, z), Vector3(0.25, 8.0, 0.25), wood)
            _mesh_box(Vector3(x, 7.4, z), Vector3(2.0, 0.15, 0.15), wood, null, true)
            _solid(Vector3(x, 4.0, z), Vector3(0.25, 8.0, 0.25))
            z += 24.0
        for off in [-0.8, 0.0, 0.8]:
            _mesh_box(Vector3(x + off, 7.45, 0), Vector3(0.04, 0.04, HALF_LEN * 2), cable, null, true)


func _build_trees() -> void:
    var trunk := _mat(Color(0.3, 0.2, 0.12))
    var leaf := _mat(Color(0.15, 0.4, 0.15))
    for side in [-1, 1]:
        var z := -HALF_LEN + 6.0
        while z < HALF_LEN - 6.0:
            var x: float = side * 6.5
            var tz := z + rng.randf_range(-3.0, 3.0)
            _mesh_box(Vector3(x, 1.5, tz), Vector3(0.3, 3.0, 0.3), trunk)
            _solid(Vector3(x, 1.5, tz), Vector3(0.3, 3.0, 0.3))
            var crown := MeshInstance3D.new()
            var sm := SphereMesh.new()
            sm.radius = 1.4
            sm.height = 2.8
            sm.radial_segments = 12
            sm.rings = 6
            sm.material = leaf
            crown.mesh = sm
            crown.position = Vector3(x, 4.2, tz)
            add_child(crown)
            z += rng.randf_range(18.0, 28.0)


func _vehicle_body(pos: Vector3, size: Vector3) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    cs.position.y = size.y / 2.0
    body.add_child(cs)
    add_child(body)
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


func _make_car(pos: Vector3) -> void:
    var body := _vehicle_body(pos, Vector3(1.9, 1.5, 4.2))
    var cm := _mat(CAR_COLORS[rng.randi() % CAR_COLORS.size()])
    _mesh_box(Vector3(0, 0.65, 0), Vector3(1.9, 0.7, 4.2), cm, body)
    _mesh_box(Vector3(0, 1.15, -0.2), Vector3(1.6, 0.6, 2.3), cm, body)
    _mesh_box(Vector3(0, 1.22, -0.2), Vector3(1.62, 0.3, 2.0), _mat(Color(0.06, 0.08, 0.1)), body, true)
    for sx in [-0.9, 0.9]:
        for sz in [-1.3, 1.3]:
            _wheel(body, Vector3(sx, 0.35, sz), 0.35, 0.25)


func _make_rickshaw(pos: Vector3) -> void:
    var body := _vehicle_body(pos, Vector3(1.3, 2.0, 2.6))
    var cm := _mat(RICKSHAW_COLORS[rng.randi() % RICKSHAW_COLORS.size()])
    _mesh_box(Vector3(0, 0.7, 0.1), Vector3(1.2, 0.8, 2.2), cm, body)
    _mesh_box(Vector3(0, 1.5, 0.35), Vector3(1.15, 0.8, 1.6), cm, body)
    _mesh_box(Vector3(0, 1.5, -0.46), Vector3(1.0, 0.5, 0.05), _mat(Color(0.06, 0.08, 0.1)), body, true)
    _mesh_box(Vector3(0, 1.94, 0.2), Vector3(1.3, 0.08, 1.9), _mat(Color(0.05, 0.05, 0.05)), body)
    _wheel(body, Vector3(0, 0.3, -1.0), 0.3, 0.2)
    _wheel(body, Vector3(-0.6, 0.3, 0.7), 0.3, 0.2)
    _wheel(body, Vector3(0.6, 0.3, 0.7), 0.3, 0.2)


func _make_bike(pos: Vector3) -> void:
    var body := _vehicle_body(pos, Vector3(0.6, 1.1, 1.9))
    var cm := _mat(Color.from_hsv(rng.randf(), 0.6, 0.6))
    _mesh_box(Vector3(0, 0.65, 0), Vector3(0.4, 0.45, 1.3), cm, body)
    _mesh_box(Vector3(0, 0.95, 0.1), Vector3(0.35, 0.12, 0.6), black_mat, body)
    _wheel(body, Vector3(0, 0.3, -0.7), 0.3, 0.15)
    _wheel(body, Vector3(0, 0.3, 0.7), 0.3, 0.15)


func _build_vehicles() -> void:
    var z := -HALF_LEN + 12.0
    while z < HALF_LEN - 12.0:
        var side := 1 if rng.randf() < 0.5 else -1
        var kind := rng.randi() % 3
        match kind:
            0:
                _make_car(Vector3(side * 3.8, 0.03, z))
            1:
                _make_rickshaw(Vector3(side * 4.1, 0.03, z))
            2:
                _make_bike(Vector3(side * 4.4, 0.03, z))
        z += rng.randf_range(9.0, 18.0)


func _build_trash() -> void:
    var bag := _mat(Color(0.08, 0.1, 0.08))
    var bag2 := _mat(Color(0.55, 0.5, 0.4))
    for i in 18:
        var side := 1 if rng.randf() < 0.5 else -1
        var x := side * rng.randf_range(5.3, 7.2)
        var z := rng.randf_range(-HALF_LEN + 4.0, HALF_LEN - 4.0)
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
