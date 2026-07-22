extends Node3D

const DRAW_TIMEOUT_MS: int = 5000
const VIDEO_READY_TIMEOUT_MS: int = 5000
const VIDEO_FINISH_TIMEOUT_MS: int = 12000
const RELEASE_TIMEOUT_MS: int = 3000
const TEST_BUS_NAME: StringName = &"P3_4_TEST_MEDIA"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _fixture: Dictionary = {}
var _camera: Camera3D = null
var _map_quad: MeshInstance3D = null
var _cast_view: CastView = null
var _controller: PlayerOutputController = null
var _native_backends: Array[NativeOgvPlaybackBackend] = []
var _failed_request_ids: Array[int] = []
var _frame_post_draw_received: bool = false
var _max_audio_peak_db: float = -200.0
var _observed_video_duration: float = 0.0


func _ready() -> void:
	await _wait_process_frames(1, DRAW_TIMEOUT_MS, "Visible smoke startup frame timed out")
	_check(DisplayServer.get_name() != "headless", "Visible smoke was started with the headless display server")
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	P3_4FixtureFactory.cleanup()
	_fixture = P3_4FixtureFactory.create()
	_check(int(_fixture.get("error", FAILED)) == OK, String(_fixture.get("message", "夹具创建失败")))
	if int(_fixture.get("error", FAILED)) == OK:
		_setup_map_world()
		_setup_output()
		_create_test_audio_bus()
		await _test_visible_map_image_video_map()
		await _test_native_failure_and_repeated_switches()
		await _test_scene_close_and_exit_cleanup()
	await _cleanup()
	_finish()


func _test_visible_map_image_video_map() -> void:
	var frames_before_open: int = Engine.get_frames_drawn()
	var open_result: Dictionary = _controller.open_output()
	_check(int(open_result.get("error", FAILED)) == OK, "Visible player output did not open")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "MAP did not produce frame_post_draw")
	_check(Engine.get_frames_drawn() > frames_before_open, "Visible rendering did not increase Engine.get_frames_drawn()")
	var map_image: Image = _capture_cast_image()
	_check(map_image != null and not map_image.is_empty(), "MAP capture is empty")
	if map_image != null and not map_image.is_empty():
		var map_center: Color = map_image.get_pixel(map_image.get_width() / 2, map_image.get_height() / 2)
		_check(map_center.g > 0.35 and map_center.b > 0.35, "MAP center pixel does not contain the fixture map")

	var image_ref: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	await _resize_cast(Vector2i(1280, 720))
	_controller.show_image(image_ref)
	_check(_controller.phase == PlayerOutputController.OutputPhase.READY, "Visible image did not reach READY")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "1280x720 image did not draw")
	var wide_image: Image = _capture_cast_image()
	_check(wide_image != null and wide_image.get_size() == Vector2i(1280, 720), "1280x720 image capture size is wrong")
	if wide_image != null and wide_image.get_size() == Vector2i(1280, 720):
		_check(_is_black(wide_image.get_pixel(40, 360)), "4:3 image lacks the left black bar at 1280x720")
		_check(_is_black(wide_image.get_pixel(1240, 360)), "4:3 image lacks the right black bar at 1280x720")
		_check(_is_red(wide_image.get_pixel(240, 120)), "Image top-left quadrant is not red")
		_check(_is_green(wide_image.get_pixel(1040, 120)), "Image top-right quadrant is not green")
		_check(_is_blue(wide_image.get_pixel(240, 600)), "Image bottom-left quadrant is not blue")
		_check(_is_yellow(wide_image.get_pixel(1040, 600)), "Image bottom-right quadrant is not yellow")

	await _resize_cast(Vector2i(1024, 768))
	await _wait_for_draw(DRAW_TIMEOUT_MS, "1024x768 image did not draw")
	var standard_image: Image = _capture_cast_image()
	_check(standard_image != null and standard_image.get_size() == Vector2i(1024, 768), "1024x768 image capture size is wrong")
	if standard_image != null and standard_image.get_size() == Vector2i(1024, 768):
		_check(_is_red(standard_image.get_pixel(80, 80)), "4:3 image did not fill the top-left corner")
		_check(_is_yellow(standard_image.get_pixel(940, 690)), "4:3 image did not fill the bottom-right corner")

	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	var video_request: int = _controller.show_video(video_ref)
	var video_ready: bool = await _wait_until(
		Callable(self, "_controller_is_video_playing"),
		VIDEO_READY_TIMEOUT_MS,
		"Native OGV did not reach PLAYING within 5 seconds"
	)
	_check(video_ready and _controller.active_request_id == video_request, "Native OGV request did not remain active")
	var backend: NativeOgvPlaybackBackend = _native_backends.back() if not _native_backends.is_empty() else null
	_check(backend != null, "Native OGV backend was not created")
	if backend != null:
		_check(backend.get_natural_size() == Vector2i(640, 360), "Native OGV natural size is not 640x360")
		_observed_video_duration = backend.get_duration_seconds()
		_check(
			_observed_video_duration >= 8.0 and _observed_video_duration <= 10.0,
			"Native OGV duration is outside the expected 8.0-10.0 second range"
		)
	var visual_result: Dictionary = await _wait_for_video_pixels_and_audio(VIDEO_READY_TIMEOUT_MS)
	_check(bool(visual_result.get("nonempty", false)), "Native OGV never produced a non-empty first frame")
	_check(bool(visual_result.get("changed", false)), "Native OGV did not produce changing frames")
	_check(bool(visual_result.get("audio", false)), "Native OGV did not produce an audio bus peak")
	var video_image: Image = visual_result.get("image") as Image
	if video_image != null and video_image.get_size() == Vector2i(1024, 768):
		_check(_is_black(video_image.get_pixel(512, 30)), "16:9 video lacks the top black bar at 1024x768")
		_check(_is_black(video_image.get_pixel(512, 738)), "16:9 video lacks the bottom black bar at 1024x768")
	else:
		_check(false, "1024x768 video capture is unavailable")
	var natural_finish: bool = await _wait_until(
		Callable(self, "_controller_is_map"),
		VIDEO_FINISH_TIMEOUT_MS,
		"Native OGV did not naturally return to MAP"
	)
	_check(natural_finish, "Natural OGV finish did not return to MAP")
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		RELEASE_TIMEOUT_MS,
		"Natural finish did not release media nodes"
	)
	if backend != null:
		_assert_backend_released(backend, "natural finish")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "MAP did not redraw after natural video finish")
	var restored_map: Image = _capture_cast_image()
	_check(restored_map != null and not restored_map.is_empty(), "MAP capture is empty after natural finish")


