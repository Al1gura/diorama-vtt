extends Node

const TEMP_DIR: String = "user://p3_3_player_output_fixture"
const IMAGE_ID: String = "11111111111111111111111111111111"
const VIDEO_ID: String = "22222222222222222222222222222222"
const MISSING_ID: String = "33333333333333333333333333333333"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _controller: PlayerOutputController = null
var _cast_view: CastView = null
var _camera: Camera3D = null
var _queued_backends: Array[FakeVideoPlaybackBackend] = []


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_fixture()
	_create_fixture()
	_test_external_content_resolution()
	await _test_output_state_and_concurrency()
	_cleanup_fixture()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P3_3_PLAYER_OUTPUT_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_3_PLAYER_OUTPUT_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_external_content_resolution() -> void:
	var resolver: ExternalContentResolver = ExternalContentResolver.new()
	var external_ref: ExternalContentRef = _image_ref(
		ProjectSettings.globalize_path(TEMP_DIR.path_join("test.png")),
		ExternalContentRef.SourceKind.EXTERNAL_FILE
	)
	var external_result: Dictionary = resolver.resolve(external_ref, TEMP_DIR)
	_check(int(external_result.get("error", FAILED)) == OK, "Absolute external image did not resolve")
	_check(external_ref.available, "Resolved external image was not marked available")
	_check(external_ref.resolved_path.is_absolute_path(), "Resolved external image path is not absolute")

	var relative_ref: ExternalContentRef = _image_ref(
		"content/test.png",
		ExternalContentRef.SourceKind.MODULE_RELATIVE
	)
	var relative_result: Dictionary = resolver.resolve(relative_ref, TEMP_DIR)
	_check(int(relative_result.get("error", FAILED)) == OK, "Module-relative image did not resolve")
	_check(relative_ref.resolved_path.is_absolute_path(), "Module-relative result is not absolute")

	var escape_ref: ExternalContentRef = _image_ref(
		"../outside.png",
		ExternalContentRef.SourceKind.MODULE_RELATIVE
	)
	var escape_result: Dictionary = resolver.resolve(escape_ref, TEMP_DIR)
	_check(int(escape_result.get("error", OK)) == ERR_INVALID_DATA, "Parent path escape was accepted")
	_check(escape_ref.resolved_path == "", "Rejected escape retained a resolved path")

	var missing_ref: ExternalContentRef = _image_ref(
		"content/missing.png",
		ExternalContentRef.SourceKind.MODULE_RELATIVE
	)
	missing_ref.content_id = MISSING_ID
	var original_source: String = missing_ref.source_path
	var missing_result: Dictionary = resolver.resolve(missing_ref, TEMP_DIR)
	_check(int(missing_result.get("error", OK)) == ERR_FILE_NOT_FOUND, "Missing file was not reported")
	_check(not missing_ref.available, "Missing reference was marked available")
	_check(missing_ref.source_path == original_source, "Missing reference source was modified")
	var json_entry: Dictionary = missing_ref.to_json_dict()
	_check(String(json_entry.get("content_type", "")) == "image", "Content enum did not serialize as image")
	_check(String(json_entry.get("source_kind", "")) == "module_relative", "Source enum did not serialize as module_relative")
	_check(not json_entry.has("resolved_path") and not json_entry.has("available"), "Runtime fields leaked into manifest JSON")


