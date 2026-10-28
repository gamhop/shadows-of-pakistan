extends Node3D

# Procedural humanoid in shalwar kameez. Faces -Z. Origin at the feet.

var kameez := Color(0.86, 0.86, 0.8)
var shalwar := Color(0.86, 0.86, 0.8)
var skin := Color(0.78, 0.58, 0.44)
var hair := Color(0.07, 0.055, 0.05)
var shoes := Color(0.16, 0.1, 0.07)
var cap_color := Color(0.46, 0.34, 0.21)
var headwear := 1
var beard := true
var height_scale := 1.0

var body: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D

var phase := 0.0
var amp := 0.0
var run_amt := 0.0
var clock := 0.0


func configure(d: Dictionary) -> void:
    for k in d.keys():
        set(k, d[k])


func _m(color: Color, rough: float = 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m


func _capsule(parent: Node3D, pos: Vector3, r: float, h: float, color: Color, scl: Vector3 = Vector3.ONE) -> void:
    var mi := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = r
    cm.height = h
    cm.radial_segments = 12
    cm.rings = 4
    cm.material = _m(color)
    mi.mesh = cm
    mi.position = pos
    mi.scale = scl
    parent.add_child(mi)


func _sphere(parent: Node3D, pos: Vector3, r: float, color: Color, scl: Vector3 = Vector3.ONE, rough: float = 0.85) -> void:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 14
    sm.rings = 8
    sm.material = _m(color, rough)
    mi.mesh = sm
    mi.position = pos
    mi.scale = scl
    parent.add_child(mi)


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    bm.material = _m(color)
    mi.mesh = bm
    mi.position = pos
    parent.add_child(mi)


func _make_arm(x: float) -> Dictionary:
    var top := Node3D.new()
    top.position = Vector3(x, 0.50, 0)
    body.add_child(top)
    _capsule(top, Vector3(0, -0.13, 0), 0.052, 0.30, kameez)
    var low := Node3D.new()
    low.position = Vector3(0, -0.27, 0)
    top.add_child(low)
    _capsule(low, Vector3(0, -0.12, 0), 0.044, 0.27, kameez)
    _sphere(low, Vector3(0, -0.27, 0), 0.045, skin)
    return {"top": top, "low": low}


func _make_leg(x: float) -> Dictionary:
    var top := Node3D.new()
    top.position = Vector3(x, -0.02, 0)
    body.add_child(top)
    _capsule(top, Vector3(0, -0.21, 0), 0.08, 0.46, shalwar)
    var low := Node3D.new()
    low.position = Vector3(0, -0.42, 0)
    top.add_child(low)
    _capsule(low, Vector3(0, -0.2, 0), 0.065, 0.44, shalwar)
    _box(low, Vector3(0, -0.43, -0.05), Vector3(0.1, 0.06, 0.26), shoes)
    return {"top": top, "low": low}


func _ready() -> void:
    scale = Vector3.ONE * height_scale
    body = Node3D.new()
    body.position = Vector3(0, 0.92, 0)
    add_child(body)

    # torso: kameez (upper body + flared hem)
    _capsule(body, Vector3(0, 0.30, 0), 0.19, 0.58, kameez, Vector3(1, 1, 0.62))
    _box(body, Vector3(0, -0.12, 0), Vector3(0.42, 0.36, 0.27), kameez)

    # neck and head
    _capsule(body, Vector3(0, 0.60, 0), 0.06, 0.12, skin)
    _sphere(body, Vector3(0, 0.72, 0), 0.105, skin, Vector3(1, 1.15, 1.05), 0.7)
    # face
    _sphere(body, Vector3(-0.04, 0.735, -0.1), 0.014, Color(0.03, 0.03, 0.03))
    _sphere(body, Vector3(0.04, 0.735, -0.1), 0.014, Color(0.03, 0.03, 0.03))
    _sphere(body, Vector3(0, 0.70, -0.112), 0.022, skin.darkened(0.12))
    _sphere(body, Vector3(-0.108, 0.72, 0.0), 0.02, skin.darkened(0.08))
    _sphere(body, Vector3(0.108, 0.72, 0.0), 0.02, skin.darkened(0.08))
    # hair, cap, beard
    _sphere(body, Vector3(0, 0.765, 0.018), 0.108, hair, Vector3(1, 0.78, 1.04), 1.0)
    if headwear == 1:
        var cap := MeshInstance3D.new()
        var cm := CylinderMesh.new()
        cm.top_radius = 0.112
        cm.bottom_radius = 0.098
        cm.height = 0.09
        cm.radial_segments = 16
        cm.material = _m(cap_color, 1.0)
        cap.mesh = cm
        cap.position = Vector3(0, 0.80, 0.005)
        body.add_child(cap)
        _sphere(body, Vector3(0, 0.84, 0.005), 0.104, cap_color, Vector3(1, 0.45, 1), 1.0)
    if beard:
        _sphere(body, Vector3(0, 0.655, -0.075), 0.06, hair, Vector3(1, 0.8, 0.7), 1.0)

    var a1 := _make_arm(-0.235)
    var a2 := _make_arm(0.235)
    arm_l = a1["top"]
    elbow_l = a1["low"]
    arm_r = a2["top"]
    elbow_r = a2["low"]
    var l1 := _make_leg(-0.09)
    var l2 := _make_leg(0.09)
    leg_l = l1["top"]
    knee_l = l1["low"]
    leg_r = l2["top"]
    knee_r = l2["low"]


func animate(speed: float, running: bool, delta: float) -> void:
    if body == null:
        return
    clock += delta
    var moving := speed > 0.3
    var target_amp := 0.0
    if moving:
        target_amp = 0.85 if running else 0.55
        phase += delta * speed * 2.6
    amp = lerpf(amp, target_amp, minf(1.0, 10.0 * delta))
    run_amt = lerpf(run_amt, 1.0 if (running and moving) else 0.0, minf(1.0, 6.0 * delta))
    var s := sin(phase)
    var c := cos(phase)
    leg_l.rotation.x = s * amp
    leg_r.rotation.x = -s * amp
    knee_l.rotation.x = -maxf(0.0, c) * amp * 1.3
    knee_r.rotation.x = -maxf(0.0, -c) * amp * 1.3
    arm_l.rotation.x = -s * amp * 0.9
    arm_r.rotation.x = s * amp * 0.9
    var bend := 0.2 + run_amt * 0.9
    elbow_l.rotation.x = bend
    elbow_r.rotation.x = bend
    body.position.y = 0.92 + absf(s) * 0.035 * amp + sin(clock * 2.0) * 0.004
    body.rotation.x = -0.14 * run_amt
