extends CharacterBody3D

# Ek gaari / rickshaw / bike / humvee / truck. Teen halat:
#   PARKED : khari hai (physics band)
#   AI     : traffic mein koi chala raha hai (sadak ki lane par)
#   PLAYER : aap chala rahe hain
#   COAST  : aap utar gaye, dheere dheere ruk rahi hai
# Aage ka rukh hamesha -Z hai.

const LANE := 1.8

enum Mode { PARKED, AI, PLAYER, COAST }

var mode := Mode.PARKED
var size := Vector3(1.9, 1.5, 4.2)
var speed := 0.0
var throttle := 0.0
var steer := 0.0
var max_speed := 20.0
var accel := 9.0
var brake := 22.0
var steer_max := 0.55
var wheelbase := 2.5

var ai_dir := Vector3.ZERO
var ai_cruise := 8.0
var road := 0.0
var lines: Array = []
var bound := 105.0
var plan_line := INF
var plan_dir := Vector3.ZERO
var done_line := INF

var driver: Node3D = null
var far_t := 0.0
var sleeping := false

var block_dist := INF
var check_t := 0.0
var scan_shape: BoxShape3D = null
var blocked_by_player := false
var stuck_t := 0.0
var ignore_t := 0.0
var honk_cd := 0.0
var main_ref: Node = null


func _ready() -> void:
    set_process(false)
    size = get_meta("size", size)
    add_to_group("vehicles")
    if size.x < 1.0:
        max_speed = 22.0
        accel = 8.0
        steer_max = 0.7
        wheelbase = 1.3
    elif size.x < 1.5:
        max_speed = 14.0
        accel = 6.0
        steer_max = 0.65
        wheelbase = 1.8
    elif size.z > 6.0:
        max_speed = 15.0
        accel = 4.5
        brake = 14.0
        steer_max = 0.45
        wheelbase = 4.5
    elif size.x > 2.3:
        max_speed = 17.0
        accel = 7.0
        wheelbase = 2.9
    set_physics_process(false)
    call_deferred("_cull")


# door ki gaariyan dikhana band (FPS bachane ke liye)
func _cull() -> void:
    _cull_node(self)


func _cull_node(n: Node) -> void:
    var g := n as GeometryInstance3D
    if g:
        g.visibility_range_end = 170.0
        g.visibility_range_end_margin = 6.0
    for c in n.get_children():
        _cull_node(c)


func can_enter() -> bool:
    # chalti hui gaari mein bhi ghus sakte hain (driver ko bahar kheench kar)
    return mode != Mode.PLAYER


func take_control() -> void:
    if driver and is_instance_valid(driver):
        driver.queue_free()
        driver = null
    mode = Mode.PLAYER
    throttle = 0.0
    steer = 0.0
    set_physics_process(true)


func release() -> void:
    mode = Mode.COAST
    throttle = 0.0
    steer = 0.0


func start_ai(dir: Vector3, road_c: float, line_list: Array, cruise: float, bound_v: float) -> void:
    mode = Mode.AI
    ai_dir = dir
    road = road_c
    lines = line_list
    ai_cruise = cruise
    bound = bound_v
    speed = cruise * 0.5
    _add_driver()
    set_physics_process(true)
    set_process(true)


func _physics_process(delta: float) -> void:
    if mode == Mode.AI:
        # bohot door ki gaariyan ruki rehti hain (CPU bachane ke liye)
        far_t -= delta
        if far_t <= 0.0:
            far_t = 0.4
            var cam := get_viewport().get_camera_3d()
            sleeping = cam != null and cam.global_position.distance_to(global_position) > 190.0
        if sleeping:
            return
        # rukawat ki jaanch physics tick mein (har 0.1 sec), harkat _process mein
        check_t -= delta
        if check_t <= 0.0:
            check_t = 0.1
            _scan_ahead()
        return
    if mode == Mode.PARKED:
        return
    _drive(delta)
    if mode == Mode.COAST and absf(speed) < 0.15:
        speed = 0.0
        mode = Mode.PARKED
        set_physics_process(false)


# AI gaariyan har frame par chalti hain (60Hz physics par chalane se jhatke lagte the)
func _process(delta: float) -> void:
    if mode != Mode.AI or sleeping:
        return
    _ai(minf(delta, 0.05))


