extends Node3D

# Hero: cyborg (GLB, skeleton + animations). main.gd isay "avatar" ki tarah use karta hai:
# setup(), animate(speed, running, delta). Model na mile to purana model_avatar.gd chal jata hai.
# Halat neeche build label mein "hero ..." likhi aati hai (masla pakadne ke liye).

const MODEL_PATH := "res://assets/models/hero.glb"
const FLIP := true            # model ka munh +Z tha, game -Z mein chalta hai. Ulta dikhe to false karein
const WALK_SPEED := 4.5
const RUN_SPEED := 9.5

var anim: AnimationPlayer
var idle_name := ""
var walk_name := ""
var run_name := ""
var cur := ""
var meshes: Array = []
var status_t := 0.0


func configure(_d: Dictionary) -> void:
    pass


func _set_status(s: String) -> void:
    Engine.set_meta("hero_status", s)


# true agar model load ho gaya
func setup() -> bool:
    if not ResourceLoader.exists(MODEL_PATH):
        _set_status("hero: file missing -> old model")
        return false
    var scene := load(MODEL_PATH) as PackedScene
    if scene == null:
        _set_status("hero: load failed -> old model")
        return false
    var inst := scene.instantiate() as Node3D
    if inst == null:
        _set_status("hero: instantiate failed -> old model")
        return false
    _attach(inst)
    return true


func _attach(inst: Node3D) -> void:
    if FLIP:
        inst.rotation.y = PI
    add_child(inst)
    _fix_meshes(inst)
    anim = _find_anim(inst)
    if anim == null:
        _set_status("hero: loaded, no animations m%d" % meshes.size())
        return
    idle_name = _pick(["stand", "idle"])
    walk_name = _pick(["walk"])
    run_name = _pick(["run"])
    for key in [idle_name, walk_name, run_name]:
        if key != "":
            var a := anim.get_animation(key)
            if a:
                a.loop_mode = Animation.LOOP_LINEAR
    cur = idle_name
    _set_status("hero: loaded m%d" % meshes.size())


func _ready() -> void:
    # tree mein aane ke baad animation dobara shuru (pehle tree se bahar play ho sakta hai nakaam)
    if anim and idle_name != "":
        anim.play(idle_name)


# Skinned mesh kabhi kabhi galat bounding box ki wajah se screen se "cull" ho jata hai (nazar nahi aata).
# Isliye culling bohot dheeli kar di.
func _fix_meshes(n: Node) -> void:
    var mi := n as MeshInstance3D
    if mi:
        mi.extra_cull_margin = 16384.0
        mi.ignore_occlusion_culling = true
        mi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
        mi.visibility_range_end = 0.0
        mi.visible = true
        meshes.append(mi)
    for c in n.get_children():
        _fix_meshes(c)


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


func _process(delta: float) -> void:
    status_t -= delta
    if status_t > 0.0:
        return
    status_t = 1.0
    var vis := 0
    for mi in meshes:
        var m := mi as MeshInstance3D
        if is_instance_valid(m):
            m.visible = true
            if m.is_visible_in_tree():
                vis += 1
    var playing := anim != null and anim.is_playing()
    _set_status("hero: m%d vis%d %s%s y%.1f" % [meshes.size(), vis, cur, "" if playing else " STOPPED", global_position.y])


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
    if want != cur or not anim.is_playing():
        cur = want
        anim.play(want, 0.2)
    anim.speed_scale = sc
