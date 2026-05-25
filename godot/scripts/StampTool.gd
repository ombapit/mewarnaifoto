extends RefCounted
class_name StampTool

# Cap bentuk ke Image di posisi center, radius r, warna color.
static func stamp(img: Image, center: Vector2i, r: int, color: Color, shape: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var poly := PackedVector2Array()
	if shape == "triangle":
		poly = _triangle(center, r)
	elif shape == "star":
		poly = _star(center, r)
	elif shape == "square":
		poly = _square(center, r)

	for y in range(center.y - r, center.y + r + 1):
		if y < 0 or y >= h:
			continue
		for x in range(center.x - r, center.x + r + 1):
			if x < 0 or x >= w:
				continue
			var p := Vector2(x, y)
			var inside := false
			match shape:
				"circle":
					inside = p.distance_to(Vector2(center)) <= r
				"square", "triangle", "star":
					inside = _point_in_poly(p, poly)
				"heart":
					inside = _in_heart(p, center, r)
				"moon":
					inside = _in_moon(p, center, r)
			if inside:
				img.set_pixel(x, y, color)


static func _triangle(c: Vector2i, r: int) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(c.x, c.y - r),
		Vector2(c.x - r * 0.87, c.y + r * 0.5),
		Vector2(c.x + r * 0.87, c.y + r * 0.5),
	])


static func _square(c: Vector2i, r: int) -> PackedVector2Array:
	var s := r * 0.8
	return PackedVector2Array([
		Vector2(c.x - s, c.y - s), Vector2(c.x + s, c.y - s),
		Vector2(c.x + s, c.y + s), Vector2(c.x - s, c.y + s),
	])


static func _star(c: Vector2i, r: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var inner := r * 0.45
	for i in range(10):
		var ang := PI * i / 5.0 - PI / 2.0
		var rad: float = r if i % 2 == 0 else inner
		pts.append(Vector2(c.x + cos(ang) * rad, c.y + sin(ang) * rad))
	return pts


static func _point_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var n := poly.size()
	var j := n - 1
	for i in range(n):
		var a := poly[i]
		var b := poly[j]
		if ((a.y > p.y) != (b.y > p.y)) and \
			(p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x):
			inside = not inside
		j = i
	return inside


static func _in_heart(p: Vector2, c: Vector2i, r: int) -> bool:
	var nx := (p.x - c.x) / float(r)
	var ny := -(p.y - c.y) / float(r) + 0.25
	var a := nx * nx + ny * ny - 1.0
	return a * a * a - nx * nx * ny * ny * ny <= 0.0


static func _in_moon(p: Vector2, c: Vector2i, r: int) -> bool:
	var d_main := p.distance_to(Vector2(c))
	var cut := Vector2(c.x + r * 0.5, c.y - r * 0.15)
	var d_cut := p.distance_to(cut)
	return d_main <= r and d_cut > r * 0.85
