extends CanvasLayer

const NAMES := ["Water", "Food", "Medkit"]
const VERBS := ["Drink", "Eat", "Use"]
const DECAY_WATER := 0.35
const DECAY_FOOD := 0.2
const PICK_RANGE := 2.2

var water := 100.0
var food := 100.0
var counts := [0, 0, 0]
var items := []
var toast_time := 0.0
var nearest := -1
var holder: Node3D

var main_node: Node
var water_bar: ColorRect
var food_bar: ColorRect
var pick_btn: Button
var bag_btn: Button
var bag_menu: Control
var death_menu: Control
var toast: Label
var bag_info: Label
var use_btns := []


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 11
    main_node = get_parent()
    _build_ui()


func respawn(lines: Array, seed_v: int) -> void:
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    items.clear()
    nearest = -1
    holder = Node3D.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    for i in 48:
        var kind := rng.randi() % 3
        var c: float = lines[rng.randi() % lines.size()]
        var off := rng.randf_range(-2.5, 2.5)
        if rng.randf() < 0.5:
            var s := 1.0 if rng.randf() < 0.5 else -1.0
            off = s * rng.randf_range(5.4, 7.0)
        var along := rng.randf_range(-95.0, 95.0)
        var x := c + off
        var z := along
        if rng.randf() < 0.5:
            x = along
            z = c + off
        var node := MeshInstance3D.new()
        var color := Color(0.2, 0.55, 1.0)
        match kind:
            0:
                var cm := CylinderMesh.new()
                cm.top_radius = 0.12
                cm.bottom_radius = 0.12
                cm.height = 0.4
                cm.radial_segments = 10
                node.mesh = cm
                color = Color(0.2, 0.55, 1.0)
            1:
                var bm := BoxMesh.new()
                bm.size = Vector3(0.4, 0.2, 0.3)
                node.mesh = bm
                color = Color(1.0, 0.6, 0.15)
            2:
                var mm := BoxMesh.new()
                mm.size = Vector3(0.45, 0.3, 0.3)
                node.mesh = mm
                color = Color(0.9, 0.15, 0.15)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.6
        node.material_override = mat
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        node.position = Vector3(x, 0.55, z)
        holder.add_child(node)
        items.append({"node": node, "kind": kind})
    main_node.add_child.call_deferred(holder)


func _button(text: String, fs: int) -> Button:
    var b := Button.new()
    b.text = text
    b.add_theme_font_size_override("font_size", fs)
    return b


func _bar(root: Control, y: float, h: float, color: Color) -> ColorRect:
    var bg := ColorRect.new()
    bg.color = Color(0, 0, 0, 0.45)
    bg.position = Vector2(140, y)
    bg.size = Vector2(500, h)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bg)
    var fill := ColorRect.new()
    fill.color = color
    fill.size = Vector2(500, h)
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bg.add_child(fill)
    return fill


func _make_menu(root: Control, title_text: String, dim_color: Color) -> VBoxContainer:
    var menu := Control.new()
    menu.visible = false
    root.add_child(menu)
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = dim_color
    menu.add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    menu.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var panel := PanelContainer.new()
    center.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 30)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    margin.add_child(box)
    var title := Label.new()
    title.text = title_text
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 52)
    box.add_child(title)
    box.set_meta("menu", menu)
    return box


func _build_ui() -> void:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    water_bar = _bar(root, 122.0, 22.0, Color(0.2, 0.55, 1.0))
    food_bar = _bar(root, 154.0, 22.0, Color(1.0, 0.6, 0.15))

    toast = Label.new()
    toast.add_theme_font_size_override("font_size", 44)
    toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast.visible = false
    root.add_child(toast)
    toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    toast.offset_top = 170.0
    toast.offset_bottom = 240.0

    pick_btn = _button("PICK UP", 38)
    pick_btn.anchor_left = 1.0
    pick_btn.anchor_right = 1.0
    pick_btn.anchor_top = 1.0
    pick_btn.anchor_bottom = 1.0
    pick_btn.offset_left = -440.0
    pick_btn.offset_right = -140.0
    pick_btn.offset_top = -560.0
    pick_btn.offset_bottom = -450.0
    pick_btn.visible = false
    pick_btn.pressed.connect(_on_pick)
    root.add_child(pick_btn)

    bag_btn = _button("BAG", 34)
    bag_btn.anchor_left = 1.0
    bag_btn.anchor_right = 1.0
    bag_btn.anchor_top = 0.0
    bag_btn.anchor_bottom = 0.0
    bag_btn.offset_left = -300.0
    bag_btn.offset_right = -40.0
    bag_btn.offset_top = 140.0
    bag_btn.offset_bottom = 230.0
    bag_btn.pressed.connect(_open_bag)
    root.add_child(bag_btn)

    var bag_box := _make_menu(root, "BAG", Color(0, 0, 0, 0.55))
    bag_menu = bag_box.get_meta("menu")
    bag_info = Label.new()
    bag_info.add_theme_font_size_override("font_size", 34)
    bag_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bag_box.add_child(bag_info)
    for i in 3:
        var b := _button("", 34)
        b.custom_minimum_size = Vector2(760, 80)
        b.pressed.connect(_use.bind(i))
        bag_box.add_child(b)
        use_btns.append(b)
    var close_btn := _button("Close", 34)
    close_btn.custom_minimum_size = Vector2(760, 80)
    close_btn.pressed.connect(_close_bag)
    bag_box.add_child(close_btn)

    var death_box := _make_menu(root, "YOU DIED", Color(0.35, 0, 0, 0.7))
    death_menu = death_box.get_meta("menu")
    var restart_btn := _button("Restart", 40)
    restart_btn.custom_minimum_size = Vector2(760, 100)
    restart_btn.pressed.connect(_restart)
    death_box.add_child(restart_btn)


