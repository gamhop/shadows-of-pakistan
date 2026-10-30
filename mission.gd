extends CanvasLayer

# Level wale missions. Har level ka mission-type badalta hai (supply, hunt, deliver, race)
# aur har 4 level ke baad mushkil badhti hai: ROOKIE -> PRO -> ELITE.
# Mission poora karne par paisa milta hai (economy.gd) aur agla level khulta hai.

const DOOR_RANGE := 4.0
const POINT_RANGE := 7.0
const TYPES := ["supply", "hunt", "deliver", "race"]
const TIERS := ["ROOKIE", "PRO", "ELITE"]

var main_node: Node
var ui: Control
var holder: Node3D
var door: StaticBody3D
var door_home := Vector3.ZERO
var shelter_beam: MeshInstance3D
var point_beam: MeshInstance3D
var lines: Array = []
var shelter_pos := Vector3.ZERO
var target := Vector3.ZERO
var show_arrow := false
var action_btn: Button
var start_btn: Button
var end_menu: Control
var end_title: Label
var end_info: Label
var next_btn: Button
var free_btn: Button
var retry_btn: Button
var level := 1
var m: Dictionary = {}
var active := false
var finished := false
var step := 0
var time_left := 0.0
var start_kills := 0
var need_combat := false
var points: Array = []
var point_i := 0
var refill_t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 12
    main_node = get_parent()
    rng.randomize()
    _build_ui()


func _eco() -> Node:
    return main_node.get("economy") as Node


func _current_level() -> int:
    var e := _eco()
    return int(e.get("level")) if e else 1


# ------------------------------------------------------------ mission definitions

func _make_mission(lv: int) -> Dictionary:
    var tier := (lv - 1) / 4
    var d := {"level": lv, "type": TYPES[(lv - 1) % 4], "tier": tier}
    d["tier_name"] = TIERS[mini(tier, TIERS.size() - 1)]
    d["reward"] = 1000 + 800 * lv
    match str(d["type"]):
        "supply":
            d["title"] = "Safe House"
            d["water"] = mini(3 + tier, 7)
            d["food"] = mini(2 + tier, 5)
            d["kills"] = mini(3 + tier * 2, 9)
            d["time"] = 480.0
        "hunt":
            d["title"] = "Clean Sweep"
            d["kills"] = mini(5 + tier * 2, 14)
            d["time"] = 300.0
        "deliver":
            d["title"] = "Delivery"
            d["legs"] = mini(2 + tier, 5)
            d["time"] = float(maxi(170 - tier * 15, 100)) + 30.0 * float(mini(tier, 3))
        "race":
            d["title"] = "Checkpoint Rush"
            d["legs"] = mini(4 + tier * 2, 10)
            d["time"] = float(mini(4 + tier * 2, 10) * maxi(30 - tier * 3, 18))
    return d


func _pick_point(avoid: Vector3, min_d: float) -> Vector3:
    for t in 60:
        var x: float = lines[rng.randi() % lines.size()]
        var z: float = lines[rng.randi() % lines.size()]
        if Vector2(x - avoid.x, z - avoid.z).length() >= min_d:
            return Vector3(x, 0.0, z)
    return Vector3(lines[0], 0.0, lines[lines.size() - 1])


# ------------------------------------------------------------ world

func _mat(color: Color) -> StandardMaterial3D:
    var mt := StandardMaterial3D.new()
    mt.albedo_color = color
    mt.roughness = 1.0
    return mt


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


func _make_beam(color: Color) -> MeshInstance3D:
    var beam := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.5
    cm.bottom_radius = 0.5
    cm.height = 60.0
    cm.radial_segments = 12
    var bmat := StandardMaterial3D.new()
    bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    bmat.albedo_color = color
    cm.material = bmat
    beam.mesh = cm
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    holder.add_child(beam)
    return beam


func respawn(line_list: Array, seed_v: int) -> void:
    lines = line_list
    rng.seed = seed_v + int(Time.get_ticks_msec())
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    holder = Node3D.new()
    var cx: float = lines[0]
    var cz: float = lines[1] if lines.size() > 1 else lines[0]
    shelter_pos = Vector3(cx, 0.0, cz)
    _build_shelter(shelter_pos)
    point_beam = _make_beam(Color(0.2, 0.9, 1.0, 0.3))
    point_beam.visible = false
    main_node.add_child.call_deferred(holder)
    start_mission(_current_level(), false)


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
    door_home = door.position

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

    shelter_beam = _make_beam(Color(1.0, 0.85, 0.2, 0.28))
    shelter_beam.position = pos + Vector3(0, 30.0, 0)


# ------------------------------------------------------------ mission start / flow

