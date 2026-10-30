extends CanvasLayer

const NEED_WATER := 3
const NEED_FOOD := 2
const KILL_GOAL := 3
const TIME_LIMIT := 480.0
const DOOR_RANGE := 4.0

var main_node: Node
var ui: Control
var holder: Node3D
var door: StaticBody3D
var target := Vector3.ZERO
var action_btn: Button
var end_menu: Control
var end_title: Label
var end_info: Label
var continue_btn: Button
var step := 0
var time_left := TIME_LIMIT
var start_kills := 0
var finished := false
var need_combat := false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 12
    main_node = get_parent()
    _build_ui()


func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    return m


func _solid_box(pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = pos
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    bm.material = mat
    mi.mesh = bm
    body.add_child(mi)
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    body.add_child(cs)
    holder.add_child(body)
    return body


func respawn(lines: Array, _seed_v: int) -> void:
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    holder = Node3D.new()
    var cx: float = lines[0]
    var cz: float = lines[1] if lines.size() > 1 else lines[0]
    target = Vector3(cx, 0.0, cz + 2.0)
    _build_shelter(Vector3(cx, 0.0, cz))
    main_node.add_child.call_deferred(holder)
    step = 0
    time_left = TIME_LIMIT
    finished = false
    var combat = main_node.get("combat")
    need_combat = combat != null
    start_kills = int(combat.get("kills")) if need_combat else 0
    end_menu.visible = false
    action_btn.visible = false


func _build_shelter(pos: Vector3) -> void:
    var wall := _mat(Color(0.75, 0.7, 0.6))
    var roof := _mat(Color(0.3, 0.3, 0.32))
    _solid_box(pos + Vector3(0, 1.6, -2.0), Vector3(6.0, 3.2, 0.3), wall)
    _solid_box(pos + Vector3(-2.85, 1.6, 0.0), Vector3(0.3, 3.2, 4.0), wall)
    _solid_box(pos + Vector3(2.85, 1.6, 0.0), Vector3(0.3, 3.2, 4.0), wall)
    _solid_box(pos + Vector3(0, 3.35, 0.0), Vector3(6.3, 0.3, 4.3), roof)
    _solid_box(pos + Vector3(-1.95, 1.6, 2.0), Vector3(2.1, 3.2, 0.3), wall)
    _solid_box(pos + Vector3(1.95, 1.6, 2.0), Vector3(2.1, 3.2, 0.3), wall)
    _solid_box(pos + Vector3(0, 2.9, 2.0), Vector3(1.8, 0.6, 0.3), wall)
    door = _solid_box(pos + Vector3(0, 1.3, 2.0), Vector3(1.8, 2.6, 0.2), _mat(Color(0.45, 0.2, 0.15)))

    var sign_label := Label3D.new()
    sign_label.text = "SAFE HOUSE"
    sign_label.font_size = 96
    sign_label.pixel_size = 0.006
    sign_label.outline_size = 12
    sign_label.position = pos + Vector3(0, 3.05, 2.2)
    holder.add_child(sign_label)

    var lamp := OmniLight3D.new()
    lamp.position = pos + Vector3(0, 2.6, 0)
    lamp.omni_range = 7.0
    lamp.light_energy = 1.4
    holder.add_child(lamp)

    var beam := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.5
    cm.bottom_radius = 0.5
    cm.height = 60.0
    cm.radial_segments = 12
    var bmat := StandardMaterial3D.new()
    bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bmat.albedo_color = Color(1.0, 0.85, 0.2, 0.28)
    cm.material = bmat
    beam.mesh = cm
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    beam.position = pos + Vector3(0, 30.0, 0)
    holder.add_child(beam)


func _btn(text: String) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(760, 84)
    b.add_theme_font_size_override("font_size", 34)
    return b


func _build_ui() -> void:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.draw.connect(_draw_ui)

    action_btn = Button.new()
    action_btn.text = "OPEN DOOR"
    action_btn.add_theme_font_size_override("font_size", 38)
    action_btn.anchor_left = 1.0
    action_btn.anchor_right = 1.0
    action_btn.anchor_top = 1.0
    action_btn.anchor_bottom = 1.0
    action_btn.offset_left = -440.0
    action_btn.offset_right = -140.0
    action_btn.offset_top = -830.0
    action_btn.offset_bottom = -720.0
    action_btn.visible = false
    action_btn.pressed.connect(_on_action)
    root.add_child(action_btn)

    end_menu = Control.new()
    end_menu.visible = false
    root.add_child(end_menu)
    end_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    end_menu.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    end_menu.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 36)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)
    end_title = Label.new()
    end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_title.add_theme_font_size_override("font_size", 60)
    box.add_child(end_title)
    end_info = Label.new()
    end_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    end_info.add_theme_font_size_override("font_size", 34)
    box.add_child(end_info)
    continue_btn = _btn("Continue (free roam)")
    continue_btn.pressed.connect(_on_continue)
    box.add_child(continue_btn)
    var again := _btn("Restart mission")
    again.pressed.connect(_on_restart)
    box.add_child(again)


