#!/bin/sh
# Run inside ~/shadows-of-pakistan. Safe to run twice.
# Paon-assist: crosshair fixed rehta hai, lekin neeche dekhte hue paon ke paas wale dushman ko goli lagti hai.
cd "$(dirname "$0")" || exit 1
python3 - <<'PY'
import sys
p = "combat.gd"
s = open(p).read()
if "# feet assist" in s:
    print("already patched")
    sys.exit(0)

a1 = "const AIM_Y := 0.2"
i = s.index(a1)
j = s.index("\n", i) + 1
s = s[:j] + '''const FEET_PITCH := -0.7   # itna neeche dekhne par paon-assist chalu
const FEET_RADIUS := 2.0   # paon se itni doori tak ka dushman lagta hai
''' + s[j:]

a2 = "    var hit := space.intersect_ray(q)\n    var end := to\n"
assert s.count(a2) == 1, "shoot anchor not found"
s = s.replace(a2, '''    var hit := space.intersect_ray(q)
    # feet assist: crosshair se dushman na lage to paon ke paas wala dushman lag jata hai
    var pitch_now: float = main_node.get("cam_pitch")
    var ray_enemy: bool = not hit.is_empty() and hit["collider"] != null and hit["collider"].has_method("take_damage")
    if pitch_now <= FEET_PITCH and not ray_enemy:
        var fe := _feet_enemy(player)
        if fe != null:
            var fp: Vector3 = fe.global_position + Vector3(0, 0.9, 0)
            hit = {"position": fp, "collider": fe, "normal": (from - fp).normalized()}
    var end := to
''')

a3 = "func _fire_feel(muzzle: Vector3) -> void:"
assert s.count(a3) == 1, "fire_feel anchor not found"
s = s.replace(a3, '''func _feet_enemy(player: Node3D) -> Node3D:
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


''' + a3)
open(p, "w").write(s)
print("combat.gd patched")
PY
echo "== CHECKS (expected in brackets) =="
echo "[1] feet assist marker (1):"; grep -c "# feet assist" combat.gd
echo "[2] _feet_enemy lines (2):"; grep -c "_feet_enemy" combat.gd
echo "[3] FEET_ consts (2 defs + 2 uses = 4):"; grep -c "FEET_" combat.gd
