extends Node3D

const FIXTURE_PATH: String = "res://build/p45_acceptance/vlc_fixture.mp4"
const DRAW_TIMEOUT_MS: int = 10000
const VIDEO_READY_TIMEOUT_MS: int = 15000
const RELEASE_TIMEOUT_MS: int = 5000
const MEDIA_BUS_NAME: StringName = &"Media"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _camera: Camera3D = null
var _map_quad: MeshInstance3D = null
var _cast_view: CastView = null
var _controller: PlayerOutputController = null
var _frame_post_draw_received: bool = false
var _max_audio_peak_db: float = -200.0
var _pause_position_delta: float = -1.0
var _runtime_failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_check(DisplayServer.get_name() != "headless", "Native Video visible test was started headless")
	_check(FileAccess.file_exists(FIXTURE_PATH), "Real MP4 fixture is missing")
	if DisplayServer.get_name() != "headless" and FileAccess.file_exists(FIXTURE_PATH):
		_setup_map_world()
		_setup_output()
		await _test_native_video_lifecycle()
	await _cleanup()
	_finish()


func _test_native_video_lifecycle() -> void:
	var open_result: Dictionary = _controller.open_output()
	_check(int(open_result.get("error", FAILED)) == OK, "Player output did not open")
	_check(_controller.set_video_volume_linear(0.5) == OK, "Media volume could not be set")
	var video_ref: ExternalContentRef = _create_video_ref()
	_controller.show_video(video_ref)
	var initial_playing: bool = await _wait_until(
		Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS
	)
	_check(initial_playing, "MP4 did not reach PLAYING")
	if not initial_playing:
		return
	var state: Dictionary = _controller.get_video_debug_state()
	_check(String(state.get("backend", "")) == "native_video", "MP4 did not use Native Video backend")
	_check(float(state.get("stream_position", -1.0)) >= 0.0, "MP4 stream position is invalid")
	_check(
		await _wait_until(Callable(self, "_video_has_first_frame"), DRAW_TIMEOUT_MS),
		"MP4 first frame stayed blank"
	)
	var shared_texture: Texture2D = _controller.get_active_media_texture()
	_check(shared_texture != null, "MP4 did not expose a shared output texture")
	if shared_texture != null:
		var size: Vector2 = shared_texture.get_size()
		_check(size.x > 0.0 and size.y > 0.0, "MP4 output texture size is invalid")
	_check(
		await _wait_until(Callable(self, "_stream_position_above").bind(0.1), DRAW_TIMEOUT_MS),
		"MP4 position did not advance"
	)
	_check(
		await _wait_until(Callable(self, "_media_audio_detected"), DRAW_TIMEOUT_MS),
		"MP4 audio did not reach the Media bus"
	)

	_check(_controller.pause_video() == OK, "MP4 pause command failed")
	var paused_position: float = float(_controller.get_video_debug_state().get("stream_position", -1.0))
	var paused_frame: PackedByteArray = _capture_cast_data()
	await _wait_process_frames(12)
	var held_state: Dictionary = _controller.get_video_debug_state()
	var held_position: float = float(held_state.get("stream_position", -1.0))
	_pause_position_delta = absf(held_position - paused_position)
	_check(bool(held_state.get("paused", false)), "Native Video did not remain paused")
	_check(_pause_position_delta <= 0.05, "Paused MP4 position kept advancing")
	_check(_capture_cast_data() == paused_frame, "Paused MP4 frame kept changing")

	_check(_controller.resume_video() == OK, "MP4 resume command failed")
	_check(
		await _wait_until(
			Callable(self, "_stream_position_above").bind(paused_position + 0.1),
			DRAW_TIMEOUT_MS
		),
		"Resumed MP4 position did not advance"
	)
	await _wait_for_draw(DRAW_TIMEOUT_MS)
	_check(_capture_cast_data() != paused_frame, "Resumed MP4 frame did not change")

	for round_index: int in range(3):
		_controller.return_to_map()
		_check(await _wait_until(Callable(self, "_controller_is_map"), RELEASE_TIMEOUT_MS), "Rapid switch did not restore MAP")
		_check(await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS), "Rapid switch retained media nodes")
		_controller.show_video(video_ref)
		_check(
			await _wait_until(Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS),
			"Rapid MP4 switch failed in round %d" % round_index
		)

	_controller.prepare_scene_switch()
	_check(await _wait_until(Callable(self, "_controller_is_map"), RELEASE_TIMEOUT_MS), "Scene switch did not restore MAP")
	_check(await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS), "Scene switch retained media nodes")

	_controller.show_video(video_ref)
	_check(
		await _wait_until(Callable(self, "_controller_is_video_playing"), VIDEO_READY_TIMEOUT_MS),
		"Window-close MP4 did not start"
	)
	var closing_window: Window = _cast_view.get_cast_window()
	var close_result: Dictionary = _controller.close_output()
	_check(int(close_result.get("error", FAILED)) == OK, "Closing player output failed")
	await _wait_process_frames(2)
	_check(await _wait_until(Callable(self, "_media_nodes_at_baseline"), RELEASE_TIMEOUT_MS), "Window close retained media nodes")
	_check(not _controller.is_open(), "Player output remained open")
	_check(closing_window == null or not is_instance_valid(closing_window), "Native player window survived close")
	_check(_media_bus_is_silent(), "Media bus remained audible after close")


