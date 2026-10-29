extends CanvasLayer

const SAVE_PATH := "user://settings.cfg"
const PRESETS := ["Low", "Medium", "High", "Ultra"]
const AA_NAMES := ["Off", "2x", "4x"]
const FPS_VALUES := [30, 60, 0]
const FPS_NAMES := ["30", "60", "Max"]
const SENS_VALUES := [0.5, 0.75, 1.0, 1.5, 2.0]

var preset := 1
var shadows := true
var shadow_dist := 20.0
var shadow_size := 1024
var aa := 0
var fps_idx := 1
var show_fps := false
var sens_idx := 2

var sun: DirectionalLight3D
var menu: Control
var gear: Button
var fps_label: Label
var btn_preset: Button
var btn_shadows: Button
var btn_aa: Button
var btn_fps: Button
var btn_showfps: Button
var btn_sens: Button


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 10
    for c in get_parent().get_children():
        if c is DirectionalLight3D:
            sun = c as DirectionalLight3D
    _load()
    _build_ui()
    _apply()


func _make_button(text: String, min_size: Vector2) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", 34)
    return b


func _build_ui() -> void:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    fps_label = Label.new()
    fps_label.position = Vector2(700, 20)
    fps_label.add_theme_font_size_override("font_size", 36)
    root.add_child(fps_label)

    gear = _make_button("Settings", Vector2(260, 90))
    gear.anchor_left = 1.0
    gear.anchor_right = 1.0
    gear.anchor_top = 0.0
    gear.anchor_bottom = 0.0
    gear.offset_left = -300.0
    gear.offset_right = -40.0
    gear.offset_top = 30.0
    gear.offset_bottom = 120.0
    gear.pressed.connect(_open)
    root.add_child(gear)

    menu = Control.new()
    menu.visible = false
    root.add_child(menu)
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
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
    title.text = "SETTINGS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 44)
    box.add_child(title)

    var bsize := Vector2(760, 80)
    btn_preset = _make_button("", bsize)
    btn_preset.pressed.connect(_on_preset)
    box.add_child(btn_preset)
    btn_shadows = _make_button("", bsize)
    btn_shadows.pressed.connect(_on_shadows)
    box.add_child(btn_shadows)
    btn_aa = _make_button("", bsize)
    btn_aa.pressed.connect(_on_aa)
    box.add_child(btn_aa)
    btn_fps = _make_button("", bsize)
    btn_fps.pressed.connect(_on_fps)
    box.add_child(btn_fps)
    btn_showfps = _make_button("", bsize)
    btn_showfps.pressed.connect(_on_showfps)
    box.add_child(btn_showfps)
    btn_sens = _make_button("", bsize)
    btn_sens.pressed.connect(_on_sens)
    box.add_child(btn_sens)
    var btn_close := _make_button("Close", bsize)
    btn_close.pressed.connect(_close)
    box.add_child(btn_close)


func _on_preset() -> void:
    preset = (preset + 1) % 4
    match preset:
        0:
            shadows = false
            shadow_dist = 20.0
            shadow_size = 1024
            aa = 0
        1:
            shadows = true
            shadow_dist = 20.0
            shadow_size = 1024
            aa = 0
        2:
            shadows = true
            shadow_dist = 40.0
            shadow_size = 2048
            aa = 1
        3:
            shadows = true
            shadow_dist = 60.0
            shadow_size = 4096
            aa = 2
    _apply()


func _on_shadows() -> void:
    shadows = not shadows
    preset = -1
    _apply()


func _on_aa() -> void:
    aa = (aa + 1) % 3
    preset = -1
    _apply()


func _on_fps() -> void:
    fps_idx = (fps_idx + 1) % 3
    _apply()


func _on_showfps() -> void:
    show_fps = not show_fps
    _apply()


func _on_sens() -> void:
    sens_idx = (sens_idx + 1) % 5
    _apply()


func _apply() -> void:
    if sun:
        sun.shadow_enabled = false   # saye hamesha band
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        sun.directional_shadow_max_distance = shadow_dist
    RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
    var vp := get_viewport()
    match aa:
        0:
            vp.msaa_3d = Viewport.MSAA_DISABLED
        1:
            vp.msaa_3d = Viewport.MSAA_2X
        2:
            vp.msaa_3d = Viewport.MSAA_4X
    Engine.max_fps = FPS_VALUES[fps_idx]
    Engine.set_meta("cam_sens", SENS_VALUES[sens_idx])
    fps_label.visible = show_fps
    _refresh()
    _save()


func _refresh() -> void:
    btn_preset.text = "Quality: " + (PRESETS[preset] if preset >= 0 else "Custom")
    btn_shadows.text = "Shadows: Off"
    btn_shadows.disabled = true
    btn_aa.text = "Anti-aliasing: " + AA_NAMES[aa]
    btn_fps.text = "FPS limit: " + FPS_NAMES[fps_idx]
    btn_showfps.text = "Show FPS: " + ("On" if show_fps else "Off")
    btn_sens.text = "Camera sensitivity: " + str(SENS_VALUES[sens_idx]) + "x"


func _process(_delta: float) -> void:
    if show_fps:
        fps_label.text = "FPS: " + str(Engine.get_frames_per_second())


func _reset_main_input() -> void:
    var p := get_parent()
    p.set("stick", Vector2.ZERO)
    p.set("stick_touch", -1)
    p.set("look_touch", -1)
    p.set("run_touch", -1)


func _open() -> void:
    _reset_main_input()
    get_tree().paused = true
    menu.visible = true
    gear.visible = false


func _close() -> void:
    menu.visible = false
    gear.visible = true
    _reset_main_input()
    get_tree().paused = false


func _save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("g", "preset", preset)
    cfg.set_value("g", "shadows", shadows)
    cfg.set_value("g", "shadow_dist", shadow_dist)
    cfg.set_value("g", "shadow_size", shadow_size)
    cfg.set_value("g", "aa", aa)
    cfg.set_value("g", "fps_idx", fps_idx)
    cfg.set_value("g", "show_fps", show_fps)
    cfg.set_value("g", "sens_idx", sens_idx)
    cfg.save(SAVE_PATH)


func _load() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    preset = cfg.get_value("g", "preset", preset)
    shadows = cfg.get_value("g", "shadows", shadows)
    shadow_dist = cfg.get_value("g", "shadow_dist", shadow_dist)
    shadow_size = cfg.get_value("g", "shadow_size", shadow_size)
    aa = cfg.get_value("g", "aa", aa)
    fps_idx = cfg.get_value("g", "fps_idx", fps_idx)
    show_fps = cfg.get_value("g", "show_fps", show_fps)
    sens_idx = cfg.get_value("g", "sens_idx", sens_idx)
