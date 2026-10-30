extends CanvasLayer

const ENEMY_SCRIPT := preload("res://enemy.gd")
const ENEMY_COUNT := 10
const FIRE_RATE := 0.12
const DAMAGE := 20.0
const MAG_SIZE := 30
const RELOAD_TIME := 1.8
const SHOT_RANGE := 70.0
const HEAD_MULT := 2.5
const HEAD_MIN_Y := 1.5
const MAX_HOLES := 24
const AIM_Y := 0.2  # crosshair height on screen (0 = top, 0.5 = centre). Chhota = zyada upar
const FEET_PITCH := -0.7   # itna neeche dekhne par paon-assist chalu
const FEET_RADIUS := 2.0   # paon se itni doori tak ka dushman lagta hai

var main_node: Node
var ui: Control
var holder: Node3D
var ammo := MAG_SIZE
var reload_left := 0.0
var cooldown := 0.0
var fire_touch := -1
var kills := 0
var alive := 0
var flash_t := 0.0
var hit_t := 0.0
var head_t := 0.0
var recoil_off := 0.0
var muzzle_t := 0.0
var muzzle_mesh: MeshInstance3D
var muzzle_light: OmniLight3D
var holes: Array = []
var hole_mat: StandardMaterial3D
var rng := RandomNumberGenerator.new()
var snd_shot: Array = []
var snd_idx := 0
var snd_hit: AudioStreamPlayer
var snd_head: AudioStreamPlayer
var snd_wall: AudioStreamPlayer
var snd_click: AudioStreamPlayer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 8
    add_to_group("combat")
    main_node = get_parent()
    rng.randomize()
    _build_ui()
    _build_audio()


func respawn(lines: Array, seed_v: int) -> void:
    if holder and is_instance_valid(holder):
        if holder.get_parent():
            holder.get_parent().remove_child(holder)
        holder.queue_free()
    alive = 0
    recoil_off = 0.0
    holder = Node3D.new()
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var player := main_node.get("player") as Node3D
    var origin := player.global_position if player else Vector3.ZERO
    var made := 0
    var tries := 0
    while made < ENEMY_COUNT and tries < 300:
        tries += 1
        var c: float = lines[rng.randi() % lines.size()]
        var along := rng.randf_range(-95.0, 95.0)
        var off := rng.randf_range(-2.5, 2.5)
        var x := c + off
        var z := along
        if rng.randf() < 0.5:
            x = along
            z = c + off
        if Vector2(x - origin.x, z - origin.z).length() < 28.0:
            continue
        var e = ENEMY_SCRIPT.new()
        e.position = Vector3(x, 0.1, z)
        e.died.connect(_on_enemy_died)
        holder.add_child(e)
        alive += 1
        made += 1
    main_node.add_child.call_deferred(holder)


func _on_enemy_died() -> void:
    kills += 1
    alive -= 1


func flash() -> void:
    flash_t = 0.45


func _build_ui() -> void:
    ui = Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.draw.connect(_draw_ui)


func _fire_base() -> Vector2:
    var vp := get_viewport().get_visible_rect().size
    return Vector2(vp.x - 600.0, vp.y - 210.0)