func start_mission(lv: int, new_world: bool) -> void:
    level = lv
    m = _make_mission(lv)
    active = true
    finished = false
    step = 0
    time_left = float(m["time"])
    point_i = 0
    points.clear()
    show_arrow = false
    refill_t = 3.0
    end_menu.visible = false
    action_btn.visible = false
    if shelter_beam:
        shelter_beam.visible = false
    if point_beam:
        point_beam.visible = false
    if door:
        door.position = door_home
    var combat = main_node.get("combat")
    need_combat = combat != null
    var t := str(m["type"])
    if new_world:
        if need_combat and (t == "supply" or t == "hunt"):
            combat.call("respawn", lines, rng.randi())
        var sv = main_node.get("survival")
        if sv and t == "supply":
            sv.call("respawn", lines, rng.randi())
    start_kills = int(combat.get("kills")) if need_combat else 0
    match t:
        "supply":
            if shelter_beam:
                shelter_beam.visible = true
        "deliver", "race":
            var player := main_node.get("player") as Node3D
            var prev := player.global_position if player else Vector3.ZERO
            var n: int = int(m["legs"]) + (1 if t == "deliver" else 0)
            for i in n:
                var p := _pick_point(prev, 50.0 if i == 0 else 70.0)
                points.append(p)
                prev = p
            _set_target(points[0])
    _toast("%s  +Rs %d" % [str(m["title"]), int(m["reward"])])


func _set_target(p: Vector3) -> void:
    target = p
    show_arrow = true
    if point_beam:
        point_beam.position = p + Vector3(0, 30.0, 0)
        point_beam.visible = true


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

    start_btn = Button.new()
    start_btn.text = "START MISSION"
    start_btn.add_theme_font_size_override("font_size", 30)
    start_btn.anchor_left = 0.0
    start_btn.anchor_right = 0.0
    start_btn.anchor_top = 0.0
    start_btn.anchor_bottom = 0.0
    start_btn.offset_left = 60.0
    start_btn.offset_right = 420.0
    start_btn.offset_top = 260.0
    start_btn.offset_bottom = 345.0
    start_btn.visible = false
    start_btn.pressed.connect(_on_start)
    root.add_child(start_btn)

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
    next_btn = _btn("Next mission")
    next_btn.pressed.connect(_on_next)
    box.add_child(next_btn)
    retry_btn = _btn("Retry mission")
    retry_btn.pressed.connect(_on_retry)
    box.add_child(retry_btn)
    free_btn = _btn("Free roam")
    free_btn.pressed.connect(_on_free)
    box.add_child(free_btn)


# ------------------------------------------------------------ helpers

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


# Dushman kam par jayen to naye bana do (mission ke liye kaafi dushman hon)
func _refill_enemies(remaining: int) -> void:
    var c = main_node.get("combat")
    if c == null or remaining <= 0:
        return
    if int(c.get("alive")) < mini(remaining, 4) and refill_t <= 0.0:
        refill_t = 6.0
        c.call("respawn", lines, rng.randi())
        _toast("More enemies")


func _process(delta: float) -> void:
    if get_tree().paused:
        action_btn.visible = false
        start_btn.visible = false
        return
    ui.queue_redraw()
    start_btn.visible = not active
    if not active:
        start_btn.text = "START MISSION %d" % _current_level()
        action_btn.visible = false
        return
    refill_t = maxf(refill_t - delta, 0.0)
    time_left -= delta
    if time_left <= 0.0:
        _fail("Time ran out")
        return
    match str(m["type"]):
        "supply":
            _tick_supply()
        "hunt":
            _tick_hunt()
        _:
            _tick_points()


func _tick_supply() -> void:
    var counts: Array = _counts()
    match step:
        0:
            if counts[0] >= int(m["water"]) and counts[1] >= int(m["food"]):
                step = 1 if need_combat else 2
                _toast("Supplies collected")
                if step == 2:
                    _set_arrow_shelter()
        1:
            var left: int = int(m["kills"]) - (_kills() - start_kills)
            if left <= 0:
                step = 2
                _toast("Go to Safe House")
                _set_arrow_shelter()
            else:
                _refill_enemies(left)
    action_btn.visible = _dist_now_shelter() < DOOR_RANGE and not finished


func _set_arrow_shelter() -> void:
    target = shelter_pos + Vector3(0, 0, 2.0)
    show_arrow = true


func _dist_now_shelter() -> float:
    var player := main_node.get("player") as Node3D
    if player == null:
        return 999.0
    return Vector2(player.global_position.x - shelter_pos.x, player.global_position.z - (shelter_pos.z + 2.0)).length()


func _tick_hunt() -> void:
    var left: int = int(m["kills"]) - (_kills() - start_kills)
    if left <= 0:
        _complete()
    else:
        _refill_enemies(left)


func _tick_points() -> void:
    if point_i >= points.size():
        return
    if _dist_now() < POINT_RANGE:
        point_i += 1
        if point_i >= points.size():
            _complete()
            return
        if str(m["type"]) == "deliver":
            _toast("Package picked up" if point_i == 1 else "Delivered. Next stop")
        else:
            _toast("Checkpoint %d/%d" % [point_i, points.size()])
        _set_target(points[point_i])


