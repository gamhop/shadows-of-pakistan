extends CanvasLayer

# BAKERY & STORE: plaza ke north mein, sadak ki taraf darwaza. Andar kamra, mezon par cheezen aur daam.
# Paas jane par neeche wala button aata hai: khareedna, ATM balance, ya bottle wapis karna.
# Khareedi hui cheezen survival bag mein jati hain (Food / Water / Medkit), missions mein bhi kaam aati hain.

const SHOP_POS := Vector3(0.0, 0.0, -22.5)
const ITEM_RANGE := 2.4
const MACHINE_RANGE := 2.6
const BOTTLE_REFUND := 15

const MODEL_DIR := "res://assets/models/"
const CATALOG := [
    {"name": "Bread", "price": 30, "kind": 1, "amount": 1, "model": "", "prim": "bread", "scale": 1.6},
    {"name": "Water Bottle", "price": 40, "kind": 0, "amount": 1, "model": "", "prim": "water", "scale": 1.6},
    {"name": "Eggs", "price": 150, "kind": 1, "amount": 2, "model": "egg-carton.glb", "prim": "box", "scale": 1.8},
    {"name": "Chips", "price": 60, "kind": 1, "amount": 1, "model": "chips-bag.glb", "prim": "box", "scale": 1.8},
    {"name": "Cereal", "price": 200, "kind": 1, "amount": 2, "model": "cereal-box.glb", "prim": "box", "scale": 1.7},
    {"name": "Medkit", "price": 300, "kind": 2, "amount": 1, "model": "", "prim": "medkit", "scale": 1.6},
]
const KIND_NAMES := ["Water", "Food", "Medkit"]
const TABLE_X := [-6.5, -3.9, -1.3, 1.3, 3.9, 6.5]

var main_node: Node
var holder: Node3D
var buy_btn: Button
var interacts: Array = []
var cur := -1
var scan_t := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 12
    main_node = get_parent()
    buy_btn = Button.new()
    buy_btn.add_theme_font_size_override("font_size", 28)
    buy_btn.anchor_left = 0.0
    buy_btn.anchor_right = 0.0
    buy_btn.anchor_top = 0.0
    buy_btn.anchor_bottom = 0.0
    buy_btn.offset_left = 60.0
    buy_btn.offset_right = 520.0
    buy_btn.offset_top = 365.0
    buy_btn.offset_bottom = 450.0
    buy_btn.visible = false
    buy_btn.pressed.connect(_on_btn)
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(buy_btn)


func _eco() -> Node:
    return main_node.get("economy") as Node


func _toast(msg: String) -> void:
    var sv = main_node.get("survival")
    if sv:
        sv.call("_show_toast", msg)


func _fmt(n: int) -> String:
    var e := _eco()
    if e:
        return str(e.call("fmt", n))
    return str(n)


# ------------------------------------------------------------ 3D dukaan

func respawn(_city: Node3D, _lines: Array) -> void:
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    holder = Node3D.new()
    interacts.clear()
    cur = -1
    _build_shop()
    _build_items()
    _build_fixtures()
    _build_garden()
    main_node.add_child.call_deferred(holder)


func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.9
    return m


func _box(pos: Vector3, size: Vector3, color: Color, solid: bool = true, parent: Node3D = null) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    bm.material = _mat(color)
    mi.mesh = bm
    var p: Node3D = parent if parent else holder
    if solid:
        var body := StaticBody3D.new()
        body.position = pos
        body.add_child(mi)
        var cs := CollisionShape3D.new()
        var bs := BoxShape3D.new()
        bs.size = size
        cs.shape = bs
        body.add_child(cs)
        p.add_child(body)
    else:
        mi.position = pos
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        p.add_child(mi)


func _label(text: String, pos: Vector3, fs: int, px: float, color: Color, billboard: bool) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.font_size = fs
    l.pixel_size = px
    l.outline_size = 10
    l.modulate = color
    if billboard:
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.position = pos
    holder.add_child(l)
    return l


func _build_shop() -> void:
    var c := SHOP_POS
    var wall := Color(0.95, 0.9, 0.78)
    # peeche wali deewar plaza ki taraf, darwaza sadak ki taraf (-Z)
    _box(c + Vector3(0, 2.0, 3.5), Vector3(18, 4, 0.4), wall)
    _box(c + Vector3(-9.0, 2.0, 0), Vector3(0.4, 4, 7), wall)
    _box(c + Vector3(9.0, 2.0, 0), Vector3(0.4, 4, 7), wall)
    _box(c + Vector3(0, 4.2, 0), Vector3(19, 0.4, 8.4), Color(0.55, 0.25, 0.15))
    _box(c + Vector3(0, 3.5, -3.5), Vector3(18, 1.0, 0.4), Color(0.45, 0.2, 0.12))
    _box(c + Vector3(0, 0.12, 0), Vector3(17, 0.03, 6.4), Color(0.8, 0.72, 0.6), false)
    var sign_label := _label("BAKERY", c + Vector3(0, 3.5, -3.75), 110, 0.008, Color(1.0, 0.92, 0.7), false)
    sign_label.rotation.y = PI
    var lamp := OmniLight3D.new()
    lamp.position = c + Vector3(0, 3.0, 0)
    lamp.omni_range = 14.0
    lamp.light_energy = 1.7
    lamp.light_color = Color(1.0, 0.9, 0.75)
    holder.add_child(lamp)


