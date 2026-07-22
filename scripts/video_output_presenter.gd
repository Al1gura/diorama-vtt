class_name VideoOutputPresenter
extends PlayerOutputPresenter

const FIRST_FRAME_TIMEOUT_SECONDS: float = 3.0

var _host: Control = null
var _backend: VideoPlaybackBackend = null
var _aspect: AspectRatioContainer = null
var _natural_size: Vector2i = Vector2i.ZERO
var _duration_seconds: float = 0.0
var _elapsed_seconds: float = 0.0
var _backend_loading: bool = false
var _backend_ready: bool = false
var _audio_bus: StringName = &"Master"


func configure(
		host: Control,
		backend: VideoPlaybackBackend,
		audio_bus: StringName = &"Master"
) -> void:
	_host = host
	_backend = backend
	_audio_bus = audio_bus if audio_bus != &"" else &"Master"


func prepare(request_id: int, resolved_content: Dictionary) -> void:
	super.prepare(request_id, resolved_content)
	if _host == null or _backend == null:
		failed.emit(request_id, ERR_UNCONFIGURED, "视频承载面或后端不可用")
		return
	_connect_backend()
	_aspect = AspectRatioContainer.new()
	_aspect.name = "VideoAspect"
	_aspect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_aspect.hide()
	_host.add_child(_aspect)
	_backend_loading = true
	_backend.load_file(String(resolved_content.get("resolved_path", "")), _audio_bus)
	if _released or _backend == null:
		return
	var view: Control = _backend.get_view()
	if view != null and is_instance_valid(view):
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_aspect.add_child(view)
	_backend_loading = false
	var play_error: int = _backend.play()
	if play_error != OK:
		failed.emit(request_id, play_error, "视频无法开始播放")
		return
	if _backend_ready:
		_commit_ready()
	else:
		_elapsed_seconds = 0.0
		set_process(true)


func activate() -> int:
	if _aspect == null or not is_instance_valid(_aspect) or not _backend_ready:
		return ERR_UNCONFIGURED
	_aspect.show()
	return OK


func deactivate(_reason: StringName) -> void:
	if _aspect != null and is_instance_valid(_aspect):
		_aspect.hide()


func set_paused(paused: bool) -> int:
	if _backend == null or not _backend_ready:
		return ERR_UNCONFIGURED
	return _backend.set_paused(paused)


func is_paused() -> bool:
	return _backend != null and _backend.is_paused()


func get_stream_position() -> float:
	return _backend.get_stream_position() if _backend != null else 0.0


func get_debug_state() -> Dictionary:
	return _backend.get_debug_state() if _backend != null else {}


func get_output_texture() -> Texture2D:
	return _backend.get_video_texture() if _backend != null else null


func release() -> void:
	if _released:
		return
	set_process(false)
	if _backend != null:
		_backend.stop()
		_backend.release()
		_disconnect_backend()
	_backend = null
	if _aspect != null and is_instance_valid(_aspect):
		_aspect.queue_free()
	_aspect = null
	_host = null
	_backend_ready = false
	_natural_size = Vector2i.ZERO
	_duration_seconds = 0.0
	_audio_bus = &"Master"
	super.release()


func get_natural_size() -> Vector2i:
	return _natural_size


func _process(delta: float) -> void:
	if _backend == null or _backend_ready:
		set_process(false)
		return
	var size: Vector2i = _backend.get_natural_size()
	if size.x > 0 and size.y > 0:
		_on_backend_ready(size, _backend.get_duration_seconds())
		return
	_elapsed_seconds += delta
	if _elapsed_seconds >= FIRST_FRAME_TIMEOUT_SECONDS:
		set_process(false)
		failed.emit(_request_id, ERR_TIMEOUT, "视频首帧等待超时")


func _connect_backend() -> void:
	_backend.ready.connect(_on_backend_ready)
	_backend.failed.connect(_on_backend_failed)
	_backend.finished.connect(_on_backend_finished)


func _disconnect_backend() -> void:
	if _backend == null:
		return
	var ready_callable: Callable = Callable(self, "_on_backend_ready")
	var failed_callable: Callable = Callable(self, "_on_backend_failed")
	var finished_callable: Callable = Callable(self, "_on_backend_finished")
	if _backend.ready.is_connected(ready_callable):
		_backend.ready.disconnect(ready_callable)
	if _backend.failed.is_connected(failed_callable):
		_backend.failed.disconnect(failed_callable)
	if _backend.finished.is_connected(finished_callable):
		_backend.finished.disconnect(finished_callable)


func _on_backend_ready(natural_size: Vector2i, duration_seconds: float) -> void:
	if _released or natural_size.x <= 0 or natural_size.y <= 0:
		return
	_natural_size = natural_size
	_duration_seconds = duration_seconds
	_backend_ready = true
	if not _backend_loading:
		_commit_ready()


func _commit_ready() -> void:
	set_process(false)
	if _aspect == null or not is_instance_valid(_aspect):
		failed.emit(_request_id, ERR_UNCONFIGURED, "视频比例容器已释放")
		return
	_aspect.ratio = float(_natural_size.x) / float(_natural_size.y)
	prepared.emit(_request_id)


func _on_backend_failed(error: int, message: String) -> void:
	if not _released:
		failed.emit(_request_id, error, message)


func _on_backend_finished() -> void:
	if _released:
		return
	if not _backend_ready:
		failed.emit(_request_id, ERR_FILE_CORRUPT, "视频未取得首帧就已结束")
		return
	finished.emit(_request_id)
