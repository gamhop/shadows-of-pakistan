extends CanvasLayer

const ENEMY_SCRIPT := preload("res://enemy.gd")
const ENEMY_COUNT := 10
const FIRE_RATE := 0.12
const DAMAGE := 20.0
const MAG_SIZE := 30
const RELOAD_TIME := 1.8
const SHOT_RANGE := 70.0

var main_node: Node
var ui: Control
var holder: Node3D
var ammo := MAG_SIZE
var reload_left := 0.0
var cooldown := 0.0
var fire_touch := -1
var kills := 0
var alive := 0
var flash_t := 0.0
var hit_t := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 8
    add_to_group("combat")
    main_node = get_parent()
    _build_ui()


func respawn(lines: Array, seed_v: int) -> void:
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    alive = 0
    holder = Node3D.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var player := main_node.get("player") as Node3D
    var origin := player.global_position if player else Vector3.ZERO
    var made := 0
    var tries := 0
    while made < ENEMY_COUNT and tries < 300:
        tries += 1
        var c: float = lines[rng.randi() % lines.size()]
        var along := rng.randf_range(-95.0, 95.0)
        var off := rng.randf_range(-2.5, 2.5)
        var x := c + off
        var z := along
        if rng.randf() < 0.5:
            x = along
            z = c + off
        if Vector2(x - origin.x, z - origin.z).length() < 28.0:
            continue
        var e = ENEMY_SCRIPT.new()
        e.position = Vector3(x, 0.1, z)
        e.died.connect(_on_enemy_died)
        holder.add_child(e)
        alive += 1
        made += 1
    main_node.add_child.call_deferred(holder)


func _on_enemy_died() -> void:
    kills += 1
    alive -= 1


func flash() -> void:
    flash_t = 0.45


func _build_ui() -> void:
    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.draw.connect(_draw_ui)


func _fire_base() -> Vector2:
    var vp := get_viewport().get_visible_rect().size
    return Vector2(vp.x - 600.0, vp.y - 210.0)


func _draw_ui() -> void:
    var vp := get_viewport().get_visible_rect().size
    var c := vp / 2.0
    var cc := Color(1, 0.3, 0.3) if hit_t > 0.0 else Color(1, 1, 1, 0.9)
    ui.draw_line(c + Vector2(-22, 0), c + Vector2(-8, 0), cc, 3.0)
    ui.draw_line(c + Vector2(8, 0), c + Vector2(22, 0), cc, 3.0)
    ui.draw_line(c + Vector2(0, -22), c + Vector2(0, -8), cc, 3.0)
    ui.draw_line(c + Vector2(0, 8), c + Vector2(0, 22), cc, 3.0)

    var fb := _fire_base()
    var fcol := Color(0.9, 0.2, 0.2, 0.55) if fire_touch != -1 else Color(1, 1, 1, 0.2)
    ui.draw_circle(fb, 120.0, fcol)
    ui.draw_string(ThemeDB.fallback_font, fb + Vector2(-100, 16), "FIRE", HORIZONTAL_ALIGNMENT_CENTER, 200, 44)
    var ammo_text := "RELOADING" if reload_left > 0.0 else "AMMO " + str(ammo)
    ui.draw_string(ThemeDB.fallback_font, fb + Vector2(-140, -140), ammo_text, HORIZONTAL_ALIGNMENT_CENTER, 280, 36)
    ui.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2.0 - 220, 130), "Kills: %d   Enemies: %d" % [kills, alive], HORIZONTAL_ALIGNMENT_CENTER, 440, 38)
    if flash_t > 0.0:
        ui.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.8, 0.0, 0.0, flash_t))


func _input(event: InputEvent) -> void:
    if get_tree().paused:
        return
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if fire_touch == -1 and t.position.distance_to(_fire_base()) < 150.0:
                fire_touch = t.index
                get_viewport().set_input_as_handled()
        elif t.index == fire_touch:
            fire_touch = -1


func _process(delta: float) -> void:
    if get_tree().paused:
        fire_touch = -1
        return
    flash_t = maxf(flash_t - delta, 0.0)
    hit_t = maxf(hit_t - delta, 0.0)
    ui.queue_redraw()


func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    cooldown = maxf(cooldown - delta, 0.0)
    if reload_left > 0.0:
        reload_left -= delta
        if reload_left <= 0.0:
            ammo = MAG_SIZE
    elif fire_touch != -1 and cooldown <= 0.0:
        _shoot()
        cooldown = FIRE_RATE
        ammo -= 1
        if ammo <= 0:
            reload_left = RELOAD_TIME


func _shoot() -> void:
    var cam := get_viewport().get_camera_3d()
    var player := main_node.get("player") as CharacterBody3D
    if cam == null or player == null:
        return
    var from := cam.global_position
    var to := from + (-cam.global_transform.basis.z) * SHOT_RANGE
    var space := cam.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [player.get_rid()]
    var hit := space.intersect_ray(q)
    var end := to
    if not hit.is_empty():
        end = hit["position"]
        var col = hit["collider"]
        if col and col.has_method("take_damage"):
            col.take_damage(DAMAGE)
            hit_t = 0.15
    _tracer(player.global_position + Vector3(0, 1.4, 0), end)


func _tracer(from: Vector3, to: Vector3) -> void:
    var length := from.distance_to(to)
    if length < 0.5:
        return
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.04, 0.04, length)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.9, 0.4)
    bm.material = mat
    mi.mesh = bm
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    main_node.add_child(mi)
    mi.global_position = (from + to) / 2.0
    mi.look_at(to, Vector3.UP)
    get_tree().create_timer(0.05).timeout.connect(mi.queue_free)
