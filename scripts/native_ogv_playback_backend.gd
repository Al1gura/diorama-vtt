class_name NativeOgvPlaybackBackend
extends VideoPlaybackBackend

var _player: VideoStreamPlayer = null
var _stream: VideoStreamTheora = null
var _released: bool = false
var _finished_signal_connected: bool = false
var _audio_bus: StringName = &"Master"


func load_file(path: String, audio_bus: StringName) -> void:
	if _player != null or _stream != null:
		release()
	_released = false
	_audio_bus = audio_bus if audio_bus != &"" else &"Master"
	if path.get_extension().to_lower() != "ogv":
		failed.emit(ERR_FILE_UNRECOGNIZED, "P3 原生后端只接受 OGV 测试视频")
		return
	if not FileAccess.file_exists(path):
		failed.emit(ERR_FILE_NOT_FOUND, "OGV 文件不存在")
		return
	_player = VideoStreamPlayer.new()
	_player.name = "NativeOgvPlayer"
	_player.expand = true
	_player.autoplay = false
	_player.loop = false
	_player.bus = _audio_bus
	_player.add_to_group("gvtt_player_output_player")
	_player.finished.connect(_on_player_finished)
	_finished_signal_connected = true
	_stream = VideoStreamTheora.new()
	_stream.file = path
	_player.stream = _stream


func play() -> int:
	if _player == null or _stream == null:
		return ERR_UNCONFIGURED
	if not _player.is_inside_tree():
		return ERR_UNCONFIGURED
	_player.paused = false
	_player.play()
	return OK


func set_paused(paused: bool) -> int:
	if _player == null:
		return ERR_UNCONFIGURED
	_player.paused = paused
	return OK


func stop() -> void:
	if _player != null:
		_player.stop()


func release() -> void:
	if _released:
		return
	_released = true
	stop()
	if _player != null:
		_player.stream = null
		var finished_callable: Callable = Callable(self, "_on_player_finished")
		if _player.finished.is_connected(finished_callable):
			_player.finished.disconnect(finished_callable)
		_finished_signal_connected = false
		if is_instance_valid(_player):
			_player.queue_free()
	_finished_signal_connected = false
	_player = null
	_stream = null
	released.emit()


func is_playing() -> bool:
	return _player != null and _player.is_playing()


func is_paused() -> bool:
	return _player != null and _player.paused


func get_stream_position() -> float:
	return _player.get_stream_position() if _player != null else 0.0


func get_natural_size() -> Vector2i:
	if _player == null:
		return Vector2i.ZERO
	var texture: Texture2D = _player.get_video_texture()
	if texture == null:
		return Vector2i.ZERO
	var size: Vector2 = texture.get_size()
	return Vector2i(roundi(size.x), roundi(size.y))


func get_duration_seconds() -> float:
	return _player.get_stream_length() if _player != null else 0.0


func get_view() -> Control:
	return _player


func get_video_texture() -> Texture2D:
	return _player.get_video_texture() if _player != null else null


func get_debug_state() -> Dictionary:
	return {
		"released": _released,
		"playing": is_playing(),
		"paused": is_paused(),
		"stream_position": get_stream_position(),
		"has_stream": _stream != null or (_player != null and _player.stream != null),
		"has_view": _player != null and is_instance_valid(_player),
		"finished_signal_connected": _finished_signal_connected,
	}


func _on_player_finished() -> void:
	finished.emit()
