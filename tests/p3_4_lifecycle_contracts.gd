extends Node

const WAIT_TIMEOUT_MS: int = 3000
const IMAGE_SHA256: String = "6cad696fde8ff9f226297d8637a3af20dea4787b4aeee28ea81d17c5c0e1a14b"
const VIDEO_SHA256: String = "3a14a04c0cdf193458fbfe38ccbe2b8add016b197dd6880991b1d0aefcec6142"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _fixture: Dictionary = {}
var _controller: PlayerOutputController = null
var _cast_view: CastView = null
var _camera: Camera3D = null
var _queued_backends: Array[FakeVideoPlaybackBackend] = []
var _requested_events: Array[Dictionary] = []
var _progress_events: Array[Dictionary] = []
var _completed_events: Array[Dictionary] = []
var _failed_events: Array[Dictionary] = []
var _cancelled_events: Array[Dictionary] = []
var _released_events: Array[Dictionary] = []


func _ready() -> void:
	await _wait_process_frames(1, WAIT_TIMEOUT_MS, "Lifecycle test startup frame timed out")
	P3_4FixtureFactory.cleanup()
	_fixture = P3_4FixtureFactory.create()
	_check(int(_fixture.get("error", FAILED)) == OK, String(_fixture.get("message", "夹具创建失败")))
	if int(_fixture.get("error", FAILED)) == OK:
		_test_fixture_and_reopen()
		_test_reference_failures()
		await _test_lifecycle_events_and_replacement()
	await _cleanup_runtime()
	P3_4FixtureFactory.cleanup()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
		"image_sha256": FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_IMAGE_PATH),
		"video_sha256": FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_VIDEO_PATH),
	}
	print("P3_4_LIFECYCLE_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_4_LIFECYCLE_FAILURES " + JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_fixture_and_reopen() -> void:
	var module_dir: String = String(_fixture.get("module_dir", ""))
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	_check(manifest != null, "Fixture manifest is missing")
	if manifest == null:
		return
	_check(manifest.locations.size() == 2, "Fixture manifest does not contain two locations")
	_check(manifest.external_contents.size() == 6, "Fixture manifest does not contain six media references")
	_check(FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_IMAGE_PATH) == IMAGE_SHA256, "Fixture PNG hash changed")
	_check(FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_VIDEO_PATH) == VIDEO_SHA256, "Fixture OGV hash changed")
	_check(
		FileAccess.file_exists(module_dir.path_join("invalid_cases/path_escape_manifest.json")),
		"Path-escape manifest copy is missing"
	)
	_check(
		FileAccess.file_exists(module_dir.path_join("invalid_cases/future_schema_manifest.json")),
		"Future-schema manifest copy is missing"
	)
	var session_id: String = String(_fixture.get("session_id", ""))
	ModuleGate.close_module()
	var reopen_error: int = ModuleGate.open_module(P3_4FixtureFactory.MODULE_NAME)
	_check(reopen_error == OK, "Fixture module did not reopen")
	manifest = ModuleGate.current_manifest()
	_check(manifest != null and manifest.locations.size() == 2, "Reopened fixture lost locations")
	var session_result: Dictionary = ModuleGate.open_playthrough(session_id)
	var session: Playthrough = session_result.get("value") as Playthrough
	_check(int(session_result.get("error", FAILED)) == OK, "Fixture playthrough did not reopen")
	_check(session != null and session.notes.contains("wall_open"), "Recoverable playthrough change was lost")
	if session == null:
		return
	var first_location_id: String = String(_fixture.get("first_location_id", ""))
	_check(session.location_states.has(first_location_id), "Reopened playthrough lost its location snapshot")
	var session_dir: String = module_dir.path_join(ModuleIo.SESSIONS_DIR_NAME).path_join(session_id)
	var snapshot_result: Dictionary = ModuleIo.load_session_snapshot_recoverable(
		session_dir,
		first_location_id
	)
	var snapshot_root: Node = snapshot_result.get("value") as Node
	_check(int(snapshot_result.get("error", FAILED)) == OK, "Recoverable location snapshot did not load")
	_check(
		snapshot_root != null and String(snapshot_root.get_meta("p3_4_recoverable_change", "")) == "wall_open",
		"Recovered snapshot lost its runtime change marker"
	)
	if snapshot_root != null:
		var marker: Node3D = snapshot_root.get_node_or_null("LifecycleMarker") as Node3D
		_check(marker != null and marker.position == Vector3(9.0, 0.0, 4.0), "Recovered snapshot marker is wrong")
		snapshot_root.free()


