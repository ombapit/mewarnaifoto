extends Control
class_name Crayon

signal selected(crayon)

const CRAYON_W := 56.0
const CRAYON_H := 150.0
const TIP_H := 32.0
const LIFT := 26.0

var color: Color = Color.WHITE
var active: bool = false
var _lift: float = 0.0


func setup(c: Color) -> void:
	color = c
	custom_minimum_size = Vector2(CRAYON_W + 14, CRAYON_H + LIFT + 12)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func set_active(v: bool) -> void:
	active = v
	var target: float = LIFT if v else 0.0
	var tw := create_tween()
	tw.tween_method(_set_lift, _lift, target, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_lift(val: float) -> void:
	_lift = val
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var hit := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hit = true
	elif event is InputEventScreenTouch and event.pressed:
		hit = true
	if hit:
		emit_signal("selected", self)
		accept_event()


func _draw() -> void:
	var cx := size.x * 0.5
	var bottom := size.y - 6.0 - _lift
	var body_left := cx - CRAYON_W * 0.5
	var tip_apex_y := bottom - CRAYON_H
	var tip_base_y := tip_apex_y + TIP_H

	var apex := Vector2(cx, tip_apex_y)
	var base_l := Vector2(body_left, tip_base_y)
	var base_r := Vector2(body_left + CRAYON_W, tip_base_y)

	# Glow saat aktif
	if active:
		draw_rect(Rect2(body_left - 6, tip_apex_y - 6, CRAYON_W + 12, CRAYON_H + 12),
			Color(1, 0.88, 0.3, 0.55), true)

	# Bayangan tipis di bawah
	draw_rect(Rect2(body_left, bottom - 2, CRAYON_W, 5), Color(0, 0, 0, 0.12), true)

	# Ujung krayon
	draw_colored_polygon(PackedVector2Array([apex, base_l, base_r]), color.darkened(0.12))

	# Badan krayon
	draw_rect(Rect2(body_left, tip_base_y, CRAYON_W, bottom - tip_base_y), color, true)

	# Garis pembungkus kertas
	var band_color := color.darkened(0.28)
	draw_line(Vector2(body_left, tip_base_y + 16), Vector2(base_r.x, tip_base_y + 16), band_color, 2.0)
	draw_line(Vector2(body_left, tip_base_y + 26), Vector2(base_r.x, tip_base_y + 26), band_color, 2.0)

	# Outline
	var outline := color.darkened(0.45)
	draw_polyline(PackedVector2Array([
		apex, base_r, Vector2(base_r.x, bottom),
		Vector2(body_left, bottom), base_l, apex,
	]), outline, 2.0)
