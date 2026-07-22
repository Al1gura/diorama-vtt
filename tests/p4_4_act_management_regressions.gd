extends Node

const MODULE_NAME: String = "__p4_4_act_management__"
const EXTERNAL_DIR: String = "user://p4_4_external_media"
const SOURCE_IMAGE: String = "res://tests/fixtures/p3_4/quadrants_640x480.png"
const SOURCE_VIDEO: String = "res://tests/fixtures/p3_4/motion_audio_320x180.ogv"
const GM_SECRET: String = "GM_ONLY_SECRET"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _main: Node3D = null
var _image_id: String = ""
var _video_id: String = ""
var _act_id: String = ""
var _second_act_id: String = ""
var _image_item_id: String = ""
var _video_item_id: String = ""
var _text_item_id: String = ""
var _location_item_id: String = ""


func _ready() -> void:
	_main = $Main as Node3D
	await get_tree().process_frame
	_cleanup()
	_test_act_data_lifecycle()
	await get_tree().process_frame
	_test_panel_permissions_and_missing_reference()
	await _test_reusable_unordered_act_semantics()
	await _test_text_output_isolation()
	_cleanup()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"display_server": DisplayServer.get_name(),
		"failed": _failures.size(),
		"failures": _failures,
		"frames_drawn": Engine.get_frames_drawn(),
	}
	print("P4_4_ACT_MANAGEMENT_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P4_4_ACT_MANAGEMENT_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_act_data_lifecycle() -> void:
	_check(ModuleGate.create_module(MODULE_NAME) == OK, "P4.4 module could not be created")
	if not ModuleGate.has_open_module():
		return
	var external_dir: String = ProjectSettings.globalize_path(EXTERNAL_DIR)
	_check(
		DirAccess.make_dir_recursive_absolute(external_dir) == OK,
		"P4.4 external directory could not be created"
	)
	var image_path: String = external_dir.path_join("act_image.png")
	var video_path: String = external_dir.path_join("act_video.ogv")
	_check(_copy_fixture(SOURCE_IMAGE, image_path) == OK, "P4.4 image fixture copy failed")
	_check(_copy_fixture(SOURCE_VIDEO, video_path) == OK, "P4.4 video fixture copy failed")
	var image_result: Dictionary = ModuleGate.register_external_content(
		image_path,
		ExternalContentRef.ContentType.IMAGE
	)
	var video_result: Dictionary = ModuleGate.register_external_content(
		video_path,
		ExternalContentRef.ContentType.VIDEO
	)
	var image_ref: ExternalContentRef = image_result.get("content") as ExternalContentRef
	var video_ref: ExternalContentRef = video_result.get("content") as ExternalContentRef
	_image_id = image_ref.content_id if image_ref != null else ""
	_video_id = video_ref.content_id if video_ref != null else ""
	_check(
		_image_id != "" and _video_id != "",
		"P4.4 media references were not registered"
	)

	var first_scene_name: String = ModuleGate.add_scene()
	var second_scene_name: String = ModuleGate.add_scene()
	_check(first_scene_name != "" and second_scene_name != "", "P4.4 map references could not be created")
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	var first_location: LocationRef = manifest.locations[0] if manifest != null else null
	var second_location: LocationRef = (
		manifest.locations[1]
		if manifest != null and manifest.locations.size() > 1
		else null
	)
	if first_location != null:
		var first_root: Node3D = Node3D.new()
		_check(ModuleIo.save_scene_tree(first_root, first_location.canonical_path) == OK, "P4.4 first map could not be saved")
		first_root.free()
	if second_location != null:
		var second_root: Node3D = Node3D.new()
		_check(
			ModuleIo.save_scene_tree(second_root, second_location.canonical_path) == OK,
			"P4.4 second map could not be saved"
		)
		second_root.free()

	var act_result: Dictionary = ModuleGate.create_act("废弃矿井")
	var second_act_result: Dictionary = ModuleGate.create_act("常用线索")
	var disposable_act_result: Dictionary = ModuleGate.create_act("临时整理")
	var act: ActRef = act_result.get("act") as ActRef
	var second_act: ActRef = second_act_result.get("act") as ActRef
	var disposable_act: ActRef = disposable_act_result.get("act") as ActRef
	_act_id = act.act_id if act != null else ""
	_second_act_id = second_act.act_id if second_act != null else ""
	_check(
		_act_id != "" and _second_act_id != "" and disposable_act != null,
		"P4.4 acts could not be created"
	)
	var image_item_result: Dictionary = ModuleGate.add_act_item(
		_act_id,
		ActItemRef.ItemType.MEDIA,
		_image_id
	)
	var video_item_result: Dictionary = ModuleGate.add_act_item(
		_act_id,
		ActItemRef.ItemType.MEDIA,
		_video_id
	)
	var text_item_result: Dictionary = ModuleGate.add_act_item(
		_act_id,
		ActItemRef.ItemType.TEXT,
		"",
		"墙上抓痕",
		"墙上有新鲜的抓痕。",
		GM_SECRET
	)
	var location_item_result: Dictionary = ModuleGate.add_act_item(
		_act_id,
		ActItemRef.ItemType.LOCATION,
		first_location.location_id if first_location != null else ""
	)
	var image_item: ActItemRef = image_item_result.get("item") as ActItemRef
	var video_item: ActItemRef = video_item_result.get("item") as ActItemRef
	var text_item: ActItemRef = text_item_result.get("item") as ActItemRef
	var location_item: ActItemRef = location_item_result.get("item") as ActItemRef
	_image_item_id = image_item.item_id if image_item != null else ""
	_video_item_id = video_item.item_id if video_item != null else ""
	_text_item_id = text_item.item_id if text_item != null else ""
	_location_item_id = location_item.item_id if location_item != null else ""
	_check(
		_image_item_id != ""
		and _video_item_id != ""
		and _text_item_id != ""
		and _location_item_id != "",
		"P4.4 act items could not be created"
	)
	_check(ModuleGate.move_act_item(_act_id, _text_item_id, 0) == OK, "P4.4 act item reorder failed")
	_check(ModuleGate.update_act_notes(_act_id, GM_SECRET) == OK, "P4.4 act notes could not be saved")
	var duplicate_result: Dictionary = ModuleGate.add_act_item(
		_second_act_id,
		ActItemRef.ItemType.MEDIA,
		_image_id
	)
	_check(int(duplicate_result.get("error", FAILED)) == OK, "P4.4 content could not be reused across acts")
	var reusable_act: ActRef = ModuleGate.current_manifest().find_act_by_id(_second_act_id)
	_check(
		reusable_act != null
		and reusable_act.items.size() == 1
		and reusable_act.items[0].item_type == ActItemRef.ItemType.MEDIA,
		"P4.4 act without a map was not preserved"
	)
	_check(
		ModuleGate.remove_act(disposable_act.act_id) == OK,
		"P4.4 disposable act could not be removed"
	)
	_check(FileAccess.file_exists(image_path), "Removing an act deleted the source image")
	_check(ModuleGate.remove_external_content(_image_id) == OK, "P4.4 media registration could not be removed")
	var current_act: ActRef = ModuleGate.current_manifest().find_act_by_id(_act_id)
	_check(
		current_act != null and current_act.find_item(_image_item_id) != null,
		"Missing media reference was silently removed"
	)
	_check(FileAccess.file_exists(image_path), "Removing media registration deleted the source image")

	ModuleGate.close_module()
	_check(ModuleGate.open_module(MODULE_NAME) == OK, "P4.4 module could not be reopened")
	manifest = ModuleGate.current_manifest()
	current_act = manifest.find_act_by_id(_act_id) if manifest != null else null
	_check(manifest != null and manifest.acts.size() == 2, "P4.4 reusable act count did not persist")
	_check(current_act != null and current_act.items.size() == 4, "P4.4 act item count did not persist")
	_check(
		current_act != null and current_act.items[0].item_id == _text_item_id,
		"P4.4 act item order did not persist"
	)
	_check(
		current_act != null and current_act.find_item(_image_item_id) != null,
		"P4.4 missing reference did not persist"
	)
	reusable_act = manifest.find_act_by_id(_second_act_id) if manifest != null else null
	_check(
		reusable_act != null and reusable_act.items.size() == 1,
		"P4.4 mapless reusable act did not persist"
	)
	var act_data: Dictionary = current_act.to_json_dict() if current_act != null else {}
	for forbidden_key: String in [
		"order",
		"previous_act_id",
		"next_act_id",
		"completed",
		"unlocked",
		"use_count",
	]:
		_check(not act_data.has(forbidden_key), "P4.4 act persisted narrative state: " + forbidden_key)


func _test_panel_permissions_and_missing_reference() -> void:
	var panel: ActLibraryPanel = _main.get("_act_library_panel") as ActLibraryPanel
	var scene_section: VBoxContainer = _main.get("_scene_section") as VBoxContainer
	_check(panel != null, "P4.4 main window did not create the act panel")
	if panel == null:
		return
	_check(
		scene_section != null and panel.get_parent().get_index() < scene_section.get_index(),
		"P4.4 act workspace was not placed before the map asset service"
	)
	_check(panel.select_act_by_id(_act_id), "P4.4 panel could not select the act")
	_check(panel.select_item_by_id(_image_item_id), "P4.4 panel could not select missing item")
	var edit_state: Dictionary = panel.get_control_state()
	_check(bool(edit_state.get("editable", false)), "P4.4 panel did not start in edit mode")
	_check(not bool(edit_state.get("add_disabled", true)), "P4.4 add control disabled in edit mode")
	_check(bool(edit_state.get("present_disabled", false)), "P4.4 missing item remained playable")
	_check(not bool(edit_state.get("edit_disabled", true)), "P4.4 missing item could not be edited")
	_check(not bool(edit_state.get("remove_disabled", true)), "P4.4 missing item could not be removed")
	panel.apply_mode(ModeGate.AppMode.RUN)
	var run_state: Dictionary = panel.get_control_state()
	_check(not bool(run_state.get("editable", true)), "P4.4 panel remained editable in run mode")
	_check(bool(run_state.get("act_menu_disabled", false)), "P4.4 act management menu enabled in run mode")
	_check(bool(run_state.get("add_disabled", false)), "P4.4 add control enabled in run mode")
	_check(bool(run_state.get("edit_disabled", false)), "P4.4 edit control enabled in run mode")
	_check(bool(run_state.get("remove_disabled", false)), "P4.4 remove control enabled in run mode")
	_check(panel.select_item_by_id(_text_item_id), "P4.4 panel could not select text item")
	run_state = panel.get_control_state()
	_check(not bool(run_state.get("present_disabled", true)), "P4.4 text item was not available for presentation")
	panel.apply_mode(ModeGate.AppMode.EDIT)


func _test_reusable_unordered_act_semantics() -> void:
	var panel: ActLibraryPanel = _main.get("_act_library_panel") as ActLibraryPanel
	var controller: PlayerOutputController = _main.get("_player_output_controller") as PlayerOutputController
	_check(panel != null and controller != null, "P4.4 reusable act test dependencies are missing")
	if panel == null or controller == null:
		return
	var before_manifest: Dictionary = ModuleGate.current_manifest().to_json_dict()
	_check(panel.select_act_by_id(_act_id), "P4.4 reusable act could not be viewed the first time")
	_check(panel.get_viewed_act_id() == _act_id, "P4.4 panel stored the wrong viewed act")
	_check(panel.select_item_by_id(_text_item_id), "P4.4 reusable text could not be selected")
	panel.call("_present_selected")
	await _wait_for_output_kind(controller, PlayerOutputController.OutputKind.TEXT, 120)
	var first_request_id: int = controller.active_request_id
	_check(first_request_id > 0, "P4.4 first reusable act presentation did not create a request")
	_check(panel.select_act_by_id(_second_act_id), "P4.4 panel could not view another act")
	_check(
		controller.active_kind == PlayerOutputController.OutputKind.TEXT
		and controller.active_request_id == first_request_id,
		"Viewing another act changed player output"
	)
	controller.return_to_map()
	await get_tree().process_frame
	_check(panel.select_act_by_id(_act_id), "P4.4 reusable act could not be viewed again")
	_check(panel.select_act_by_id(_act_id), "P4.4 repeated viewing of the same act failed")
	_check(panel.select_item_by_id(_text_item_id), "P4.4 reusable text could not be reselected")
	panel.call("_present_selected")
	await _wait_for_output_kind(controller, PlayerOutputController.OutputKind.TEXT, 120)
	_check(
		controller.active_kind == PlayerOutputController.OutputKind.TEXT
		and controller.active_request_id > first_request_id,
		"P4.4 same act could not present the same content again"
	)
	_check(
		ModuleGate.current_manifest().to_json_dict() == before_manifest,
		"Viewing or reusing an act mutated the module manifest"
	)
	var playthrough_data: Dictionary = Playthrough.new().to_json_dict()
	for forbidden_key: String in [
		"current_act_id",
		"act_order",
		"act_history",
		"completed_acts",
		"unlocked_acts",
	]:
		_check(
			not playthrough_data.has(forbidden_key),
			"P4.4 playthrough exposed narrative act state: " + forbidden_key
		)


func _test_text_output_isolation() -> void:
	var panel: ActLibraryPanel = _main.get("_act_library_panel") as ActLibraryPanel
	var controller: PlayerOutputController = _main.get("_player_output_controller") as PlayerOutputController
	_check(panel != null and controller != null, "P4.4 output test dependencies are missing")
	if panel == null or controller == null:
		return
	_check(panel.select_act_by_id(_act_id), "P4.4 output test could not select act")
	_check(panel.select_item_by_id(_text_item_id), "P4.4 output test could not select text")
	panel.call("_present_selected")
	await _wait_for_output_kind(controller, PlayerOutputController.OutputKind.TEXT, 120)
	var cast_window: Window = _cast_window(controller)
	_check(cast_window != null, "P4.4 text output did not open player window")
	if cast_window == null:
		return
	_check(
		not _window_contains_group(cast_window, "gvtt_gm_act_control"),
		"Player window contains GM act controls"
	)
	_check(_window_contains_group(cast_window, "gvtt_player_output_text"), "Player window did not create text output")
	_check(not _window_contains_text(cast_window, GM_SECRET), "Player window exposed GM-only notes")
	_check(_window_contains_text(cast_window, "墙上有新鲜的抓痕。"), "Player window did not show text content")
	var return_map_button: Button = _main.get("_media_return_map_button") as Button
	_check(return_map_button != null and not return_map_button.disabled, "Text output cannot return to map")
	controller.show_text("empty-text", "空文本", "")
	await get_tree().process_frame
	_check(controller.active_kind == PlayerOutputController.OutputKind.MAP, "Empty text did not safely recover to map")
	var gm_status: Label = _main.get("_media_output_status_label") as Label
	_check(gm_status != null and gm_status.text.contains("失败"), "GM window did not show the text failure")
	_check(not _window_contains_group(cast_window, "gvtt_player_output_text"), "Failed text output left player text node")
	_check(not _window_contains_text(cast_window, "媒体演出失败"), "Player window exposed GM error message")
	if DisplayServer.get_name() != "headless":
		await _test_video_button_states(controller)


func _test_video_button_states(controller: PlayerOutputController) -> void:
	var video_ref: ExternalContentRef = _find_media(_video_id)
	_check(video_ref != null, "P4.4 video button test lost the video reference")
	if video_ref == null:
		return
	controller.show_video(video_ref)
	await _wait_for_video_playing(controller, 300)
	var pause_button: Button = _main.get("_media_video_pause_button") as Button
	var stop_button: Button = _main.get("_media_video_stop_button") as Button
	var return_map_button: Button = _main.get("_media_return_map_button") as Button
	_check(controller.phase == PlayerOutputController.OutputPhase.PLAYING, "P4.4 video never reached PLAYING")
	_check(pause_button != null and not pause_button.disabled, "Pause button disabled while video plays")
	_check(stop_button != null and not stop_button.disabled, "Stop button disabled while video plays")
	_check(return_map_button != null and not return_map_button.disabled, "Return-to-map disabled while video plays")
	_check(controller.pause_video() == OK, "P4.4 video pause command failed")
	await get_tree().process_frame
	_check(pause_button != null and pause_button.text == "继续", "Paused video button did not become Continue")
	_check(stop_button != null and not stop_button.disabled, "Stop button disabled while video is paused")
	_check(controller.resume_video() == OK, "P4.4 video resume command failed")
	_check(controller.stop_video() > 0, "P4.4 video stop command failed")
	await get_tree().process_frame
	_check(controller.active_kind == PlayerOutputController.OutputKind.MAP, "Video stop did not restore map")
	_check(pause_button != null and pause_button.disabled, "Pause button enabled after returning to map")
	_check(stop_button != null and stop_button.disabled, "Stop button enabled after returning to map")
	_check(return_map_button != null and return_map_button.disabled, "Return-to-map enabled while map is active")


func _wait_for_output_kind(
		controller: PlayerOutputController,
		kind: PlayerOutputController.OutputKind,
		max_frames: int
) -> void:
	for _index: int in range(max_frames):
		if controller.active_kind == kind:
			return
		await get_tree().process_frame


func _wait_for_video_playing(controller: PlayerOutputController, max_frames: int) -> void:
	for _index: int in range(max_frames):
		if (
			controller.active_kind == PlayerOutputController.OutputKind.VIDEO
			and controller.phase == PlayerOutputController.OutputPhase.PLAYING
		):
			return
		await get_tree().process_frame


func _cast_window(controller: PlayerOutputController) -> Window:
	var cast_view: CastView = controller.get("_cast_view") as CastView
	return cast_view.get_cast_window() if cast_view != null else null


func _find_media(content_id: String) -> ExternalContentRef:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return null
	for content: ExternalContentRef in manifest.external_contents:
		if content.content_id == content_id:
			return content
	return null


func _window_contains_group(window: Window, group_name: StringName) -> bool:
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if window.is_ancestor_of(node):
			return true
	return false


func _window_contains_text(window: Window, value: String) -> bool:
	for node: Node in window.find_children("*", "", true, false):
		if node is Label and String((node as Label).text).contains(value):
			return true
	return false


func _copy_fixture(source_path: String, target_path: String) -> int:
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), target_path)


func _cleanup() -> void:
	if ModuleGate.has_open_module():
		ModuleGate.close_module()
	_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(MODULE_NAME))
	_remove_dir_recursive(ProjectSettings.globalize_path(EXTERNAL_DIR))


func _remove_dir_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			var entry_path: String = dir_path.path_join(entry_name)
			if dir.current_is_dir():
				_remove_dir_recursive(entry_path)
			else:
				DirAccess.remove_absolute(entry_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