func _test_reference_failures() -> void:
	var resolver: ExternalContentResolver = ExternalContentResolver.new()
	var module_dir: String = String(_fixture.get("module_dir", ""))
	var valid_image: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	var valid_video: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	var missing_image: ExternalContentRef = _fixture.get("missing_image_ref") as ExternalContentRef
	var missing_video: ExternalContentRef = _fixture.get("missing_video_ref") as ExternalContentRef
	var corrupt_image: ExternalContentRef = _fixture.get("corrupt_image_ref") as ExternalContentRef
	var fake_video: ExternalContentRef = _fixture.get("fake_video_ref") as ExternalContentRef
	var escape_ref: ExternalContentRef = _fixture.get("escape_ref") as ExternalContentRef
	_check(int(resolver.resolve(valid_image, module_dir).get("error", FAILED)) == OK, "Valid image reference did not resolve")
	_check(int(resolver.resolve(valid_video, module_dir).get("error", FAILED)) == OK, "Valid video reference did not resolve")
	_check(
		int(resolver.resolve(missing_image, module_dir).get("error", OK)) == ERR_FILE_NOT_FOUND,
		"Missing image reference was not reported"
	)
	_check(
		int(resolver.resolve(missing_video, module_dir).get("error", OK)) == ERR_FILE_NOT_FOUND,
		"Missing video reference was not reported"
	)
	_check(int(resolver.resolve(corrupt_image, module_dir).get("error", FAILED)) == OK, "Existing corrupt image path did not resolve")
	_check(int(resolver.resolve(fake_video, module_dir).get("error", FAILED)) == OK, "Existing fake OGV path did not resolve")
	_check(
		int(resolver.resolve(escape_ref, module_dir).get("error", OK)) == ERR_INVALID_DATA,
		"Parent path escape was accepted"
	)


