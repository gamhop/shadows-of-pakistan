extends CharacterBody3D

signal died

const GRAVITY := 20.0
const WALK_SPEED := 1.6
const CHASE_SPEED := 4.2
const SIGHT_RANGE := 22.0
const LOSE_RANGE := 36.0
const ATTACK_RANGE := 1.9
const ATTACK_DAMAGE := 8.0
const ATTACK_COOLDOWN := 1.0
const MAX_HEALTH := 100.0

var health := MAX_HEALTH
var dead := false
var chasing := false
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var idle_time := 1.0
var walk_time := 0.0
var attack_cd := 0.0
var lost_time := 0.0
var main_node: Node
var player: Node3D
var col_shape: CollisionShape3D
var bar_bg: MeshInstance3D
var bar_fg: MeshInstance3D
var bar_mesh: QuadMesh
var rng := RandomNumberGenerator.new()


func _ready() -> void:
    main_node = get_tree().current_scene
    rng.randomize()
    home = global_position
    wander_target = home

    var shape := CapsuleShape3D.new()
    shape.radius = 0.4
    shape.height = 1.8
    col_shape = CollisionShape3D.new()
    col_shape.shape = shape
    col_shape.position.y = 0.9
    add_child(col_shape)

    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.4
    cap.height = 1.8
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.45, 0.1, 0.1)
    cap.material = body_mat
    body.mesh = cap
    body.position.y = 0.9
    add_child(body)

    var head := MeshInstance3D.new()
    var hs := SphereMesh.new()
    hs.radius = 0.2
    hs.height = 0.4
    hs.radial_segments = 10
    hs.rings = 5
    var head_mat := StandardMaterial3D.new()
    head_mat.albedo_color = Color(0.75, 0.55, 0.4)
    hs.material = head_mat
    head.mesh = hs
    head.position = Vector3(0, 1.75, 0)
    add_child(head)

    var gun := MeshInstance3D.new()
    var gb := BoxMesh.new()
    gb.size = Vector3(0.1, 0.12, 0.6)
    gun.mesh = gb
    gun.position = Vector3(0.3, 1.1, -0.45)
    add_child(gun)

    bar_bg = MeshInstance3D.new()
    var bg_mesh := QuadMesh.new()
    bg_mesh.size = Vector2(1.0, 0.12)
    bg_mesh.material = _bar_mat(Color(0, 0, 0))
    bar_bg.mesh = bg_mesh
    bar_bg.position = Vector3(0, 2.3, 0)
    bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bar_bg)

    bar_fg = MeshInstance3D.new()
    bar_mesh = QuadMesh.new()
    bar_mesh.material = _bar_mat(Color(0.9, 0.1, 0.1))
    bar_fg.mesh = bar_mesh
    bar_fg.position = Vector3(0, 2.3, 0)
    bar_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bar_fg)
    _update_bar()


func _bar_mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    return m


func _update_bar() -> void:
    var w := 0.96 * clampf(health / MAX_HEALTH, 0.0, 1.0)
    bar_mesh.size = Vector2(maxf(w, 0.001), 0.08)
    bar_mesh.center_offset = Vector3(-(0.96 - w) / 2.0, 0.0, 0.01)


func _face(v: Vector3, delta: float) -> void:
    if v.length() < 0.01:
        return
    rotation.y = lerp_angle(rotation.y, atan2(-v.x, -v.z), 8.0 * delta)


func _has_line_of_sight() -> bool:
    var space := get_world_3d().direct_space_state
    var from := global_position + Vector3(0, 1.5, 0)
    var to := player.global_position + Vector3(0, 1.2, 0)
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [get_rid()]
    var hit := space.intersect_ray(q)
    return hit.is_empty() or hit["collider"] == player


func _hit_player() -> void:
    var h: float = main_node.get("health")
    main_node.set("health", h - ATTACK_DAMAGE)
    var combat := get_tree().get_first_node_in_group("combat")
    if combat:
        combat.call("flash")


func take_damage(amount: float) -> void:
    if dead:
        return
    health -= amount
    chasing = true
    lost_time = 0.0
    _update_bar()
    if health <= 0.0:
        _die()


func _die() -> void:
    dead = true
    died.emit()
    col_shape.set_deferred("disabled", true)
    bar_bg.visible = false
    bar_fg.visible = false
    rotation_degrees.x = -90.0
    position.y += 0.4
    get_tree().create_timer(6.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
    if dead:
        return
    if player == null:
        player = main_node.get("player") as Node3D
        if player == null:
            return
    attack_cd = maxf(attack_cd - delta, 0.0)
    var flat := player.global_position - global_position
    flat.y = 0.0
    var dist := flat.length()
    var sees := dist < SIGHT_RANGE and _has_line_of_sight()
    if sees:
        chasing = true
        lost_time = 0.0
    elif chasing:
        lost_time += delta
        if dist > LOSE_RANGE or lost_time > 5.0:
            chasing = false
            home = global_position
            idle_time = 1.0

    if chasing:
        _face(flat, delta)
        var dir := flat.normalized() if dist > ATTACK_RANGE * 0.8 else Vector3.ZERO
        velocity.x = dir.x * CHASE_SPEED
        velocity.z = dir.z * CHASE_SPEED
        if dist <= ATTACK_RANGE and attack_cd <= 0.0:
            attack_cd = ATTACK_COOLDOWN
            _hit_player()
    elif idle_time > 0.0:
        idle_time -= delta
        velocity.x = 0.0
        velocity.z = 0.0
        if idle_time <= 0.0:
            wander_target = home + Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
            walk_time = 0.0
    else:
        walk_time += delta
        var to_t := wander_target - global_position
        to_t.y = 0.0
        if to_t.length() < 0.6 or walk_time > 6.0:
            idle_time = rng.randf_range(1.5, 4.0)
            velocity.x = 0.0
            velocity.z = 0.0
        else:
            var d := to_t.normalized()
            _face(to_t, delta)
            velocity.x = d.x * WALK_SPEED
            velocity.z = d.z * WALK_SPEED

    if is_on_floor():
        velocity.y = 0.0
    else:
        velocity.y -= GRAVITY * delta
    move_and_slide()