func _setup_map_world() -> void:
	_camera = Camera3D.new()
	_camera.name = "P4_5MainCamera"
	_camera.position = Vector3(0.0, 0.0, 4.0)
	_camera.current = true
	add_child(_camera)
	_map_quad = MeshInstance3D.new()
	_map_quad.name = "P4_5MapQuad"
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
	_cast_view.name = "P4_5CastView"
	add_child(_cast_view)
	_controller = PlayerOutputController.new()
	_controller.name = "P4_5PlayerOutputController"
	add_child(_controller)
	_controller.configure(_cast_view, _camera, null)
	_controller.output_failed.connect(_on_output_failed)


func _on_output_failed(
		_request_id: int,
		_content_id: String,
		error: int,
		message: String
) -> void:
	var failure: String = "error=%d message=%s" % [error, message]
	_runtime_failures.append(failure)
	print("P4_5_NATIVE_VIDEO_RUNTIME_FAILURE " + failure)


func _create_video_ref() -> ExternalContentRef:
	var content: ExternalContentRef = ExternalContentRef.new()
	content.content_id = "45000000000000000000000000000001"
	content.content_type = ExternalContentRef.ContentType.VIDEO
	content.display_name = "P4.5 Native Video MP4"
	content.source_kind = ExternalContentRef.SourceKind.EXTERNAL_FILE
	content.source_path = ProjectSettings.globalize_path(FIXTURE_PATH)
	return content


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
	return float(_controller.get_video_debug_state().get("stream_position", 0.0)) > threshold


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
	return AudioServer.get_bus_peak_volume_left_db(bus_index, 0) <= -60.0


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


func _wait_for_draw(timeout_ms: int) -> bool:
	_frame_post_draw_received = false
	var draw_callable: Callable = Callable(self, "_on_frame_post_draw")
	RenderingServer.frame_post_draw.connect(draw_callable, CONNECT_ONE_SHOT)
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	while not _frame_post_draw_received and Time.get_ticks_msec() <= deadline_ms:
		await get_tree().process_frame
	return _frame_post_draw_received


func _on_frame_post_draw() -> void:
	_frame_post_draw_received = true


func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() <= deadline_ms:
		if bool(predicate.call()):
			return true
		await get_tree().process_frame
	return false


func _wait_process_frames(frame_count: int) -> void:
	for frame_index: int in range(frame_count):
		await get_tree().process_frame


func _cleanup() -> void:
	if _controller != null and is_instance_valid(_controller) and _controller.is_open():
		_controller.close_output()
	await _wait_process_frames(2)


func _finish() -> void:
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
		"display_server": DisplayServer.get_name(),
		"frames_drawn": Engine.get_frames_drawn(),
		"max_audio_peak_db": _max_audio_peak_db,
		"pause_position_delta": _pause_position_delta,
		"runtime_failures": _runtime_failures,
		"mp4_sha256": FileAccess.get_sha256(FIXTURE_PATH),
	}
	print("P4_5_NATIVE_VIDEO_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P4_5_NATIVE_VIDEO_FAILURES " + JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
