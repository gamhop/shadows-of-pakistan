extends CanvasLayer

# ENTER / EXIT button, gaari chalane ka control aur speed dikhana.
# Chalate waqt: stick upar = gas, neeche = brake / reverse, daen baen = steering.

const NEAR_DIST := 2.2

var main_node: Node
var btn: Button
var speed_label: Label
var car: CharacterBody3D = null
var near_car: CharacterBody3D = null
var scan_t := 0.0


func _ready() -> void:
    layer = 9
    main_node = get_parent()
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    btn = Button.new()
    btn.text = "ENTER"
    btn.add_theme_font_size_override("font_size", 38)
    btn.anchor_left = 1.0
    btn.anchor_right = 1.0
    btn.anchor_top = 1.0
    btn.anchor_bottom = 1.0
    btn.offset_left = -440.0
    btn.offset_right = -140.0
    btn.offset_top = -700.0
    btn.offset_bottom = -590.0
    btn.visible = false
    btn.pressed.connect(_on_btn)
    root.add_child(btn)

    speed_label = Label.new()
    speed_label.add_theme_font_size_override("font_size", 52)
    speed_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    speed_label.add_theme_constant_override("outline_size", 8)
    speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    speed_label.visible = false
    root.add_child(speed_label)
    speed_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    speed_label.offset_top = -130.0
    speed_label.offset_bottom = -40.0


func _arm() -> SpringArm3D:
    var cp := main_node.get("cam_pivot") as Node3D
    if cp == null:
        return null
    for c in cp.get_children():
        if c is SpringArm3D:
            return c as SpringArm3D
    return null


func _set_player_collision(on: bool) -> void:
    var p := main_node.get("player") as Node3D
    if p == null:
        return
    for c in p.get_children():
        if c is CollisionShape3D:
            c.set_deferred("disabled", not on)


func _reset_main_input() -> void:
    main_node.set("stick", Vector2.ZERO)
    main_node.set("stick_touch", -1)
    main_node.set("look_touch", -1)
    main_node.set("run_touch", -1)
    main_node.set("run_on", false)


func _toast(msg: String) -> void:
    var sv = main_node.get("survival")
    if sv:
        sv.call("_show_toast", msg)


func _find_near(player: Node3D) -> CharacterBody3D:
    var best: CharacterBody3D = null
    var best_d := NEAR_DIST
    for n in get_tree().get_nodes_in_group("vehicles"):
        var v := n as CharacterBody3D
        if v == null or not v.call("can_enter"):
            continue
        var sz: Vector3 = v.get("size")
        var lp := v.to_local(player.global_position)
        var dx := maxf(absf(lp.x) - sz.x / 2.0, 0.0)
        var dz := maxf(absf(lp.z) - sz.z / 2.0, 0.0)
        var d := Vector2(dx, dz).length()
        if absf(lp.y) < 2.5 and d < best_d:
            best_d = d
            best = v
    return best


func _process(delta: float) -> void:
    if car != null and not is_instance_valid(car):
        _after_exit()
    var player := main_node.get("player") as Node3D
    if player == null:
        return
    if car != null:
        btn.text = "EXIT"
        btn.visible = true
        speed_label.text = "%d km/h" % int(absf(float(car.get("speed"))) * 3.6)
        speed_label.visible = true
        return
    speed_label.visible = false
    scan_t -= delta
    if scan_t <= 0.0:
        scan_t = 0.12
        near_car = _find_near(player)
    btn.text = "ENTER"
    btn.visible = near_car != null and is_instance_valid(near_car)


func _on_btn() -> void:
    if car != null:
        _exit()
    elif near_car != null and is_instance_valid(near_car):
        _enter(near_car)


func _enter(v: CharacterBody3D) -> void:
    car = v
    v.call("take_control")
    main_node.set("driving", true)
    _reset_main_input()
    var avatar := main_node.get("avatar") as Node3D
    if avatar:
        avatar.visible = false
    _set_player_collision(false)
    var arm := _arm()
    if arm:
        arm.add_excluded_object(v.get_rid())
        arm.spring_length = 7.5
    _toast("Stick: up = gas, down = brake, left/right = steer")


func _exit() -> void:
    var v := car
    var spot := _exit_spot(v)
    v.call("release")
    var arm := _arm()
    if arm:
        arm.remove_excluded_object(v.get_rid())
    _after_exit()
    var player := main_node.get("player") as CharacterBody3D
    if player:
        player.global_position = Vector3(spot.x, 0.1, spot.z)
        player.velocity = Vector3.ZERO


func _after_exit() -> void:
    car = null
    main_node.set("driving", false)
    _reset_main_input()
    var avatar := main_node.get("avatar") as Node3D
    if avatar:
        avatar.visible = true
    _set_player_collision(true)
    var arm := _arm()
    if arm:
        arm.spring_length = 5.0
    speed_label.visible = false


func _exit_spot(v: Node3D) -> Vector3:
    var sz: Vector3 = v.get("size")
    var b := v.global_transform.basis
    var c := v.global_position
    var dirs := [-b.x, b.x, b.z, -b.z]
    var dists := [sz.x / 2.0 + 1.1, sz.x / 2.0 + 1.1, sz.z / 2.0 + 1.1, sz.z / 2.0 + 1.1]
    var space := v.get_world_3d().direct_space_state
    for i in 4:
        var d: Vector3 = dirs[i]
        var spot := c + d.normalized() * float(dists[i])
        var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.9, 0), spot + Vector3(0, 0.9, 0))
        q.exclude = [v.get_rid()]
        if space.intersect_ray(q).is_empty():
            return spot
    return c + Vector3(0, 2.5, 0)


func _physics_process(delta: float) -> void:
    if car == null or not is_instance_valid(car):
        return
    var st: Vector2 = main_node.get("stick")
    var gas := -st.y
    if absf(gas) < 0.12:
        gas = 0.0
    car.set("throttle", gas)
    car.set("steer", clampf(st.x * 1.3, -1.0, 1.0))

    var player := main_node.get("player") as CharacterBody3D
    if player:
        player.global_position = car.global_position
        player.rotation.y = car.rotation.y
        player.velocity = Vector3.ZERO
    var cp := main_node.get("cam_pivot") as Node3D
    if cp:
        cp.global_position = car.global_position + Vector3(0, 2.2, 0)
    if int(main_node.get("look_touch")) == -1:
        var yaw: float = main_node.get("cam_yaw")
        main_node.set("cam_yaw", lerp_angle(yaw, car.rotation.y, clampf(1.8 * delta, 0.0, 1.0)))
        var pitch: float = main_node.get("cam_pitch")
        main_node.set("cam_pitch", lerpf(pitch, -0.16, clampf(1.5 * delta, 0.0, 1.0)))