func _test_native_failure_and_repeated_switches() -> void:
	var fake_video_ref: ExternalContentRef = _fixture.get("fake_video_ref") as ExternalContentRef
	var fake_request: int = _controller.show_video(fake_video_ref)
	var fake_failed: bool = await _wait_until(
		Callable(self, "_request_failed").bind(fake_request),
		VIDEO_READY_TIMEOUT_MS,
		"Pseudo OGV did not report a native playback failure"
	)
	_check(fake_failed, "Pseudo OGV failure result is missing")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Pseudo OGV did not recover to MAP")
	if not _native_backends.is_empty():
		_assert_backend_released(_native_backends.back(), "pseudo OGV failure")

	var image_ref: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	var switch_backends: Array[NativeOgvPlaybackBackend] = []
	for round_index: int in range(10):
		_controller.show_image(image_ref)
		_check(
			_controller.active_kind == PlayerOutputController.OutputKind.IMAGE,
			"Image did not activate in repeated round %d" % round_index
		)
		_controller.show_video(video_ref)
		var ready: bool = await _wait_until(
			Callable(self, "_controller_is_video_playing"),
			VIDEO_READY_TIMEOUT_MS,
			"Video did not become ready in repeated round %d" % round_index
		)
		_check(ready, "Video readiness failed in repeated round %d" % round_index)
		if not _native_backends.is_empty():
			switch_backends.append(_native_backends.back())
		_controller.show_image(image_ref)
	await _wait_for_draw(DRAW_TIMEOUT_MS, "Final image did not draw after ten rounds")
	_controller.show_map()
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		RELEASE_TIMEOUT_MS,
		"Presenter/player/texture nodes did not return to baseline after ten rounds"
	)
	_check(_media_nodes_at_baseline(), "Ten-round switching left media nodes alive")
	for backend: NativeOgvPlaybackBackend in switch_backends:
		_assert_backend_released(backend, "ten-round switch")