func _test_lifecycle_events_and_replacement() -> void:
	_setup_output_controller()
	var open_result: Dictionary = _controller.open_output()
	_check(int(open_result.get("error", FAILED)) == OK, "Lifecycle output did not open")
	var image_ref: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	var corrupt_ref: ExternalContentRef = _fixture.get("corrupt_image_ref") as ExternalContentRef
	var missing_ref: ExternalContentRef = _fixture.get("missing_image_ref") as ExternalContentRef
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef

	var image_request: int = _controller.show_image(image_ref)
	_check(_controller.phase == PlayerOutputController.OutputPhase.READY, "Valid image did not reach READY")
	_check(_has_event(_requested_events, image_request), "Image request event is missing")
	_check(_has_progress(image_request, 0.0, &"requested"), "Image requested progress is missing")
	_check(_has_progress(image_request, 0.35, &"resolved"), "Image resolved progress is missing")
	_check(_has_progress(image_request, 0.7, &"preparing"), "Image preparing progress is missing")
	_check(_has_progress(image_request, 1.0, &"ready"), "Image ready progress is missing")
	_check(_has_event(_completed_events, image_request), "Image completion event is missing")

	var corrupt_request: int = _controller.show_image(corrupt_ref)
	_check(_has_event(_failed_events, corrupt_request), "Corrupt image failure event is missing")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Corrupt image did not recover to MAP")
	var missing_request: int = _controller.show_image(missing_ref)
	_check(_has_event(_failed_events, missing_request), "Missing image failure event is missing")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Missing image did not recover to MAP")

	var cancel_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.WAIT_FOR_TEST)
	var cancel_request_id: int = _controller.show_video(video_ref)
	_check(_controller.phase == PlayerOutputController.OutputPhase.LOADING, "Delayed video did not remain LOADING")
	var cancel_result: bool = _controller.cancel_request(cancel_request_id, &"test_cancel")
	_check(cancel_result, "Active video request could not be cancelled")
	_check(_has_event(_cancelled_events, cancel_request_id), "Explicit cancellation event is missing")
	_check(_has_event(_released_events, cancel_request_id), "Cancelled video release event is missing")
	_check(bool(cancel_backend.get_debug_state().get("released", false)), "Cancelled fake backend was not released")
	cancel_backend.complete_ready()
	cancel_backend.complete_failed()
	cancel_backend.complete_finished()
	await _wait_process_frames(2, WAIT_TIMEOUT_MS, "Stale cancelled callbacks were not processed")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Stale cancelled callback changed MAP output")

	var stale_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.WAIT_FOR_TEST)
	var stale_request: int = _controller.show_video(video_ref)
	var final_image_request: int = _controller.show_image(image_ref)
	stale_backend.complete_ready()
	stale_backend.complete_failed()
	stale_backend.complete_finished()
	await _wait_process_frames(2, WAIT_TIMEOUT_MS, "Stale replacement callbacks were not processed")
	_check(final_image_request == stale_request + 1, "Replacement request ID did not strictly increase")
	_check(_controller.active_request_id == final_image_request, "Stale callback changed the active request ID")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.IMAGE, "Stale callback replaced the final image")

	for round_index: int in range(10):
		_controller.show_image(image_ref)
		_new_backend(FakeVideoPlaybackBackend.LoadBehavior.READY_IMMEDIATELY)
		_controller.show_video(video_ref)
		_check(
			_controller.active_kind == PlayerOutputController.OutputKind.VIDEO,
			"Ten-round switch failed on video round %d" % round_index
		)
	_controller.show_map()
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		WAIT_TIMEOUT_MS,
		"Media nodes did not return to baseline after ten rounds"
	)
	_check(_media_nodes_at_baseline(), "Presenter/player/texture nodes remain after ten rounds")

	var closing_backend: FakeVideoPlaybackBackend = _new_backend(FakeVideoPlaybackBackend.LoadBehavior.READY_IMMEDIATELY)
	_controller.show_video(video_ref)
	_controller.clear_lifecycle_trace()
	var closing_window: Window = _cast_view.get_cast_window()
	var first_close: Dictionary = _controller.close_output()
	var second_close: Dictionary = _controller.close_output()
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		WAIT_TIMEOUT_MS,
		"Media nodes did not release after closing output"
	)
	await _wait_process_frames(2, WAIT_TIMEOUT_MS, "Native window release did not settle")
	_check(int(first_close.get("error", FAILED)) == OK, "First close_output failed")
	_check(int(second_close.get("error", FAILED)) == OK, "Idempotent close_output failed")
	_check(closing_backend.call_log.count("release_backend") == 1, "Backend release was not idempotent")
	_check(not bool(closing_backend.get_debug_state().get("has_stream", true)), "Closed backend retained its stream")
	_check(
		not bool(closing_backend.get_debug_state().get("finished_signal_connected", true)),
		"Closed backend retained its finished signal"
	)
	_check(
		_controller.get_lifecycle_trace().slice(0, 3) == ["release_media", "release_map", "release_window"],
		"Native window was not released last"
	)
	_check(closing_window == null or not is_instance_valid(closing_window), "Native window survived close_output")
	var reopen_result: Dictionary = _controller.open_output()
	_check(int(reopen_result.get("error", FAILED)) == OK, "Player output did not reopen after close")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Reopened output did not settle on MAP")


