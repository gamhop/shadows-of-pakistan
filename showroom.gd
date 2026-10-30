extends CanvasLayer

# SHOWROOM: plaza mein spawn ke saamne. Yahan se gaari, bodyguard aur hathiyar khareed sakte hain.
# Khareedi hui gaariyan plaza ke dono kinaron par khadi hoti hain (aglay game mein bhi milti hain).

const GuardScript := preload("res://guard.gd")
const SHOP_POS := Vector3(0.0, 0.0, 22.5)
const NEAR := 15.0
const MAX_GARAGE := 6
const MAX_GUARDS := 3

const VEHICLES := [
    {"key": "bike", "name": "Bike", "price": 1500},
    {"key": "rickshaw", "name": "Rickshaw", "price": 2500},
    {"key": "car", "name": "Car (Mehran)", "price": 5000},
    {"key": "truck", "name": "Truck", "price": 12000},
    {"key": "humvee", "name": "Humvee", "price": 15000},
]
const GUARD_PRICES := [4000, 6000, 9000]
const WEAPONS := [
    {"name": "Rifle (starter)", "damage": 20.0, "rate": 0.12, "mag": 30, "price": 0},
    {"name": "Assault Rifle", "damage": 28.0, "rate": 0.10, "mag": 40, "price": 6000},
    {"name": "Machine Gun", "damage": 30.0, "rate": 0.07, "mag": 90, "price": 14000},
    {"name": "Heavy Rifle", "damage": 55.0, "rate": 0.14, "mag": 30, "price": 25000},
]

var main_node: Node
var city: Node3D
var holder: Node3D
var guard_holder: Node3D
var shop_btn: Button
var menu: Control
var title_label: Label
var money_label: Label
var status_label: Label
var rows: VBoxContainer
var tab_btns: Array = []
var tab := 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 13
    main_node = get_parent()
    _build_ui()


func _eco() -> Node:
    return main_node.get("economy") as Node


func _toast(msg: String) -> void:
    var sv = main_node.get("survival")
    if sv:
        sv.call("_show_toast", msg)


# ------------------------------------------------------------ 3D showroom

func respawn(city_node: Node3D, _lines: Array) -> void:
    city = city_node
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    holder = Node3D.new()
    _build_showroom()
    main_node.add_child.call_deferred(holder)
    _spawn_garage()
    _sync_guards()
    apply_weapon()


func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    return m


