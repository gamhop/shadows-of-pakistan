extends Node3D

# Asli 3D character (Tripo GLB). Isme skeleton nahi hai, isliye chalne ka animation
# shader se hota hai: tangein aur bazu hip/kandhe ke ird-gird jhoolte hain.
# main.gd isay "avatar" ki tarah use karta hai (animate(speed, running, delta)).

const MODEL_PATH := "res://assets/models/player.glb"
const MODEL_HEIGHT := 0.9599      # GLB ki asli unchai
const MODEL_FOOT := -0.4764       # GLB mein pairon ka y
const TARGET_HEIGHT := 1.8        # game mein unchai (meter)

const SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float leg_angle = 0.0;
uniform float arm_angle = 0.0;

void vertex() {
    vec3 v = VERTEX;
    vec3 n = NORMAL;
    float aw = smoothstep(0.115, 0.145, abs(VERTEX.x)) * smoothstep(0.31, 0.22, VERTEX.y) * smoothstep(-0.13, -0.09, VERTEX.y);
    float lw = smoothstep(-0.03, -0.11, VERTEX.y) * (1.0 - aw);
    float side = clamp(VERTEX.x / 0.012, -1.0, 1.0);
    // tangein (hip ke ird-gird)
    float la = leg_angle * side * lw;
    float c = cos(la);
    float s = sin(la);
    float dy = v.y + 0.03;
    float ny = -0.03 + dy * c - v.z * s;
    float nz = dy * s + v.z * c;
    v.y = ny;
    v.z = nz;
    float ny2 = n.y * c - n.z * s;
    float nz2 = n.y * s + n.z * c;
    n.y = ny2;
    n.z = nz2;
    // bazu (kandhe ke ird-gird), tangon ke ulta
    float aa = -arm_angle * sign(VERTEX.x) * aw;
    float c2 = cos(aa);
    float s2 = sin(aa);
    float dy2 = v.y - 0.27;
    float ny3 = 0.27 + dy2 * c2 - v.z * s2;
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
    NORMAL_MAP = texture(normal_tex, UV).rgb;
    ROUGHNESS = 0.9;
    METALLIC = 0.05;
}
"""

var pivot: Node3D
var model: Node3D
var mat: ShaderMaterial
var phase := 0.0
var amp := 0.0
var run_amt := 0.0
var base_y := 0.0


func configure(_d: Dictionary) -> void:
    pass


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
    if src.normal_texture:
        mat.set_shader_parameter("normal_tex", src.normal_texture)
    else:
        var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
        img.fill(Color(0.5, 0.5, 1.0))
        mat.set_shader_parameter("normal_tex", ImageTexture.create_from_image(img))
    mi.material_override = mat
    pivot = Node3D.new()
    add_child(pivot)
    model = inst
    var s := TARGET_HEIGHT / MODEL_HEIGHT
    model.scale = Vector3.ONE * s
    model.rotation.y = PI           # GLB ka chehra +Z par hai, game mein aage -Z hai
    base_y = -MODEL_FOOT * s
    model.position.y = base_y
    pivot.add_child(model)
    return true


func _find_mesh(n: Node) -> MeshInstance3D:
    if n is MeshInstance3D:
        return n
    for c in n.get_children():
        var r := _find_mesh(c)
        if r:
            return r
    return null


func animate(speed: float, running: bool, delta: float) -> void:
    if mat == null:
        return
    var moving := speed > 0.3
    var target_amp := 0.0
    if moving:
        target_amp = 0.75 if running else 0.42
        phase += delta * PI * (3.2 if running else 2.0)
    amp = lerpf(amp, target_amp, clampf(10.0 * delta, 0.0, 1.0))
    run_amt = lerpf(run_amt, 1.0 if (moving and running) else 0.0, clampf(8.0 * delta, 0.0, 1.0))
    var sw := sin(phase)
    mat.set_shader_parameter("leg_angle", amp * sw)
    mat.set_shader_parameter("arm_angle", amp * 0.8 * sw)
    # upar-neeche hilna aur daudte waqt aage jhukna
    model.position.y = base_y + absf(sw) * 0.03 * amp * 2.0
    pivot.rotation.x = -0.14 * run_amt