func _draw_ui() -> void:
    var vp := get_viewport().get_visible_rect().size
    var c := _aim_point()
    var cc := Color(1, 0.3, 0.3) if hit_t > 0.0 else Color(1, 1, 1, 0.9)
    if head_t > 0.0:
        cc = Color(1, 0.85, 0.1)
        var hc := head_t / 0.25
        ui.draw_line(c + Vector2(-30, -30) * (1.0 + hc * 0.3), c + Vector2(-16, -16), cc, 4.0)
        ui.draw_line(c + Vector2(30, -30) * (1.0 + hc * 0.3), c + Vector2(16, -16), cc, 4.0)
        ui.draw_line(c + Vector2(-30, 30) * (1.0 + hc * 0.3), c + Vector2(-16, 16), cc, 4.0)
        ui.draw_line(c + Vector2(30, 30) * (1.0 + hc * 0.3), c + Vector2(16, 16), cc, 4.0)
    ui.draw_line(c + Vector2(-22, 0), c + Vector2(-8, 0), cc, 3.0)
    ui.draw_line(c + Vector2(8, 0), c + Vector2(22, 0), cc, 3.0)
    ui.draw_line(c + Vector2(0, -22), c + Vector2(0, -8), cc, 3.0)
    ui.draw_line(c + Vector2(0, 8), c + Vector2(0, 22), cc, 3.0)

    if not bool(main_node.get("driving")):
        var fb := _fire_base()
        var fcol := Color(0.9, 0.2, 0.2, 0.55) if fire_touch != -1 else Color(1, 1, 1, 0.2)
        ui.draw_circle(fb, 120.0, fcol)
        ui.draw_string(ThemeDB.fallback_font, fb + Vector2(-100, 16), "FIRE", HORIZONTAL_ALIGNMENT_CENTER, 200, 44)
        var ammo_text := "RELOADING" if reload_left > 0.0 else "AMMO " + str(ammo)
        ui.draw_string(ThemeDB.fallback_font, fb + Vector2(-140, -140), ammo_text, HORIZONTAL_ALIGNMENT_CENTER, 280, 36)
    ui.draw_string(ThemeDB.fallback_font, Vector2(vp.x / 2.0 - 220, 130), "Kills: %d   Enemies: %d" % [kills, alive], HORIZONTAL_ALIGNMENT_CENTER, 440, 38)
    if flash_t > 0.0:
        ui.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.8, 0.0, 0.0, flash_t))


func _input(event: InputEvent) -> void:
    if get_tree().paused:
        return
    if bool(main_node.get("driving")):
        fire_touch = -1
        return
    if event is InputEventScreenTouch:
        var t := event as InputEventScreenTouch
        if t.pressed:
            if fire_touch == -1 and t.position.distance_to(_fire_base()) < 150.0:
                fire_touch = t.index
                get_viewport().set_input_as_handled()
        elif t.index == fire_touch:
            fire_touch = -1


func _process(delta: float) -> void:
    if get_tree().paused:
        fire_touch = -1
        return
    flash_t = maxf(flash_t - delta, 0.0)
    hit_t = maxf(hit_t - delta, 0.0)
    head_t = maxf(head_t - delta, 0.0)
    if recoil_off > 0.0001:
        var back := recoil_off * clampf(7.0 * delta, 0.0, 1.0)
        recoil_off -= back
        var cp: float = main_node.get("cam_pitch")
        main_node.set("cam_pitch", clampf(cp - back, -1.5, 0.95))
    if muzzle_t > 0.0:
        muzzle_t -= delta
        if muzzle_t <= 0.0:
            if muzzle_mesh:
                muzzle_mesh.visible = false
            if muzzle_light:
                muzzle_light.visible = false
    ui.queue_redraw()


func _physics_process(delta: float) -> void:
    if get_tree().paused:
        return
    cooldown = maxf(cooldown - delta, 0.0)
    if reload_left > 0.0:
        reload_left -= delta
        if reload_left <= 0.0:
            ammo = MAG_SIZE
            snd_click.play()
    elif fire_touch != -1 and cooldown <= 0.0:
        _shoot()
        cooldown = FIRE_RATE
        ammo -= 1
        if ammo <= 0:
            reload_left = RELOAD_TIME
            snd_click.play()


func _aim_point() -> Vector2:
    # crosshair fixed: camera ke sath hi upar-neeche hota hai, koi slide nahi
    var vp := get_viewport().get_visible_rect().size
    return Vector2(vp.x / 2.0, vp.y * AIM_Y)