func _box(pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    bm.material = _mat(color)
    mi.mesh = bm
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        body.add_child(mi)
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        cs.shape = bs
        body.add_child(cs)
        holder.add_child(body)
    else:
        mi.position = pos
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        holder.add_child(mi)


func _build_showroom() -> void:
    var c := SHOP_POS
    var wall := Color(0.9, 0.88, 0.8)
    _box(c + Vector3(0, 2.0, -3.5), Vector3(18, 4, 0.4), wall)
    _box(c + Vector3(-9.0, 2.0, 0), Vector3(0.4, 4, 7), wall)
    _box(c + Vector3(9.0, 2.0, 0), Vector3(0.4, 4, 7), wall)
    _box(c + Vector3(0, 4.2, 0), Vector3(19, 0.4, 8.4), Color(0.25, 0.25, 0.28))
    _box(c + Vector3(0, 3.5, 3.5), Vector3(18, 1.0, 0.4), Color(0.05, 0.3, 0.15))
    _box(c + Vector3(0, 0.12, 0), Vector3(17, 0.03, 6.4), Color(0.45, 0.08, 0.08), false)
    _box(c + Vector3(0, 0.5, -1.8), Vector3(7, 1.0, 1.0), Color(0.35, 0.22, 0.12))

    var sign_label := Label3D.new()
    sign_label.text = "SHOWROOM"
    sign_label.font_size = 110
    sign_label.pixel_size = 0.008
    sign_label.outline_size = 14
    sign_label.modulate = Color(1.0, 0.95, 0.6)
    sign_label.position = c + Vector3(0, 3.5, 3.75)
    holder.add_child(sign_label)

    var lamp := OmniLight3D.new()
    lamp.position = c + Vector3(0, 3.0, 0)
    lamp.omni_range = 14.0
    lamp.light_energy = 1.6
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
    bmat.albedo_color = Color(0.2, 1.0, 0.4, 0.28)
    cm.material = bmat
    beam.mesh = cm
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    beam.position = c + Vector3(0, 30.0, 0)
    holder.add_child(beam)


# ------------------------------------------------------------ gaariyan

func _slots() -> Array:
    var out: Array = []
    for x in [-21.0, 21.0]:
        for z in [16.0, 8.0, 0.0, -8.0, -16.0]:
            out.append(Vector3(x, 0.1, z))
    return out


func _free_slot() -> Variant:
    for s in _slots():
        var p: Vector3 = s
        var ok := true
        for n in get_tree().get_nodes_in_group("vehicles"):
            var v := n as Node3D
            if v and Vector2(v.global_position.x - p.x, v.global_position.z - p.z).length() < 6.0:
                ok = false
                break
        if ok:
            return p
    return null


func _spawn_vehicle(key: String, pos: Vector3) -> bool:
    if city == null or not is_instance_valid(city):
        return false
    var rot := 0.0
    match key:
        "bike":
            city.call("_make_bike", pos, rot)
        "rickshaw":
            city.call("_make_rickshaw", pos, rot)
        "truck", "humvee":
            if not bool(city.call("_make_model_vehicle", key, pos, rot)):
                city.call("_make_car", pos, rot)
        _:
            city.call("_make_car", pos, rot)
    return true


func _spawn_garage() -> void:
    var eco := _eco()
    if eco == null:
        return
    var g: Array = eco.get("garage")
    for k in g:
        var slot = _free_slot()
        if slot == null:
            break
        _spawn_vehicle(str(k), slot as Vector3)


func _buy_vehicle(i: int) -> void:
    var eco := _eco()
    var it: Dictionary = VEHICLES[i]
    var g: Array = eco.get("garage")
    if g.size() >= MAX_GARAGE:
        status_label.text = "Garage full (max %d)" % MAX_GARAGE
        return
    var slot = _free_slot()
    if slot == null:
        status_label.text = "No free parking space at the plaza"
        return
    if not bool(eco.call("spend", int(it["price"]))):
        status_label.text = "Not enough money"
        return
    g.append(str(it["key"]))
    eco.call("save_game")
    _spawn_vehicle(str(it["key"]), slot as Vector3)
    status_label.text = "%s is parked at the plaza edge. Walk to it and press ENTER" % str(it["name"])
    _refresh()


# ------------------------------------------------------------ bodyguards

func _sync_guards() -> void:
    if guard_holder and is_instance_valid(guard_holder):
        if guard_holder.get_parent():
            guard_holder.get_parent().remove_child(guard_holder)
        guard_holder.queue_free()
    guard_holder = Node3D.new()
    var eco := _eco()
    var n := 0
    if eco:
        n = int(eco.get("guards"))
    var player := main_node.get("player") as Node3D
    var origin := player.global_position if player else Vector3.ZERO
    for i in n:
        _add_guard(i, origin)
    main_node.add_child.call_deferred(guard_holder)


func _add_guard(i: int, origin: Vector3) -> void:
    var g := GuardScript.new()
    g.set("main_node", main_node)
    g.set("slot", i)
    g.position = origin + Vector3(2.0 + float(i), 0.3, 2.0)
    guard_holder.add_child(g)


func _buy_guard() -> void:
    var eco := _eco()
    var n: int = int(eco.get("guards"))
    if n >= MAX_GUARDS:
        status_label.text = "You already have %d guards" % MAX_GUARDS
        return
    if not bool(eco.call("spend", int(GUARD_PRICES[n]))):
        status_label.text = "Not enough money"
        return
    eco.set("guards", n + 1)
    eco.call("save_game")
    var player := main_node.get("player") as Node3D
    var origin := player.global_position if player else Vector3.ZERO
    if guard_holder == null or not is_instance_valid(guard_holder):
        _sync_guards()
    else:
        _add_guard(n, origin)
    status_label.text = "Guard hired. He follows you and shoots nearby enemies"
    _refresh()


# ------------------------------------------------------------ hathiyar

func apply_weapon() -> void:
    var eco := _eco()
    var c = main_node.get("combat")
    if eco == null or c == null:
        return
    var w: Dictionary = WEAPONS[clampi(int(eco.get("weapon")), 0, WEAPONS.size() - 1)]
    c.call("set_weapon", float(w["damage"]), float(w["rate"]), int(w["mag"]))


func _buy_weapon(i: int) -> void:
    var eco := _eco()
    var owned: Array = eco.get("weapons_owned")
    var w: Dictionary = WEAPONS[i]
    if owned.has(i):
        eco.set("weapon", i)
        eco.call("save_game")
        apply_weapon()
        status_label.text = "%s equipped" % str(w["name"])
        _refresh()
        return
    if not bool(eco.call("spend", int(w["price"]))):
        status_label.text = "Not enough money"
        return
    owned.append(i)
    eco.set("weapon", i)
    eco.call("save_game")
    apply_weapon()
    status_label.text = "%s bought and equipped" % str(w["name"])
    _refresh()


# ------------------------------------------------------------ UI

func _btn(text: String, size: Vector2, fs: int) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = size
    b.add_theme_font_size_override("font_size", fs)
    return b


func _build_ui() -> void:
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    shop_btn = Button.new()
    shop_btn.text = "SHOWROOM"
    shop_btn.add_theme_font_size_override("font_size", 34)
    shop_btn.anchor_left = 0.0
    shop_btn.anchor_right = 0.0
    shop_btn.anchor_top = 0.0
    shop_btn.anchor_bottom = 0.0
    shop_btn.offset_left = 60.0
    shop_btn.offset_right = 380.0
    shop_btn.offset_top = 365.0
    shop_btn.offset_bottom = 450.0
    shop_btn.visible = false
    shop_btn.pressed.connect(_open)
    root.add_child(shop_btn)

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
        margin.add_theme_constant_override("margin_" + side, 28)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.custom_minimum_size = Vector2(1100, 0)
    box.add_theme_constant_override("separation", 12)
    margin.add_child(box)

    title_label = Label.new()
    title_label.text = "SHOWROOM"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 56)
    box.add_child(title_label)
    money_label = Label.new()
    money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    money_label.add_theme_font_size_override("font_size", 38)
    money_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
    box.add_child(money_label)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 12)
    box.add_child(tabs)
    var names := ["VEHICLES", "GUARDS", "WEAPONS"]
    for i in 3:
        var tb := _btn(names[i], Vector2(340, 80), 32)
        tb.pressed.connect(_set_tab.bind(i))
        tabs.add_child(tb)
        tab_btns.append(tb)

    rows = VBoxContainer.new()
    rows.add_theme_constant_override("separation", 10)
    box.add_child(rows)

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 30)
    status_label.custom_minimum_size = Vector2(0, 44)
    box.add_child(status_label)

    var close := _btn("CLOSE", Vector2(0, 84), 36)
    close.pressed.connect(_close)
    box.add_child(close)


