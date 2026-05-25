extends Node

const UUID_PATH = "user://uuid.dat"
const API_BASE_URL_DEFAULT = "https://mewarnaifoto.davidsuwandi.my.id"

var user_uuid: String = ""
var api_base_url: String = API_BASE_URL_DEFAULT


func _ready() -> void:
	_load_or_create_uuid()
	# Paksa portrait di runtime (lebih andal dari project setting saja)
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)


func _load_or_create_uuid() -> void:
	if FileAccess.file_exists(UUID_PATH):
		var f := FileAccess.open(UUID_PATH, FileAccess.READ)
		user_uuid = f.get_line().strip_edges()
		f.close()
	else:
		user_uuid = _generate_uuid()
		var f := FileAccess.open(UUID_PATH, FileAccess.WRITE)
		f.store_line(user_uuid)
		f.close()


func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hex := func(n: int) -> String: return "%08x" % n
	return "%s-%04x-%04x-%04x-%s" % [
		hex.call(rng.randi()),
		rng.randi() & 0xFFFF,
		(rng.randi() & 0x0FFF) | 0x4000,
		(rng.randi() & 0x3FFF) | 0x8000,
		"%04x%08x" % [rng.randi() & 0xFFFF, rng.randi()],
	]