func _shoot() -> void:
    var cam := get_viewport().get_camera_3d()
    var player := main_node.get("player") as CharacterBody3D
    if cam == null or player == null:
        return
    var aim := _aim_point()
    var from := cam.project_ray_origin(aim)
    var dir := cam.project_ray_normal(aim)
    var to := from + dir * SHOT_RANGE
    var space := cam.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(from, to)
    q.exclude = [player.get_rid()]
    var hit := space.intersect_ray(q)
    # feet assist: crosshair se dushman na lage to paon ke paas wala dushman lag jata hai
    var pitch_now: float = main_node.get("cam_pitch")
    var ray_enemy: bool = not hit.is_empty() and hit["collider"] != null and hit["collider"].has_method("take_damage")
    if pitch_now <= FEET_PITCH and not ray_enemy:
        var fe := _feet_enemy(player)
        if fe != null:
            var fp: Vector3 = fe.global_position + Vector3(0, 0.9, 0)
            hit = {"position": fp, "collider": fe, "normal": (from - fp).normalized()}
    var end := to
    var muzzle := player.global_position + Vector3(0, 1.4, 0) + dir * 0.7 + cam.global_transform.basis.x * 0.25
    if not hit.is_empty():
        end = hit["position"]
        var col = hit["collider"]
        var n: Vector3 = hit["normal"]
        if col and col.has_method("take_damage"):
            var head: bool = (end.y - col.global_position.y) >= HEAD_MIN_Y
            var dmg := DAMAGE * (HEAD_MULT if head else 1.0)
            col.call("take_damage", dmg, end, dir, head)
            hit_t = 0.15
            if head:
                head_t = 0.25
                snd_head.play()
                Input.vibrate_handheld(55)
            else:
                snd_hit.play()
                Input.vibrate_handheld(30)
            _burst(end, n, Color(0.55, 0.02, 0.02), 12 if head else 8, 3.5)
        else:
            snd_wall.play()
            _burst(end, n, Color(0.85, 0.8, 0.65), 6, 3.0)
            _bullet_hole(end, n)
    _tracer(muzzle, end)
    _fire_feel(muzzle)


func _feet_enemy(player: Node3D) -> Node3D:
    var yaw: float = main_node.get("cam_yaw")
    var f := Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
    var best: Node3D = null
    var best_d := FEET_RADIUS
    for n in holder.get_children():
        if not is_instance_valid(n) or not n.has_method("take_damage") or n.get("dead"):
            continue
        var to_e: Vector3 = n.global_position - player.global_position
        to_e.y = 0.0
        var d := to_e.length()
        if d >= best_d:
            continue
        if d > 0.5 and f.dot(to_e / d) < 0.2:
            continue
        best_d = d
        best = n
    return best


func _fire_feel(muzzle: Vector3) -> void:
    # gunshot sound (round-robin so shots overlap)
    var p: AudioStreamPlayer = snd_shot[snd_idx]
    snd_idx = (snd_idx + 1) % snd_shot.size()
    p.pitch_scale = rng.randf_range(0.93, 1.07)
    p.play()
    Input.vibrate_handheld(14)
    # recoil: camera kicks up a little, slightly sideways, then settles back
    var kick := rng.randf_range(0.010, 0.018)
    var cp: float = main_node.get("cam_pitch")
    main_node.set("cam_pitch", clampf(cp + kick, -1.5, 0.95))
    recoil_off += kick
    var cy: float = main_node.get("cam_yaw")
    main_node.set("cam_yaw", cy + rng.randf_range(-0.004, 0.004))
    var cam := get_viewport().get_camera_3d()
    if cam:
        cam.fov -= 1.6
    # muzzle flash
    if muzzle_mesh == null or not is_instance_valid(muzzle_mesh):
        _build_muzzle()
    muzzle_mesh.global_position = muzzle
    muzzle_mesh.rotation.z = rng.randf() * TAU
    muzzle_mesh.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
    muzzle_mesh.visible = true
    muzzle_light.global_position = muzzle
    muzzle_light.visible = true
    muzzle_t = 0.045


func _build_muzzle() -> void:
    muzzle_mesh = MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(0.45, 0.45)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.billboard_keep_scale = true
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_color = Color(1.0, 0.8, 0.35, 0.95)
    var g := GradientTexture2D.new()
    g.fill = GradientTexture2D.FILL_RADIAL
    g.fill_from = Vector2(0.5, 0.5)
    g.fill_to = Vector2(1.0, 0.5)
    var gr := Gradient.new()
    gr.set_color(0, Color(1, 1, 1, 1))
    gr.set_color(1, Color(1, 1, 1, 0))
    g.gradient = gr
    m.albedo_texture = g
    qm.material = m
    muzzle_mesh.mesh = qm
    muzzle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_mesh.visible = false
    main_node.add_child(muzzle_mesh)
    muzzle_light = OmniLight3D.new()
    muzzle_light.light_color = Color(1.0, 0.75, 0.4)
    muzzle_light.light_energy = 2.5
    muzzle_light.omni_range = 5.0
    muzzle_light.shadow_enabled = false
    muzzle_light.visible = false
    main_node.add_child(muzzle_light)


