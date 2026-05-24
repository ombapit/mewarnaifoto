extends Node

const SCENE_UPLOAD   = "res://scenes/Upload.tscn"
const SCENE_COLORING = "res://scenes/Coloring.tscn"
const SCENE_GALLERY  = "res://scenes/Gallery.tscn"

var _current_scene: Node = null


func _ready() -> void:
	go_to_upload()


func go_to_upload() -> void:
	_switch_scene(SCENE_UPLOAD)


func go_to_coloring(artwork_id: String) -> void:
	_switch_scene(SCENE_COLORING, {"artwork_id": artwork_id})


func go_to_gallery() -> void:
	_switch_scene(SCENE_GALLERY)


func _switch_scene(path: String, params: Dictionary = {}) -> void:
	if _current_scene:
		_current_scene.queue_free()
	var packed: PackedScene = load(path)
	_current_scene = packed.instantiate()
	if _current_scene.has_method("init_params"):
		_current_scene.init_params(params)
	add_child(_current_scene)