func _process(delta: float) -> void:
    var paused := get_tree().paused
    bag_btn.visible = not paused
    if paused:
        pick_btn.visible = false
        return

    water = maxf(water - DECAY_WATER * delta, 0.0)
    food = maxf(food - DECAY_FOOD * delta, 0.0)
    var health: float = main_node.get("health")
    if water <= 0.0 or food <= 0.0:
        health -= 2.0 * delta
    elif water > 60.0 and food > 60.0 and health < 100.0:
        health = minf(health + 0.5 * delta, 100.0)
    main_node.set("health", health)
    water_bar.size.x = 500.0 * water / 100.0
    food_bar.size.x = 500.0 * food / 100.0
    if health <= 0.0:
        get_tree().paused = true
        death_menu.visible = true
        return

    nearest = -1
    var best := PICK_RANGE
    var player := main_node.get("player") as Node3D
    for i in items.size():
        var node: MeshInstance3D = items[i]["node"]
        if not node.is_inside_tree():
            continue
        node.rotation.y += 1.5 * delta
        if player:
            var d := node.global_position.distance_to(player.global_position + Vector3(0, 0.9, 0))
            if d < best:
                best = d
                nearest = i
    pick_btn.visible = nearest >= 0

    if toast_time > 0.0:
        toast_time -= delta
        if toast_time <= 0.0:
            toast.visible = false


func _show_toast(text: String) -> void:
    toast.text = text
    toast.visible = true
    toast_time = 1.4


func _on_pick() -> void:
    if nearest < 0 or nearest >= items.size():
        return
    var entry = items[nearest]
    var kind: int = entry["kind"]
    counts[kind] += 1
    _show_toast("+1 " + NAMES[kind])
    var node: MeshInstance3D = entry["node"]
    node.queue_free()
    items.remove_at(nearest)
    nearest = -1
    pick_btn.visible = false
    _refresh_bag()






func _reset_main_input() -> void:
    main_node.set("stick", Vector2.ZERO)
    main_node.set("stick_touch", -1)
    main_node.set("look_touch", -1)
    main_node.set("run_touch", -1)


func _open_bag() -> void:
    _reset_main_input()
    _refresh_bag()
    get_tree().paused = true
    bag_menu.visible = true


func _close_bag() -> void:
    bag_menu.visible = false
    _reset_main_input()
    get_tree().paused = false


func _restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()


func _bars_now() -> void:
    water_bar.size.x = 500.0 * water / 100.0
    food_bar.size.x = 500.0 * food / 100.0


func _use(kind: int) -> void:
    if counts[kind] <= 0:
        return
    var health: float = main_node.get("health")
    var msg := ""
    match kind:
        0:
            if water >= 99.0:
                msg = "Water already full"
            else:
                water = minf(water + 35.0, 100.0)
                msg = "Water +35"
        1:
            if food >= 99.0:
                msg = "Food already full"
            else:
                food = minf(food + 35.0, 100.0)
                msg = "Food +35"
        2:
            if health >= 99.0:
                msg = "Health already full"
            else:
                main_node.set("health", minf(health + 40.0, 100.0))
                msg = "Health +40"
    if not msg.contains("already"):
        counts[kind] -= 1
    _bars_now()
    _refresh_bag(msg)


func _refresh_bag(msg: String = "") -> void:
    for i in 3:
        var b: Button = use_btns[i]
        b.text = VERBS[i] + " " + NAMES[i] + "  (x" + str(counts[i]) + ")"
        b.disabled = counts[i] <= 0
    var h: float = main_node.get("health")
    bag_info.text = "Health %d%%   Water %d%%   Food %d%%" % [int(h), int(water), int(food)]
    if msg != "":
        bag_info.text += "\n" + msg
