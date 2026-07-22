extends Node3D

const DRAW_TIMEOUT_MS: int = 5000
const VIDEO_READY_TIMEOUT_MS: int = 5000
const VIDEO_FINISH_TIMEOUT_MS: int = 12000
const RELEASE_TIMEOUT_MS: int = 3000
const MEDIA_BUS_NAME: StringName = &"Media"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _fixture: Dictionary = {}
var _camera: Camera3D = null
var _map_quad: MeshInstance3D = null
var _cast_view: CastView = null
var _controller: PlayerOutputController = null
var _native_backends: Array[NativeOgvPlaybackBackend] = []
var _frame_post_draw_received: bool = false
var _max_audio_peak_db: float = -200.0
var _pause_position_delta: float = -1.0


func _ready() -> void:
	await _wait_process_frames(1, DRAW_TIMEOUT_MS, "P4.3 startup frame timed out")
	_check(DisplayServer.get_name() != "headless", "P4.3 visible test was started headless")
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	P3_4FixtureFactory.cleanup()
	_fixture = P3_4FixtureFactory.create()
	_check(int(_fixture.get("error", FAILED)) == OK, String(_fixture.get("message", "夹具创建失败")))
	if int(_fixture.get("error", FAILED)) == OK:
		_setup_map_world()
		_setup_output()
		await _test_play_pause_resume_stop()
		await _test_natural_finish()
		await _test_ten_round_switching()
		await _test_scene_switch_cleanup()
		await _test_window_close_cleanup()
	await _cleanup()
	_finish()


func _test_play_pause_resume_stop() -> void:
	var open_result: Dictionary = _controller.open_output()
	_check(int(open_result.get("error", FAILED)) == OK, "P4.3 player output did not open")
	_check(_controller.set_video_volume_linear(0.5) == OK, "Media volume could not be set")
	var bus_index: int = AudioServer.get_bus_index(MEDIA_BUS_NAME)
	_check(bus_index > 0, "Product Media audio bus was not created independently from Master")
	if bus_index >= 0:
		_check(AudioServer.get_bus_name(bus_index) == String(MEDIA_BUS_NAME), "Media bus name is wrong")
		_check(
			is_equal_approx(AudioServer.get_bus_volume_linear(bus_index), 0.5),
			"Media bus volume did not use the requested linear value"
		)

	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	_controller.show_video(video_ref)
	_check(
		await _wait_until(Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS, "OGV did not reach PLAYING"),
		"OGV playback did not become controllable"
	)
	var backend: NativeOgvPlaybackBackend = _native_backends.back() if not _native_backends.is_empty() else null
	_check(backend != null, "Native OGV backend was not created")
	if backend == null:
		return
	_check(backend.get_natural_size() == Vector2i(640, 360), "OGV first-frame size is not 640x360")
	_check(
		await _wait_until(Callable(self, "_video_has_first_frame"), DRAW_TIMEOUT_MS, "OGV first frame stayed blank"),
		"OGV did not produce a visible first frame"
	)
	var shared_video_texture: Texture2D = _controller.get_active_media_texture()
	_check(shared_video_texture != null, "Video output did not expose a shared GM texture")
	if shared_video_texture != null:
		_check(shared_video_texture.get_size() == Vector2(640.0, 360.0), "Shared video texture size is wrong")
	_check(
		await _wait_until(Callable(self, "_stream_position_above").bind(0.05), DRAW_TIMEOUT_MS, "OGV position did not advance"),
		"OGV did not advance before pause"
	)
	_check(
		await _wait_until(Callable(self, "_media_audio_detected"), DRAW_TIMEOUT_MS, "Media bus had no audio peak"),
		"OGV audio did not reach the product Media bus"
	)

	var pause_error: int = _controller.pause_video()
	_check(pause_error == OK, "Pause command failed")
	_check(_controller.phase == PlayerOutputController.OutputPhase.PAUSED, "Controller did not enter PAUSED")
	var paused_state: Dictionary = _controller.get_video_debug_state()
	var paused_position: float = float(paused_state.get("stream_position", -1.0))
	var paused_frame: PackedByteArray = _capture_cast_data()
	await _wait_process_frames(12, DRAW_TIMEOUT_MS, "Paused frame wait timed out")
	var held_state: Dictionary = _controller.get_video_debug_state()
	var held_position: float = float(held_state.get("stream_position", -1.0))
	_pause_position_delta = absf(held_position - paused_position)
	_check(bool(held_state.get("paused", false)), "Native backend did not remain paused")
	_check(_pause_position_delta <= 0.03, "Paused video position kept advancing")
	_check(_capture_cast_data() == paused_frame, "Paused video frame kept changing")

	var resume_error: int = _controller.resume_video()
	_check(resume_error == OK, "Resume command failed")
	_check(_controller.phase == PlayerOutputController.OutputPhase.PLAYING, "Controller did not return to PLAYING")
	_check(
		await _wait_until(
			Callable(self, "_stream_position_above").bind(paused_position + 0.08),
			DRAW_TIMEOUT_MS,
			"Resumed video position did not advance"
		),
		"Resume did not continue playback"
	)
	await _wait_for_draw(DRAW_TIMEOUT_MS, "Resumed video did not draw")
	_check(_capture_cast_data() != paused_frame, "Resumed video frame did not change")

	var stop_error: int = _controller.stop_video()
	_check(stop_error > 0, "Stop did not allocate a return-to-map request")
	_check(_controller_is_map(), "Stop did not return to MAP")
	_check(
		await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS, "Stop retained media nodes"),
		"Stop did not release Presenter and player nodes"
	)
	_assert_backend_released(backend, "stop")
	_check(
		await _wait_until(Callable(self, "_media_bus_is_silent"), RELEASE_TIMEOUT_MS, "Media bus stayed audible after stop"),
		"Stop did not silence the Media bus"
	)


