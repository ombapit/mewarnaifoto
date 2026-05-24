extends Control
class_name AnimatedBackground

@export var base_color: Color = Color(1, 0.96, 0.86)
@export var count: int = 16

const PALETTE := [
	Color(1, 0.7, 0.7, 0.5),
	Color(1, 0.88, 0.5, 0.5),
	Color(0.7, 0.9, 0.75, 0.5),
	Color(0.7, 0.82, 1, 0.5),
	Color(0.85, 0.7, 1, 0.5),
]

var _shapes: Array = []
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_spawn)


func _spawn() -> void:
	_shapes.clear()
	if size.x < 1.0:
		return
	for i in range(count):
		_shapes.append({
			"pos": Vector2(randf() * size.x, randf() * size.y),
			"vel": Vector2(randf_range(-12, 12), randf_range(-22, -8)),
			"radius": randf_range(14, 42),
			"color": PALETTE[randi() % PALETTE.size()],
			"kind": randi() % 2,            # 0 = gelembung, 1 = bintang
			"phase": randf() * TAU,
			"spin": randf_range(-0.6, 0.6),
		})


func _process(delta: float) -> void:
	if _shapes.is_empty():
		_spawn()
		return
	_t += delta
	for s in _shapes:
		s.pos += s.vel * delta
		# wrap
		if s.pos.y < -60.0:
			s.pos.y = size.y + 60.0
			s.pos.x = randf() * size.x
		if s.pos.x < -60.0:
			s.pos.x = size.x + 60.0
		elif s.pos.x > size.x + 60.0:
			s.pos.x = -60.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), base_color, true)
	for s in _shapes:
		var bob := sin(_t * 1.2 + s.phase) * 6.0
		var center: Vector2 = s.pos + Vector2(0, bob)
		if s.kind == 0:
			draw_circle(center, s.radius, s.color)
			draw_circle(center - Vector2(s.radius * 0.3, s.radius * 0.3), s.radius * 0.22, Color(1, 1, 1, 0.4))
		else:
			_draw_star(center, s.radius, _t * s.spin + s.phase, s.color)


func _draw_star(c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var inner := r * 0.45
	for i in range(10):
		var ang := rot + PI * i / 5.0 - PI / 2.0
		var rad: float = r if i % 2 == 0 else inner
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)
