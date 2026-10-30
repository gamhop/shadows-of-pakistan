extends Node3D

# Dushman ka fauji (GLB). Skeleton nahi hai, isliye chalna shader se hota hai:
# tangein hip ke ird-gird aur bazu kandhe ke ird-gird jhoolte hain.

const MODEL_PATH := "res://assets/models/enemy_soldier.glb"

const SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float leg_angle = 0.0;
uniform float arm_angle = 0.0;
uniform float flash = 0.0;

void vertex() {
    vec3 v = VERTEX;
    vec3 n = NORMAL;
    float aw = smoothstep(0.23, 0.28, abs(VERTEX.x)) * smoothstep(1.42, 1.30, VERTEX.y) * smoothstep(0.66, 0.74, VERTEX.y);
    float lw = smoothstep(0.74, 0.60, VERTEX.y) * (1.0 - aw);
    float side = clamp(VERTEX.x / 0.02, -1.0, 1.0);
    float la = leg_angle * side * lw;
    float c = cos(la);
    float s = sin(la);
    float dy = v.y - 0.74;
    float ny = 0.74 + dy * c - v.z * s;
    float nz = dy * s + v.z * c;
    v.y = ny;
    v.z = nz;
    float ny2 = n.y * c - n.z * s;
    float nz2 = n.y * s + n.z * c;
    n.y = ny2;
    n.z = nz2;
    float aa = -arm_angle * sign(VERTEX.x) * aw;
    float c2 = cos(aa);
    float s2 = sin(aa);
    float dy2 = v.y - 1.42;
    float ny3 = 1.42 + dy2 * c2 - v.z * s2;
    float nz3 = dy2 * s2 + v.z * c2;
    v.y = ny3;
    v.z = nz3;
    float ny4 = n.y * c2 - n.z * s2;
    float nz4 = n.y * s2 + n.z * c2;
    n.y = ny4;
    n.z = nz4;
    VERTEX = v;
    NORMAL = normalize(n);
}

void fragment() {
    ALBEDO = texture(albedo_tex, UV).rgb;
    ROUGHNESS = 0.85;
    METALLIC = 0.0;
    EMISSION = vec3(flash);
}
"""

var mat: ShaderMaterial
var phase := 0.0
var amp := 0.0
var flash_v := 0.0
var frozen := false


# true agar model load ho gaya
func setup() -> bool:
    if not ResourceLoader.exists(MODEL_PATH):
        return false
    var scene := load(MODEL_PATH) as PackedScene
    if scene == null:
        return false
    var inst := scene.instantiate() as Node3D
    if inst == null:
        return false
    var mi := _find_mesh(inst)
    if mi == null:
        inst.free()
        return false
    var src := mi.get_active_material(0) as BaseMaterial3D
    if src == null or src.albedo_texture == null:
        inst.free()
        return false
    var sh := Shader.new()
    sh.code = SHADER
    mat = ShaderMaterial.new()
    mat.shader = sh
    mat.set_shader_parameter("albedo_tex", src.albedo_texture)
    mi.material_override = mat
    add_child(inst)
    return true


func _find_mesh(n: Node) -> MeshInstance3D:
    if n is MeshInstance3D:
        return n
    for c in n.get_children():
        var r := _find_mesh(c)
        if r:
            return r
    return null


func animate(speed: float, delta: float) -> void:
    if mat == null or frozen:
        return
    var moving := speed > 0.3
    var target := 0.0
    if moving:
        target = clampf(speed / 4.2, 0.3, 1.0) * 0.7
        phase += delta * PI * (1.6 + speed * 0.45)
    amp = lerpf(amp, target, clampf(10.0 * delta, 0.0, 1.0))
    var sw := sin(phase)
    mat.set_shader_parameter("leg_angle", amp * sw)
    mat.set_shader_parameter("arm_angle", amp * 0.8 * sw)
    if flash_v > 0.0:
        flash_v = maxf(flash_v - delta * 14.0, 0.0)
        mat.set_shader_parameter("flash", flash_v)


func flash() -> void:
    flash_v = 0.9
    if mat:
        mat.set_shader_parameter("flash", flash_v)


func stop() -> void:
    frozen = true
    if mat:
        mat.set_shader_parameter("flash", 0.0)
        mat.set_shader_parameter("leg_angle", 0.0)
        mat.set_shader_parameter("arm_angle", 0.0)