func _burst(pos: Vector3, normal: Vector3, color: Color, count: int, speed: float) -> void:
    var p := CPUParticles3D.new()
    p.amount = count
    p.lifetime = 0.45
    p.one_shot = true
    p.explosiveness = 1.0
    p.direction = normal
    p.spread = 55.0
    p.initial_velocity_min = speed * 0.5
    p.initial_velocity_max = speed
    p.gravity = Vector3(0, -9.0, 0)
    p.scale_amount_min = 0.6
    p.scale_amount_max = 1.2
    var bm := BoxMesh.new()
    bm.size = Vector3(0.045, 0.045, 0.045)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    bm.material = mat
    p.mesh = bm
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    main_node.add_child(p)
    p.global_position = pos + normal * 0.05
    p.emitting = true
    get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _bullet_hole(pos: Vector3, normal: Vector3) -> void:
    if hole_mat == null:
        hole_mat = StandardMaterial3D.new()
        hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        hole_mat.albedo_color = Color(0.03, 0.03, 0.03, 0.9)
        var g := GradientTexture2D.new()
        g.fill = GradientTexture2D.FILL_RADIAL
        g.fill_from = Vector2(0.5, 0.5)
        g.fill_to = Vector2(1.0, 0.5)
        var gr := Gradient.new()
        gr.set_color(0, Color(1, 1, 1, 1))
        gr.set_color(1, Color(1, 1, 1, 0))
        g.gradient = gr
        hole_mat.albedo_texture = g
    var mi := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(0.16, 0.16)
    qm.material = hole_mat
    mi.mesh = qm
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    main_node.add_child(mi)
    var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
    mi.global_position = pos + normal * 0.012
    mi.look_at(pos - normal, up)
    holes.append(mi)
    if holes.size() > MAX_HOLES:
        var old = holes.pop_front()
        if is_instance_valid(old):
            old.queue_free()


# ---------- procedural sounds (no audio files needed) ----------
func _build_audio() -> void:
    var shot := _synth(0.28, 0)
    for i in 4:
        snd_shot.append(_player(shot, -4.0))
    snd_hit = _player(_synth(0.14, 1), -3.0)
    snd_head = _player(_synth(0.22, 2), -2.0)
    snd_wall = _player(_synth(0.1, 3), -8.0)
    snd_click = _player(_synth(0.06, 4), -6.0)


func _wave(kind: int, t: float, nz: float) -> float:
    match kind:
        0:
            return nz * exp(-t * 26.0) * 0.55 + sin(TAU * 85.0 * t) * exp(-t * 16.0) * 0.7 + nz * exp(-t * 90.0) * 0.5
        1:
            return sin(TAU * 170.0 * t) * exp(-t * 30.0) * 0.8 + nz * exp(-t * 55.0) * 0.4
        2:
            return sin(TAU * 150.0 * t) * exp(-t * 22.0) * 0.7 + sin(TAU * 1500.0 * t) * exp(-t * 28.0) * 0.45 + nz * exp(-t * 60.0) * 0.4
        3:
            return nz * exp(-t * 60.0) * 0.5 + sin(TAU * 900.0 * t) * exp(-t * 70.0) * 0.25
        _:
            return nz * exp(-t * 110.0) * 0.6 + sin(TAU * 2200.0 * t) * exp(-t * 120.0) * 0.3


func _player(stream: AudioStream, vol_db: float) -> AudioStreamPlayer:
    var p := AudioStreamPlayer.new()
    p.stream = stream
    p.volume_db = vol_db
    p.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(p)
    return p


func _synth(dur: float, kind: int) -> AudioStreamWAV:
    var rate := 22050
    var n := int(dur * rate)
    var data := PackedByteArray()
    data.resize(n * 2)
    var r := RandomNumberGenerator.new()
    r.seed = 1234 + kind
    for i in n:
        var t := float(i) / float(rate)
        var v := clampf(_wave(kind, t, r.randf() * 2.0 - 1.0), -1.0, 1.0)
        data.encode_s16(i * 2, int(v * 32000.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.stereo = false
    w.data = data
    return w


func _tracer(from: Vector3, to: Vector3) -> void:
    var length := from.distance_to(to)
    if length < 0.5:
        return
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(0.035, 0.035, length)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.9, 0.4)
    bm.material = mat
    mi.mesh = bm
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    main_node.add_child(mi)
    mi.global_position = (from + to) / 2.0
    mi.look_at(to, Vector3.UP)
    get_tree().create_timer(0.05).timeout.connect(mi.queue_free)
