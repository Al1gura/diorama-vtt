extends Node3D

const DRAW_TIMEOUT_MS: int = 5000
const FADE_TIMEOUT_MS: int = 1500
const RELEASE_TIMEOUT_MS: int = 3000

var _assertion_count: int = 0
var _failures: Array[String] = []
var _fixture: Dictionary = {}
var _camera: Camera3D = null
var _map_quad: MeshInstance3D = null
var _cast_view: CastView = null
var _controller: PlayerOutputController = null
var _failed_requests: Dictionary = {}
var _frame_post_draw_received: bool = false


func _ready() -> void:
	await _wait_process_frames(1, DRAW_TIMEOUT_MS, "P4.2 startup frame timed out")
	_check(DisplayServer.get_name() != "headless", "P4.2 visible test was started headless")
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	P3_4FixtureFactory.cleanup()
	_fixture = P3_4FixtureFactory.create()
	_check(int(_fixture.get("error", FAILED)) == OK, String(_fixture.get("message", "夹具创建失败")))
	if int(_fixture.get("error", FAILED)) == OK:
		_setup_map_world()
		_setup_output()
		await _test_normal_display_and_aspect_ratios()
		await _test_fade_and_fast_return()
		await _test_missing_and_corrupt_failures()
		await _test_ten_round_release()
	await _cleanup()
	_finish()


func _test_normal_display_and_aspect_ratios() -> void:
	var open_result: Dictionary = _controller.open_output()
	_check(int(open_result.get("error", FAILED)) == OK, "P4.2 player output did not open")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "Initial map did not draw")
	var image_ref: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	await _resize_cast(Vector2i(1280, 720))
	var request_id: int = _controller.show_image(image_ref)
	_check(request_id > 0, "Valid image request ID was not allocated")
	_check(_controller.phase == PlayerOutputController.OutputPhase.READY, "Valid image did not reach READY")
	var shared_image_texture: Texture2D = _controller.get_active_media_texture()
	_check(shared_image_texture != null, "Image output did not expose a shared GM texture")
	if shared_image_texture != null:
		_check(shared_image_texture.get_size() == Vector2(640.0, 480.0), "Shared image texture size is wrong")
	_check(_current_image_alpha() <= 0.01, "Image fade-in did not start transparent")
	await _wait_until(Callable(self, "_image_is_opaque"), FADE_TIMEOUT_MS, "Image fade-in did not finish")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "1280x720 image did not draw")
	var wide_image: Image = _capture_cast_image()
	_check(wide_image != null and wide_image.get_size() == Vector2i(1280, 720), "1280x720 capture size is wrong")
	if wide_image != null and wide_image.get_size() == Vector2i(1280, 720):
		_check(_is_black(wide_image.get_pixel(40, 360)), "4:3 image lacks the left black bar")
		_check(_is_black(wide_image.get_pixel(1240, 360)), "4:3 image lacks the right black bar")
		_check(_is_red(wide_image.get_pixel(240, 120)), "Top-left image quadrant is not red")
		_check(_is_green(wide_image.get_pixel(1040, 120)), "Top-right image quadrant is not green")
		_check(_is_blue(wide_image.get_pixel(240, 600)), "Bottom-left image quadrant is not blue")
		_check(_is_yellow(wide_image.get_pixel(1040, 600)), "Bottom-right image quadrant is not yellow")

	await _resize_cast(Vector2i(1024, 768))
	await _wait_for_draw(DRAW_TIMEOUT_MS, "1024x768 image did not draw")
	var standard_image: Image = _capture_cast_image()
	_check(standard_image != null and standard_image.get_size() == Vector2i(1024, 768), "1024x768 capture size is wrong")
	if standard_image != null and standard_image.get_size() == Vector2i(1024, 768):
		_check(_is_red(standard_image.get_pixel(80, 80)), "4:3 image did not fill the top-left corner")
		_check(_is_yellow(standard_image.get_pixel(940, 690)), "4:3 image did not fill the bottom-right corner")


func _test_fade_and_fast_return() -> void:
	var map_request_id: int = _controller.return_to_map()
	_check(map_request_id > 0, "Return-to-map request ID was not allocated")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Return-to-map did not commit MAP immediately")
	_check(_fade_overlay_count() == 1, "Opaque image did not create one fade-out overlay")
	await _wait_until(Callable(self, "_fade_overlays_finished"), FADE_TIMEOUT_MS, "Image fade-out did not release its overlay")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "Map did not redraw after image fade-out")
	var restored_map: Image = _capture_cast_image()
	_check(restored_map != null and not restored_map.is_empty(), "Map capture is empty after image fade-out")
	if restored_map != null and not restored_map.is_empty():
		var center_x: int = int(restored_map.get_width() * 0.5)
		var center_y: int = int(restored_map.get_height() * 0.5)
		var center: Color = restored_map.get_pixel(center_x, center_y)
		_check(center.g > 0.35 and center.b > 0.35, "Map was not restored after image fade-out")

	var image_ref: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	_controller.show_image(image_ref)
	_controller.return_to_map()
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Fast return did not keep MAP active")
	await _wait_until(Callable(self, "_all_image_nodes_released"), RELEASE_TIMEOUT_MS, "Fast return retained image nodes")


