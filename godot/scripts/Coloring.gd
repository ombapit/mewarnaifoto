extends Control

const UNDO_LIMIT = 20

const DEFAULT_PALETTE := [
	# Merah - oranye
	Color8(229, 57, 53), Color8(255, 112, 67), Color8(244, 81, 30), Color8(255, 138, 101),
	# Kuning
	Color8(253, 216, 53), Color8(255, 235, 59), Color8(255, 193, 7),
	# Hijau
	Color8(124, 179, 66), Color8(67, 160, 71), Color8(0, 137, 123), Color8(174, 213, 129),
	# Biru
	Color8(3, 169, 244), Color8(30, 136, 229), Color8(25, 60, 184), Color8(129, 212, 250),
	# Ungu - pink
	Color8(142, 36, 170), Color8(171, 71, 188), Color8(236, 64, 122), Color8(244, 143, 177),
	# Coklat / kulit
	Color8(141, 110, 99), Color8(109, 76, 65), Color8(255, 204, 153), Color8(255, 224, 189),
	# Pastel
	Color8(255, 183, 197), Color8(255, 218, 185), Color8(187, 222, 251), Color8(200, 230, 201),
	# Netral
	Color8(255, 255, 255), Color8(189, 189, 189), Color8(97, 97, 97), Color8(0, 0, 0),
]

const BRUSH_SIZES := [6, 12, 20, 32, 48]

@onready var canvas_area: Control       = $CanvasArea
@onready var canvas_content: Control    = $CanvasArea/CanvasContent
@onready var color_layer: TextureRect   = $CanvasArea/CanvasContent/ColorLayer
@onready var sketch_layer: TextureRect  = $CanvasArea/CanvasContent/SketchLayer
@onready var crayons_container: Container = $BottomPanel/CrayonTray/Crayons
@onready var brush_picker: Control      = $BottomPanel/MidRow/SizeBox/BrushSize
@onready var btn_pan: Button            = $BottomPanel/MidRow/BtnPan
@onready var btn_eraser: Button         = $BottomPanel/MidRow/BtnEraser
@onready var btn_stamp: Button          = $BottomPanel/MidRow/BtnStamp
@onready var btn_undo: Button           = $BottomPanel/Actions/BtnUndo
@onready var btn_save: Button           = $BottomPanel/Actions/BtnSave
@onready var btn_preview: Button        = $BottomPanel/Actions/BtnPreview
@onready var btn_back: Button           = $BottomPanel/Actions/BtnBack
@onready var color_picker_btn: ColorPickerButton = $BottomPanel/MidRow/ColorBox/ColorPickerBtn
@onready var autosave_timer: Timer      = $AutosaveTimer

var _crayons: Array[Crayon] = []

var _artwork_id: String = ""
var _sketch_img: Image
var _color_img: Image
var _color_tex: ImageTexture
var _current_color: Color = Color(1, 0, 0)

var _preview_open: bool = false
var _brush_idx: int = 2
var _drawing: bool = false
var _last_pos: Vector2i = Vector2i(-1, -1)

# zoom / pan
const MIN_ZOOM := 1.0
const MAX_ZOOM := 5.0
var _zoom: float = 1.0
var _touches: Dictionary = {}
var _pinching: bool = false
var _last_pinch_dist: float = 0.0
var _last_pinch_mid: Vector2 = Vector2.ZERO
var _pan_mode: bool = false
var _last_pan_pos: Vector2 = Vector2.ZERO
var _eraser: bool = false

const STAMP_SHAPES := ["star", "moon", "triangle", "heart", "circle", "square"]
const STAMP_ICONS := ["★", "🌙", "▲", "♥", "●", "■"]
var _stamp_mode: bool = false
var _stamp_idx: int = 0

var _undo_stack: Array[Image] = []


func init_params(params: Dictionary) -> void:
	_artwork_id = params.get("artwork_id", "")


