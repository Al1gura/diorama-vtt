class_name FakeVideoPlaybackBackend
extends VideoPlaybackBackend

enum LoadBehavior {
	READY_IMMEDIATELY,
	FAIL_IMMEDIATELY,
	WAIT_FOR_TEST,
}

var load_behavior: LoadBehavior = LoadBehavior.READY_IMMEDIATELY
var natural_size: Vector2i = Vector2i(320, 180)
var duration_seconds: float = 1.2
var failure_error: int = ERR_FILE_CORRUPT
var failure_message: String = "测试视频加载失败"
var call_log: Array[String] = []
var _view: ColorRect = null
var _playing: bool = false
var _paused: bool = false
var _stream_position: float = 0.0
var _released: bool = false


func load_file(_path: String, _audio_bus: StringName) -> void:
	call_log.append("load_file")
	_view = ColorRect.new()
	_view.color = Color(0.2, 0.4, 0.8, 1.0)
	match load_behavior:
		LoadBehavior.READY_IMMEDIATELY:
			ready.emit(natural_size, duration_seconds)
		LoadBehavior.FAIL_IMMEDIATELY:
			failed.emit(failure_error, failure_message)


func play() -> int:
	call_log.append("play")
	if _released:
		return ERR_UNCONFIGURED
	_playing = true
	_paused = false
	return OK


func set_paused(paused: bool) -> int:
	call_log.append("pause" if paused else "resume")
	if _released:
		return ERR_UNCONFIGURED
	_paused = paused
	return OK


func stop() -> void:
	call_log.append("stop")
	_playing = false
	_paused = false
	_stream_position = 0.0


func release() -> void:
	if _released:
		return
	call_log.append("clear_stream")
	_playing = false
	_paused = false
	_stream_position = 0.0
	call_log.append("disconnect_signals")
	_released = true
	call_log.append("release_backend")
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	released.emit()


func is_playing() -> bool:
	return _playing


func is_paused() -> bool:
	return _paused


func get_stream_position() -> float:
	return _stream_position


func get_natural_size() -> Vector2i:
	return natural_size if not _released else Vector2i.ZERO


func get_duration_seconds() -> float:
	return duration_seconds


func get_view() -> Control:
	return _view


func get_debug_state() -> Dictionary:
	return {
		"released": _released,
		"playing": _playing,
		"paused": _paused,
		"stream_position": _stream_position,
		"has_stream": not _released,
		"has_view": _view != null and is_instance_valid(_view),
		"finished_signal_connected": not _released,
	}


func complete_ready() -> void:
	ready.emit(natural_size, duration_seconds)


func complete_failed() -> void:
	failed.emit(failure_error, failure_message)


func complete_finished() -> void:
	_playing = false
	_paused = false
	finished.emit()
