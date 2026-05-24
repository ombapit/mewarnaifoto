extends Control

const MAX_RETRIES = 3

@onready var vbox: VBoxContainer      = $VBox
@onready var title: Label             = $VBox/Title
@onready var preview_image: TextureRect = $VBox/PreviewImage
@onready var btn_pick: Button        = $VBox/BtnPick
@onready var btn_camera: Button      = $VBox/BtnCamera
@onready var btn_process: Button     = $VBox/BtnProcess
@onready var btn_gallery: Button     = $VBox/BtnGallery
@onready var btn_mute: Button         = $BtnMute
@onready var status_label: Label     = $VBox/StatusLabel
@onready var http: HTTPRequest       = $HTTPRequest

var _photo_bytes: PackedByteArray = []
var _retry_count: int = 0
var _img_plugin: Object = null


func _ready() -> void:
	btn_pick.pressed.connect(_on_pick_pressed)
	btn_camera.pressed.connect(_on_camera_pressed)
	btn_process.pressed.connect(_on_process_pressed)
	btn_gallery.pressed.connect(_on_gallery_pressed)
	btn_mute.pressed.connect(_on_mute_pressed)
	btn_mute.text = "🔇" if MusicPlayer.muted else "🔊"
	http.request_completed.connect(_on_request_completed)
	btn_process.disabled = true
	_init_android_plugin()
	_set_dashboard_mode(true)
	_animate_title()


func _set_dashboard_mode(is_dashboard: bool) -> void:
	preview_image.visible = not is_dashboard
	btn_process.visible = not is_dashboard
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER if is_dashboard else BoxContainer.ALIGNMENT_BEGIN
	var h := 190.0 if is_dashboard else 150.0
	btn_pick.custom_minimum_size.y = h
	btn_camera.custom_minimum_size.y = h
	btn_gallery.custom_minimum_size.y = h


func _init_android_plugin() -> void:
	if OS.get_name() != "Android":
		return
	if not Engine.has_singleton("GodotGetImage"):
		_set_status("Plugin kamera/galeri belum terpasang.")
		return
	_img_plugin = Engine.get_singleton("GodotGetImage")

	# Daftar semua signal plugin → bantu cocokkan nama
	var sig_names: Array = []
	for s in _img_plugin.get_signal_list():
		sig_names.append(s.name)
	print("[GodotGetImage] signals: ", sig_names)

	if _img_plugin.has_signal("image_request_completed"):
		_img_plugin.connect("image_request_completed", _on_image_received)
	if _img_plugin.has_signal("error"):
		_img_plugin.connect("error", _on_plugin_error)
	if _img_plugin.has_signal("image_request_failed"):
		_img_plugin.connect("image_request_failed", _on_plugin_error)
	if _img_plugin.has_signal("permission_not_granted_by_user"):
		_img_plugin.connect("permission_not_granted_by_user", _on_perm_denied)


func _animate_title() -> void:
	await get_tree().process_frame
	title.pivot_offset = title.size * 0.5
	var tw := create_tween().set_loops()
	tw.tween_property(title, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE)


func _on_pick_pressed() -> void:
	if OS.get_name() == "Android":
		if _img_plugin:
			# Buka system picker → galeri, internal storage, SD card (SAF)
			_img_plugin.getGalleryImage()
		else:
			_set_status("Plugin galeri belum terpasang.")
	else:
		_pick_desktop()


func _on_camera_pressed() -> void:
	if OS.get_name() == "Android":
		if _img_plugin:
			_img_plugin.getCameraImage()
		else:
			_set_status("Plugin kamera belum terpasang.")
	else:
		_set_status("Kamera hanya tersedia di Android.")


func _on_image_received(result = null) -> void:
	print("[GodotGetImage] result type: ", type_string(typeof(result)))
	var item = _extract_image_data(result)
	if item == null:
		_set_status("Data foto kosong / tak dikenali.")
		return

	if item is PackedByteArray:
		print("[GodotGetImage] bytes: ", item.size())
		if not _load_photo_bytes(item):
			_set_status("Gagal load gambar (%d byte)." % item.size())
	elif item is Image:
		_photo_bytes = item.save_jpg_to_buffer(0.9)
		_set_dashboard_mode(false)
		_show_preview(_photo_bytes)
		btn_process.disabled = false
		_set_status("Foto siap. Tekan Jadikan Sketsa.")
	else:
		_set_status("Format tak dikenali: %s" % type_string(typeof(item)))


