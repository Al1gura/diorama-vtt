class_name PlayerOutputController
extends Node

signal output_requested(request_id: int, kind: int, content_id: String)
signal output_progressed(
	request_id: int,
	kind: int,
	content_id: String,
	progress: float,
	stage: StringName
)
signal output_ready(request_id: int, kind: int, content_id: String)
signal output_completed(request_id: int, kind: int, content_id: String)
signal output_changed(kind: int, content_id: String)
signal output_failed(request_id: int, content_id: String, error: int, message: String)
signal output_interrupted(request_id: int, content_id: String, reason: StringName)
signal output_cancelled(request_id: int, kind: int, content_id: String, reason: StringName)
signal output_released(request_id: int, kind: int, content_id: String)
signal video_finished(request_id: int, content_id: String)
signal video_playback_changed(phase: int)
signal video_volume_changed(volume_linear: float)

enum OutputKind {
	NONE,
	MAP,
	IMAGE,
	VIDEO,
	TEXT,
}

enum OutputPhase {
	IDLE,
	LOADING,
	READY,
	PLAYING,
	PAUSED,
	FAILED,
	RELEASING,
}

const DEFAULT_VIDEO_AUDIO_BUS: StringName = &"Media"
const MIN_AUDIBLE_VOLUME_LINEAR: float = 0.0001
const NATIVE_VIDEO_BACKEND_SCRIPT: Script = preload("res://scripts/native_video_playback_backend.gd")
var active_kind: OutputKind = OutputKind.NONE
var phase: OutputPhase = OutputPhase.IDLE
var active_content_id: String = ""
var active_request_id: int = 0
var active_presenter: PlayerOutputPresenter = null

var _cast_view: CastView = null
var _main_camera: Camera3D = null
var _los_service: Node = null
var _map_presenter: MapOutputPresenter = null
var _resolver: ExternalContentResolver = ExternalContentResolver.new()
var _module_dir_provider: Callable = Callable()
var _video_backend_factory: Callable = Callable()
var _video_audio_bus: StringName = DEFAULT_VIDEO_AUDIO_BUS
var _video_volume_linear: float = 1.0
var _lifecycle_trace: Array[String] = []


func configure(
		cast_view: CastView,
		main_camera: Camera3D,
		los_service: Node,
		module_dir_provider: Callable = Callable()
) -> void:
	_cast_view = cast_view
	_main_camera = main_camera
	_los_service = los_service
	_module_dir_provider = module_dir_provider
	if _cast_view != null:
		var close_callable: Callable = Callable(self, "_on_cast_close_requested")
		if not _cast_view.close_requested.is_connected(close_callable):
			_cast_view.close_requested.connect(close_callable)


func set_video_backend_factory(factory: Callable) -> void:
	_video_backend_factory = factory


func set_video_audio_bus(audio_bus: StringName) -> void:
	_video_audio_bus = audio_bus if audio_bus != &"" else DEFAULT_VIDEO_AUDIO_BUS


func set_video_volume_linear(volume_linear: float) -> int:
	_video_volume_linear = clampf(volume_linear, 0.0, 1.0)
	var bus_index: int = _ensure_video_audio_bus()
	AudioServer.set_bus_volume_linear(bus_index, _video_volume_linear)
	AudioServer.set_bus_mute(bus_index, _video_volume_linear <= MIN_AUDIBLE_VOLUME_LINEAR)
	video_volume_changed.emit(_video_volume_linear)
	return OK


func get_video_volume_linear() -> float:
	return _video_volume_linear


func pause_video() -> int:
	if active_kind != OutputKind.VIDEO or active_presenter == null:
		return ERR_UNCONFIGURED
	var presenter: VideoOutputPresenter = active_presenter as VideoOutputPresenter
	if presenter == null or phase != OutputPhase.PLAYING:
		return ERR_UNCONFIGURED
	var pause_error: int = presenter.set_paused(true)
	if pause_error == OK:
		phase = OutputPhase.PAUSED
		video_playback_changed.emit(phase)
	return pause_error


func resume_video() -> int:
	if active_kind != OutputKind.VIDEO or active_presenter == null:
		return ERR_UNCONFIGURED
	var presenter: VideoOutputPresenter = active_presenter as VideoOutputPresenter
	if presenter == null or phase != OutputPhase.PAUSED:
		return ERR_UNCONFIGURED
	var resume_error: int = presenter.set_paused(false)
	if resume_error == OK:
		phase = OutputPhase.PLAYING
		video_playback_changed.emit(phase)
	return resume_error