func _ready() -> void:
	_build_crayons()
	brush_picker.call("setup", BRUSH_SIZES.size(), _brush_idx)
	brush_picker.connect("size_selected", _on_brush_size_selected)
	btn_pan.pressed.connect(_on_toggle_pan)
	btn_eraser.pressed.connect(_on_toggle_eraser)
	btn_stamp.pressed.connect(_on_stamp_pressed)
	_update_pan_visual()
	_update_eraser_visual()
	_update_stamp_visual()
	btn_undo.pressed.connect(_on_undo)
	btn_save.pressed.connect(_on_save)
	btn_preview.pressed.connect(_on_preview)
	btn_back.pressed.connect(_on_back)
	color_picker_btn.color_changed.connect(_on_picker_changed)
	autosave_timer.timeout.connect(_on_autosave)
	SaveManager.set_active(_artwork_id)
	_load_artwork()
	AdsManager.hide_banner()
	autosave_timer.start(SaveManager.AUTOSAVE_INTERVAL)


func _load_artwork() -> void:
	var dir: String = SaveManager.get_artwork_dir(_artwork_id)

	_sketch_img = Image.new()
	_sketch_img.load(dir + "sketch.png")

	_color_img = Image.new()
	var color_path: String = dir + "layer_color.png"
	if FileAccess.file_exists(color_path) and FileAccess.get_file_as_bytes(color_path).size() > 0:
		_color_img.load(color_path)
	else:
		_color_img = Image.create(_sketch_img.get_width(), _sketch_img.get_height(), false, Image.FORMAT_RGBA8)
		_color_img.fill(Color.WHITE)

	_color_tex = ImageTexture.create_from_image(_color_img)
	color_layer.texture = _color_tex
	sketch_layer.texture = ImageTexture.create_from_image(_sketch_img)


func _build_crayons() -> void:
	for color: Color in DEFAULT_PALETTE:
		var crayon := Crayon.new()
		crayons_container.add_child(crayon)
		crayon.setup(color)
		crayon.selected.connect(_on_crayon_selected)
		_crayons.append(crayon)
	# Aktifkan krayon pertama (merah) sebagai default
	if not _crayons.is_empty():
		_on_crayon_selected(_crayons[0])


func _on_crayon_selected(crayon: Crayon) -> void:
	_current_color = crayon.color
	# Pilih krayon → matikan eraser & stamp (tetap bisa warnai biasa)
	_eraser = false
	_stamp_mode = false
	_refresh_tool_visuals()
	for cr: Crayon in _crayons:
		cr.set_active(cr == crayon)


func _on_picker_changed(c: Color) -> void:
	_current_color = c
	_eraser = false
	_stamp_mode = false
	_refresh_tool_visuals()
	for cr: Crayon in _crayons:
		cr.set_active(false)


# --- input ---