# ------------------------------------------------------------ player / coasting
func _drive(delta: float) -> void:
    var t := throttle if mode == Mode.PLAYER else 0.0
    if t > 0.05:
        if speed < 0.0:
            speed = move_toward(speed, 0.0, brake * delta)
        else:
            speed = move_toward(speed, max_speed * t, accel * delta)
    elif t < -0.05:
        if speed > 0.5:
            speed = move_toward(speed, 0.0, brake * delta)
        else:
            speed = move_toward(speed, -max_speed * 0.3 * absf(t), accel * delta)
    else:
        speed = move_toward(speed, 0.0, 6.0 * delta)

    var st := steer if mode == Mode.PLAYER else 0.0
    var fast_k := clampf(1.0 - absf(speed) / (max_speed * 1.6), 0.45, 1.0)
    rotation.y -= (speed / wheelbase) * tan(st * steer_max * fast_k) * delta

    var fwd := -global_transform.basis.z
    velocity.x = fwd.x * speed
    velocity.z = fwd.z * speed
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= 20.0 * delta
    move_and_slide()

    for i in get_slide_collision_count():
        var c := get_slide_collision(i)
        var col = c.get_collider()
        if col == null:
            continue
        if col.has_method("take_damage") and absf(speed) > 4.0:
            col.call("take_damage", 40.0 + absf(speed) * 5.0, c.get_position(), fwd, false)
            speed *= 0.75
        elif c.get_normal().dot(fwd * signf(speed)) < -0.6 and absf(speed) > 2.0:
            speed *= 0.35


# ------------------------------------------------------------ traffic driver
func _ai(delta: float) -> void:
    var is_z := absf(ai_dir.z) > 0.5
    var da := ai_dir.z if is_z else ai_dir.x
    var a := global_position.z if is_z else global_position.x

    # shehar ke kinare par wapas mur jao
    if a * da > bound - 14.0:
        ai_dir = -ai_dir
        plan_line = INF
        done_line = INF
        return

    # jo chauraha peeche reh gaya usay bhool jao
    if done_line != INF and absf(a - done_line) > 20.0:
        done_line = INF

    if plan_line == INF:
        # agle chaurahe par kya karna hai (seedha, ya mur jana)
        var best := 999.0
        var next_l := INF
        for l in lines:
            var lf: float = l
            if lf == done_line:
                continue
            var ahead := (lf - a) * da
            if ahead > -1.0 and ahead < best:
                best = ahead
                next_l = lf
        if best < 16.0:
            plan_line = next_l
            var left := Vector3.UP.cross(ai_dir)
            var r := randf()
            if r < 0.2:
                plan_dir = left
            elif r < 0.4:
                plan_dir = -left
            else:
                plan_dir = ai_dir
    else:
        if plan_dir == ai_dir:
            if (a - plan_line) * da > 4.0:
                done_line = plan_line
                plan_line = INF
        else:
            var lane2 := Vector3.UP.cross(plan_dir) * LANE
            var trig := plan_line + (lane2.z if is_z else lane2.x)
            var lead := 2.0 if plan_dir.dot(Vector3.UP.cross(ai_dir)) > 0.5 else 4.0
            if (a - trig) * da >= -lead:
                done_line = road
                road = plan_line
                ai_dir = plan_dir
                plan_line = INF
                return

    # saamne koi rukawat? (aap, dushman, log ya doosri gaari) - _scan_ahead se
    honk_cd = maxf(honk_cd - delta, 0.0)
    ignore_t = maxf(ignore_t - delta, 0.0)
    var target := ai_cruise
    if ignore_t <= 0.0 and block_dist < INF:
        # rukawat jitni kareeb, utni dheemi (achanak brake nahi)
        var stop_d := 3.0 + speed * 0.6
        target = ai_cruise * clampf((block_dist - stop_d) / 8.0, 0.0, 1.0)
    # bahut der se phansi ho (aur wajah aap nahi) to thoda aage nikal jao
    if target == 0.0 and speed < 0.3 and not blocked_by_player:
        stuck_t += delta
        if stuck_t > 8.0:
            ignore_t = 3.0
            stuck_t = 0.0
    elif target > 0.0:
        stuck_t = 0.0
    # aap saamne hon aur gaari ruki ho to horn bajao
    if blocked_by_player and speed < 0.5 and honk_cd <= 0.0 and size.x >= 1.0:
        honk_cd = 5.0
        var au := get_tree().get_first_node_in_group("audio")
        if au:
            au.call("play3d", "horn", global_position + Vector3(0, 1.2, 0), 0.0)

    # apni lane ki taraf narmi se mudna (steering), achanak nahi
    var lane := Vector3.UP.cross(ai_dir) * LANE
    var lat_vec := Vector3(1, 0, 0) if is_z else Vector3(0, 0, 1)
    var err := (road + lane.x - global_position.x) if is_z else (road + lane.z - global_position.z)
    var want := (ai_dir + lat_vec * clampf(err * 0.35, -0.6, 0.6)).normalized()
    var want_yaw := atan2(-want.x, -want.z)
    var diff := angle_difference(rotation.y, want_yaw)
    var turn_rate := 2.2 if size.x >= 1.0 else 3.0
    rotation.y += clampf(diff, -turn_rate * delta, turn_rate * delta)
    # mudte waqt dheemi
    target *= clampf(1.0 - absf(diff) / 1.4, 0.35, 1.0)
    var rate := accel if target > speed else minf(brake, 14.0)
    speed = move_toward(speed, target, rate * delta)
    var fwd := -global_transform.basis.z
    global_position += fwd * speed * delta