func stop_video() -> int:
	if active_kind != OutputKind.VIDEO:
		return ERR_UNCONFIGURED
	return return_to_map()


func get_video_debug_state() -> Dictionary:
	if active_kind != OutputKind.VIDEO or active_presenter == null:
		return {}
	var presenter: VideoOutputPresenter = active_presenter as VideoOutputPresenter
	return presenter.get_debug_state() if presenter != null else {}


func get_active_media_texture() -> Texture2D:
	if active_kind != OutputKind.IMAGE and active_kind != OutputKind.VIDEO:
		return null
	if active_presenter == null or not is_instance_valid(active_presenter):
		return null
	return active_presenter.get_output_texture()


func open_output() -> Dictionary:
	if _cast_view == null or not is_instance_valid(_cast_view):
		return _result(ERR_UNCONFIGURED, "投屏窗口壳未配置")
	var parent_node: Node = _cast_view.get_parent()
	var open_error: int = _cast_view.open(parent_node)
	if open_error != OK:
		return _result(open_error, "投屏原生窗口创建失败")
	_ensure_map_presenter()
	if _map_presenter == null:
		_cast_view.release_window()
		return _result(ERR_CANT_CREATE, "地图呈现器创建失败")
	_cast_view.show_map_surface()
	var map_error: int = _map_presenter.activate()
	if map_error != OK:
		active_kind = OutputKind.NONE
		phase = OutputPhase.FAILED
		return _result(map_error, "地图输出启动失败")
	active_kind = OutputKind.MAP
	phase = OutputPhase.IDLE
	active_content_id = ""
	active_presenter = _map_presenter
	output_changed.emit(active_kind, active_content_id)
	return _result(OK, "投屏已打开")


func show_map() -> int:
	var request_id: int = _allocate_request_id()
	var previous_request_id: int = active_request_id
	var previous_kind: OutputKind = active_kind
	var previous_content_id: String = active_content_id
	active_request_id = request_id
	output_requested.emit(request_id, OutputKind.MAP, "")
	output_progressed.emit(request_id, OutputKind.MAP, "", 0.0, &"requested")
	if previous_kind in [OutputKind.IMAGE, OutputKind.VIDEO, OutputKind.TEXT]:
		_emit_cancelled(
			previous_request_id,
			previous_kind,
			previous_content_id,
			&"return_to_map"
		)
		_release_media(
			previous_request_id,
			previous_kind,
			previous_content_id,
			&"return_to_map"
		)
	return _commit_map(request_id)


func show_image(content_ref: ExternalContentRef) -> int:
	return _show_media(OutputKind.IMAGE, content_ref)


func show_video(content_ref: ExternalContentRef) -> int:
	return _show_media(OutputKind.VIDEO, content_ref)


func show_text(item_id: String, title: String, text_content: String) -> int:
	var request_id: int = _allocate_request_id()
	var previous_request_id: int = active_request_id
	var previous_kind: OutputKind = active_kind
	var previous_content_id: String = active_content_id
	active_request_id = request_id
	active_kind = OutputKind.TEXT
	phase = OutputPhase.LOADING
	active_content_id = item_id
	output_requested.emit(request_id, OutputKind.TEXT, item_id)
	output_progressed.emit(request_id, OutputKind.TEXT, item_id, 0.0, &"requested")
	if previous_kind in [OutputKind.IMAGE, OutputKind.VIDEO, OutputKind.TEXT]:
		_emit_cancelled(previous_request_id, previous_kind, previous_content_id, &"superseded")
		_release_media(previous_request_id, previous_kind, previous_content_id)
	if not is_open():
		_fail_request(request_id, ERR_UNCONFIGURED, "投屏窗口尚未打开")
		return request_id
	if _map_presenter != null:
		_map_presenter.deactivate(&"media")
	_cast_view.show_media_surface()
	var presenter: TextOutputPresenter = TextOutputPresenter.new()
	presenter.name = "TextOutputPresenter"
	presenter.configure(_cast_view.get_presenter_host())
	presenter.add_to_group("gvtt_player_output_presenter")
	add_child(presenter)
	_connect_presenter(presenter)
	active_presenter = presenter
	output_progressed.emit(request_id, OutputKind.TEXT, item_id, 0.7, &"preparing")
	presenter.prepare(request_id, {"title": title, "text_content": text_content})
	return request_id


