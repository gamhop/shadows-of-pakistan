extends CharacterBody3D

# Bodyguard: aap ke saath chalta hai aur paas ke dushman par goli chalata hai.
# Dushman sirf aap ko nishana banate hain, isliye guard ko nuksan nahi hota.

const GRAVITY := 20.0
const RANGE := 28.0
const FIRE_CD := 0.5
const DAMAGE := 16.0
const WALK := 5.5
const RUN := 9.5
const ModelAvatarScript := preload("res://model_avatar.gd")

var main_node: Node
var slot := 0
var avatar: Node3D
var shape: CollisionShape3D
var cd := 0.0
var scan_t := 0.0
var target: Node3D = null
var was_driving := false


func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    shape = CollisionShape3D.new()
    var cs := CapsuleShape3D.new()
    cs.radius = 0.4
    cs.height = 1.8
    shape.shape = cs
    shape.position.y = 0.9
    add_child(shape)

    var ma := ModelAvatarScript.new()
    if ma.call("setup"):
        avatar = ma
    else:
        ma.free()
        avatar = Node3D.new()
        var mi := MeshInstance3D.new()
        var cm := CapsuleMesh.new()
        cm.radius = 0.4
        cm.height = 1.8
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.2, 0.45, 0.25)
        cm.material = mat
        mi.mesh = cm
        mi.position.y = 0.9
        avatar.add_child(mi)
    add_child(avatar)

    var tag := Label3D.new()
    tag.text = "GUARD"
    tag.font_size = 48
    tag.pixel_size = 0.006
    tag.outline_size = 10
    tag.modulate = Color(0.5, 1.0, 0.5)
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.position = Vector3(0, 2.25, 0)
    add_child(tag)

    var player := main_node.get("player") as CharacterBody3D
    if player:
        add_collision_exception_with(player)
        player.add_collision_exception_with(self)


func _find_target(player: Node3D) -> Node3D:
    var combat = main_node.get("combat")
    if combat == null:
        return null
    var h := combat.get("holder") as Node3D
    if h == null or not is_instance_valid(h):
        return null
    var best: Node3D = null
    var best_d := RANGE
    for n in h.get_children():
        if not is_instance_valid(n) or not n.has_method("take_damage") or n.get("dead"):
            continue
        var d := global_position.distance_to(n.global_position)
        if d < best_d and _los(n, player):
            best = n
            best_d = d
    return best


func _los(n: Node3D, player: Node3D) -> bool:
    var space := get_world_3d().direct_space_state
    var from := global_position + Vector3(0, 1.4, 0)
    var to := n.global_position + Vector3(0, 1.2, 0)
    var q := PhysicsRayQueryParameters3D.create(from, to)
    var ex: Array = [get_rid()]
    var pb := player as CollisionObject3D
    if pb:
        ex.append(pb.get_rid())
    q.exclude = ex
    var hit := space.intersect_ray(q)
    return hit.is_empty() or hit["collider"] == n


func _shoot(n: Node3D) -> void:
    var combat = main_node.get("combat")
    if combat == null:
        return
    var from := global_position + Vector3(0, 1.4, 0)
    var end := n.global_position + Vector3(0, 1.2, 0)
    var dir := (end - from).normalized()
    n.call("take_damage", DAMAGE, end, dir, false)
    combat.call("_tracer", from + dir * 0.6, end)
    cd = FIRE_CD + randf() * 0.2


func _physics_process(delta: float) -> void:
    var player := main_node.get("player") as Node3D
    if player == null:
        return
    if bool(main_node.get("driving")):
        if not was_driving:
            was_driving = true
            visible = false
            shape.set_deferred("disabled", true)
        global_position = player.global_position
        velocity = Vector3.ZERO
        return
    if was_driving:
        was_driving = false
        visible = true
        shape.set_deferred("disabled", false)
        global_position = player.global_position + Vector3(2.0, 0.3, 2.0)

    var yaw: float = main_node.get("cam_yaw")
    var offs := [Vector3(-2.4, 0, -0.6), Vector3(2.4, 0, -0.6), Vector3(0, 0, -3.2)]
    var want: Vector3 = player.global_position + (offs[slot % 3] as Vector3).rotated(Vector3.UP, yaw)
    var to_w := want - global_position
    to_w.y = 0.0
    var d := to_w.length()
    if d > 45.0:
        global_position = want + Vector3(0, 0.3, 0)
        velocity = Vector3.ZERO
        return
    var spd := 0.0
    var dir := Vector3.ZERO
    if d > 0.5:
        dir = to_w / d
        spd = RUN if d > 6.0 else WALK * clampf(d / 1.5, 0.0, 1.0)
    velocity.x = dir.x * spd
    velocity.z = dir.z * spd
    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= GRAVITY * delta
    move_and_slide()

    scan_t -= delta
    if scan_t <= 0.0:
        scan_t = 0.25
        target = _find_target(player)
    cd = maxf(cd - delta, 0.0)
    var face := dir
    if target != null and is_instance_valid(target) and not bool(target.get("dead")):
        face = target.global_position - global_position
        face.y = 0.0
        if cd <= 0.0:
            _shoot(target)
    else:
        target = null
    if face.length() > 0.05:
        rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 10.0 * delta)
    if avatar.has_method("animate"):
        avatar.call("animate", Vector2(velocity.x, velocity.z).length(), d > 6.0, delta)
