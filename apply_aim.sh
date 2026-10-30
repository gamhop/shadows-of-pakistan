#!/bin/sh
# Run inside ~/shadows-of-pakistan. Safe to run twice.
# Crosshair ab camera ke sath fixed: neeche/upar karne par slide nahi hota.
cd "$(dirname "$0")" || exit 1
python3 - <<'PY'
import re, sys
p = "combat.gd"
s = open(p).read()
if "# crosshair fixed" in s:
    print("already patched")
    sys.exit(0)
start = s.index("func _aim_point() -> Vector2:")
end = s.index("func _shoot() -> void:")
new = '''func _aim_point() -> Vector2:
    # crosshair fixed: camera ke sath hi upar-neeche hota hai, koi slide nahi
    var vp := get_viewport().get_visible_rect().size
    return Vector2(vp.x / 2.0, vp.y * AIM_Y)


'''
s = s[:start] + new + s[end:]
s = re.sub(r"^const FEET_START.*\n", "", s, flags=re.M)
s = re.sub(r"^const FEET_FULL.*\n", "", s, flags=re.M)
open(p, "w").write(s)
print("combat.gd patched")
PY
echo "== CHECKS (expected in brackets) =="
echo "[1] FEET lines left (0):"; grep -c "FEET_" combat.gd
echo "[2] crosshair fixed marker (1):"; grep -c "# crosshair fixed" combat.gd
echo "[3] _aim_point defs (1):"; grep -c "func _aim_point" combat.gd