func _test_natural_finish() -> void:
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	_controller.show_video(video_ref)
	_check(
		await _wait_until(Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS, "Natural-finish OGV did not start"),
		"Natural-finish OGV never reached PLAYING"
	)
	var backend: NativeOgvPlaybackBackend = _native_backends.back()
	_check(
		await _wait_until(Callable(self, "_controller_is_map"), VIDEO_FINISH_TIMEOUT_MS, "Natural finish did not return to MAP"),
		"Natural finish did not restore MAP"
	)
	_check(
		await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS, "Natural finish retained nodes"),
		"Natural finish did not release media nodes"
	)
	_assert_backend_released(backend, "natural finish")
	_check(_media_bus_is_silent(), "Natural finish did not silence Media")


func _test_ten_round_switching() -> void:
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	var round_backends: Array[NativeOgvPlaybackBackend] = []
	for round_index: int in range(10):
		_controller.show_video(video_ref)
		var ready: bool = await _wait_until(
			Callable(self, "_controller_is_video_playing"),
			VIDEO_READY_TIMEOUT_MS,
			"Video did not become ready in round %d" % round_index
		)
		_check(ready, "Video readiness failed in round %d" % round_index)
		if not _native_backends.is_empty():
			round_backends.append(_native_backends.back())
		_controller.return_to_map()
		_check(_controller_is_map(), "Round %d did not return to MAP" % round_index)
	_check(
		await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS, "Ten rounds retained media nodes"),
		"Ten rounds left media nodes alive"
	)
	for backend: NativeOgvPlaybackBackend in round_backends:
		_assert_backend_released(backend, "ten-round switch")


func _test_scene_switch_cleanup() -> void:
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	_controller.show_video(video_ref)
	await _wait_until(Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS, "Scene-switch OGV did not start")
	var backend: NativeOgvPlaybackBackend = _native_backends.back()
	_controller.prepare_scene_switch()
	_check(_controller_is_map(), "Scene switch did not restore MAP")
	_check(
		await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS, "Scene switch retained media nodes"),
		"Scene switch did not release video nodes"
	)
	_assert_backend_released(backend, "scene switch")
	_check(_media_bus_is_silent(), "Scene switch did not silence Media")


func _test_window_close_cleanup() -> void:
	var video_ref: ExternalContentRef = _fixture.get("video_ref") as ExternalContentRef
	_controller.show_video(video_ref)
	await _wait_until(Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS, "Window-close OGV did not start")
	var backend: NativeOgvPlaybackBackend = _native_backends.back()
	var closing_window: Window = _cast_view.get_cast_window()
	_controller.clear_lifecycle_trace()
	closing_window.close_requested.emit()
	_check(
		await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS, "Window close retained media nodes"),
		"Window close did not release video nodes"
	)
	await _wait_process_frames(2, RELEASE_TIMEOUT_MS, "Native window release did not settle")
	_assert_backend_released(backend, "window close")
	_check(
		_controller.get_lifecycle_trace() == ["release_media", "release_map", "release_window"],
		"Window close did not release media, map, then native window"
	)
	_check(not _controller.is_open(), "Window close left player output open")
	_check(closing_window == null or not is_instance_valid(closing_window), "Native player window survived close request")
	_check(get_tree().get_nodes_in_group("gvtt_player_output_window").is_empty(), "Window group retained a native window")
	_check(_media_bus_is_silent(), "Window close did not silence Media")