func _test_scene_close_and_exit_cleanup() -> void:
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	_controller.show_video(video_ref)
	await _wait_until(
		Callable(self, "_controller_is_video_playing"),
		VIDEO_READY_TIMEOUT_MS,
		"Scene-switch video did not become ready"
	)
	var scene_backend: NativeOgvPlaybackBackend = _native_backends.back()
	_controller.prepare_scene_switch()
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		RELEASE_TIMEOUT_MS,
		"Scene switch did not release media nodes"
	)
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Scene switch did not restore MAP")
	_assert_backend_released(scene_backend, "scene switch")

	_controller.show_video(video_ref)
	await _wait_until(
		Callable(self, "_controller_is_video_playing"),
		VIDEO_READY_TIMEOUT_MS,
		"Close-output video did not become ready"
	)
	var close_backend: NativeOgvPlaybackBackend = _native_backends.back()
	var closing_window: Window = _cast_view.get_cast_window()
	_controller.clear_lifecycle_trace()
	_controller.close_output()
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		RELEASE_TIMEOUT_MS,
		"Closing output did not release media nodes"
	)
	await _wait_process_frames(2, RELEASE_TIMEOUT_MS, "Native window close did not settle")
	_assert_backend_released(close_backend, "close output")
	_check(
		_controller.get_lifecycle_trace() == ["release_media", "release_map", "release_window"],
		"Close output did not release the native window last"
	)
	_check(closing_window == null or not is_instance_valid(closing_window), "Native player window survived close output")

	var reopen_result: Dictionary = _controller.open_output()
	_check(int(reopen_result.get("error", FAILED)) == OK, "Player output did not reopen before exit cleanup")
	_controller.show_video(video_ref)
	await _wait_until(
		Callable(self, "_controller_is_video_playing"),
		VIDEO_READY_TIMEOUT_MS,
		"Exit-cleanup video did not become ready"
	)
	var exit_backend: NativeOgvPlaybackBackend = _native_backends.back()
	_controller.close_output()
	await _wait_until(
		Callable(self, "_media_nodes_at_baseline"),
		RELEASE_TIMEOUT_MS,
		"Exit cleanup did not release media nodes"
	)
	_assert_backend_released(exit_backend, "exit cleanup")
	_check(not _controller.is_open(), "Exit cleanup left the player output open")


func _setup_map_world() -> void:
	_camera = Camera3D.new()
	_camera.name = "P3_4MainCamera"
	_camera.position = Vector3(0.0, 0.0, 4.0)
	_camera.current = true
	add_child(_camera)
	_map_quad = MeshInstance3D.new()
	_map_quad.name = "P3_4MapQuad"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(8.0, 4.5)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.72, 0.78, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = material
	_map_quad.mesh = quad
	add_child(_map_quad)


func _setup_output() -> void:
	_cast_view = CastView.new()
	_cast_view.name = "P3_4CastView"
	add_child(_cast_view)
	_controller = PlayerOutputController.new()
	_controller.name = "P3_4PlayerOutputController"
	add_child(_controller)
	_controller.configure(
		_cast_view,
		_camera,
		null,
		Callable(self, "_fixture_module_dir")
	)
	_controller.set_video_backend_factory(Callable(self, "_create_native_backend"))
	_controller.set_video_audio_bus(TEST_BUS_NAME)
	_controller.output_failed.connect(_on_output_failed)


func _create_test_audio_bus() -> void:
	var existing_index: int = AudioServer.get_bus_index(TEST_BUS_NAME)
	if existing_index >= 0:
		AudioServer.remove_bus(existing_index)
	AudioServer.add_bus()
	var bus_index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, TEST_BUS_NAME)
	_check(AudioServer.get_bus_index(TEST_BUS_NAME) >= 0, "Temporary media audio bus was not created")


func _create_native_backend() -> VideoPlaybackBackend:
	var backend: NativeOgvPlaybackBackend = NativeOgvPlaybackBackend.new()
	_native_backends.append(backend)
	return backend


func _fixture_module_dir() -> String:
	return String(_fixture.get("module_dir", ""))


func _on_output_failed(request_id: int, _content_id: String, _error: int, _message: String) -> void:
	_failed_request_ids.append(request_id)


func _request_failed(request_id: int) -> bool:
	return _failed_request_ids.has(request_id)


func _controller_is_video_playing() -> bool:
	return (
		_controller != null
		and _controller.active_kind == PlayerOutputController.OutputKind.VIDEO
		and _controller.phase == PlayerOutputController.OutputPhase.PLAYING
	)


func _controller_is_map() -> bool:
	return (
		_controller != null
		and _controller.active_kind == PlayerOutputController.OutputKind.MAP
		and _controller.phase == PlayerOutputController.OutputPhase.IDLE
	)


func _media_nodes_at_baseline() -> bool:
	return (
		get_tree().get_nodes_in_group("gvtt_player_output_presenter").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_player").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_texture").is_empty()
	)


func _resize_cast(size: Vector2i) -> bool:
	var window: Window = _cast_view.get_cast_window()
	if window == null:
		_check(false, "Cannot resize a missing cast window")
		return false
	window.size = size
	return await _wait_until(
		Callable(self, "_cast_size_is").bind(size),
		DRAW_TIMEOUT_MS,
		"Cast window did not resize to %s" % [size]
	)


func _cast_size_is(size: Vector2i) -> bool:
	var window: Window = _cast_view.get_cast_window()
	return window != null and window.size == size


