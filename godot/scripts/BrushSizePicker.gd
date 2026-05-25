extends Control
class_name BrushSizePicker

signal size_selected(index: int)

const DOT := [12.0, 22.0, 32.0, 44.0, 56.0]   # diameter titik (visual)
const ACCENT := Color(0.2, 0.5, 1.0)
const GRAY := Color(0.62, 0.62, 0.66)

var active: int = 1
var _count: int = 3


func setup(count: int, current: int) -> void:
	_count = count
	active = current
	custom_minimum_size = Vector2(330, 90)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var hit := false
	var x := 0.0
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hit = true
		x = event.position.x
	elif event is InputEventScreenTouch and event.pressed:
		hit = true
		x = event.position.x
	if hit:
		var idx := int(clampf(x / (size.x / _count), 0.0, _count - 1))
		active = idx
		emit_signal("size_selected", idx)
		accept_event()
		queue_redraw()


func _draw() -> void:
	var cy := size.y * 0.5
	for i in range(_count):
		var cx := size.x * (i + 0.5) / _count
		var center := Vector2(cx, cy)
		var dia: float = DOT[i] if i < DOT.size() else 12.0
		var r := dia * 0.5
		var is_on := i == active

		if is_on:
			draw_circle(center, r + 7.0, Color(0.2, 0.5, 1.0, 0.2))
			draw_arc(center, r + 5.0, 0, TAU, 32, ACCENT, 3.0, true)

		draw_circle(center, r, ACCENT if is_on else GRAY)
