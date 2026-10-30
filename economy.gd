extends CanvasLayer

# Paisa, mission level aur khareedari ka hisaab. Sab kuch user://shadows_save.json mein save hota hai.

const SAVE_PATH := "user://shadows_save.json"

var main_node: Node
var ui: Control
var money := 0
var level := 1                    # agla mission jo khelna hai
var guards := 0                   # kitne bodyguard hire kiye
var garage: Array = []            # khareedi hui gaariyon ki keys
var weapons_owned: Array = [0]    # khareedey hue hathiyar (index)
var weapon := 0                   # abhi kaun sa hathiyar hai
var pop_text := ""
var pop_t := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 7
    main_node = get_parent()
    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.draw.connect(_draw_ui)
    load_game()


func fmt(n: int) -> String:
    var s := str(absi(n))
    var out := ""
    var count := 0
    for i in range(s.length() - 1, -1, -1):
        out = s[i] + out
        count += 1
        if count % 3 == 0 and i > 0:
            out = "," + out
    return ("-" if n < 0 else "") + out


func add_money(n: int) -> void:
    money += n
    pop_text = "+Rs " + fmt(n)
    pop_t = 2.5
    save_game()


func spend(n: int) -> bool:
    if money < n:
        return false
    money -= n
    save_game()
    return true


func complete_level() -> void:
    level += 1
    save_game()


func save_game() -> void:
    var data := {
        "money": money,
        "level": level,
        "guards": guards,
        "garage": garage,
        "weapons": weapons_owned,
        "weapon": weapon,
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify(data))
    f.close()


func load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    f.close()
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var d: Dictionary = parsed
    money = int(d.get("money", 0))
    level = maxi(int(d.get("level", 1)), 1)
    guards = clampi(int(d.get("guards", 0)), 0, 3)
    garage = []
    for k in d.get("garage", []):
        garage.append(str(k))
    weapons_owned = []
    for w in d.get("weapons", [0]):
        weapons_owned.append(int(w))
    if not weapons_owned.has(0):
        weapons_owned.append(0)
    weapon = int(d.get("weapon", 0))
    if not weapons_owned.has(weapon):
        weapon = 0


func _process(delta: float) -> void:
    pop_t = maxf(pop_t - delta, 0.0)
    ui.queue_redraw()


func _draw_ui() -> void:
    var font := ThemeDB.fallback_font
    ui.draw_string(font, Vector2(660, 80), "Rs " + fmt(money) + "    LEVEL " + str(level), HORIZONTAL_ALIGNMENT_LEFT, 600, 36, Color(0.6, 1.0, 0.6))
    if pop_t > 0.0:
        ui.draw_string(font, Vector2(660, 124), pop_text, HORIZONTAL_ALIGNMENT_LEFT, 600, 34, Color(1.0, 0.9, 0.3, clampf(pop_t, 0.0, 1.0)))
