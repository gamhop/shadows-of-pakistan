#!/bin/sh
# Run inside ~/shadows-of-pakistan after unzipping the pack. Safe to run twice.
cd "$(dirname "$0")" || exit 1

echo "== main.gd: no stamina, driving hooks =="
if grep -q 'stamina - 18.0' main.gd; then
    sed -i 's|^    var running := run_on and moving and not exhausted$|    var running := run_on and moving|' main.gd
    sed -i '/^    if running:$/,/^            exhausted = false$/d' main.gd
    sed -i '/^    var scol := /d' main.gd
    sed -i '/^    ui.draw_rect(Rect2(140, 88, 500, 20)/d' main.gd
    sed -i '/^    ui.draw_rect(Rect2(140, 88, 500.0 \* stamina/d' main.gd
fi
grep -q '^var driving' main.gd || sed -i 's|^var run_on := false$|&\nvar driving := false|' main.gd
grep -q '^var drive: CanvasLayer' main.gd || sed -i 's|^var survival: CanvasLayer$|&\nvar drive: CanvasLayer\nvar traffic: Node|' main.gd
grep -q 'res://drive.gd' main.gd || sed -i 's|^    add_child(survival)$|&\n    drive = preload("res://drive.gd").new()\n    add_child(drive)\n    traffic = preload("res://traffic.gd").new()\n    add_child(traffic)|' main.gd
grep -q 'traffic.call("respawn"' main.gd || sed -i 's|^    survival.call("respawn", lines, int(t\["seed"\]) + 1)$|&\n    traffic.call("respawn", city, lines, int(t["seed"]) + 4)|' main.gd
grep -q 'if driving:' main.gd || sed -i 's|^    var dir := Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, cam_yaw)$|&\n    if driving:\n        dir = Vector3.ZERO|' main.gd

echo "== city.gd: drivable vehicles, more cars =="
if ! grep -q 'VehicleScript' city.gd; then
    sed -i 's|^const VEHICLE_MODELS := {$|const VehicleScript := preload("res://vehicle.gd")\n&|' city.gd
    sed -i 's|^var tex_cache: Dictionary = {}$|&\nvar last_vehicle: Node3D|' city.gd
    sed -i '/^func _vehicle_body/,/^    return body$/ { s/-> StaticBody3D:/-> CharacterBody3D:/; s/var body := StaticBody3D.new()/var body := CharacterBody3D.new()\n    body.set_script(VehicleScript)\n    body.set_meta("size", size)/; s/^    return body$/    last_vehicle = body\n    return body/ }' city.gd
    sed -i 's|rng.randf_range(24.0, 42.0) / traffic|rng.randf_range(17.0, 30.0) / traffic|' city.gd
fi

echo "== mission: Safe House =="
grep -q '^var mission' main.gd || sed -i 's|^var traffic: Node$|&\nvar mission: CanvasLayer|' main.gd
grep -q 'res://mission.gd' main.gd || sed -i 's|^    add_child(traffic)$|&\n    mission = preload("res://mission.gd").new()\n    add_child(mission)|' main.gd
grep -q 'mission.call("respawn"' main.gd || sed -i 's|^    combat.call("respawn", lines, int(t\["seed"\]) + 2)$|&\n    mission.call("respawn", lines, int(t["seed"]) + 3)|' main.gd

echo
echo "== CHECKS (expected in brackets) =="
echo "[1] stamina lines left in main.gd (1):"; grep -c "stamina" main.gd
echo "[2] 'driving' lines in main.gd (2):"; grep -c "driving" main.gd
echo "[3] drive/traffic lines in main.gd (7):"; grep -c "drive\|traffic" main.gd
echo "[4] vehicle hooks in city.gd (4):"; grep -c "VehicleScript\|last_vehicle" city.gd
echo "[5] denser parking in city.gd (1):"; grep -c "17.0, 30.0" city.gd
echo "[6] mission lines in main.gd (4):"; grep -c "mission" main.gd
echo "[7] files:"; ls -l vehicle.gd drive.gd traffic.gd mission.gd
