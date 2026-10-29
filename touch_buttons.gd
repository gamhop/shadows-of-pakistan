extends Node

# Ek ungli se chalte/ghumte hue doosri ungli se koi bhi button dabane par wo button
# block nahi hota. (Godot sirf pehli ungli ko button ke liye sunta hai, doosri ko nahi;
# yahan hum doosri, teesri ungli se dabaye gaye button khud chalate hain.)

var primary := -1                  # wo ungli jo Godot khud button ke liye sunta hai
var manual: Dictionary = {}        # ungli index -> Button jo us ungli se dabaya gaya


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
    var t := event as InputEventScreenTouch
    if t == null:
        return
    if t.pressed:
        if primary == -1:
            primary = t.index
        else:
            manual[t.index] = _button_at(t.position)
    else:
        if t.index == primary:
            primary = -1
        elif manual.has(t.index):
            var b = manual[t.index]
            manual.erase(t.index)
            if b != null and is_instance_valid(b) and not get_tree().paused:
                var btn := b as Button
                if btn and btn.is_visible_in_tree() and not btn.disabled and btn.get_global_rect().has_point(t.position):
                    btn.pressed.emit()


func _button_at(pos: Vector2) -> Button:
    var best: Button = null
    var best_layer := -9999
    for c in get_parent().get_children():
        var cl := c as CanvasLayer
        if cl == null:
            continue
        var b := _find(cl, pos)
        if b != null and cl.layer >= best_layer:
            best = b
            best_layer = cl.layer
    return best


func _find(n: Node, pos: Vector2) -> Button:
    for c in n.get_children():
        var b := c as Button
        if b and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
            return b
        var r := _find(c, pos)
        if r:
            return r
    return null