# ------------------------------------------------------------ cheezen

func _prim(kind: String) -> Node3D:
    var root := Node3D.new()
    match kind:
        "bread":
            for k in 2:
                var mi := MeshInstance3D.new()
                var cm := CapsuleMesh.new()
                cm.radius = 0.09
                cm.height = 0.42
                cm.material = _mat(Color(0.74, 0.48, 0.22))
                mi.mesh = cm
                mi.rotation_degrees = Vector3(0, 0, 90)
                mi.position = Vector3(0, 0.09 + 0.14 * k, 0.0)
                root.add_child(mi)
        "water":
            var mi := MeshInstance3D.new()
            var cyl := CylinderMesh.new()
            cyl.top_radius = 0.06
            cyl.bottom_radius = 0.06
            cyl.height = 0.3
            cyl.material = _mat(Color(0.35, 0.65, 1.0))
            mi.mesh = cyl
            mi.position.y = 0.15
            root.add_child(mi)
            var cap := MeshInstance3D.new()
            var cc := CylinderMesh.new()
            cc.top_radius = 0.03
            cc.bottom_radius = 0.03
            cc.height = 0.05
            cc.material = _mat(Color(0.95, 0.95, 0.95))
            cap.mesh = cc
            cap.position.y = 0.325
            root.add_child(cap)
        "medkit":
            _box(Vector3(0, 0.1, 0), Vector3(0.32, 0.2, 0.14), Color(0.95, 0.95, 0.95), false, root)
            _box(Vector3(0, 0.1, -0.072), Vector3(0.18, 0.06, 0.01), Color(0.85, 0.1, 0.1), false, root)
            _box(Vector3(0, 0.1, -0.072), Vector3(0.06, 0.16, 0.01), Color(0.85, 0.1, 0.1), false, root)
        _:
            _box(Vector3(0, 0.1, 0), Vector3(0.3, 0.2, 0.2), Color(0.8, 0.6, 0.3), false, root)
    return root


func _model(file: String) -> Node3D:
    var path := MODEL_DIR + file
    if not ResourceLoader.exists(path):
        return null
    var scene := load(path) as PackedScene
    if scene == null:
        return null
    return scene.instantiate() as Node3D


func _build_items() -> void:
    var c := SHOP_POS
    for i in CATALOG.size():
        var it: Dictionary = CATALOG[i]
        var x: float = TABLE_X[i]
        _box(c + Vector3(x, 0.45, 2.6), Vector3(2.2, 0.9, 1.0), Color(0.5, 0.33, 0.18))
        var node: Node3D = null
        if str(it["model"]) != "":
            node = _model(str(it["model"]))
        if node == null:
            node = _prim(str(it["prim"]))
        node.scale = Vector3.ONE * float(it["scale"])
        node.position = c + Vector3(x, 0.9, 2.6)
        node.rotation.y = PI          # munh darwaze (-Z) ki taraf
        holder.add_child(node)
        _label("%s\nRs %s" % [str(it["name"]), _fmt(int(it["price"]))], c + Vector3(x, 1.85, 2.2), 44, 0.005, Color(1.0, 0.95, 0.6), true)
        interacts.append({"pos": c + Vector3(x, 0.0, 2.6), "type": "item", "idx": i, "range": ITEM_RANGE})


func _build_fixtures() -> void:
    var c := SHOP_POS
    # bottle return machine (baen deewar), ATM (daayen deewar)
    var bm := _model("bottle-return-machine.glb")
    if bm == null:
        bm = Node3D.new()
        _box(Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.9), Color(0.55, 0.8, 0.7), false, bm)
    bm.position = c + Vector3(-8.2, 0, -0.5)
    bm.rotation.y = PI / 2.0
    holder.add_child(bm)
    _label("BOTTLE RETURN", c + Vector3(-8.0, 2.3, -0.5), 40, 0.005, Color(0.7, 1.0, 0.85), true)
    interacts.append({"pos": c + Vector3(-8.2, 0.0, -0.5), "type": "bottle", "idx": 0, "range": MACHINE_RANGE})
    _solid_post(c + Vector3(-8.2, 1.0, -0.5), Vector3(0.9, 2.0, 0.9))

    var atm := _model("atm.glb")
    if atm == null:
        atm = Node3D.new()
        _box(Vector3(0, 0.9, 0), Vector3(0.62, 1.8, 0.75), Color(0.5, 0.65, 0.9), false, atm)
    atm.position = c + Vector3(8.2, 0, -0.5)
    atm.rotation.y = -PI / 2.0
    holder.add_child(atm)
    _label("ATM", c + Vector3(8.0, 2.1, -0.5), 48, 0.005, Color(0.7, 0.85, 1.0), true)
    interacts.append({"pos": c + Vector3(8.2, 0.0, -0.5), "type": "atm", "idx": 0, "range": MACHINE_RANGE})
    _solid_post(c + Vector3(8.2, 0.9, -0.5), Vector3(0.75, 1.8, 0.75))


