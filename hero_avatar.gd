extends Node3D

# Hero: cyborg (GLB, skeleton + animations). main.gd isay "avatar" ki tarah use karta hai:
# setup(), animate(speed, running, delta). Model na mile to purana model_avatar.gd chal jata hai.

const MODEL_PATH := "res://assets/models/hero.glb"
const FLIP := true            # model ka munh +Z tha, game -Z mein chalta hai. Ulta dikhe to false karein
const WALK_SPEED := 4.5
const RUN_SPEED := 9.5

var anim: AnimationPlayer
var idle_name := ""
var walk_name := ""
var run_name := ""
var cur := ""


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
    _attach(inst)
    return true


func _attach(inst: Node3D) -> void:
    if FLIP:
        inst.rotation.y = PI
    add_child(inst)
    anim = _find_anim(inst)
    if anim == null:
        return
    idle_name = _pick(["stand", "idle"])
    walk_name = _pick(["walk"])
    run_name = _pick(["run"])
    for key in [idle_name, walk_name, run_name]:
        if key != "":
            var a := anim.get_animation(key)
            if a:
                a.loop_mode = Animation.LOOP_LINEAR
    if idle_name != "":
        cur = idle_name
        anim.play(idle_name)


func _find_anim(n: Node) -> AnimationPlayer:
    if n is AnimationPlayer:
        return n
    for c in n.get_children():
        var r := _find_anim(c)
        if r:
            return r
    return null


func _pick(keys: Array) -> String:
    var list := anim.get_animation_list()
    for k in keys:
        for a in list:
            if str(a).to_lower() == k:
                return str(a)
    for k in keys:
        for a in list:
            var low := str(a).to_lower()
            if low.find(k) != -1 and low.find("up") == -1:
                return str(a)
    return ""


func animate(speed: float, running: bool, _delta: float) -> void:
    if anim == null:
        return
    var want := idle_name
    var sc := 1.0
    if speed > 0.3:
        if running and run_name != "":
            want = run_name
            sc = clampf(speed / RUN_SPEED, 0.6, 1.4)
        elif walk_name != "":
            want = walk_name
            sc = clampf(speed / WALK_SPEED, 0.6, 1.4)
    if want == "":
        return
    if want != cur:
        cur = want
        anim.play(want, 0.2)
    anim.speed_scale = sc
