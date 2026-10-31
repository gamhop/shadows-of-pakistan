extends CanvasLayer

const BuildInfo := preload("res://build_info.gd")

var label: Label
var t := 0.0


func _ready() -> void:
    layer = 50
    label = Label.new()
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
    label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    label.add_theme_constant_override("outline_size", 6)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    label.position += Vector2(24, -16)
    _refresh()


func _process(delta: float) -> void:
    t += delta
    if t > 1.0:
        t = 0.0
        _refresh()


func _refresh() -> void:
    var ok := 0
    var total := 0
    var main := get_parent()
    var city = main.get("city")
    if city:
        var cache: Dictionary = city.get("tex_cache")
        for k in cache:
            if str(k).ends_with("_diff"):
                total += 1
                if cache[k] != null:
                    ok += 1
    label.text = "Build %s | wall/road textures: %d/%d" % [BuildInfo.BUILD, ok, total] + " | " + str(Engine.get_meta("hero_status", "hero: ?"))
