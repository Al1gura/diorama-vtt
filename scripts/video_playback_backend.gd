class_name VideoPlaybackBackend
extends RefCounted

signal ready(natural_size: Vector2i, duration_seconds: float)
signal finished
signal failed(error: int, message: String)
signal released


func load_file(_path: String, _audio_bus: StringName) -> void:
	failed.emit(ERR_UNAVAILABLE, "视频后端未实现")


func play() -> int:
	return ERR_UNAVAILABLE


func set_paused(_paused: bool) -> int:
	return ERR_UNAVAILABLE


func stop() -> void:
	pass


func release() -> void:
	released.emit()


func is_playing() -> bool:
	return false


func is_paused() -> bool:
	return false


func get_stream_position() -> float:
	return 0.0


func get_natural_size() -> Vector2i:
	return Vector2i.ZERO


func get_duration_seconds() -> float:
	return 0.0


func get_view() -> Control:
	return null


func get_video_texture() -> Texture2D:
	return null


func get_debug_state() -> Dictionary:
	return {
		"released": false,
		"playing": false,
		"paused": false,
		"stream_position": 0.0,
		"has_stream": false,
		"has_view": false,
		"finished_signal_connected": false,
	}
