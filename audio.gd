extends Node

# Poori game ki awaazein, sab code se bani hain (koi audio file nahi).
# Ambient (hawa, traffic, rickshaw), qadmon ki awaaz, chiriyan, door ke horn,
# player/dushman ki chikhein, marna, dil ki dhadkan, saans, utha-na, khana/peena,
# dawa, aur har button ki click.

const RATE := 11025
const AMB_RATE := 8000

const K_STEP := 0
const K_HURT := 1
const K_DIE := 2
const K_HEART := 3
const K_PANT := 4
const K_EHURT := 5
const K_EDIE := 6
const K_GROWL := 7
const K_PUNCH := 8
const K_PICK := 9
const K_EAT := 10
const K_DRINK := 11
const K_HEAL := 12
const K_CLICK := 13
const K_BIRD := 14
const K_HORN := 15
const K_WIND := 16
const K_TRAFFIC := 17
const K_ENGINE := 18

var rng := RandomNumberGenerator.new()
var main_node: Node
var bank: Dictionary = {}
var p2d: Array = []
var p3d: Array = []
var i2d := 0
var i3d := 0
var amb: Array = []
var t_amb := 0.0
var step_t := 0.2
var last_health := 100.0
var hurt_cd := 0.0
var heart_t := 0.0
var dead_played := false
var was_exhausted := false
var bird_t := 3.0
var horn_t := 14.0
var ready_ok := false


func _ready() -> void:
    add_to_group("audio")
    process_mode = Node.PROCESS_MODE_ALWAYS
    rng.randomize()
    main_node = get_parent()
    for i in 8:
        var p := AudioStreamPlayer.new()
        add_child(p)
        p2d.append(p)
    for i in 8:
        var q := AudioStreamPlayer3D.new()
        q.unit_size = 8.0
        q.max_distance = 80.0
        q.process_mode = Node.PROCESS_MODE_PAUSABLE
        add_child(q)
        p3d.append(q)
    get_tree().node_added.connect(_on_node_added)
    _hook_buttons(get_tree().root)
    # pehla frame dikhne do, phir awaazein banao
    await get_tree().process_frame
    _build_bank()
    _start_ambient()
    ready_ok = true


func _hook_buttons(n: Node) -> void:
    _on_node_added(n)
    for c in n.get_children():
        _hook_buttons(c)


func _on_node_added(n: Node) -> void:
    var b := n as Button
    if b and not b.pressed.is_connected(_click):
        b.pressed.connect(_click)


func _click() -> void:
    play2d("click", -6.0)