func _objective_text() -> String:
    var counts: Array = _counts()
    match str(m["type"]):
        "supply":
            match step:
                0:
                    return "Water %d/%d  Food %d/%d" % [mini(counts[0], int(m["water"])), int(m["water"]), mini(counts[1], int(m["food"])), int(m["food"])]
                1:
                    return "Enemies %d/%d" % [mini(_kills() - start_kills, int(m["kills"])), int(m["kills"])]
            return "Safe House %d m" % int(_dist_now())
        "hunt":
            return "Enemies %d/%d" % [mini(_kills() - start_kills, int(m["kills"])), int(m["kills"])]
        "deliver":
            if point_i == 0:
                return "Package %d m" % int(_dist_now())
            return "Drop %d/%d  %d m" % [point_i, points.size() - 1, int(_dist_now())]
    return "Checkpoint %d/%d  %d m" % [point_i + 1, points.size(), int(_dist_now())]


func _draw_ui() -> void:
    if get_tree().paused or not active:
        return
    var vp := get_viewport().get_visible_rect().size
    var font := ThemeDB.fallback_font
    var t := int(maxf(time_left, 0.0))
    var line := "%s  %d:%02d   |   %s" % [str(m["title"]), t / 60, t % 60, _objective_text()]
    var sz := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
    var pos := Vector2(vp.x / 2.0 - sz.x / 2.0, 150.0)
    ui.draw_rect(Rect2(pos.x - 16.0, pos.y - 34.0, sz.x + 32.0, 50.0), Color(0, 0, 0, 0.4))
    ui.draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.92, 0.5))
    if show_arrow and not finished:
        var cam := get_viewport().get_camera_3d()
        var player := main_node.get("player") as Node3D
        if cam and player:
            var fwd := -cam.global_transform.basis.z
            fwd.y = 0.0
            var to_t := target - player.global_position
            to_t.y = 0.0
            if fwd.length() > 0.01 and to_t.length() > 0.5:
                var ang := fwd.normalized().signed_angle_to(to_t.normalized(), Vector3.UP)
                var c := Vector2(vp.x / 2.0, 250.0)
                var pts := PackedVector2Array()
                for p in [Vector2(0, -34), Vector2(22, 20), Vector2(0, 8), Vector2(-22, 20)]:
                    pts.append(c + p.rotated(-ang))
                ui.draw_colored_polygon(pts, Color(1, 0.85, 0.2, 0.9))


# ------------------------------------------------------------ buttons

func _on_action() -> void:
    if finished or door == null or str(m["type"]) != "supply":
        return
    var counts: Array = _counts()
    if counts[0] < int(m["water"]) or counts[1] < int(m["food"]):
        _toast("Need %d water and %d food in your bag" % [int(m["water"]), int(m["food"])])
        return
    if need_combat and _kills() - start_kills < int(m["kills"]):
        _toast("Eliminate %d enemies first" % int(m["kills"]))
        return
    counts[0] -= int(m["water"])
    counts[1] -= int(m["food"])
    var sv = main_node.get("survival")
    if sv:
        sv.call("_refresh_bag")
    var tw := create_tween()
    tw.tween_property(door, "position:x", door.position.x + 2.0, 0.8)
    finished = true
    action_btn.visible = false
    get_tree().create_timer(1.2).timeout.connect(_complete)


func _complete() -> void:
    if not active:
        return
    active = false
    finished = true
    var used := int(float(m["time"]) - time_left)
    var reward: int = int(m["reward"])
    var e := _eco()
    var lvl_next := level + 1
    if e:
        e.call("add_money", reward)
        e.call("complete_level")
        lvl_next = int(e.get("level"))
    end_title.text = "MISSION COMPLETE"
    end_title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
    var info := "Time %d:%02d   Reward: Rs %d" % [used / 60, used % 60, reward]
    if str(m["type"]) in ["supply", "hunt"]:
        info += "   Enemies down: %d" % (_kills() - start_kills)
    end_info.text = info
    next_btn.text = "Next mission (Level %d)" % lvl_next
    next_btn.visible = true
    retry_btn.visible = false
    free_btn.visible = true
    end_menu.visible = true
    get_tree().paused = true


func _fail(reason: String) -> void:
    active = false
    finished = true
    end_title.text = "MISSION FAILED"
    end_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
    end_info.text = reason
    next_btn.visible = false
    retry_btn.visible = true
    free_btn.visible = true
    end_menu.visible = true
    get_tree().paused = true


func _on_start() -> void:
    start_mission(_current_level(), true)


func _on_next() -> void:
    get_tree().paused = false
    start_mission(_current_level(), true)


func _on_retry() -> void:
    get_tree().paused = false
    start_mission(level, true)


func _on_free() -> void:
    end_menu.visible = false
    get_tree().paused = false