func _counts() -> Array:
    var sv = main_node.get("survival")
    if sv:
        return sv.get("counts")
    return [0, 0, 0]


func _kills() -> int:
    var c = main_node.get("combat")
    if c:
        return int(c.get("kills"))
    return 0


func _dist_now() -> float:
    var player := main_node.get("player") as Node3D
    if player == null:
        return 0.0
    return Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length()


func _toast(msg: String) -> void:
    var sv = main_node.get("survival")
    if sv:
        sv.call("_show_toast", msg)


func _process(delta: float) -> void:
    if get_tree().paused:
        action_btn.visible = false
        return
    ui.queue_redraw()
    if finished:
        action_btn.visible = false
        return
    time_left -= delta
    if time_left <= 0.0:
        _fail("Time ran out")
        return
    var counts: Array = _counts()
    match step:
        0:
            if counts[0] >= NEED_WATER and counts[1] >= NEED_FOOD:
                step = 1 if need_combat else 2
                _toast("Supplies collected")
        1:
            if _kills() - start_kills >= KILL_GOAL:
                step = 2
                _toast("Path is clear - head to the Safe House")
    action_btn.visible = _dist_now() < DOOR_RANGE


func _objective_text() -> String:
    if finished:
        return "Mission complete - free roam"
    var counts: Array = _counts()
    match step:
        0:
            return "Collect supplies: Water %d/%d   Food %d/%d" % [mini(counts[0], NEED_WATER), NEED_WATER, mini(counts[1], NEED_FOOD), NEED_FOOD]
        1:
            return "Eliminate enemies: %d/%d" % [mini(_kills() - start_kills, KILL_GOAL), KILL_GOAL]
    return "Reach the Safe House: %d m" % int(_dist_now())


func _draw_ui() -> void:
    if get_tree().paused:
        return
    var vp := get_viewport().get_visible_rect().size
    var font := ThemeDB.fallback_font
    var t := int(maxf(time_left, 0.0))
    var head := "MISSION 1: Safe House   %d:%02d" % [t / 60, t % 60]
    ui.draw_string(font, Vector2(vp.x / 2.0 - 450, 300), head, HORIZONTAL_ALIGNMENT_CENTER, 900, 34, Color(1, 0.9, 0.4))
    ui.draw_string(font, Vector2(vp.x / 2.0 - 450, 345), _objective_text(), HORIZONTAL_ALIGNMENT_CENTER, 900, 32)
    if step == 2 and not finished:
        var cam := get_viewport().get_camera_3d()
        var player := main_node.get("player") as Node3D
        if cam and player:
            var fwd := -cam.global_transform.basis.z
            fwd.y = 0.0
            var to_t := target - player.global_position
            to_t.y = 0.0
            if fwd.length() > 0.01 and to_t.length() > 0.5:
                var ang := fwd.normalized().signed_angle_to(to_t.normalized(), Vector3.UP)
                var c := Vector2(vp.x / 2.0, 440.0)
                var pts := PackedVector2Array()
                for p in [Vector2(0, -44), Vector2(28, 26), Vector2(0, 10), Vector2(-28, 26)]:
                    pts.append(c + p.rotated(-ang))
                ui.draw_colored_polygon(pts, Color(1, 0.85, 0.2, 0.9))


func _on_action() -> void:
    if finished or door == null:
        return
    var counts: Array = _counts()
    if counts[0] < NEED_WATER or counts[1] < NEED_FOOD:
        _toast("Need %d water and %d food in your bag" % [NEED_WATER, NEED_FOOD])
        return
    if need_combat and _kills() - start_kills < KILL_GOAL:
        _toast("Eliminate %d enemies first" % KILL_GOAL)
        return
    counts[0] -= NEED_WATER
    counts[1] -= NEED_FOOD
    var sv = main_node.get("survival")
    if sv:
        sv.call("_refresh_bag")
    var tw := create_tween()
    tw.tween_property(door, "position:x", door.position.x + 2.0, 0.8)
    step = 3
    finished = true
    action_btn.visible = false
    get_tree().create_timer(1.2).timeout.connect(_complete)


func _complete() -> void:
    var used := int(TIME_LIMIT - time_left)
    end_title.text = "MISSION COMPLETE"
    end_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
    end_info.text = "Time %d:%02d   Enemies down: %d" % [used / 60, used % 60, _kills() - start_kills]
    continue_btn.visible = true
    end_menu.visible = true
    get_tree().paused = true


func _fail(reason: String) -> void:
    finished = true
    end_title.text = "MISSION FAILED"
    end_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
    end_info.text = reason
    continue_btn.visible = false
    end_menu.visible = true
    get_tree().paused = true


func _on_continue() -> void:
    end_menu.visible = false
    get_tree().paused = false


func _on_restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()