func _extract_image_data(result):
	# Plugin bisa kirim: PackedByteArray, Image, Array, atau Dictionary.
	if result is PackedByteArray or result is Image:
		return result
	if result is Array:
		return result[0] if not result.is_empty() else null
	if result is Dictionary:
		print("[GodotGetImage] dict keys: ", result.keys())
		# coba key umum
		for k in ["data", "image", "bytes", "buffer", "0", 0]:
			if result.has(k):
				return result[k]
		# fallback: ambil value pertama yang berupa bytes/Image
		for v in result.values():
			if v is PackedByteArray or v is Image:
				return v
	return null


func _on_plugin_error(msg = "") -> void:
	_set_status("Error plugin: %s" % str(msg))


func _on_perm_denied(perm = "") -> void:
	_set_status("Izin ditolak: %s" % str(perm))


func _pick_desktop() -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.jpg,*.jpeg,*.png ; Images"])
	dialog.file_selected.connect(_on_file_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.9)


func _on_file_selected(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	_load_photo_bytes(f.get_buffer(f.get_length()))
	f.close()


func _load_photo_bytes(data: PackedByteArray) -> bool:
	if data.is_empty():
		return false
	# Normalisasi ke JPG agar konsisten dikirim ke server
	var img := Image.new()
	if img.load_jpg_from_buffer(data) != OK:
		if img.load_png_from_buffer(data) != OK:
			if img.load_webp_from_buffer(data) != OK:
				return false
	_photo_bytes = img.save_jpg_to_buffer(0.9)
	_set_dashboard_mode(false)
	_show_preview(_photo_bytes)
	btn_process.disabled = false
	_set_status("Foto siap. Tekan Jadikan Sketsa.")
	return true


func _show_preview(data: PackedByteArray) -> void:
	var img := Image.new()
	img.load_jpg_from_buffer(data)
	if img.is_empty():
		img.load_png_from_buffer(data)
	var tex := ImageTexture.create_from_image(img)
	preview_image.texture = tex


func _on_process_pressed() -> void:
	if _photo_bytes.is_empty():
		return
	_retry_count = 0
	_send_to_api()


func _send_to_api() -> void:
	btn_process.disabled = true
	_set_status("Mengirim ke server...")

	var url: String = GlobalConfig.api_base_url + "/process-image"
	var boundary := "----GodotBoundary%d" % Time.get_ticks_msec()
	var body := PackedByteArray()

	# Build multipart/form-data
	var header_str := "--%s\r\nContent-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n" % boundary
	body.append_array(header_str.to_utf8_buffer())
	body.append_array(_photo_bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())

	var headers := [
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"Content-Length: %d" % body.size(),
	]
	http.request_raw(url, headers, HTTPClient.METHOD_POST, body)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_retry_count += 1
		if _retry_count <= MAX_RETRIES:
			_set_status("Gagal. Mencoba ulang %d/%d..." % [_retry_count, MAX_RETRIES])
			await get_tree().create_timer(pow(2.0, _retry_count)).timeout
			_send_to_api()
		else:
			btn_process.disabled = false
			_set_status("Gagal terhubung ke server. Coba lagi.")
		return

	var artwork_id: String = SaveManager.new_artwork(body, _photo_bytes)
	SaveManager.save_color_layer(PackedByteArray())  # kosong, siap diwarnai
	_set_status("Sketch siap!")
	get_tree().get_root().get_node("Main").go_to_coloring(artwork_id)


func _on_gallery_pressed() -> void:
	get_tree().get_root().get_node("Main").go_to_gallery()


func _on_mute_pressed() -> void:
	btn_mute.text = "🔇" if MusicPlayer.toggle_mute() else "🔊"


func _set_status(msg: String) -> void:
	status_label.text = msg