func _setup_map_world() -> void:
	_camera = Camera3D.new()
	_camera.name = "P4_3MainCamera"
	_camera.position = Vector3(0.0, 0.0, 4.0)
	_camera.current = true
	add_child(_camera)
	_map_quad = MeshInstance3D.new()
	_map_quad.name = "P4_3MapQuad"
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
	_cast_view.name = "P4_3CastView"
	add_child(_cast_view)
	_controller = PlayerOutputController.new()
	_controller.name = "P4_3PlayerOutputController"
	add_child(_controller)
	_controller.configure(_cast_view, _camera, null, Callable(self, "_fixture_module_dir"))
	_controller.set_video_backend_factory(Callable(self, "_create_native_backend"))


func _create_native_backend() -> VideoPlaybackBackend:
	var backend: NativeOgvPlaybackBackend = NativeOgvPlaybackBackend.new()
	_native_backends.append(backend)
	return backend


func _fixture_module_dir() -> String:
	return String(_fixture.get("module_dir", ""))


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


func _stream_position_above(threshold: float) -> bool:
	var state: Dictionary = _controller.get_video_debug_state()
	return float(state.get("stream_position", 0.0)) > threshold


func _video_has_first_frame() -> bool:
	var image: Image = _capture_cast_image()
	if image == null or image.is_empty():
		return false
	var center: Color = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	return center.r > 0.05 or center.g > 0.05 or center.b > 0.05


func _media_audio_detected() -> bool:
	var bus_index: int = AudioServer.get_bus_index(MEDIA_BUS_NAME)
	if bus_index < 0:
		return false
	var left_peak: float = AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
	var right_peak: float = AudioServer.get_bus_peak_volume_right_db(bus_index, 0)
	_max_audio_peak_db = maxf(_max_audio_peak_db, maxf(left_peak, right_peak))
	return _max_audio_peak_db > -60.0


func _media_bus_is_silent() -> bool:
	var bus_index: int = AudioServer.get_bus_index(MEDIA_BUS_NAME)
	if bus_index < 0 or not AudioServer.is_bus_mute(bus_index):
		return false
	var left_peak: float = AudioServer.get_bus_peak_volume_left_db(bus_index, 0)
	var right_peak: float = AudioServer.get_bus_peak_volume_right_db(bus_index, 0)
	return maxf(left_peak, right_peak) <= -60.0


func _media_nodes_at_baseline() -> bool:
	return (
		get_tree().get_nodes_in_group("gvtt_player_output_presenter").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_player").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_texture").is_empty()
	)


func _capture_cast_image() -> Image:
	var window: Window = _cast_view.get_cast_window()
	if window == null or not is_instance_valid(window):
		return null
	var texture: ViewportTexture = window.get_texture()
	return texture.get_image() if texture != null else null


func _capture_cast_data() -> PackedByteArray:
	var image: Image = _capture_cast_image()
	return image.get_data() if image != null and not image.is_empty() else PackedByteArray()


func _assert_backend_released(backend: NativeOgvPlaybackBackend, context: String) -> void:
	var state: Dictionary = backend.get_debug_state()
	_check(bool(state.get("released", false)), "%s backend was not released" % context)
	_check(not bool(state.get("playing", true)), "%s backend is still playing" % context)
	_check(not bool(state.get("paused", true)), "%s backend stayed paused" % context)
	_check(not bool(state.get("has_stream", true)), "%s backend retained its stream" % context)
	_check(not bool(state.get("has_view", true)), "%s backend retained its player view" % context)
	_check(
		not bool(state.get("finished_signal_connected", true)),
		"%s backend retained its finished signal" % context
	)


func _wait_for_draw(timeout_ms: int, failure_message: String) -> bool:
	_frame_post_draw_received = false
	var draw_callable: Callable = Callable(self, "_on_frame_post_draw")
	if RenderingServer.frame_post_draw.is_connected(draw_callable):
		RenderingServer.frame_post_draw.disconnect(draw_callable)
	RenderingServer.frame_post_draw.connect(draw_callable, CONNECT_ONE_SHOT)
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	while not _frame_post_draw_received and Time.get_ticks_msec() <= deadline_ms:
		await get_tree().process_frame
	if not _frame_post_draw_received:
		if RenderingServer.frame_post_draw.is_connected(draw_callable):
			RenderingServer.frame_post_draw.disconnect(draw_callable)
		_check(false, failure_message)
		return false
	return true


func _on_frame_post_draw() -> void:
	_frame_post_draw_received = true


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
	await _wait_process_frames(2, RELEASE_TIMEOUT_MS, "P4.3 cleanup timed out")
	P3_4FixtureFactory.cleanup()


func _finish() -> void:
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
		"display_server": DisplayServer.get_name(),
		"frames_drawn": Engine.get_frames_drawn(),
		"max_audio_peak_db": _max_audio_peak_db,
		"pause_position_delta": _pause_position_delta,
		"video_sha256": FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_VIDEO_PATH),
	}
	print("P4_3_VIDEO_PRESENTATION_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P4_3_VIDEO_PRESENTATION_FAILURES " + JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
