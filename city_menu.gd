extends CanvasLayer

const Cities := preload("res://cities.gd")

var main_node: Node
var menu: Control
var open_btn: Button
var title: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 12
    main_node = get_parent()
    _build_ui()
    _open.call_deferred()


func _make_button(text: String, min_size: Vector2, fs: int) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", fs)
    return b


func _build_ui() -> void:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    open_btn = _make_button("CITIES", Vector2(260, 90), 34)
    open_btn.anchor_left = 1.0
    open_btn.anchor_right = 1.0
    open_btn.anchor_top = 0.0
    open_btn.anchor_bottom = 0.0
    open_btn.offset_left = -300.0
    open_btn.offset_right = -40.0
    open_btn.offset_top = 250.0
    open_btn.offset_bottom = 340.0
    open_btn.pressed.connect(_open)
    root.add_child(open_btn)

    menu = Control.new()
    menu.visible = false
    root.add_child(menu)
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.7)
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
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)

    title = Label.new()
    title.text = "CHOOSE YOUR CITY"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 46)
    box.add_child(title)

    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 14)
    grid.add_theme_constant_override("v_separation", 14)
    box.add_child(grid)
    var all: Array = Cities.get_all()
    for i in all.size():
        var d: Dictionary = all[i]
        var b := _make_button(str(d["name"]) + "\n" + str(d["tag"]), Vector2(500, 110), 30)
        b.pressed.connect(_pick.bind(i))
        grid.add_child(b)

    var close_btn := _make_button("Close", Vector2(1014, 80), 34)
    close_btn.pressed.connect(_close)
    box.add_child(close_btn)


func _process(_delta: float) -> void:
    open_btn.visible = not get_tree().paused


func _reset_main_input() -> void:
    main_node.set("stick", Vector2.ZERO)
    main_node.set("stick_touch", -1)
    main_node.set("look_touch", -1)
    main_node.set("run_touch", -1)


func _open() -> void:
    _reset_main_input()
    get_tree().paused = true
    menu.visible = true


func _close() -> void:
    menu.visible = false
    _reset_main_input()
    get_tree().paused = false


func _pick(idx: int) -> void:
    menu.visible = false
    _reset_main_input()
    main_node.call("load_city", idx)
    get_tree().paused = false