func _test_missing_and_corrupt_failures() -> void:
	var missing_ref: ExternalContentRef = _fixture.get("missing_image_ref") as ExternalContentRef
	var missing_request: int = _controller.show_image(missing_ref)
	_check(_failed_requests.has(missing_request), "Missing image failure signal is absent")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Missing image did not recover to MAP")
	_assert_safe_failure_message(missing_request, "Missing image")

	var corrupt_ref: ExternalContentRef = _fixture.get("corrupt_image_ref") as ExternalContentRef
	var corrupt_request: int = _controller.show_image(corrupt_ref)
	_check(_failed_requests.has(corrupt_request), "Corrupt image failure signal is absent")
	_check(_controller.active_kind == PlayerOutputController.OutputKind.MAP, "Corrupt image did not recover to MAP")
	_assert_safe_failure_message(corrupt_request, "Corrupt image")
	await _wait_for_draw(DRAW_TIMEOUT_MS, "Safe map did not draw after image failures")
	var safe_image: Image = _capture_cast_image()
	_check(safe_image != null and not safe_image.is_empty(), "Player output is blank after image failures")


func _test_ten_round_release() -> void:
	var image_ref: ExternalContentRef = _fixture.get("image_ref") as ExternalContentRef
	for round_index: int in range(10):
		_controller.show_image(image_ref)
		_check(
			_controller.active_kind == PlayerOutputController.OutputKind.IMAGE,
			"Image did not activate in round %d" % round_index
		)
		_controller.return_to_map()
		_check(
			_controller.active_kind == PlayerOutputController.OutputKind.MAP,
			"Map did not restore in round %d" % round_index
		)
	await _wait_until(Callable(self, "_all_image_nodes_released"), RELEASE_TIMEOUT_MS, "Ten rounds retained image nodes")
	_check(_all_image_nodes_released(), "Ten rounds left Presenter, texture, or fade nodes alive")


func _setup_map_world() -> void:
	_camera = Camera3D.new()
	_camera.name = "P4_2MainCamera"
	_camera.position = Vector3(0.0, 0.0, 4.0)
	_camera.current = true
	add_child(_camera)
	_map_quad = MeshInstance3D.new()
	_map_quad.name = "P4_2MapQuad"
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
	_cast_view.name = "P4_2CastView"
	add_child(_cast_view)
	_controller = PlayerOutputController.new()
	_controller.name = "P4_2PlayerOutputController"
	add_child(_controller)
	_controller.configure(_cast_view, _camera, null, Callable(self, "_fixture_module_dir"))
	_controller.output_failed.connect(_on_output_failed)


func _fixture_module_dir() -> String:
	return String(_fixture.get("module_dir", ""))


func _on_output_failed(request_id: int, _content_id: String, error: int, message: String) -> void:
	_failed_requests[request_id] = {"error": error, "message": message}


func _assert_safe_failure_message(request_id: int, context: String) -> void:
	var failure: Dictionary = _failed_requests.get(request_id, {}) as Dictionary
	var message: String = String(failure.get("message", ""))
	_check(message != "", context + " failure message is empty")
	_check(not message.contains("user://"), context + " exposed a user path")
	_check(not message.contains("res://"), context + " exposed a resource path")
	_check(not message.contains("Stack Trace"), context + " exposed a stack trace")


func _current_image_alpha() -> float:
	var nodes: Array[Node] = get_tree().get_nodes_in_group("gvtt_player_output_texture")
	for node: Node in nodes:
		var control: Control = node as Control
		if control != null and is_instance_valid(control) and control.visible:
			return control.modulate.a
	return -1.0


func _image_is_opaque() -> bool:
	return _current_image_alpha() >= 0.99


func _fade_overlay_count() -> int:
	return get_tree().get_nodes_in_group("gvtt_player_output_image_fade").size()


func _fade_overlays_finished() -> bool:
	return _fade_overlay_count() == 0


func _all_image_nodes_released() -> bool:
	return (
		get_tree().get_nodes_in_group("gvtt_player_output_presenter").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_texture").is_empty()
		and get_tree().get_nodes_in_group("gvtt_player_output_image_fade").is_empty()
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


func _wait_for_draw(timeout_ms: int, failure_message: String) -> bool:
	_frame_post_draw_received = false
	var draw_callable: Callable = Callable(self, "_on_frame_post_draw")
	if not RenderingServer.frame_post_draw.is_connected(draw_callable):
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


func _capture_cast_image() -> Image:
	var window: Window = _cast_view.get_cast_window()
	if window == null or not is_instance_valid(window):
		return null
	var texture: ViewportTexture = window.get_texture()
	return texture.get_image() if texture != null else null


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


func _is_black(color: Color) -> bool:
	return color.r < 0.05 and color.g < 0.05 and color.b < 0.05


func _is_red(color: Color) -> bool:
	return color.r > 0.65 and color.g < 0.35 and color.b < 0.35


func _is_green(color: Color) -> bool:
	return color.g > 0.55 and color.r < 0.4 and color.b < 0.4


func _is_blue(color: Color) -> bool:
	return color.b > 0.55 and color.r < 0.4 and color.g < 0.4


func _is_yellow(color: Color) -> bool:
	return color.r > 0.65 and color.g > 0.55 and color.b < 0.4


func _cleanup() -> void:
	if _controller != null and is_instance_valid(_controller):
		_controller.close_output()
	await _wait_process_frames(2, RELEASE_TIMEOUT_MS, "P4.2 cleanup timed out")
	P3_4FixtureFactory.cleanup()


func _finish() -> void:
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
		"display_server": DisplayServer.get_name(),
		"frames_drawn": Engine.get_frames_drawn(),
		"image_sha256": FileAccess.get_sha256(P3_4FixtureFactory.SOURCE_IMAGE_PATH),
	}
	print("P4_2_IMAGE_PRESENTATION_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P4_2_IMAGE_PRESENTATION_FAILURES " + JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
