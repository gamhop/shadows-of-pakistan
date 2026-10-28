extends Node3D

const AvatarScript := preload("res://avatar.gd")
const KAMEEZ := [Color(0.92, 0.92, 0.88), Color(0.6, 0.75, 0.85), Color(0.55, 0.55, 0.55), Color(0.5, 0.38, 0.28), Color(0.2, 0.4, 0.3), Color(0.45, 0.15, 0.18), Color(0.2, 0.25, 0.4)]
const SKINS := [Color(0.86, 0.67, 0.52), Color(0.74, 0.54, 0.4), Color(0.62, 0.44, 0.32)]
const CAPS := [Color(0.46, 0.34, 0.21), Color(0.9, 0.9, 0.85), Color(0.2, 0.2, 0.22)]

var orient := 0
var line_c := 0.0
var lo := -90.0
var hi := 90.0
var t := 0.0
var dir := 1.0
var speed := 1.3
var seed_v := 1
var avatar: Node3D


func _ready() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var k: Color = KAMEEZ[rng.randi() % KAMEEZ.size()]
    var sh: Color = k if rng.randf() < 0.7 else KAMEEZ[rng.randi() % KAMEEZ.size()]
    avatar = AvatarScript.new()
    avatar.call("configure", {
        "kameez": k,
        "shalwar": sh,
        "skin": SKINS[rng.randi() % SKINS.size()],
        "cap_color": CAPS[rng.randi() % CAPS.size()],
        "headwear": rng.randi() % 2,
        "beard": rng.randf() < 0.5,
        "height_scale": rng.randf_range(0.93, 1.04),
    })
    add_child(avatar)
    speed = rng.randf_range(1.1, 1.6)
    _place()


func _place() -> void:
    if orient == 0:
        position = Vector3(line_c, 0.08, t)
    else:
        position = Vector3(t, 0.08, line_c)


func _process(delta: float) -> void:
    t += dir * speed * delta
    if t > hi:
        t = hi
        dir = -1.0
    elif t < lo:
        t = lo
        dir = 1.0
    _place()
    var dx := 0.0
    var dz := 0.0
    if orient == 0:
        dz = dir
    else:
        dx = dir
    rotation.y = lerp_angle(rotation.y, atan2(-dx, -dz), minf(1.0, 8.0 * delta))
    avatar.call("animate", speed, false, delta)
