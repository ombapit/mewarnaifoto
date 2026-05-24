extends Node

const SAVE_DIR = "user://artworks/"
const AUTOSAVE_INTERVAL = 30.0

signal autosave_triggered

var _timer: float = 0.0
var _active_artwork_id: String = ""
var _dirty: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		_timer = 0.0
		emit_signal("autosave_triggered")


func mark_dirty() -> void:
	_dirty = true


func mark_clean() -> void:
	_dirty = false
	_timer = 0.0


func new_artwork(sketch_png: PackedByteArray, original_png: PackedByteArray) -> String:
	var id := "%d" % Time.get_unix_time_from_system()
	var dir := SAVE_DIR + id + "/"
	DirAccess.make_dir_recursive_absolute(dir)

	_write_bytes(dir + "sketch.png", sketch_png)
	_write_bytes(dir + "original.png", original_png)

	var meta := {
		"id": id,
		"created": Time.get_datetime_string_from_system(),
		"completed": false,
	}
	_write_json(dir + "meta.json", meta)
	_active_artwork_id = id
	return id


func save_color_layer(color_png: PackedByteArray) -> void:
	if _active_artwork_id == "":
		return
	var dir := SAVE_DIR + _active_artwork_id + "/"
	_write_bytes(dir + "layer_color.png", color_png)
	mark_clean()


func save_sticker_layer(sticker_png: PackedByteArray) -> void:
	if _active_artwork_id == "":
		return
	var dir := SAVE_DIR + _active_artwork_id + "/"
	_write_bytes(dir + "layer_sticker.png", sticker_png)


func save_thumbnail(thumb_jpg: PackedByteArray) -> void:
	if _active_artwork_id == "":
		return
	_write_bytes(SAVE_DIR + _active_artwork_id + "/thumb.jpg", thumb_jpg)


func list_artworks() -> Array:
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var folder: String = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "." and folder != "..":
			var meta_path := SAVE_DIR + folder + "/meta.json"
			if FileAccess.file_exists(meta_path):
				result.append(_read_json(meta_path))
		folder = dir.get_next()
	result.sort_custom(func(a, b): return a["id"] > b["id"])
	return result


func delete_artwork(id: String) -> void:
	var dir := SAVE_DIR + id + "/"
	for fname: String in ["sketch.png", "original.png", "layer_color.png", "layer_sticker.png", "thumb.jpg", "meta.json"]:
		var path: String = dir + fname
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


func get_artwork_dir(id: String) -> String:
	return SAVE_DIR + id + "/"


func set_active(id: String) -> void:
	_active_artwork_id = id


# --- helpers ---

func _write_bytes(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var result: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return result if result is Dictionary else {}
