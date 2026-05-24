extends Control

const UNDO_LIMIT = 20

const DEFAULT_PALETTE := [
	Color(1, 0, 0),       # merah
	Color(1, 0.5, 0),     # oranye
	Color(1, 1, 0),       # kuning
	Color(0, 0.8, 0),     # hijau
	Color(0, 0.5, 1),     # biru muda
	Color(0, 0, 0.8),     # biru tua
	Color(0.6, 0, 0.8),   # ungu
	Color(1, 0.4, 0.7),   # pink
	Color(0.5, 0.3, 0.1), # coklat
	Color(1, 1, 1),       # putih
	Color(0.5, 0.5, 0.5), # abu
	Color(0, 0, 0),       # hitam
]

const BRUSH_SIZES := [8, 18, 32]

@onready var canvas_area: Control       = $CanvasArea
@onready var color_layer: TextureRect   = $CanvasArea/ColorLayer
@onready var sketch_layer: TextureRect  = $CanvasArea/SketchLayer
@onready var crayons_container: HBoxContainer = $BottomPanel/CrayonTray/Crayons
@onready var brush_picker: Control      = $BottomPanel/MidRow/SizeBox/BrushSize
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
var _brush_idx: int = 1
var _drawing: bool = false
var _last_pos: Vector2i = Vector2i(-1, -1)

var _undo_stack: Array[Image] = []


func init_params(params: Dictionary) -> void:
	_artwork_id = params.get("artwork_id", "")


func _ready() -> void:
	_build_crayons()
	brush_picker.call("setup", BRUSH_SIZES.size(), _brush_idx)
	brush_picker.connect("size_selected", _on_brush_size_selected)
	btn_undo.pressed.connect(_on_undo)
	btn_save.pressed.connect(_on_save)
	btn_preview.pressed.connect(_on_preview)
	btn_back.pressed.connect(_on_back)
	color_picker_btn.color_changed.connect(_on_picker_changed)
	autosave_timer.timeout.connect(_on_autosave)
	SaveManager.set_active(_artwork_id)
	_load_artwork()
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
	for cr: Crayon in _crayons:
		cr.set_active(cr == crayon)


func _on_picker_changed(c: Color) -> void:
	_current_color = c
	for cr: Crayon in _crayons:
		cr.set_active(false)


# --- input ---

func _input(event: InputEvent) -> void:
	if _preview_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_end_stroke()
	elif event is InputEventMouseMotion and _drawing:
		_continue_stroke(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_start_stroke(event.position)
		else:
			_end_stroke()
	elif event is InputEventScreenDrag and _drawing:
		_continue_stroke(event.position)


func _start_stroke(screen_pos: Vector2) -> void:
	var img_pos := _screen_to_img(screen_pos)
	if img_pos.x < 0:
		return  # tap di luar canvas (toolbar dll)
	_push_undo()
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
	var rect := canvas_area.get_global_rect()
	var img_size := Vector2(_color_img.get_size())
	var scale: float = min(rect.size.x / img_size.x, rect.size.y / img_size.y)
	var disp_size := img_size * scale
	var offset := rect.position + (rect.size - disp_size) * 0.5
	var local := screen_pos - offset
	if local.x < 0 or local.y < 0 or local.x >= disp_size.x or local.y >= disp_size.y:
		return Vector2i(-1, -1)
	return Vector2i(local / scale)


func _paint_dab(center: Vector2i) -> void:
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
				_color_img.set_pixel(x, y, _current_color)


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
	get_tree().get_root().get_node("Main").go_to_upload()