func _setup_output_controller() -> void:
	_cast_view = CastView.new()
	_cast_view.name = "P3_4CastView"
	add_child(_cast_view)
	_camera = Camera3D.new()
	_camera.name = "P3_4Camera"
	add_child(_camera)
	_controller = PlayerOutputController.new()
	_controller.name = "P3_4PlayerOutputController"
	add_child(_controller)
	_controller.configure(
		_cast_view,
		_camera,
		null,
		Callable(self, "_fixture_module_dir")
	)
	_controller.set_video_backend_factory(Callable(self, "_create_fake_backend"))
	_controller.output_requested.connect(_on_output_requested)
	_controller.output_progressed.connect(_on_output_progressed)
	_controller.output_completed.connect(_on_output_completed)
	_controller.output_failed.connect(_on_output_failed)
	_controller.output_cancelled.connect(_on_output_cancelled)
	_controller.output_released.connect(_on_output_released)


func _new_backend(behavior: FakeVideoPlaybackBackend.LoadBehavior) -> FakeVideoPlaybackBackend:
	var backend: FakeVideoPlaybackBackend = FakeVideoPlaybackBackend.new()
	backend.load_behavior = behavior
	_queued_backends.append(backend)
	return backend


func _create_fake_backend() -> VideoPlaybackBackend:
	if _queued_backends.is_empty():
		return FakeVideoPlaybackBackend.new()
	return _queued_backends.pop_front()


func _fixture_module_dir() -> String:
	return String(_fixture.get("module_dir", ""))


func _on_output_requested(request_id: int, kind: int, content_id: String) -> void:
	_requested_events.append({"request_id": request_id, "kind": kind, "content_id": content_id})


func _on_output_progressed(
		request_id: int,
		kind: int,
		content_id: String,
		progress: float,
		stage: StringName
) -> void:
	_progress_events.append({
		"request_id": request_id,
		"kind": kind,
		"content_id": content_id,
		"progress": progress,
		"stage": stage,
	})


func _on_output_completed(request_id: int, kind: int, content_id: String) -> void:
	_completed_events.append({"request_id": request_id, "kind": kind, "content_id": content_id})


func _on_output_failed(request_id: int, content_id: String, error: int, message: String) -> void:
	_failed_events.append({
		"request_id": request_id,
		"content_id": content_id,
		"error": error,
		"message": message,
	})


func _on_output_cancelled(
		request_id: int,
		kind: int,
		content_id: String,
		reason: StringName
) -> void:
	_cancelled_events.append({
		"request_id": request_id,
		"kind": kind,
		"content_id": content_id,
		"reason": reason,
	})


func _on_output_released(request_id: int, kind: int, content_id: String) -> void:
	_released_events.append({"request_id": request_id, "kind": kind, "content_id": content_id})


func _has_event(events: Array[Dictionary], request_id: int) -> bool:
	for event: Dictionary in events:
		if int(event.get("request_id", 0)) == request_id:
			return true
	return false


func _has_progress(request_id: int, progress: float, stage: StringName) -> bool:
	for event: Dictionary in _progress_events:
		if (
			int(event.get("request_id", 0)) == request_id
			and is_equal_approx(float(event.get("progress", -1.0)), progress)
			and StringName(event.get("stage", &"")) == stage
		):
			return true
	return false


func _media_nodes_at_baseline() -> bool:
	return (
		get_tree().get_nodes_in_group("gvtt_player_output_presenter").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_player").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_texture").is_empty()
	)


func _wait_until(predicate: Callable, timeout_ms: int, failure_message: String) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline_ms:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	_check(false, failure_message)
	return false


func _wait_process_frames(frame_count: int, timeout_ms: int, failure_message: String) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	var remaining_frames: int = frame_count
	while remaining_frames > 0 and Time.get_ticks_msec() <= deadline_ms:
		await get_tree().process_frame
		remaining_frames -= 1
	if remaining_frames > 0:
		_check(false, failure_message)
		return false
	return true


func _cleanup_runtime() -> void:
	if _controller != null and is_instance_valid(_controller):
		_controller.close_output()
		_controller.queue_free()
	if _cast_view != null and is_instance_valid(_cast_view):
		_cast_view.queue_free()
	if _camera != null and is_instance_valid(_camera):
		_camera.queue_free()
	await _wait_process_frames(2, WAIT_TIMEOUT_MS, "Lifecycle test runtime cleanup timed out")
	_controller = null
	_cast_view = null
	_camera = null


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
