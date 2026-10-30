extends Node

# Shehar mein chalti hui gaariyan (rickshaw aur car), jinhe koi chala raha hai.
# main.gd load_city() mein respawn(city, lines, seed) bulata hai.

const VehicleScript := preload("res://vehicle.gd")
const AI_COUNT := 16

var main_node: Node


func _ready() -> void:
    main_node = get_parent()


func respawn(city: Node, lines: Array, seed_v: int) -> void:
    if city == null or lines.size() < 2:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    var bound := 105.0
    var consts: Dictionary = city.get_script().get_script_constant_map()
    if consts.has("HALF"):
        bound = float(consts["HALF"])
    var player := main_node.get("player") as Node3D
    var origin := player.global_position if player else Vector3.ZERO
    var used: Array = []
    var made := 0
    var tries := 0
    while made < AI_COUNT and tries < 400:
        tries += 1
        var c: float = lines[rng.randi() % lines.size()]
        var along := rng.randf_range(-bound + 24.0, bound - 24.0)
        var near_line := false
        for l in lines:
            if absf(along - float(l)) < 11.0:
                near_line = true
        if near_line:
            continue
        var axis_z := rng.randf() < 0.5
        var sgn := 1.0 if rng.randf() < 0.5 else -1.0
        var dir := Vector3(0, 0, sgn) if axis_z else Vector3(sgn, 0, 0)
        var base := Vector3(c, 0.03, along) if axis_z else Vector3(along, 0.03, c)
        var pos := base + Vector3.UP.cross(dir) * VehicleScript.LANE
        if Vector2(pos.x - origin.x, pos.z - origin.z).length() < 30.0:
            continue
        var too_close := false
        for u in used:
            var up: Vector3 = u
            if Vector2(pos.x - up.x, pos.z - up.z).length() < 16.0:
                too_close = true
        if too_close:
            continue
        var rot := atan2(-dir.x, -dir.z)
        var before = city.get("last_vehicle")
        if rng.randf() < 0.35:
            city.call("_make_rickshaw", pos, rot)
        else:
            city.call("_make_car", pos, rot)
        var v = city.get("last_vehicle")
        if v == null or v == before:
            continue
        v.call("start_ai", dir, c, lines, rng.randf_range(6.5, 10.0), bound)
        used.append(pos)
        made += 1