func _solid_post(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    body.add_child(cs)
    holder.add_child(body)


func _build_garden() -> void:
    var c := SHOP_POS
    var spots := [
        {"f": "lavender-bush.glb", "p": Vector3(-12.5, 0, -1.2), "s": 1.8},
        {"f": "lavender-bush.glb", "p": Vector3(12.5, 0, -1.2), "s": 1.8},
        {"f": "lavender-bush.glb", "p": Vector3(-12.5, 0, 1.6), "s": 1.6},
        {"f": "lavender-bush.glb", "p": Vector3(12.5, 0, 1.6), "s": 1.6},
        {"f": "daisy-patch.glb", "p": Vector3(-11.8, 0, -3.4), "s": 2.2},
        {"f": "daisy-patch.glb", "p": Vector3(11.8, 0, -3.4), "s": 2.2},
        {"f": "daisy-patch.glb", "p": Vector3(-6.5, 0, -4.6), "s": 2.0},
        {"f": "daisy-patch.glb", "p": Vector3(6.5, 0, -4.6), "s": 2.0},
    ]
    for sp in spots:
        var n := _model(str(sp["f"]))
        if n == null:
            continue
        n.scale = Vector3.ONE * float(sp["s"])
        n.position = c + (sp["p"] as Vector3) + Vector3(0, 0.08, 0)
        n.rotation.y = float(int(abs((sp["p"] as Vector3).x * 7.0 + (sp["p"] as Vector3).z * 3.0)) % 6)
        holder.add_child(n)


# ------------------------------------------------------------ khareedari

func _process(delta: float) -> void:
    if get_tree().paused:
        buy_btn.visible = false
        return
    scan_t -= delta
    if scan_t > 0.0:
        return
    scan_t = 0.1
    var player := main_node.get("player") as Node3D
    if player == null or bool(main_node.get("driving")):
        buy_btn.visible = false
        cur = -1
        return
    var best := -1
    var best_d := 999.0
    for i in interacts.size():
        var it: Dictionary = interacts[i]
        var p: Vector3 = it["pos"]
        var d := Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length()
        if d < float(it["range"]) and d < best_d:
            best_d = d
            best = i
    cur = best
    if cur < 0:
        buy_btn.visible = false
        return
    var e: Dictionary = interacts[cur]
    match str(e["type"]):
        "item":
            var it: Dictionary = CATALOG[int(e["idx"])]
            buy_btn.text = "BUY %s  Rs %s" % [str(it["name"]), _fmt(int(it["price"]))]
        "atm":
            buy_btn.text = "ATM: CHECK BALANCE"
        "bottle":
            buy_btn.text = "RETURN BOTTLE  +Rs %d" % BOTTLE_REFUND
    buy_btn.visible = true


func _counts() -> Array:
    var sv = main_node.get("survival")
    if sv:
        return sv.get("counts")
    return [0, 0, 0]


func _refresh_bag() -> void:
    var sv = main_node.get("survival")
    if sv:
        sv.call("_refresh_bag")


func _on_btn() -> void:
    if cur < 0 or cur >= interacts.size():
        return
    var e: Dictionary = interacts[cur]
    var eco := _eco()
    if eco == null:
        return
    match str(e["type"]):
        "item":
            var it: Dictionary = CATALOG[int(e["idx"])]
            var price: int = int(it["price"])
            if not bool(eco.call("spend", price)):
                _toast("Not enough money (Rs %s)" % _fmt(price))
                return
            var counts: Array = _counts()
            var k: int = int(it["kind"])
            counts[k] += int(it["amount"])
            _refresh_bag()
            _toast("+%d %s   -Rs %s" % [int(it["amount"]), str(KIND_NAMES[k]), _fmt(price)])
        "atm":
            _toast("ATM balance: Rs %s" % _fmt(int(eco.get("money"))))
        "bottle":
            var counts2: Array = _counts()
            if counts2[0] <= 0:
                _toast("No water bottle in your bag")
                return
            counts2[0] -= 1
            _refresh_bag()
            eco.call("add_money", BOTTLE_REFUND)
            _toast("Bottle returned  +Rs %d" % BOTTLE_REFUND)