func return_to_map() -> int:
	return show_map()


func cancel_request(request_id: int, reason: StringName) -> bool:
	if request_id == 0 or request_id != active_request_id:
		return false
	if active_kind not in [OutputKind.IMAGE, OutputKind.VIDEO, OutputKind.TEXT]:
		return false
	var cancelled_kind: OutputKind = active_kind
	var cancelled_content_id: String = active_content_id
	_emit_cancelled(request_id, cancelled_kind, cancelled_content_id, reason)
	var map_request_id: int = _allocate_request_id()
	active_request_id = map_request_id
	_release_media(request_id, cancelled_kind, cancelled_content_id)
	output_requested.emit(map_request_id, OutputKind.MAP, "")
	output_progressed.emit(map_request_id, OutputKind.MAP, "", 0.0, &"requested")
	_commit_map(map_request_id)
	return true


func close_output() -> Dictionary:
	if _cast_view == null:
		return _result(ERR_UNCONFIGURED, "投屏窗口壳未配置")
	var closing_request_id: int = active_request_id
	var closing_kind: OutputKind = active_kind
	var closing_content_id: String = active_content_id
	active_request_id = _allocate_request_id()
	if closing_kind in [OutputKind.IMAGE, OutputKind.VIDEO, OutputKind.TEXT]:
		_emit_cancelled(
			closing_request_id,
			closing_kind,
			closing_content_id,
			&"close_output"
		)
		_release_media(closing_request_id, closing_kind, closing_content_id)
	if _map_presenter != null:
		_lifecycle_trace.append("release_map")
		_map_presenter.release()
		_map_presenter.queue_free()
		_map_presenter = null
	_lifecycle_trace.append("release_window")
	_cast_view.release_window()
	active_kind = OutputKind.NONE
	phase = OutputPhase.IDLE
	active_content_id = ""
	active_presenter = null
	output_changed.emit(active_kind, active_content_id)
	return _result(OK, "投屏已关闭")


func prepare_scene_switch() -> int:
	if _cast_view == null or not _cast_view.is_open():
		return 0
	if active_kind in [OutputKind.IMAGE, OutputKind.VIDEO, OutputKind.TEXT]:
		return show_map()
	return active_request_id


func is_open() -> bool:
	return _cast_view != null and _cast_view.is_open()


func get_lifecycle_trace() -> Array[String]:
	return _lifecycle_trace.duplicate()


func clear_lifecycle_trace() -> void:
	_lifecycle_trace.clear()


func _show_media(kind: OutputKind, content_ref: ExternalContentRef) -> int:
	var request_id: int = _allocate_request_id()
	var previous_request_id: int = active_request_id
	var previous_kind: OutputKind = active_kind
	var previous_content_id: String = active_content_id
	active_request_id = request_id
	active_kind = kind
	phase = OutputPhase.LOADING
	active_content_id = content_ref.content_id if content_ref != null else ""
	output_requested.emit(request_id, kind, active_content_id)
	output_progressed.emit(request_id, kind, active_content_id, 0.0, &"requested")
	if previous_kind in [OutputKind.IMAGE, OutputKind.VIDEO, OutputKind.TEXT]:
		_emit_cancelled(
			previous_request_id,
			previous_kind,
			previous_content_id,
			&"superseded"
		)
		_release_media(previous_request_id, previous_kind, previous_content_id)
	phase = OutputPhase.LOADING
	if not is_open():
		_fail_request(request_id, ERR_UNCONFIGURED, "投屏窗口尚未打开")
		return request_id
	var module_dir: String = _get_module_dir()
	var resolve_result: Dictionary = _resolver.resolve(content_ref, module_dir)
	var resolve_error: int = int(resolve_result.get("error", FAILED))
	if resolve_error != OK:
		_fail_request(request_id, resolve_error, String(resolve_result.get("message", "外部内容解析失败")))
		return request_id
	output_progressed.emit(request_id, kind, active_content_id, 0.35, &"resolved")
	if _map_presenter != null:
		_map_presenter.deactivate(&"media")
	_cast_view.show_media_surface()
	var presenter: PlayerOutputPresenter = _create_media_presenter(kind, resolve_result)
	if presenter == null:
		_fail_request(request_id, ERR_CANT_CREATE, "媒体呈现器创建失败")
		return request_id
	presenter.name = "ImageOutputPresenter" if kind == OutputKind.IMAGE else "VideoOutputPresenter"
	presenter.add_to_group("gvtt_player_output_presenter")
	add_child(presenter)
	_connect_presenter(presenter)
	active_presenter = presenter
	output_progressed.emit(request_id, kind, active_content_id, 0.7, &"preparing")
	presenter.prepare(request_id, resolve_result)
	return request_id