func _wait_for_video_pixels_and_audio(timeout_ms: int) -> Dictionary:
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	var first_data: PackedByteArray = PackedByteArray()
	var latest_image: Image = null
	var nonempty: bool = false
	var changed: bool = false
	var audio: bool = false
	while Time.get_ticks_msec() <= deadline_ms:
		var draw_ok: bool = await _wait_for_draw(1000, "Video frame draw timed out")
		if not draw_ok:
			break
		latest_image = _capture_cast_image()
		if latest_image != null and not latest_image.is_empty():
			var center: Color = latest_image.get_pixel(
				latest_image.get_width() / 2,
				latest_image.get_height() / 2
			)
			if not _is_black(center):
				nonempty = true
			var current_data: PackedByteArray = latest_image.get_data()
			if first_data.is_empty() and nonempty:
				first_data = current_data
			elif not first_data.is_empty() and current_data != first_data:
				changed = true
		var bus_index: int = AudioServer.get_bus_index(TEST_BUS_NAME)
		if bus_index >= 0:
			var left_peak: float = AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
			var right_peak: float = AudioServer.get_bus_peak_volume_right_db(bus_index, 0)
			_max_audio_peak_db = maxf(_max_audio_peak_db, maxf(left_peak, right_peak))
			audio = audio or _max_audio_peak_db > -60.0
		if nonempty and changed and audio:
			break
	return {
		"nonempty": nonempty,
		"changed": changed,
		"audio": audio,
		"image": latest_image,
	}


func _wait_for_draw(timeout_ms: int, failure_message: String) -> bool:
	_frame_post_draw_received = false
	var draw_callable: Callable = Callable(self, "_on_frame_post_draw")
	if RenderingServer.frame_post_draw.is_connected(draw_callable):
		RenderingServer.frame_post_draw.disconnect(draw_callable)
	RenderingServer.frame_post_draw.connect(draw_callable, CONNECT_ONE_SHOT)
	var frames_before: int = Engine.get_frames_drawn()
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline_ms:
		await get_tree().process_frame
		if _frame_post_draw_received and Engine.get_frames_drawn() > frames_before:
			return true
	if RenderingServer.frame_post_draw.is_connected(draw_callable):
		RenderingServer.frame_post_draw.disconnect(draw_callable)
	_check(false, failure_message)
	return false


func _on_frame_post_draw() -> void:
	_frame_post_draw_received = true


func _capture_cast_image() -> Image:
	var window: Window = _cast_view.get_cast_window()
	if window == null or not is_instance_valid(window):
		return null
	var texture: ViewportTexture = window.get_texture()
	if texture == null:
		return null
	return texture.get_image()


func _assert_backend_released(backend: NativeOgvPlaybackBackend, context: String) -> void:
	var state: Dictionary = backend.get_debug_state()
	_check(bool(state.get("released", false)), "%s backend was not released" % context)
	_check(not bool(state.get("playing", true)), "%s backend is still playing" % context)
	_check(not bool(state.get("has_stream", true)), "%s backend retained its stream" % context)
	_check(not bool(state.get("has_view", true)), "%s backend retained its player view" % context)
	_check(
		not bool(state.get("finished_signal_connected", true)),
		"%s backend retained its finished signal" % context
	)


func _is_black(color: Color) -> bool:
	return color.r < 0.05 and color.g < 0.05 and color.b < 0.05


func _is_red(color: Color) -> bool:
	return color.r > 0.7 and color.g < 0.25 and color.b < 0.25


func _is_green(color: Color) -> bool:
	return color.g > 0.65 and color.r < 0.25 and color.b < 0.3


func _is_blue(color: Color) -> bool:
	return color.b > 0.7 and color.r < 0.25 and color.g < 0.35


func _is_yellow(color: Color) -> bool:
	return color.r > 0.7 and color.g > 0.6 and color.b < 0.3


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


func _cleanup() -> void:
	if _controller != null and is_instance_valid(_controller):
		_controller.close_output()
	await _wait_process_frames(2, RELEASE_TIMEOUT_MS, "Visible smoke cleanup timed out")
	var bus_index: int = AudioServer.get_bus_index(TEST_BUS_NAME)
	if bus_index >= 0:
		AudioServer.remove_bus(bus_index)
	_check(AudioServer.get_bus_index(TEST_BUS_NAME) < 0, "Temporary media audio bus was not removed")
	P3_4FixtureFactory.cleanup()


func _finish() -> void:
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
		"display_server": DisplayServer.get_name(),
		"frames_drawn": Engine.get_frames_drawn(),
		"max_audio_peak_db": _max_audio_peak_db,
		"video_duration_seconds": _observed_video_duration,
		"image_sha256": FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_IMAGE_PATH),
		"video_sha256": FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_VIDEO_PATH),
	}
	print("P3_4_VISIBLE_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_4_VISIBLE_FAILURES " + JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