func _open() -> void:
    status_label.text = ""
    tab = 0
    _refresh()
    menu.visible = true
    get_tree().paused = true


func _close() -> void:
    menu.visible = false
    get_tree().paused = false


func _set_tab(i: int) -> void:
    tab = i
    status_label.text = ""
    _refresh()


func _row(text: String, enabled: bool, cb: Callable) -> void:
    var b := _btn(text, Vector2(0, 80), 32)
    b.disabled = not enabled
    b.pressed.connect(cb)
    rows.add_child(b)


func _refresh() -> void:
    var eco := _eco()
    if eco == null:
        return
    for c in rows.get_children():
        rows.remove_child(c)
        c.queue_free()
    var money: int = int(eco.get("money"))
    money_label.text = "Your money: Rs " + str(eco.call("fmt", money))
    for i in tab_btns.size():
        (tab_btns[i] as Button).disabled = (i == tab)
    match tab:
        0:
            var g: Array = eco.get("garage")
            title_label.text = "SHOWROOM - VEHICLES  (garage %d/%d)" % [g.size(), MAX_GARAGE]
            for i in VEHICLES.size():
                var it: Dictionary = VEHICLES[i]
                var price: int = int(it["price"])
                _row("%s     Rs %s" % [str(it["name"]), str(eco.call("fmt", price))], money >= price, _buy_vehicle.bind(i))
        1:
            var n: int = int(eco.get("guards"))
            title_label.text = "SHOWROOM - BODYGUARDS  (%d/%d)" % [n, MAX_GUARDS]
            if n >= MAX_GUARDS:
                _row("All guards hired", false, _buy_guard)
            else:
                var price: int = int(GUARD_PRICES[n])
                _row("Hire guard #%d     Rs %s" % [n + 1, str(eco.call("fmt", price))], money >= price, _buy_guard)
        2:
            title_label.text = "SHOWROOM - WEAPONS"
            var owned: Array = eco.get("weapons_owned")
            var cur: int = int(eco.get("weapon"))
            for i in WEAPONS.size():
                var w: Dictionary = WEAPONS[i]
                var label := "%s   dmg %d  rate %d/s  mag %d" % [str(w["name"]), int(w["damage"]), int(round(1.0 / float(w["rate"]))), int(w["mag"])]
                if i == cur:
                    _row(label + "   [EQUIPPED]", false, _buy_weapon.bind(i))
                elif owned.has(i):
                    _row(label + "   [EQUIP]", true, _buy_weapon.bind(i))
                else:
                    var price: int = int(w["price"])
                    _row(label + "   Rs " + str(eco.call("fmt", price)), money >= price, _buy_weapon.bind(i))


func _process(_delta: float) -> void:
    if get_tree().paused:
        shop_btn.visible = false
        return
    var player := main_node.get("player") as Node3D
    if player == null:
        return
    var d := Vector2(player.global_position.x - SHOP_POS.x, player.global_position.z - SHOP_POS.z).length()
    shop_btn.visible = d < NEAR and not bool(main_node.get("driving"))
