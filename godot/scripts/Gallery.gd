extends Control

@onready var grid: GridContainer       = $Scroll/Grid
@onready var btn_back: Button          = $TopBar/BtnBack
@onready var fullscreen_overlay: Control = $FullscreenOverlay
@onready var fs_image: TextureRect     = $FullscreenOverlay/Image
@onready var fs_close: Button          = $FullscreenOverlay/BtnClose
@onready var fs_continue: Button       = $FullscreenOverlay/Actions/BtnContinue
@onready var fs_share: Button          = $FullscreenOverlay/Actions/BtnShare
@onready var fs_delete: Button         = $FullscreenOverlay/Actions/BtnDelete

var _selected_id: String = ""


func _ready() -> void:
	btn_back.pressed.connect(_on_back)
	fs_close.pressed.connect(func(): fullscreen_overlay.visible = false)
	fs_continue.pressed.connect(_on_continue)
	fs_share.pressed.connect(_on_share)
	fs_delete.pressed.connect(_on_delete)
	fullscreen_overlay.visible = false
	AdsManager.hide_banner()
	_load_grid()


func _load_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var artworks := SaveManager.list_artworks()
	if artworks.is_empty():
		var lbl := Label.new()
		lbl.text = "Belum ada karya. Yuk mulai mewarnai!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(lbl)
		return

	for meta in artworks:
		_add_thumbnail(meta)


func _add_thumbnail(meta: Dictionary) -> void:
	var id: String = meta.get("id", "")
	var dir := SaveManager.get_artwork_dir(id)
	var thumb_path := dir + "thumb.jpg"

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(300, 300)

	if FileAccess.file_exists(thumb_path):
		var img := Image.new()
		img.load(thumb_path)
		var tex := ImageTexture.create_from_image(img)
		btn.icon = tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true

	btn.pressed.connect(func(): _open_fullscreen(id))
	grid.add_child(btn)


func _merge(id: String) -> Image:
	var dir := SaveManager.get_artwork_dir(id)
	var sketch_img := Image.new()
	sketch_img.load(dir + "sketch.png")

	var w := sketch_img.get_width()
	var h := sketch_img.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)

	var color_path := dir + "layer_color.png"
	if FileAccess.file_exists(color_path) and FileAccess.get_file_as_bytes(color_path).size() > 0:
		var color_img := Image.new()
		if color_img.load(color_path) == OK and not color_img.is_empty():
			out.blend_rect(color_img, Rect2i(0, 0, color_img.get_width(), color_img.get_height()), Vector2i.ZERO)

	out.blend_rect(sketch_img, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return out


func _open_fullscreen(id: String) -> void:
	_selected_id = id
	fs_image.texture = ImageTexture.create_from_image(_merge(id))
	fullscreen_overlay.visible = true


func _on_continue() -> void:
	if _selected_id == "":
		return
	get_tree().get_root().get_node("Main").go_to_coloring(_selected_id)


func _on_share() -> void:
	if _selected_id == "":
		return
	var export_path := "user://export_%s.jpg" % _selected_id
	_merge(_selected_id).save_jpg(export_path, 0.95)

	if OS.get_name() == "Android":
		var abs_path := ProjectSettings.globalize_path(export_path)
		OS.shell_open(abs_path)  # Trigger Android share sheet
	else:
		OS.shell_open(ProjectSettings.globalize_path(export_path))


func _on_delete() -> void:
	if _selected_id == "":
		return
	SaveManager.delete_artwork(_selected_id)
	fullscreen_overlay.visible = false
	_selected_id = ""
	_load_grid()


func _on_back() -> void:
	get_tree().get_root().get_node("Main").go_to_upload()
