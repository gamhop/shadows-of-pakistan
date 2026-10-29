#!/bin/sh
# Run this inside ~/shadows-of-pakistan after unzipping the pack.
# Safe to run more than once: every edit checks first.
cd "$(dirname "$0")" || exit 1

echo "== main.gd hooks =="
grep -q '^var combat: CanvasLayer' main.gd || sed -i 's|^var survival: CanvasLayer$|&\nvar combat: CanvasLayer|' main.gd
grep -q 'res://combat.gd' main.gd || sed -i 's|^    add_child(survival)$|&\n    combat = preload("res://combat.gd").new()\n    add_child(combat)|' main.gd
grep -q 'combat.call("respawn"' main.gd || sed -i 's|^    survival.call("respawn", lines, int(t\["seed"\]) + 1)$|&\n    combat.call("respawn", lines, int(t["seed"]) + 2)|' main.gd
grep -q 'res://build_label.gd' main.gd || sed -i 's|^    add_child(preload("res://settings_menu.gd").new())$|&\n    add_child(preload("res://build_label.gd").new())|' main.gd

echo "== workflow stamp =="
if [ -f .github/workflows/android.yml ]; then
    grep -q 'ci_stamp' .github/workflows/android.yml || sed -i 's#^          grep -n "version/" export_presets.cfg$#&\n          sh ci_stamp.sh#' .github/workflows/android.yml
fi

echo
echo "== CHECKS =="
echo "[1] main.gd combat lines (expect 4):"
grep -c "combat" main.gd
echo "[2] build_label in main.gd (expect 1):"
grep -c "build_label" main.gd
echo "[3] ci_stamp in workflow (expect 1):"
grep -c "ci_stamp" .github/workflows/android.yml
echo "[4] files:"
ls -l enemy.gd combat.gd build_label.gd build_info.gd ci_stamp.sh
