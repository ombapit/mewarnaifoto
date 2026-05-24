extends Node

const BGM_PATHS = ["res://assets/audio/bgm.mp3", "res://assets/audio/bgm.ogg"]
const MUTE_SAVE = "user://muted.dat"

var _player: AudioStreamPlayer
var muted: bool = false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -8.0
	add_child(_player)
	_load_mute_state()
	_start_music()


func _start_music() -> void:
	var path := ""
	for p in BGM_PATHS:
		if ResourceLoader.exists(p):
			path = p
			break
	if path == "":
		print("[MusicPlayer] bgm belum ada di ", BGM_PATHS)
		return
	var stream := load(path)
	# Loop kalau format mendukung
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_player.stream = stream
	if not muted:
		_player.play()


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		_player.stop()
	elif _player.stream:
		_player.play()
	_save_mute_state()
	return muted


func _load_mute_state() -> void:
	if FileAccess.file_exists(MUTE_SAVE):
		var f := FileAccess.open(MUTE_SAVE, FileAccess.READ)
		muted = f.get_line().strip_edges() == "1"
		f.close()


func _save_mute_state() -> void:
	var f := FileAccess.open(MUTE_SAVE, FileAccess.WRITE)
	f.store_line("1" if muted else "0")
	f.close()
