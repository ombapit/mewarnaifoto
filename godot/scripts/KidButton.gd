extends Button
class_name KidButton

const FUN := [
	Color("ff6b6b"), Color("ffd93d"), Color("6bcb77"),
	Color("4d96ff"), Color("ff9f45"), Color("c780fa"),
]

@export var base_color: Color = Color(0, 0, 0, 0)  # alpha 0 = auto pilih dari FUN

var _t: float = 0.0
var _press: float = 1.0
var _press_target: float = 1.0


func _ready() -> void:
	if base_color.a == 0.0:
		base_color = FUN[get_index() % FUN.size()]
	_apply_style()
	_t = randf() * TAU
	mouse_entered.connect(func(): _press_target = 1.08)
	mouse_exited.connect(func(): _press_target = 1.0)
	button_down.connect(func(): _press_target = 0.88)
	button_up.connect(func(): _press_target = 1.0)


func _process(delta: float) -> void:
	pivot_offset = size * 0.5
	_t += delta * 3.0
	_press = lerp(_press, _press_target, clampf(delta * 16.0, 0.0, 1.0))
	var pulse := 1.0 + sin(_t) * 0.035
	scale = Vector2.ONE * pulse * _press


func _apply_style() -> void:
	add_theme_font_size_override("font_size", 50)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)

	var normal := _box(base_color)
	normal.shadow_color = Color(0, 0, 0, 0.18)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 5)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", _box(base_color.lightened(0.1)))
	add_theme_stylebox_override("pressed", _box(base_color.darkened(0.12)))
	add_theme_stylebox_override("focus", _box(base_color))
	add_theme_stylebox_override("disabled", _box(Color(0.7, 0.7, 0.7)))


func _box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.border_color = c.darkened(0.25)
	sb.set_border_width_all(3)
	return sb