func _test_output_state_and_concurrency() -> void:
	_cast_view = CastView.new()
	_cast_view.name = "CastView"
	add_child(_cast_view)
	_camera = Camera3D.new()
	_camera.name = "MainCamera"
	add_child(_camera)
	_controller = PlayerOutputController.new()
	_controller.name = "PlayerOutputController"
	add_child(_controller)
	_controller.configure(_cast_view, _camera, null, Callable(self, "_fixture_module_dir"))
	_controller.set_video_backend_factory(Callable(self, "_create_fake_backend"))
	var open_result: Dictionary = _controller.open_output()
	_check(int(open_result.get("error", FAILED)) == OK, "Player output did not open")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Open output did not settle on MAP")
	_check(_controller.phase == PlayerOutputController.OutputPhase.IDLE, "MAP did not settle in IDLE")
	_check(_cast_view.get_cast_window().get_node_or_null("PlayerOutputCanvas") != null, "Cast window lacks media canvas")
	_check(_cast_view.get_cast_window().get_node_or_null("PlayerOutputController") == null, "GM controller leaked into player window")

	var image_request: int = _controller.show_image(_image_ref("content/test.png", ExternalContentRef.SourceKind.MODULE_RELATIVE))
	_check(image_request == 1, "First output request ID is not 1")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.IMAGE, "Image request did not become active")
	_check(_controller.phase == PlayerOutputController.OutputPhase.READY, "Image request did not become READY")
	_check(_controller.active_presenter.get_natural_size() == Vector2i(64, 32), "Image natural size is wrong")

	var first_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.READY_IMMEDIATELY)
	var video_request: int = _controller.show_video(_video_ref())
	_check(video_request == image_request + 1, "Video request ID did not strictly increase")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.VIDEO, "Video request did not become active")
	_check(_controller.phase == PlayerOutputController.OutputPhase.PLAYING, "Ready video did not enter PLAYING")

	var replacement_request: int = _controller.show_image(_image_ref("content/test.png", ExternalContentRef.SourceKind.MODULE_RELATIVE))
	_check(replacement_request == video_request + 1, "Replacement request ID did not strictly increase")
	_check(first_backend.call_log == ["load_file", "play", "stop", "clear_stream", "disconnect_signals", "release_backend"], "Video cleanup order is wrong: %s" % [first_backend.call_log])

	var delayed_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.WAIT_FOR_TEST)
	var delayed_request: int = _controller.show_video(_video_ref())
	_check(_controller.phase == PlayerOutputController.OutputPhase.LOADING, "Delayed video did not remain LOADING")
	var final_image_request: int = _controller.show_image(_image_ref("content/test.png", ExternalContentRef.SourceKind.MODULE_RELATIVE))
	delayed_backend.complete_ready()
	await get_tree().process_frame
	_check(final_image_request == delayed_request + 1, "Fast replacement request ID did not increase")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.IMAGE, "Stale video callback replaced final image")
	_check(_controller.active_request_id == final_image_request, "Stale callback changed active request ID")

	var failing_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.FAIL_IMMEDIATELY)
	var failed_request: int = _controller.show_video(_video_ref())
	await get_tree().process_frame
	_check(failed_request < _controller.active_request_id, "Failure did not allocate a MAP recovery request")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Video failure did not recover to MAP")
	_check(_controller.phase == PlayerOutputController.OutputPhase.IDLE, "Video failure MAP recovery is not IDLE")
	_check(failing_backend.call_log.has("release_backend"), "Failed video backend was not released")

	var early_finish_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.WAIT_FOR_TEST)
	var early_finish_request: int = _controller.show_video(_video_ref())
	early_finish_backend.complete_finished()
	await get_tree().process_frame
	_check(early_finish_request < _controller.active_request_id, "Early finish did not allocate a MAP recovery request")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Video ending before first frame did not fail to MAP")

	var finishing_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.READY_IMMEDIATELY)
	var finishing_request: int = _controller.show_video(_video_ref())
	finishing_backend.complete_finished()
	await get_tree().process_frame
	_check(_controller.active_request_id == finishing_request + 1, "Natural finish did not allocate MAP request")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Natural finish did not return to MAP")

	_new_backend(FakeVideoPlaybackBackend.LoadBehavior.READY_IMMEDIATELY)
	_controller.show_video(_video_ref())
	var scene_switch_request: int = _controller.prepare_scene_switch()
	_check(scene_switch_request == _controller.active_request_id, "Scene switch did not complete its MAP request")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Scene switch did not return to MAP")
	_check(_controller.is_open(), "Scene switch closed the cast window")

	_new_backend(FakeVideoPlaybackBackend.LoadBehavior.READY_IMMEDIATELY)
	_controller.show_video(_video_ref())
	_controller.clear_lifecycle_trace()
	var closing_window: Window = _cast_view.get_cast_window()
	var close_result: Dictionary = _controller.close_output()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(int(close_result.get("error", FAILED)) == OK, "Close output failed")
	_check(_controller.get_lifecycle_trace() == ["release_media", "release_map", "release_window"], "Close cleanup order is wrong")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.NONE, "Close output did not settle on NONE")
	_check(not _controller.is_open(), "Close output left native window open")
	_check(closing_window == null or not is_instance_valid(closing_window), "Native player window was not finally released")


func _new_backend(behavior: FakeVideoPlaybackBackend.LoadBehavior) -> FakeVideoPlaybackBackend:
	var backend: FakeVideoPlaybackBackend = FakeVideoPlaybackBackend.new()
	backend.load_behavior = behavior
	_queued_backends.append(backend)
	return backend


func _create_fake_backend() -> VideoPlaybackBackend:
	if _queued_backends.is_empty():
		var default_backend: FakeVideoPlaybackBackend = FakeVideoPlaybackBackend.new()
		return default_backend
	return _queued_backends.pop_front()


func _fixture_module_dir() -> String:
	return TEMP_DIR


func _image_ref(path: String, source_kind: ExternalContentRef.SourceKind) -> ExternalContentRef:
	var content: ExternalContentRef = ExternalContentRef.new()
	content.content_id = IMAGE_ID
	content.content_type = ExternalContentRef.ContentType.IMAGE
	content.display_name = "测试图片"
	content.source_kind = source_kind
	content.source_path = path
	return content


func _video_ref() -> ExternalContentRef:
	var content: ExternalContentRef = ExternalContentRef.new()
	content.content_id = VIDEO_ID
	content.content_type = ExternalContentRef.ContentType.VIDEO
	content.display_name = "测试视频"
	content.source_kind = ExternalContentRef.SourceKind.MODULE_RELATIVE
	content.source_path = "content/test.ogv"
	return content


func _create_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR.path_join("content"))
	var image: Image = Image.create(64, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.85, 0.15, 0.25, 1.0))
	image.save_png(TEMP_DIR.path_join("test.png"))
	image.save_png(TEMP_DIR.path_join("content/test.png"))
	var file: FileAccess = FileAccess.open(TEMP_DIR.path_join("content/test.ogv"), FileAccess.WRITE)
	if file != null:
		file.store_string("fake ogv for injected backend")
		file.close()


func _cleanup_fixture() -> void:
	_remove_dir_recursive(TEMP_DIR)


func _remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory_name: String in DirAccess.get_directories_at(path):
		_remove_dir_recursive(path.path_join(directory_name))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