func _create_media_presenter(kind: OutputKind, resolved_content: Dictionary = {}) -> PlayerOutputPresenter:
	var host: Control = _cast_view.get_presenter_host()
	if kind == OutputKind.IMAGE:
		var image_presenter: ImageOutputPresenter = ImageOutputPresenter.new()
		image_presenter.configure(host)
		return image_presenter
	if kind == OutputKind.VIDEO:
		_ensure_video_audio_bus()
		var backend: VideoPlaybackBackend = _create_video_backend(
			String(resolved_content.get("resolved_path", ""))
		)
		if backend == null:
			return null
		var video_presenter: VideoOutputPresenter = VideoOutputPresenter.new()
		video_presenter.configure(host, backend, _video_audio_bus)
		return video_presenter
	return null


func _create_video_backend(resolved_path: String = "") -> VideoPlaybackBackend:
	if _video_backend_factory.is_valid():
		var backend_value: Variant = _video_backend_factory.call()
		return backend_value as VideoPlaybackBackend
	var extension: String = resolved_path.get_extension().to_lower()
	if extension == "ogv":
		return NativeOgvPlaybackBackend.new()
	if NATIVE_VIDEO_BACKEND_SCRIPT.SUPPORTED_EXTENSIONS.has(extension):
		return NATIVE_VIDEO_BACKEND_SCRIPT.new() as VideoPlaybackBackend
	return null


func _connect_presenter(presenter: PlayerOutputPresenter) -> void:
	presenter.prepared.connect(_on_presenter_prepared)
	presenter.failed.connect(_on_presenter_failed)
	presenter.finished.connect(_on_presenter_finished)


func _disconnect_presenter(presenter: PlayerOutputPresenter) -> void:
	var prepared_callable: Callable = Callable(self, "_on_presenter_prepared")
	var failed_callable: Callable = Callable(self, "_on_presenter_failed")
	var finished_callable: Callable = Callable(self, "_on_presenter_finished")
	if presenter.prepared.is_connected(prepared_callable):
		presenter.prepared.disconnect(prepared_callable)
	if presenter.failed.is_connected(failed_callable):
		presenter.failed.disconnect(failed_callable)
	if presenter.finished.is_connected(finished_callable):
		presenter.finished.disconnect(finished_callable)


func _on_presenter_prepared(request_id: int) -> void:
	if request_id != active_request_id or active_presenter == null:
		return
	var activate_error: int = active_presenter.activate()
	if activate_error != OK:
		_fail_request(request_id, activate_error, "媒体呈现器启用失败")
		return
	phase = OutputPhase.READY
	output_progressed.emit(request_id, active_kind, active_content_id, 1.0, &"ready")
	output_ready.emit(request_id, active_kind, active_content_id)
	output_completed.emit(request_id, active_kind, active_content_id)
	output_changed.emit(active_kind, active_content_id)
	if active_kind == OutputKind.VIDEO:
		phase = OutputPhase.PLAYING
		video_playback_changed.emit(phase)


func _on_presenter_failed(request_id: int, error: int, message: String) -> void:
	if request_id != active_request_id:
		return
	_fail_request(request_id, error, message)


func _on_presenter_finished(request_id: int) -> void:
	if request_id != active_request_id or active_kind != OutputKind.VIDEO:
		return
	var finished_content_id: String = active_content_id
	video_finished.emit(request_id, finished_content_id)
	var map_request_id: int = _allocate_request_id()
	active_request_id = map_request_id
	_release_media(request_id, OutputKind.VIDEO, finished_content_id)
	output_requested.emit(map_request_id, OutputKind.MAP, "")
	output_progressed.emit(map_request_id, OutputKind.MAP, "", 0.0, &"requested")
	_commit_map(map_request_id)