func _input(event: InputEvent) -> void:
	if _preview_open:
		return

	# --- Touch (Android) ---
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 2 and _pan_mode:
				_begin_pinch()
			elif _touches.size() == 1 and not _pinching:
				if _pan_mode:
					_last_pan_pos = event.position
				else:
					_start_stroke(event.position)
		else:
			_touches.erase(event.index)
			if _touches.size() < 2:
				_pinching = false
			if _touches.is_empty():
				_end_stroke()
		return

	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _pinching:
			_update_pinch()
		elif _pan_mode and _touches.size() == 1:
			_pan_by(event.position - _last_pan_pos)
			_last_pan_pos = event.position
		elif _drawing and _touches.size() == 1:
			_continue_stroke(event.position)
		return

	# --- Mouse (desktop test) ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _pan_mode:
			_zoom_at(_to_area_local(event.position), 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _pan_mode:
			_zoom_at(_to_area_local(event.position), 1.0 / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _pan_mode:
					_last_pan_pos = event.position
				else:
					_start_stroke(event.position)
			else:
				_end_stroke()
	elif event is InputEventMouseMotion:
		if _pan_mode and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_pan_by(event.position - _last_pan_pos)
			_last_pan_pos = event.position
		elif _drawing:
			_continue_stroke(event.position)


# --- pinch zoom / pan ---

func _begin_pinch() -> void:
	_pinching = true
	_end_stroke()
	var pts := _touches.values()
	_last_pinch_dist = pts[0].distance_to(pts[1])
	_last_pinch_mid = (pts[0] + pts[1]) * 0.5


func _update_pinch() -> void:
	if _touches.size() < 2:
		return
	var pts := _touches.values()
	var dist: float = pts[0].distance_to(pts[1])
	var mid: Vector2 = (pts[0] + pts[1]) * 0.5

	if _last_pinch_dist > 0.0:
		_zoom_at(_to_area_local(mid), dist / _last_pinch_dist)
	# pan ikut gerak jari
	canvas_content.position += mid - _last_pinch_mid
	_clamp_pan()

	_last_pinch_dist = dist
	_last_pinch_mid = mid


func _zoom_at(area_point: Vector2, factor: float) -> void:
	var old := _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	var lp := (area_point - canvas_content.position) / old
	canvas_content.scale = Vector2(_zoom, _zoom)
	canvas_content.position = area_point - lp * _zoom
	_clamp_pan()


func _clamp_pan() -> void:
	if _zoom <= MIN_ZOOM:
		canvas_content.position = Vector2.ZERO
		return
	var area := canvas_area.size
	var scaled := area * _zoom
	var pos := canvas_content.position
	pos.x = clampf(pos.x, area.x - scaled.x, 0.0)
	pos.y = clampf(pos.y, area.y - scaled.y, 0.0)
	canvas_content.position = pos


func _to_area_local(screen_pos: Vector2) -> Vector2:
	return screen_pos - canvas_area.get_global_rect().position


func _pan_by(delta: Vector2) -> void:
	canvas_content.position += delta
	_clamp_pan()


func _on_toggle_pan() -> void:
	_pan_mode = not _pan_mode
	if _pan_mode:
		_eraser = false
		_stamp_mode = false
	_end_stroke()
	_refresh_tool_visuals()


func _on_toggle_eraser() -> void:
	_eraser = not _eraser
	if _eraser:
		_pan_mode = false
		_stamp_mode = false
	_end_stroke()
	_refresh_tool_visuals()


func _on_stamp_pressed() -> void:
	if not _stamp_mode:
		_stamp_mode = true
		_pan_mode = false
		_eraser = false
	else:
		# Tap lagi saat aktif → ganti bentuk berikutnya
		_stamp_idx = (_stamp_idx + 1) % STAMP_SHAPES.size()
	_end_stroke()
	_refresh_tool_visuals()


func _refresh_tool_visuals() -> void:
	_update_pan_visual()
	_update_eraser_visual()
	_update_stamp_visual()


func _update_pan_visual() -> void:
	btn_pan.modulate = Color(1, 0.85, 0.3) if _pan_mode else Color.WHITE


func _update_eraser_visual() -> void:
	btn_eraser.modulate = Color(1, 0.85, 0.3) if _eraser else Color.WHITE


func _update_stamp_visual() -> void:
	btn_stamp.modulate = Color(1, 0.85, 0.3) if _stamp_mode else Color.WHITE
	btn_stamp.call("set_icon", STAMP_ICONS[_stamp_idx])


func _start_stroke(screen_pos: Vector2) -> void:
	var img_pos := _screen_to_img(screen_pos)
	if img_pos.x < 0:
		return  # tap di luar canvas (toolbar dll)
	_push_undo()

	if _stamp_mode:
		var r: int = BRUSH_SIZES[_brush_idx] * 3
		StampTool.stamp(_color_img, img_pos, r, _current_color, STAMP_SHAPES[_stamp_idx])
		_color_tex.update(_color_img)
		SaveManager.mark_dirty()
		return

	_drawing = true
	_last_pos = img_pos
	_paint_dab(img_pos)
	_color_tex.update(_color_img)


func _continue_stroke(screen_pos: Vector2) -> void:
	var img_pos := _screen_to_img(screen_pos)
	if img_pos.x < 0:
		return
	if _last_pos.x >= 0:
		_paint_line(_last_pos, img_pos)
	else:
		_paint_dab(img_pos)
	_last_pos = img_pos
	_color_tex.update(_color_img)
	SaveManager.mark_dirty()


func _end_stroke() -> void:
	_drawing = false
	_last_pos = Vector2i(-1, -1)


func _screen_to_img(screen_pos: Vector2) -> Vector2i:
	# Balik transform CanvasContent (scale + pan) → ruang lokal konten
	var local := canvas_content.get_global_transform().affine_inverse() * screen_pos
	var area := canvas_content.size
	var img_size := Vector2(_color_img.get_size())
	var scale: float = min(area.x / img_size.x, area.y / img_size.y)
	var disp_size := img_size * scale
	var offset := (area - disp_size) * 0.5
	var p := local - offset
	if p.x < 0 or p.y < 0 or p.x >= disp_size.x or p.y >= disp_size.y:
		return Vector2i(-1, -1)
	return Vector2i(p / scale)


func _paint_dab(center: Vector2i) -> void:
	var col := Color.WHITE if _eraser else _current_color
	var r: int = BRUSH_SIZES[_brush_idx]
	var w := _color_img.get_width()
	var h := _color_img.get_height()
	var r2 := r * r
	for y in range(center.y - r, center.y + r + 1):
		if y < 0 or y >= h:
			continue
		for x in range(center.x - r, center.x + r + 1):
			if x < 0 or x >= w:
				continue
			var dx := x - center.x
			var dy := y - center.y
			if dx * dx + dy * dy <= r2:
				_color_img.set_pixel(x, y, col)


func _paint_line(p0: Vector2i, p1: Vector2i) -> void:
	var dist := Vector2(p1 - p0).length()
	var step: float = max(1.0, BRUSH_SIZES[_brush_idx] * 0.4)
	var steps := int(dist / step) + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := Vector2(p0).lerp(Vector2(p1), t)
		_paint_dab(Vector2i(p))


# --- tools ---

func _on_brush_size_selected(idx: int) -> void:
	_brush_idx = idx


func _push_undo() -> void:
	_undo_stack.append(_color_img.duplicate())
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	btn_undo.disabled = false


func _on_undo() -> void:
	if _undo_stack.is_empty():
		return
	_color_img = _undo_stack.pop_back()
	_color_tex.update(_color_img)
	SaveManager.mark_dirty()
	if _undo_stack.is_empty():
		btn_undo.disabled = true


func _on_autosave() -> void:
	if not SaveManager._dirty:
		return
	_do_save()


func _on_save() -> void:
	_do_save()


func _do_save() -> void:
	SaveManager.save_color_layer(_color_img.save_png_to_buffer())
	_save_thumbnail()


func _save_thumbnail() -> void:
	var merged := _build_merged_image()
	var small := merged.duplicate()
	small.resize(256, int(256.0 * merged.get_height() / merged.get_width()))
	SaveManager.save_thumbnail(small.save_jpg_to_buffer(0.8))


func _build_merged_image() -> Image:
	var out := Image.create(_color_img.get_width(), _color_img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	out.blend_rect(_color_img, Rect2i(0, 0, _color_img.get_width(), _color_img.get_height()), Vector2i.ZERO)
	out.blend_rect(_sketch_img, Rect2i(0, 0, _sketch_img.get_width(), _sketch_img.get_height()), Vector2i.ZERO)
	return out


func _on_preview() -> void:
	if _preview_open:
		return
	_preview_open = true
	var tex := ImageTexture.create_from_image(_build_merged_image())
	add_child(_make_fullscreen_preview(tex))


func _close_preview(overlay: Control) -> void:
	_preview_open = false
	overlay.queue_free()


func _make_fullscreen_preview(tex: ImageTexture) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	# Tap di mana saja untuk tutup
	overlay.gui_input.connect(func(e):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_close_preview(overlay)
	)

	var img_rect := TextureRect.new()
	img_rect.texture = tex
	img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(img_rect)

	var close_btn := Button.new()
	close_btn.text = "✕ Tutup"
	close_btn.add_theme_font_size_override("font_size", 36)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	close_btn.offset_left = -120
	close_btn.offset_right = 120
	close_btn.offset_top = -120
	close_btn.offset_bottom = -40
	close_btn.pressed.connect(func(): _close_preview(overlay))
	overlay.add_child(close_btn)
	return overlay


func _on_back() -> void:
	_do_save()
	AdsManager.try_show_interstitial()
	get_tree().get_root().get_node("Main").go_to_upload()