# ---------------- public ----------------
func play2d(kind: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
    if not bank.has(kind):
        return
    var p: AudioStreamPlayer = p2d[i2d]
    i2d = (i2d + 1) % p2d.size()
    p.stream = bank[kind]
    p.volume_db = vol_db
    p.pitch_scale = pitch
    p.play()


func play3d(kind: String, pos: Vector3, vol_db: float = 0.0) -> void:
    if not bank.has(kind):
        return
    var p: AudioStreamPlayer3D = p3d[i3d]
    i3d = (i3d + 1) % p3d.size()
    p.stream = bank[kind]
    p.global_position = pos
    p.volume_db = vol_db
    p.pitch_scale = rng.randf_range(0.92, 1.08)
    p.play()


# ---------------- per-frame ----------------
func _process(delta: float) -> void:
    if not ready_ok or main_node == null:
        return
    var paused := get_tree().paused
    for a in amb:
        a.stream_paused = paused
    if paused:
        return

    t_amb += delta
    amb[1].volume_db = -23.0 + 3.0 * sin(t_amb * 0.17)
    amb[2].volume_db = -31.0 + 6.0 * sin(t_amb * 0.29)
    if bool(main_node.get("driving")):
        var dv = main_node.get("drive")
        var cv = dv.get("car") if dv else null
        var sp := 0.0
        if cv:
            sp = absf(float(cv.get("speed")))
        amb[2].volume_db = -13.0 + minf(sp, 15.0) * 0.25
        amb[2].pitch_scale = 0.8 + minf(sp / 14.0, 1.6)
    else:
        amb[2].pitch_scale = 1.0

    var player := main_node.get("player") as CharacterBody3D
    if player:
        # qadmon ki awaaz
        var vel := Vector2(player.velocity.x, player.velocity.z).length()
        if vel > 0.5 and player.is_on_floor():
            step_t -= delta
            if step_t <= 0.0:
                var running := vel > 6.5
                step_t = 0.31 if running else 0.5
                play2d("step", -7.0 if running else -11.0, rng.randf_range(0.9, 1.1))
        else:
            step_t = 0.12
        # chiriyan aur door ke horn
        bird_t -= delta
        if bird_t <= 0.0:
            bird_t = rng.randf_range(3.0, 9.0)
            var ang := rng.randf() * TAU
            var dist := rng.randf_range(12.0, 35.0)
            play3d("bird", player.global_position + Vector3(cos(ang) * dist, rng.randf_range(5.0, 10.0), sin(ang) * dist), -2.0)
        horn_t -= delta
        if horn_t <= 0.0:
            horn_t = rng.randf_range(14.0, 32.0)
            var a2 := rng.randf() * TAU
            var d2 := rng.randf_range(35.0, 60.0)
            play3d("horn", player.global_position + Vector3(cos(a2) * d2, 1.0, sin(a2) * d2), -2.0)

    # sehat: chot, maut, dhadkan
    var h: float = main_node.get("health")
    hurt_cd = maxf(hurt_cd - delta, 0.0)
    if h > 0.0 and h < last_health - 5.0 and hurt_cd <= 0.0:
        play2d("p_hurt", -2.0, rng.randf_range(0.95, 1.05))
        hurt_cd = 0.35
    if h <= 0.0 and not dead_played:
        dead_played = true
        play2d("p_die", 0.0)
    elif h > 0.0:
        dead_played = false
    last_health = h
    if h > 0.0 and h < 30.0:
        heart_t -= delta
        if heart_t <= 0.0:
            play2d("heart", -5.0)
            heart_t = lerpf(0.55, 1.1, h / 30.0)
    # thakawat ki saans
    var ex: bool = main_node.get("exhausted")
    if ex and not was_exhausted:
        play2d("pant", -4.0)
    was_exhausted = ex


# ---------------- ambient loops ----------------
func _start_ambient() -> void:
    var names := ["wind", "traffic", "engine"]
    var vols := [-22.0, -23.0, -31.0]
    for i in 3:
        var p := AudioStreamPlayer.new()
        p.stream = bank[names[i]]
        p.volume_db = vols[i]
        add_child(p)
        p.play()
        amb.append(p)


# ---------------- sound bank ----------------
func _build_bank() -> void:
    bank["step"] = _gen(K_STEP, 0.12, RATE)
    bank["p_hurt"] = _gen(K_HURT, 0.3, RATE)
    bank["p_die"] = _gen(K_DIE, 1.0, RATE)
    bank["heart"] = _gen(K_HEART, 0.35, RATE)
    bank["pant"] = _gen(K_PANT, 0.6, RATE)
    bank["e_hurt"] = _gen(K_EHURT, 0.4, RATE)
    bank["e_die"] = _gen(K_EDIE, 0.9, RATE)
    bank["e_growl"] = _gen(K_GROWL, 0.7, RATE)
    bank["punch"] = _gen(K_PUNCH, 0.18, RATE)
    bank["pickup"] = _gen(K_PICK, 0.18, RATE)
    bank["eat"] = _gen(K_EAT, 0.5, RATE)
    bank["drink"] = _gen(K_DRINK, 0.6, RATE)
    bank["heal"] = _gen(K_HEAL, 0.7, RATE)
    bank["click"] = _gen(K_CLICK, 0.05, RATE)
    bank["bird"] = _gen(K_BIRD, 0.45, RATE)
    bank["horn"] = _gen(K_HORN, 0.5, RATE)
    bank["wind"] = _gen(K_WIND, 3.0, AMB_RATE, true)
    bank["traffic"] = _gen(K_TRAFFIC, 3.0, AMB_RATE, true)
    bank["engine"] = _gen(K_ENGINE, 2.0, AMB_RATE, true)


# insaani awaaz ke harmonics (formant gains)
func _gains(f0: float, fm1: float, fm2: float) -> PackedFloat32Array:
    var g := PackedFloat32Array()
    for k in range(1, 7):
        var hf := f0 * float(k)
        var a := exp(-pow((hf - fm1) / 300.0, 2.0)) + 0.7 * exp(-pow((hf - fm2) / 400.0, 2.0)) + 0.12
        g.append(a / sqrt(float(k)))
    return g


func _harm(ph: float, g: PackedFloat32Array) -> float:
    var s := 0.0
    for k in 6:
        s += sin(TAU * float(k + 1) * ph) * g[k]
    return s


func _gen(kind: int, dur: float, rate: int, loop: bool = false) -> AudioStreamWAV:
    var n := int(dur * float(rate))
    var extra := int(0.15 * float(rate)) if loop else 0
    var buf := PackedFloat32Array()
    buf.resize(n + extra)
    var r := RandomNumberGenerator.new()
    r.seed = 900 + kind
    var lp := 0.0
    var lp2 := 0.0
    var ph := 0.0
    var g := PackedFloat32Array()
    match kind:
        K_HURT:
            g = _gains(120.0, 650.0, 1050.0)
        K_DIE:
            g = _gains(100.0, 500.0, 900.0)
        K_EHURT:
            g = _gains(150.0, 750.0, 1300.0)
        K_EDIE:
            g = _gains(110.0, 600.0, 1000.0)
        K_GROWL:
            g = _gains(75.0, 500.0, 850.0)
    for i in n + extra:
        var t := float(i) / float(rate)
        var nz := r.randf() * 2.0 - 1.0
        var s := 0.0
        match kind:
            K_STEP:
                lp += (nz - lp) * 0.25
                s = sin(TAU * 60.0 * t) * exp(-t * 45.0) * 0.7 + lp * exp(-t * 50.0) * 0.6
            K_HURT:
                ph += (125.0 - 40.0 * t / 0.3) / float(rate)
                var env := minf(t / 0.015, 1.0) * exp(-t * 9.0)
                s = (_harm(ph, g) * 0.55 + nz * 0.12 * exp(-t * 20.0)) * env * 1.4
            K_DIE:
                ph += (120.0 * exp(-t * 1.1) + 25.0) / float(rate)
                var env2 := minf(t / 0.03, 1.0) * exp(-t * 2.2)
                s = _harm(ph, g) * 0.6 * env2 + nz * 0.12 * exp(-pow(t - 0.5, 2.0) * 8.0)
                if t > 0.75:
                    s += sin(TAU * 60.0 * (t - 0.75)) * exp(-(t - 0.75) * 30.0) * 0.7
            K_HEART:
                s = sin(TAU * 55.0 * t) * exp(-t * 28.0) * 0.9
                if t > 0.17:
                    s += sin(TAU * 48.0 * (t - 0.17)) * exp(-(t - 0.17) * 30.0) * 0.6
            K_PANT:
                lp += (nz - lp) * 0.35
                var pe := exp(-pow((t - 0.15) / 0.08, 2.0)) + exp(-pow((t - 0.4) / 0.08, 2.0))
                s = (lp * 0.9 + nz * 0.1) * pe * 0.5
            K_EHURT:
                ph += (170.0 - 90.0 * t) / float(rate)
                var env3 := minf(t / 0.015, 1.0) * exp(-t * 6.0)
                s = (_harm(ph, g) * 0.55 + nz * 0.1 * exp(-t * 15.0)) * env3 * 1.4
            K_EDIE:
                ph += (150.0 * exp(-t * 1.4) + 30.0) / float(rate)
                var env4 := minf(t / 0.02, 1.0) * exp(-t * 2.5)
                s = _harm(ph, g) * 0.6 * env4
                if t > 0.65:
                    s += sin(TAU * 55.0 * (t - 0.65)) * exp(-(t - 0.65) * 28.0) * 0.7
            K_GROWL:
                ph += (75.0 + 6.0 * sin(TAU * 6.0 * t)) / float(rate)
                var am := 0.6 + 0.4 * sin(TAU * 35.0 * t)
                var env5 := pow(sin(PI * t / 0.7), 0.7)
                s = _harm(ph, g) * am * env5 * 0.7 + nz * 0.08 * env5
            K_PUNCH:
                lp += (nz - lp) * 0.3
                s = sin(TAU * 95.0 * t) * exp(-t * 28.0) * 0.8 + lp * exp(-t * 45.0) * 0.7
            K_PICK:
                s = sin(TAU * 880.0 * t) * exp(-t * 30.0) * 0.4
                if t > 0.06:
                    s += sin(TAU * 1320.0 * (t - 0.06)) * exp(-(t - 0.06) * 25.0) * 0.4
            K_EAT:
                lp += (nz - lp) * 0.5
                for bi in 3:
                    var bt := 0.02 + 0.16 * float(bi)
                    if t > bt:
                        s += lp * exp(-(t - bt) * 60.0) * 1.1
            K_DRINK:
                for bj in 2:
                    var b2 := 0.05 + 0.23 * float(bj)
                    if t > b2:
                        var u := t - b2
                        s += sin(TAU * (300.0 * u - 350.0 * u * u)) * exp(-u * 12.0) * 0.5
                lp += (nz - lp) * 0.2
                s += lp * 0.04
            K_HEAL:
                var notes := PackedFloat32Array([523.0, 659.0, 784.0])
                for j in 3:
                    var tb := float(j) * 0.12
                    if t > tb:
                        var uu := t - tb
                        s += (sin(TAU * notes[j] * uu) + 0.3 * sin(TAU * notes[j] * 2.0 * uu)) * exp(-uu * 6.0) * 0.25
            K_CLICK:
                s = sin(TAU * 1400.0 * t) * exp(-t * 110.0) * 0.4 + nz * exp(-t * 200.0) * 0.2
            K_BIRD:
                for j2 in 3:
                    var tb2 := float(j2) * 0.15
                    var u2 := (t - tb2) / 0.1
                    if u2 >= 0.0 and u2 < 1.0:
                        ph += (2600.0 + 1500.0 * u2) / float(rate)
                        s = sin(TAU * ph) * sin(PI * u2) * 0.35
            K_HORN:
                var he := minf(t / 0.03, 1.0) * (1.0 if t < 0.42 else maxf((0.5 - t) / 0.08, 0.0))
                var hs := sin(TAU * 420.0 * t) + 0.8 * sin(TAU * 528.0 * t) + 0.4 * sin(TAU * 840.0 * t)
                s = tanh(hs * 1.6) * 0.3 * he
            K_WIND:
                lp += (nz - lp) * 0.04
                lp2 += (lp - lp2) * 0.2
                s = lp2 * 3.0 * (0.6 + 0.4 * sin(TAU * t / 3.0))
            K_TRAFFIC:
                lp += (nz - lp) * 0.015
                s = lp * 4.0 * (0.7 + 0.3 * sin(TAU * t * 2.0 / 3.0)) + sin(TAU * 52.0 * t) * 0.05
            K_ENGINE:
                lp += (nz - lp) * 0.1
                var pulse := pow(maxf(sin(TAU * 10.0 * t), 0.0), 6.0)
                s = (sin(TAU * 70.0 * t) * 0.5 + lp * 0.6) * pulse * 0.5 + sin(TAU * 35.0 * t) * 0.08
        buf[i] = s
    if loop:
        for i in extra:
            var a := float(i) / float(extra)
            buf[i] = buf[i] * a + buf[n + i] * (1.0 - a)
    var data := PackedByteArray()
    data.resize(n * 2)
    for i in n:
        data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = rate
    w.stereo = false
    w.data = data
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = n
    return w