func _fail_request(request_id: int, error: int, message: String) -> void:
	if request_id != active_request_id:
		return
	phase = OutputPhase.FAILED
	var failed_kind: OutputKind = active_kind
	var failed_content_id: String = active_content_id
	output_failed.emit(request_id, failed_content_id, error, message)
	var map_request_id: int = _allocate_request_id()
	active_request_id = map_request_id
	if active_presenter != null and active_presenter != _map_presenter:
		_release_media(request_id, failed_kind, failed_content_id)
	output_requested.emit(map_request_id, OutputKind.MAP, "")
	output_progressed.emit(map_request_id, OutputKind.MAP, "", 0.0, &"requested")
	_commit_map(map_request_id)


func _release_media(
		request_id: int,
		kind: OutputKind,
		content_id: String,
		reason: StringName = &"release"
) -> void:
	var presenter: PlayerOutputPresenter = active_presenter
	if presenter == null or presenter == _map_presenter:
		return
	phase = OutputPhase.RELEASING
	_lifecycle_trace.append("release_media")
	presenter.deactivate(reason)
	presenter.release()
	_disconnect_presenter(presenter)
	presenter.queue_free()
	if kind == OutputKind.VIDEO:
		_silence_video_audio_bus()
		video_playback_changed.emit(OutputPhase.IDLE)
	if active_presenter == presenter:
		active_presenter = null
	output_released.emit(request_id, kind, content_id)


func _commit_map(request_id: int) -> int:
	if not is_open():
		active_kind = OutputKind.NONE
		phase = OutputPhase.IDLE
		active_content_id = ""
		active_presenter = null
		return request_id
	_ensure_map_presenter()
	_cast_view.show_map_surface()
	_lifecycle_trace.append("restore_map")
	var map_error: int = _map_presenter.activate() if _map_presenter != null else ERR_CANT_CREATE
	if map_error != OK:
		active_kind = OutputKind.MAP
		phase = OutputPhase.FAILED
		active_content_id = ""
		active_presenter = null
		output_failed.emit(request_id, "", map_error, "地图输出恢复失败")
		return request_id
	active_kind = OutputKind.MAP
	phase = OutputPhase.IDLE
	active_content_id = ""
	active_presenter = _map_presenter
	output_progressed.emit(request_id, active_kind, active_content_id, 1.0, &"ready")
	output_ready.emit(request_id, active_kind, active_content_id)
	output_completed.emit(request_id, active_kind, active_content_id)
	output_changed.emit(active_kind, active_content_id)
	return request_id


func _ensure_video_audio_bus() -> int:
	var bus_index: int = AudioServer.get_bus_index(_video_audio_bus)
	if bus_index < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, String(_video_audio_bus))
		AudioServer.set_bus_send(bus_index, &"Master")
	AudioServer.set_bus_volume_linear(bus_index, _video_volume_linear)
	AudioServer.set_bus_mute(bus_index, _video_volume_linear <= MIN_AUDIBLE_VOLUME_LINEAR)
	return bus_index


func _silence_video_audio_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index(_video_audio_bus)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, true)


func _ensure_map_presenter() -> void:
	if _map_presenter != null and is_instance_valid(_map_presenter):
		return
	_map_presenter = MapOutputPresenter.new()
	_map_presenter.name = "MapOutputPresenter"
	add_child(_map_presenter)
	_map_presenter.configure(_cast_view, _main_camera, _los_service)


func _get_module_dir() -> String:
	if _module_dir_provider.is_valid():
		return String(_module_dir_provider.call())
	return ModuleGate.current_module_dir()


func _allocate_request_id() -> int:
	return active_request_id + 1


func _emit_cancelled(
		request_id: int,
		kind: OutputKind,
		content_id: String,
		reason: StringName
) -> void:
	output_interrupted.emit(request_id, content_id, reason)
	output_cancelled.emit(request_id, kind, content_id, reason)


func _on_cast_close_requested() -> void:
	close_output()


func _result(error: int, message: String) -> Dictionary:
	return {
		"error": error,
		"message": message,
		"active_kind": active_kind,
		"phase": phase,
		"request_id": active_request_id,
	}
