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


func _ready() -> void:
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


func can_enter() -> bool:
    if mode == Mode.PLAYER:
        return false
    return absf(speed) < 3.0


func take_control() -> void:
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
    set_physics_process(true)


func _physics_process(delta: float) -> void:
    if mode == Mode.AI:
        _ai(delta)
        return
    if mode == Mode.PARKED:
        return
    _drive(delta)
    if mode == Mode.COAST and absf(speed) < 0.15:
        speed = 0.0
        mode = Mode.PARKED
        set_physics_process(false)


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
            if (a - trig) * da >= 0.0:
                done_line = road
                road = plan_line
                ai_dir = plan_dir
                plan_line = INF
                return

    # saamne koi rukawat?
    var target := ai_cruise
    var from := global_position + Vector3(0, 0.8, 0) + ai_dir * (size.z * 0.5 + 0.3)
    var reach := 5.0 + speed
    var q := PhysicsRayQueryParameters3D.create(from, from + ai_dir * reach)
    q.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(q)
    if not hit.is_empty():
        var d := from.distance_to(hit["position"])
        target = 0.0 if d < 3.5 + speed * 0.5 else ai_cruise * 0.4
    var rate := accel if target > speed else brake
    speed = move_toward(speed, target, rate * delta)

    # apni lane mein rehna (baen taraf ki traffic)
    var lane := Vector3.UP.cross(ai_dir) * LANE
    var pos := global_position
    var k := clampf(6.0 * delta, 0.0, 1.0)
    if is_z:
        pos.x = lerpf(pos.x, road + lane.x, k)
    else:
        pos.z = lerpf(pos.z, road + lane.z, k)
    pos += ai_dir * speed * delta
    global_position = pos
    rotation.y = lerp_angle(rotation.y, atan2(-ai_dir.x, -ai_dir.z), k)
