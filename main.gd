extends Node3D

const SPEED := 5.0
const GRAVITY := 20.0
const STICK_RADIUS := 170.0

var player: CharacterBody3D
var cam_pivot: Node3D
var ui: Control
var stick := Vector2.ZERO
var stick_touch := -1


func _ready() -> void:
    _make_world()
    _make_player()
    _make_ui()


func _make_world() -> void:
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.55, 0.72, 0.9)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.55, 0.6)
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    add_child(sun)
    _add_box(Vector3(0, -0.5, 0), Vector3(100, 1, 100), Color(0.35, 0.45, 0.3))
    var spots := [Vector3(6, 1, -8), Vector3(-7, 1.5, -12), Vector3(12, 1, 4), Vector3(-10, 1, 6), Vector3(0, 2, -20)]
    for p in spots:
        _add_box(p, Vector3(3, p.y * 2, 3), Color(0.7, 0.65, 0.55))


func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    bm.material = mat
    mesh.mesh = bm
    body.add_child(mesh)
    var col := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    col.shape = shape
    body.add_child(col)
    add_child(body)


func _make_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0, 0.1, 0)
    add_child(player)

    var body_mesh := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.4
    cap.height = 1.8
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.9, 0.45, 0.15)
    cap.material = mat
    body_mesh.mesh = cap
    body_mesh.position.y = 0.9
    player.add_child(body_mesh)

    var nose := MeshInstance3D.new()
    var nb := BoxMesh.new()
    nb.size = Vector3(0.25, 0.25, 0.5)
    nose.mesh = nb
    nose.position = Vector3(0, 1.4, -0.4)
    player.add_child(nose)

    var col := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.4
    shape.height = 1.8
    col.shape = shape
    col.position.y = 0.9
    player.add_child(col)

    cam_pivot = Node3D.new()
    cam_pivot.rotation.x = -0.35
    add_child(cam_pivot)
    var cam := Camera3D.new()
    cam.position = Vector3(0, 0, 6)
    cam.far = 300.0
    cam_pivot.add_child(cam)


func _physics_process(delta: float) -> void:
    var dir := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, cam_pivot.rotation.y)
    player.velocity.x = dir.x * SPEED
    player.velocity.z = dir.z * SPEED
    if player.is_on_floor():
        player.velocity.y = 0.0
    else:
        player.velocity.y -= GRAVITY * delta
    player.move_and_slide()
    if dir.length() > 0.1:
        var target := atan2(-dir.x, -dir.z)
        player.rotation.y = lerp_angle(player.rotation.y, target, 12.0 * delta)
    cam_pivot.global_position = player.global_position + Vector3(0, 1.5, 0)


func _stick_base() -> Vector2:
    return Vector2(300.0, get_viewport().get_visible_rect().size.y - 300.0)


func _make_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.draw.connect(_draw_ui)
    ui.queue_redraw()


func _draw_ui() -> void:
    var c := _stick_base()
    ui.draw_circle(c, STICK_RADIUS, Color(1, 1, 1, 0.15))
    ui.draw_circle(c + stick * STICK_RADIUS, 70.0, Color(1, 1, 1, 0.5))


func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if stick_touch == -1 and t.position.distance_to(_stick_base()) < STICK_RADIUS * 1.8:
                stick_touch = t.index
                _update_stick(t.position)
        elif t.index == stick_touch:
            stick_touch = -1
            stick = Vector2.ZERO
            ui.queue_redraw()
    elif event is InputEventScreenDrag:
        var d := event as InputEventScreenDrag
        if d.index == stick_touch:
            _update_stick(d.position)


func _update_stick(pos: Vector2) -> void:
    stick = ((pos - _stick_base()) / STICK_RADIUS).limit_length(1.0)
    ui.queue_redraw()