# ------------------------------------------------------------ driver (chalane wala)
func _add_driver() -> void:
    if driver != null:
        return
    driver = Node3D.new()
    var shirts := [Color(0.88, 0.88, 0.82), Color(0.2, 0.3, 0.5), Color(0.5, 0.45, 0.35), Color(0.15, 0.15, 0.18), Color(0.55, 0.2, 0.2), Color(0.25, 0.4, 0.3)]
    var skins := [Color(0.78, 0.58, 0.44), Color(0.68, 0.48, 0.36), Color(0.85, 0.66, 0.52)]
    var torso := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = 0.2
    cm.height = 0.75
    var sm := StandardMaterial3D.new()
    sm.albedo_color = shirts[randi() % shirts.size()]
    sm.roughness = 1.0
    cm.material = sm
    torso.mesh = cm
    driver.add_child(torso)
    var head := MeshInstance3D.new()
    var hm := SphereMesh.new()
    hm.radius = 0.14
    hm.height = 0.28
    var km := StandardMaterial3D.new()
    km.albedo_color = skins[randi() % skins.size()]
    km.roughness = 1.0
    hm.material = km
    head.mesh = hm
    head.position.y = 0.55
    driver.add_child(head)
    var seat := Vector3(0.45, 0.72, -0.15)
    if size.x < 1.0:
        seat = Vector3(0.0, 0.95, 0.1)
    elif size.x < 1.5:
        seat = Vector3(0.0, 0.95, -0.5)
    elif size.z > 6.0:
        seat = Vector3(0.95, 1.7, -2.6)
    elif size.x > 2.3:
        seat = Vector3(0.62, 1.1, -0.25)
    driver.position = seat
    add_child(driver)
    _cull_node(driver)


# Driver ko gaari se bahar kheench kar zameen par gira dena
func eject_driver() -> bool:
    if driver == null or not is_instance_valid(driver):
        driver = null
        return false
    var d := driver
    driver = null
    var parent := get_parent()
    var from := d.global_position
    remove_child(d)
    parent.add_child(d)
    d.global_position = from
    d.global_rotation = global_rotation
    var out := global_position + global_transform.basis.x * (size.x * 0.5 + 0.9)
    out.y = 0.25
    var tw := d.create_tween()
    tw.set_parallel(true)
    tw.tween_property(d, "global_position", out, 0.4)
    tw.tween_property(d, "rotation:x", -PI / 2.0, 0.4)
    get_tree().create_timer(8.0).timeout.connect(d.queue_free)
    return true


# Saamne ki sadak dekho: pehle chaudai wala dibba aage bhej kar, phir aap ke liye alag jaanch
func _scan_ahead() -> void:
    block_dist = INF
    blocked_by_player = false
    var reach := minf(6.0 + absf(speed) * 1.3, 16.0)
    if scan_shape == null:
        scan_shape = BoxShape3D.new()
        scan_shape.size = Vector3(minf(size.x, 1.7), 1.3, 0.5)
    var fwd := -global_transform.basis.z
    var front := global_position + Vector3(0, 0.95, 0) + fwd * (size.z * 0.5 + 0.3)
    var p := PhysicsShapeQueryParameters3D.new()
    p.shape = scan_shape
    p.exclude = [get_rid()]
    p.transform = Transform3D(global_transform.basis, front)
    p.motion = fwd * reach
    var res := get_world_3d().direct_space_state.cast_motion(p)
    if res.size() >= 1 and res[0] < 1.0:
        block_dist = res[0] * reach

    # aap saamne khade hon (sadak ke beech mein bhi) to bhi gaari ruke
    if main_ref == null:
        main_ref = get_tree().current_scene
    if main_ref and not bool(main_ref.get("driving")):
        var pl := main_ref.get("player") as Node3D
        if pl:
            var rel := pl.global_position - global_position
            var ahead := rel.dot(fwd)
            var side := absf(rel.dot(Vector3.UP.cross(fwd)))
            if ahead > size.z * 0.4 and ahead < reach + size.z * 0.5 and side < 2.6:
                var d := maxf(ahead - size.z * 0.5, 0.0)
                if d < block_dist:
                    block_dist = d
                    blocked_by_player = true
