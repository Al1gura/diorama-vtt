extends Node

const TEMP_SCENE_PATH: String = "user://p1_runtime_regression.scn"
const TEMP_MODEL_SOURCE_PATH: String = "user://p1_runtime_cache_source.glb"
const TEMP_MODEL_CATEGORY: String = "_p1_runtime_cache"
const TEMP_MODEL_FILE_NAME: String = "p1_runtime_cache_source.glb"
const TEMP_GROUND_GROUP: String = "_p1_runtime_ground"
const TEMP_MODULE_NAME: String = "_p1_runtime_regression_module"
const TEMP_EMPTY_IMPORT_SOURCE_PATH: String = "user://_p1_runtime_empty_import"
const TEMP_EMPTY_IMPORT_MODULE_NAME: String = "_p1_runtime_empty_import"
const DEFAULT_GROUND_BASE: String = "uv_checker_4096_v2"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _wall_properties_script: GDScript = load("res://scripts/wall_properties.gd")
var _empty_imported_module_name: String = ""

@onready var _main: Node3D = $Main


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_fixtures()
	_test_startup_does_not_auto_open_legacy_module()
	_test_empty_module_import_creates_first_scene()
	_open_runtime_regression_module()
	_test_module_context_boundary()
	await _test_edit_selection_pick()
	await _test_edit_token_selection_keeps_runtime_tools_off()
	await _test_mode_switch()
	await _test_pointer_gesture_cancellation()
	_test_pointer_interaction_controller_contract()
	await _test_selection_controller_contract()
	await _test_scene_persistence()
	_test_imported_ground_persistence()
	_test_placement_controller_contract()
	_test_scene_session_controller_contract()
	await _test_dirty_new_scene_cancel_does_not_create_scene()
	_test_r5_controller_contracts()
	await _test_p3_application_lifecycle_contracts()
	await _test_model_cache()
	await _test_rectangular_grid()
	_test_model_root_reset()
	await _test_runtime_token_movement()
	await _test_runtime_selection_panel_entity_variants()
	_test_movement_path_following()
	_cleanup_fixtures()

	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P1_RUNTIME_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P1_RUNTIME_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_startup_does_not_auto_open_legacy_module() -> void:
	_check(not ModuleGate.has_open_module(), "Startup auto-opened a module")
	_check(ModuleGate.current_module_name() == "", "Startup selected a module name")
	_check(ModuleGate.current_location() == "", "Startup selected a scene")
	_check(ModuleGate.list_scene_names().is_empty(), "Startup exposed old scene names")
	_check(String(_main.get("_current_scene_name")) == "", "Main startup selected a scene")
	_check(not bool(_main.call("_has_editable_scene")), "Startup unlocked scene editing")
	var startup_resources_activated: Variant = _main.get("_editor_resources_activated")
	_check(
		startup_resources_activated is bool and startup_resources_activated == false,
		"Startup activated editor resource warming before a module was opened"
	)
	var startup_model_requests: Array = _main.get("_model_thread_paths") as Array
	_check(
		startup_model_requests != null and startup_model_requests.is_empty(),
		"Startup queued model cache loads before a module was opened"
	)
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var project_source: String = FileAccess.get_file_as_string("res://project.godot")
	_check(
		project_source.contains('run/main_scene="res://scenes/module_home.tscn"'),
		"Project startup scene is not the standalone module selector"
	)
	_check(
		FileAccess.file_exists("res://scenes/module_home.tscn")
		and FileAccess.file_exists("res://scripts/module_home.gd"),
		"Standalone module selector scene is missing"
	)
	_check(main_source.contains("_build_module_home") == false, "Editor still builds ModuleHome")
	_check(
		not main_source.contains("_try_open_development_workspace"),
		"Main still contains a development-only module auto-open path"
	)
	var content_root: Node3D = _main.get("_content_root") as Node3D
	var child_count: int = content_root.get_child_count()
	_main.call("_place_model", "_missing", 0)
	_check(
		content_root.get_child_count() == child_count,
		"Placement changed ContentRoot without an open module and scene"
	)


func _test_empty_module_import_creates_first_scene() -> void:
	var dir_err: int = DirAccess.make_dir_recursive_absolute(TEMP_EMPTY_IMPORT_SOURCE_PATH)
	_check(dir_err == OK, "Empty import fixture directory could not be created")
	if dir_err != OK:
		return
	var import_err: int = ModuleGate.import_module_from_path(TEMP_EMPTY_IMPORT_SOURCE_PATH)
	_check(import_err == OK, "Empty module directory could not be imported")
	if import_err != OK:
		return
	_empty_imported_module_name = ModuleGate.current_module_name()
	var scene_names: Array[String] = ModuleGate.list_scene_names()
	_check(scene_names.size() == 1, "Empty imported module did not create exactly one scene")
	_check(scene_names[0] == "场景1", "Empty imported module did not create 场景1")
	if not scene_names.is_empty():
		var imported_manifest: ModuleManifest = ModuleGate.current_manifest()
		var imported_location: LocationRef = imported_manifest.find_location(scene_names[0])
		var scene_path: String = imported_location.canonical_path if imported_location != null else ""
		_check(FileAccess.file_exists(scene_path), "Empty imported module's first scene was not saved")
	_check(bool(_main.call("_has_editable_scene")), "Imported module did not unlock editing")
	ModuleGate.close_module()
	_check(not bool(_main.call("_has_editable_scene")), "Closing a module did not lock editing")


func _open_runtime_regression_module() -> void:
	var err: int = ModuleGate.create_module(TEMP_MODULE_NAME)
	_check(err == OK, "Regression module could not be created")
	var scene_names: Array[String] = ModuleGate.list_scene_names()
	_check(scene_names.size() == 1, "Regression module did not auto-create exactly one scene")
	if scene_names.is_empty():
		return
	var scene_name: String = scene_names[0]
	_check(
		String(_main.get("_current_scene_name")) == scene_name,
		"Regression scene was not opened"
	)
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	var location: LocationRef = manifest.find_location(scene_name)
	var scene_path: String = location.canonical_path if location != null else ""
	_check(FileAccess.file_exists(scene_path), "Regression module's first scene was not saved")


func _test_module_context_boundary() -> void:
	var app_menu_button: MenuButton = _main.get("_app_menu_btn") as MenuButton
	var module_name_label: Label = _main.get("_current_module_label") as Label
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(app_menu_button != null, "File menu is missing")
	_check(app_menu_button != null and app_menu_button.text == "文件", "File menu label is incorrect")
	var app_popup: PopupMenu = app_menu_button.get_popup() if app_menu_button != null else null
	_check(app_popup != null and app_popup.item_count == 2, "File menu does not contain exactly two module commands")
	if app_popup != null:
		var expected_commands: Dictionary = {
			1: "保存模组",
			3: "选择模组",
		}
		for command_id_value: Variant in expected_commands.keys():
			var command_id: int = int(command_id_value)
			var item_index: int = app_popup.get_item_index(command_id)
			_check(item_index >= 0, "File menu command ID is missing: " + str(command_id))
			_check(
				item_index >= 0 and app_popup.get_item_text(item_index) == String(expected_commands[command_id]),
				"File menu command text is incorrect: " + str(command_id)
			)
	_check(_main.has_method("_save_current_module"), "Save-module command is missing")
	_check(_main.has_method("_select_module"), "Select-module command is missing")
	_check(_main.has_method("_show_add_table_dialog"), "Add-table command is missing")
	_check(_main.has_method("_show_playthrough_dialog"), "Start-playthrough dialog command is missing")
	_check(_main.get("_playthrough_list") == null, "Edit panel still owns the playthrough list")
	_check(_main.get("_add_table_button") == null, "Edit panel still owns the add-table button")
	_check(not main_source.contains("关闭模组"), "Editor still presents module selection as closing")
	_check(module_name_label != null, "Current module status label is missing")
	_check(
		module_name_label != null and module_name_label.text == TEMP_MODULE_NAME,
		"Current module status label does not show the open module"
	)
	_check(not main_source.contains("_module_home_btn"), "Editor still contains a module-home toolbar button")
	_check(not main_source.contains("返回编辑器"), "Module selector still offers temporary return to editor")
	_check(not main_source.contains("ModuleHome"), "Editor still contains the module selector")
	var mode_button: Button = _main.get("_mode_btn") as Button
	_check(
		mode_button != null and mode_button.text == "开始 ▶",
		"Recorded runtime entry is not labeled 开始"
	)
	var test_button: Button = _main.get("_test_btn") as Button
	_check(
		test_button != null and test_button.text == "测试 ▶",
		"Temporary runtime entry is not labeled 测试"
	)
	var editor_resources_activated: Variant = _main.get("_editor_resources_activated")
	_check(
		editor_resources_activated is bool and editor_resources_activated == true,
		"Opening a module did not activate editor resource warming"
	)
	if _main.has_method("_select_module"):
		_main.call("_select_module")
	else:
		ModuleGate.close_module()
	_check(not ModuleGate.has_open_module(), "Selecting another module did not clear module truth")
	_check(module_name_label != null and module_name_label.text == "", "Selecting a module left stale context text")
	_check(not bool(_main.call("_has_editable_scene")), "Selecting a module left editing unlocked")
	var reopen_err: int = ModuleGate.open_module(TEMP_MODULE_NAME)
	_check(reopen_err == OK, "Module could not reopen after returning to module selector")
	_check(ModuleGate.has_open_module(), "Reopened module did not restore module truth")
	_check(module_name_label != null and module_name_label.text == TEMP_MODULE_NAME, "Reopened module context is stale")
	_check(bool(_main.call("_has_editable_scene")), "Reopened module did not unlock the editor")


func _test_edit_selection_pick() -> void:
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame
	await get_tree().physics_frame
	var content_root: Node3D = _main.get("_content_root") as Node3D
	var target: Node3D = null
	var proxy: PickProxy = null
	var created_fixture: bool = false
	for child: Node in content_root.get_children():
		if not (child is Node3D):
			continue
		var candidate: Node3D = child as Node3D
		var candidate_proxy: PickProxy = candidate.get_node_or_null("PickProxy") as PickProxy
		if candidate_proxy != null:
			target = candidate
			proxy = candidate_proxy
			break
	if target == null or proxy == null:
		target = _create_selection_pick_fixture(content_root)
		proxy = target.get_node_or_null("PickProxy") as PickProxy
		created_fixture = true
		await get_tree().process_frame
		await get_tree().physics_frame
	_check(target != null and proxy != null, "鐪熷疄璇诲洖鍦烘櫙娌℃湁鍙祴璇曠殑 PickProxy")
	if target == null or proxy == null:
		return
	var area: Area3D = proxy.get_node_or_null("PickProxyArea") as Area3D
	var shape_node: CollisionShape3D = null
	if area != null:
		shape_node = area.get_child(0) as CollisionShape3D
	_check(area != null and shape_node != null, "鐪熷疄璇诲洖 PickProxy 娌℃湁閲嶅缓杩愯鏈熸嬀鍙栫洅")
	if area == null or shape_node == null:
		return
	var camera: Camera3D = _main.get("camera") as Camera3D
	var screen_position: Vector2 = camera.unproject_position(shape_node.global_position)
	var picked: Node3D = _main.call(
		"_pick_entity_at_screen_position", screen_position) as Node3D
	_check(picked == target, "缂栬緫鎬佸皠绾挎病鏈夊懡涓湡瀹炶鍥炵墿浣撶殑 PickProxy")
	if picked == null:
		return
	var gizmo: Gizmo3D = _main.get("_gizmo") as Gizmo3D
	_main.call("_deselect")
	var press_event: InputEventMouseButton = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.position = screen_position
	press_event.global_position = screen_position
	press_event.pressed = true
	get_viewport().push_input(press_event, true)
	await get_tree().process_frame
	var dispatched_target: Node3D = _main.call("_get_selected_target") as Node3D
	_check(dispatched_target == target, "Edit selection input did not update selection controller")
	_check(gizmo != null and gizmo.visible, "缂栬緫鎬佺湡瀹炶緭鍏ユ淳鍙戝悗 Gizmo 娌℃湁鏄剧ず")
	_main.call("_deselect")
	_main.call("_select_entity", picked)
	_check(gizmo != null and gizmo.visible, "缂栬緫鎬侀€変腑鍚?Gizmo 娌℃湁绔嬪嵆鏄剧ず")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_main.call("_get_selected_target") == target, "Edit ray pick did not update selection controller")
	_check(gizmo != null and gizmo.get_selected_count() == 1, "缂栬緫鎬?Gizmo 娌℃湁淇濆瓨閫変腑瀵硅薄")
	_check(gizmo != null and gizmo.is_processing(), "Edit selection did not enable Gizmo processing")
	_check(
		gizmo != null and gizmo.visible,
		"缂栬緫鎬侀€変腑鐪熷疄璇诲洖鐗╀綋鍚庢病鏈夋樉绀?Gizmo"
	)
	_main.call("_deselect")
	if created_fixture:
		content_root.remove_child(target)
		target.free()


func _create_selection_pick_fixture(content_root: Node3D) -> Node3D:
	var target: Node3D = Node3D.new()
	target.name = "SelectionPickFixture"
	content_root.add_child(target)
	target.owner = content_root
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	mesh_instance.mesh = box_mesh
	mesh_instance.position.y = 0.5
	target.add_child(mesh_instance)
	mesh_instance.owner = content_root
	var properties: EntityProperties = EntityProperties.new()
	properties.name = "EntityProperties"
	properties.configure_from_category("decor")
	target.add_child(properties)
	properties.owner = content_root
	var proxy: PickProxy = PickProxy.new()
	proxy.name = "PickProxy"
	proxy.target_node = target
	target.add_child(proxy)
	proxy.owner = content_root
	target.force_update_transform()
	proxy.fit_from_target_synced()
	return target


func _test_edit_token_selection_keeps_runtime_tools_off() -> void:
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame
	var content_root: Node3D = _main.get("_content_root") as Node3D
	var token: Node3D = Node3D.new()
	token.name = "EditOnlyTokenToolFixture"
	content_root.add_child(token)
	var props: EntityProperties = EntityProperties.new()
	props.name = "EntityProperties"
	props.configure_from_category("token")
	token.add_child(props)
	_check(
		bool(_main.call("_ensure_entity_type_properties_for_root", token, props)),
		"Edit Token fixture did not receive TokenProperties"
	)
	_main.call("_select_entity", token)
	await get_tree().process_frame
	await get_tree().physics_frame
	var pointer: Object = _get_pointer_controller()
	_check(
		not bool(pointer.call("is_combat_aim_active")),
		"Edit-mode Token selection incorrectly started combat aim"
	)
	_check(
		not bool(pointer.call("should_block_entity_selection")),
		"Edit-mode Token selection incorrectly blocked normal picking"
	)
	_check(
		not bool(_main.call("_toggle_combat_line_lock")),
		"Edit mode unexpectedly allowed combat line locking"
	)
	var los_service: Node = _main.get("_los_service") as Node
	_check(
		los_service != null and los_service.call("get_observer_token") == token,
		"Edit-mode Token selection did not switch the LOS observer"
	)
	_main.call("_deselect")
	content_root.remove_child(token)
	token.free()


func _push_left_mouse_button(screen_position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_position
	event.global_position = screen_position
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _push_left_mouse_motion(screen_position: Vector2, relative: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = screen_position
	event.global_position = screen_position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event, true)


func _push_mouse_button(screen_position: Vector2, button_index: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.position = screen_position
	event.global_position = screen_position
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _push_key(keycode: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	get_viewport().push_input(event, true)


func _test_selection_controller_contract() -> void:
	var controller_script: GDScript = load("res://scripts/selection_controller.gd") as GDScript
	_check(controller_script != null, "R2 selection controller script is missing")
	if controller_script == null:
		return
	var controller: Object = controller_script.new()
	_check(controller != null, "R2 selection controller could not be created")
	if controller == null:
		return
	var target: Node3D = Node3D.new()
	target.name = "SelectionControllerTarget"
	add_child(target)
	var props: EntityProperties = EntityProperties.new()
	props.display_name = "Selection Controller Target"
	target.add_child(props)
	controller.call("select", target, props)
	_check(
		bool(controller.call("has_selection")),
		"R2 selection controller did not keep the selected target"
	)
	_check(
		controller.call("get_current_target") == target,
		"R2 selection controller returned the wrong selected target"
	)
	_check(
		controller.call("get_current_properties") == props,
		"R2 selection controller returned the wrong selected properties"
	)
	controller.call("clear")
	_check(
		not bool(controller.call("has_selection")),
		"R2 selection controller did not clear selection"
	)
	controller.call("select", target, props)
	target.queue_free()
	await get_tree().process_frame
	_check(
		not bool(controller.call("has_selection")),
		"R2 selection controller kept a freed target selected"
	)


func _test_placement_controller_contract() -> void:
	var controller_script: GDScript = load("res://scripts/placement_controller.gd") as GDScript
	_check(controller_script != null, "R3 placement controller script is missing")
	if controller_script == null:
		return
	var controller: Object = controller_script.new()
	_check(controller != null, "R3 placement controller could not be created")
	if controller == null:
		return
	_check(
		controller.has_method("create_drag_preview"),
		"R3 placement controller lacks drag preview entry"
	)
	_check(
		controller.has_method("place_model"),
		"R3 placement controller lacks model placement entry"
	)
	_check(
		controller.has_method("clear_drag_preview"),
		"R3 placement controller lacks preview cleanup entry"
	)


func _test_scene_session_controller_contract() -> void:
	var controller_script: GDScript = load("res://scripts/scene_session_controller.gd") as GDScript
	_check(controller_script != null, "R4 scene session controller script is missing")
	if controller_script == null:
		return
	var controller: Object = controller_script.new()
	_check(controller != null, "R4 scene session controller could not be created")
	if controller == null:
		return
	for method_name: String in [
		"configure",
		"apply_default_scene",
		"switch_to_scene",
		"save_current_scene",
		"mark_dirty",
		"is_dirty",
		"clear_dirty",
		"set_current_scene_name",
		"get_current_scene_name",
	]:
		_check(
			controller.has_method(method_name),
			"R4 scene session controller lacks " + method_name
		)
	controller.call("set_current_scene_name", "R4ContractScene")
	_check(
		String(controller.call("get_current_scene_name")) == "R4ContractScene",
		"R4 scene session controller did not keep current scene name"
	)
	controller.call("mark_dirty")
	_check(
		bool(controller.call("is_dirty")),
		"R4 scene session controller did not mark dirty state"
	)
	controller.call("clear_dirty")
	_check(
		not bool(controller.call("is_dirty")),
		"R4 scene session controller did not clear dirty state"
	)


func _test_dirty_new_scene_cancel_does_not_create_scene() -> void:
	var before_scene_name: String = _main.get("_current_scene_name")
	var before_location: String = ModuleGate.current_location()
	var before_names: Array[String] = ModuleGate.list_scene_names()
	var was_dirty: bool = bool(_main.get("_scene_dirty"))
	_main.call("_mark_scene_dirty")
	_main.call("_on_new_scene_pressed")
	await get_tree().process_frame
	_check(
		bool(_main.get("_pending_create_scene")),
		"R4 dirty new-scene flow did not defer scene creation"
	)
	_main.call("_on_switch_dialog_cancel")
	await get_tree().process_frame
	var after_names: Array[String] = ModuleGate.list_scene_names()
	_check(
		after_names.size() == before_names.size(),
		"R4 canceling dirty new-scene flow created a scene"
	)
	_check(
		ModuleGate.current_location() == before_location,
		"R4 canceling dirty new-scene flow changed ModuleGate current location"
	)
	_check(
		String(_main.get("_current_scene_name")) == before_scene_name,
		"R4 canceling dirty new-scene flow changed main current scene"
	)
	var controller: Object = _main.get("_scene_session_controller") as Object
	if was_dirty:
		controller.call("mark_dirty")
		_main.set("_scene_dirty", true)
	else:
		controller.call("clear_dirty")
		_main.set("_scene_dirty", false)


func _test_r5_controller_contracts() -> void:
	var camera_script: GDScript = load("res://scripts/camera_view_controller.gd") as GDScript
	_check(camera_script != null, "R5 camera view controller script is missing")
	if camera_script != null:
		var camera_controller: Object = camera_script.new()
		for method_name: String in [
			"configure",
			"apply_current_view",
			"apply_for_mode",
			"zoom",
			"orbit",
			"pan",
			"save_play_view",
			"restore_play_view",
			"is_map_view",
			"get_camera",
			"get_map_size",
			"set_map_size",
			"get_orbit_dist",
			"set_orbit_dist",
		]:
			_check(
				camera_controller.has_method(method_name),
				"R5 camera view controller lacks " + method_name
			)
	var ui_script: GDScript = load("res://scripts/main_ui_controller.gd") as GDScript
	_check(ui_script != null, "R5 main UI controller script is missing")
	if ui_script != null:
		var ui_controller: Object = ui_script.new()
		for method_name: String in [
			"configure",
			"apply_for_mode",
			"apply_topbar_for_mode",
			"apply_panel_for_mode",
			"is_over_left_panel",
			"is_over_property_panel",
			"show_property_panel",
			"hide_property_panel",
		]:
			_check(
				ui_controller.has_method(method_name),
				"R5 main UI controller lacks " + method_name
			)


func _test_p3_application_lifecycle_contracts() -> void:
	var startup_log: Array[String] = _string_array_from_variant(
		_main.call("get_application_contract_log")
	)
	_check_log_sequence(
		startup_log,
		[
			"startup:begin",
			"startup:window_state",
			"startup:content_roots",
			"startup:controllers_added",
			"startup:world_services",
			"startup:ui_built",
			"startup:dependencies_injected",
			"startup:signals_connected",
			"startup:mode_applied",
			"startup:end",
		],
		"P3 startup assembly contract order changed"
	)

	_main.call("clear_application_contract_log")
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	await get_tree().process_frame
	_check_log_sequence(
		_string_array_from_variant(_main.call("get_application_contract_log")),
		[
			"mode_change:begin",
			"mode_change:pointer",
			"mode_change:selection",
			"mode_change:topbar",
			"mode_change:panel",
			"mode_change:camera",
			"mode_change:gizmo",
			"mode_change:walls",
			"mode_change:token_drag",
			"mode_change:pick_proxy",
			"mode_change:end",
		],
		"P3 mode switch contract order changed"
	)
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame

	var current_scene_name: String = String(_main.get("_current_scene_name"))
	_main.call("clear_application_contract_log")
	_main.call("_switch_to_scene", current_scene_name)
	await get_tree().process_frame
	_check_log_sequence(
		_string_array_from_variant(_main.call("get_application_contract_log")),
		[
			"scene_switch:begin",
			"scene_switch:cleanup:begin",
			"scene_switch:cleanup:player_output",
			"scene_switch:cleanup:pointer",
			"scene_switch:cleanup:movement",
			"scene_switch:cleanup:runtime_tokens",
			"scene_switch:cleanup:selection",
			"scene_switch:cleanup:end",
			"scene_switch:session",
			"scene_switch:ui",
			"scene_switch:end",
		],
		"P3 scene switch cleanup contract order changed"
	)

	_main.call("_start_new_playthrough")
	await get_tree().process_frame
	_check(ModuleGate.current_session() != null, "P3 lifecycle contract could not start a playthrough before module close")
	_main.call("clear_application_contract_log")
	_main.call("_select_module")
	await get_tree().process_frame
	_check_log_sequence(
		_string_array_from_variant(_main.call("get_application_contract_log")),
		[
			"session_save:prepare:begin",
			"session_save:prepare:end",
			"session_save:begin",
			"session_save:snapshot",
			"session_save:index",
			"session_save:end",
			"mode_change:token_drag",
			"module_close:begin",
			"module_close:scene_name",
			"scene_switch:cleanup:movement",
			"scene_switch:cleanup:runtime_tokens",
			"module_close:default_scene",
			"module_close:scene_list",
			"module_close:home_scene",
			"module_close:end",
		],
		"P3 module close contract order changed"
	)
	var open_err: int = ModuleGate.open_module(TEMP_MODULE_NAME)
	_check(open_err == OK, "P3 lifecycle contract could not reopen regression module")
	await get_tree().process_frame

	_main.call("_start_new_playthrough")
	await get_tree().process_frame
	_check(ModuleGate.current_session() != null, "P3 lifecycle contract could not start a playthrough before exit")
	_main.call("clear_application_contract_log")
	_main.call("_prepare_application_exit")
	_check_log_sequence(
		_string_array_from_variant(_main.call("get_application_contract_log")),
		[
			"exit:begin",
			"session_save:prepare:begin",
			"session_save:prepare:end",
			"session_save:begin",
			"session_save:snapshot",
			"session_save:index",
			"session_save:end",
			"exit:session_saved",
			"exit:pointer",
			"exit:movement",
			"exit:combat",
			"exit:cast",
			"exit:window_state",
			"exit:end",
		],
		"P3 application exit cleanup contract order changed"
	)
	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	var playthrough_mode_button: Button = _main.get("_mode_btn") as Button
	_check(
		playthrough_mode_button != null
		and playthrough_mode_button.text == "开始 ▶",
		"Multiple playthroughs changed the recorded entry away from 开始"
	)
	var camera_controller: Object = _main.get("_camera_view_controller") as Object
	if camera_controller != null:
		var original_map_size: float = float(camera_controller.call("get_map_size"))
		var original_orbit_dist: float = float(camera_controller.call("get_orbit_dist"))
		camera_controller.call("set_map_size", 17.0)
		_check(
			is_equal_approx(float(camera_controller.call("get_map_size")), 17.0),
			"P3 camera controller did not retain map size"
		)
		camera_controller.call("set_orbit_dist", 33.0)
		_check(
			is_equal_approx(float(camera_controller.call("get_orbit_dist")), 33.0),
			"P3 camera controller did not retain orbit distance"
		)
		camera_controller.call("set_map_size", original_map_size)
		camera_controller.call("set_orbit_dist", original_orbit_dist)
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(
		not main_source.contains("var _map_size:")
		and not main_source.contains("var _orbit_dist:")
		and not main_source.contains("var _saved_orbit_dist:"),
		"P3 main reintroduced camera mirror truth"
	)
	_check_no_global_module_gate_access(
		"res://scripts/scene_session_controller.gd",
		"P3 scene session controller still reaches ModuleGate directly"
	)
	_check_no_global_module_gate_access(
		"res://scripts/placement_controller.gd",
		"P3 placement controller still reaches ModuleGate directly"
	)


func _check_no_global_module_gate_access(path: String, message: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	_check(not text.contains("ModuleGate."), message)


func _get_pointer_controller() -> Object:
	return _main.get("_pointer_controller") as Object


func _get_placement_controller() -> Object:
	return _main.get("_placement_controller") as Object


func _test_mode_switch() -> void:
	var left_panel: Control = _main.get("_left_panel") as Control
	var media_section: Control = _main.get("_media_section") as Control
	var scene_section: Control = _main.get("_scene_section") as Control
	var media_edit_row: Control = _main.get("_media_edit_row") as Control
	_check(left_panel != null and left_panel.visible, "缂栬緫鎬佸乏渚у伐鍏锋爮搴斿彲瑙?")
	_check(media_section != null and media_section.visible, "缂栬緫鎬佸獟浣撳垎鍖哄簲鍙")
	var pointer: Object = _get_pointer_controller()
	pointer.call("begin_camera_orbit", Vector2(10.0, 10.0))
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	await get_tree().process_frame
	_check(left_panel != null and left_panel.visible, "杩愯鎬佸簲淇濈暀濯掍綋鎿嶄綔宸﹁竟鏍忔壳")
	_check(media_section != null and media_section.visible, "杩愯鎬佸獟浣撳垎鍖哄簲鍙")
	_check(scene_section != null and not scene_section.visible, "Run mode exposed scene authoring controls")
	_check(media_edit_row != null and not media_edit_row.visible, "Run mode exposed media registration controls")
	_check(bool(pointer.call("is_idle")), "鍒囧埌杩愯鎬佸悗鐩告満鎵嬪娍浠嶆畫鐣?")
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame
	_check(left_panel != null and left_panel.visible, "鍒囧洖缂栬緫鎬佸悗宸ュ叿鏍忓簲鎭㈠")
	_check(scene_section != null and scene_section.visible, "Edit mode did not restore scene authoring controls")
	_check(media_edit_row != null and media_edit_row.visible, "Edit mode did not restore media registration controls")


func _test_pointer_gesture_cancellation() -> void:
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame
	var candidate_button: Button = Button.new()
	add_child(candidate_button)
	var runtime_target: Node3D = Node3D.new()
	add_child(runtime_target)
	var pointer: Object = _get_pointer_controller()
	pointer.call(
		"begin_model_candidate", candidate_button, "props", 0, Vector2(10.0, 10.0)
	)
	_main.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await get_tree().process_frame
	_check(bool(pointer.call("is_idle")), "绐楀彛澶辩劍鍚庣礌鏉愬€欓€夋墜鍔夸粛娈嬬暀")

	pointer.call(
		"begin_runtime_token_candidate", runtime_target, Vector2(20.0, 20.0)
	)
	var current_scene_name: String = _main.get("_current_scene_name")
	_main.call("_switch_to_scene", current_scene_name)
	await get_tree().process_frame
	_check(bool(pointer.call("is_idle")), "鍒囧満鏅悗杩愯鎬佹寚閽堝€欓€変粛娈嬬暀")

	pointer.call("begin_camera_pan", Vector2(30.0, 30.0))
	_main.notification(NOTIFICATION_WM_MOUSE_EXIT)
	await get_tree().process_frame
	_check(bool(pointer.call("is_idle")), "榧犳爣绂诲紑绐楀彛鍚庣浉鏈哄钩绉绘墜鍔夸粛娈嬬暀")
	remove_child(candidate_button)
	candidate_button.free()
	remove_child(runtime_target)
	runtime_target.free()


func _test_pointer_interaction_controller_contract() -> void:
	var controller_script: GDScript = load(
		"res://scripts/pointer_interaction_controller.gd") as GDScript
	_check(controller_script != null, "R1 鎸囬拡浜や簰鎺у埗鍣ㄨ剼鏈笉瀛樺湪")
	if controller_script == null:
		return
	var controller: Object = controller_script.new()
	var button: Button = Button.new()
	add_child(button)
	_check(
		bool(controller.call(
			"begin_model_candidate", button, "token", 2, Vector2(10.0, 10.0)
		)),
		"绱犳潗鍊欓€夋墜鍔挎病鏈夎繘鍏ユ帶鍒跺櫒"
	)
	_check(
		String(controller.call("get_gesture_name")) == "MODEL_CANDIDATE",
		"绱犳潗鍊欓€夌姸鎬佸悕閿欒"
	)
	_check(
		not bool(controller.call(
			"is_model_drag_threshold_met", Vector2(15.0, 10.0)
		)),
		"绱犳潗鍊欓€?5 鍍忕礌鎶栧姩琚敊璇瘑鍒负鎷栨斁"
	)
	_check(
		bool(controller.call(
			"is_model_drag_threshold_met", Vector2(16.0, 10.0)
		)),
		"绱犳潗鍊欓€夎揪鍒?6 鍍忕礌鍚庢病鏈夎Е鍙戞嫋鏀鹃槇鍊?"
	)
	_check(
		bool(controller.call("begin_model_drag", Vector2(16.0, 10.0))),
		"绱犳潗鍊欓€夋病鏈夊垏鍒版嫋鏀剧姸鎬?"
	)
	_check(
		String(controller.call("get_model_category")) == "token",
		"绱犳潗鎷栨斁娌℃湁淇濈暀绫诲埆"
	)
	_check(
		int(controller.call("get_model_index")) == 2,
		"绱犳潗鎷栨斁娌℃湁淇濈暀绱㈠紩"
	)
	controller.call("reset")
	var token_target: Node3D = Node3D.new()
	add_child(token_target)
	_check(
		bool(controller.call(
			"begin_runtime_token_candidate", token_target, Vector2(20.0, 20.0)
		)),
		"Token 鍊欓€夋墜鍔挎病鏈夎繘鍏ユ帶鍒跺櫒"
	)
	_check(
		not bool(controller.call(
			"is_runtime_token_drag_threshold_met", Vector2(25.0, 20.0)
		)),
		"Token 鍊欓€?5 鍍忕礌鎶栧姩琚敊璇瘑鍒负鎷栧姩"
	)
	_check(
		bool(controller.call(
			"is_runtime_token_drag_threshold_met", Vector2(26.0, 20.0)
		)),
		"Token 鍊欓€夎揪鍒?6 鍍忕礌鍚庢病鏈夎Е鍙戞嫋鍔ㄩ槇鍊?"
	)
	_check(
		bool(controller.call("begin_runtime_token_drag", token_target)),
		"Token 鍊欓€夋病鏈夊垏鍒版嫋鍔ㄧ姸鎬?"
	)
	_check(
		controller.call("get_runtime_token_target") == token_target,
		"Token 鎷栧姩娌℃湁淇濈暀鐩爣"
	)
	controller.call("reset")
	_check(
		bool(controller.call("begin_camera_orbit", Vector2(30.0, 30.0))),
		"鐩告満鏃嬭浆鎵嬪娍娌℃湁杩涘叆鎺у埗鍣?"
	)
	_check(
		not bool(controller.call("begin_camera_pan", Vector2(30.0, 30.0))),
		"鐩告満鏃嬭浆鏈熼棿浠嶅厑璁镐腑閿钩绉绘姠鍗犲悓涓€鎵嬪娍"
	)
	controller.call("reset")
	remove_child(button)
	button.free()
	remove_child(token_target)
	token_target.free()


func _test_scene_persistence() -> void:
	var content: Node3D = Node3D.new()
	content.name = "AuditContent"
	add_child(content)

	var entity: Node3D = Node3D.new()
	entity.name = "AuditEntity"
	content.add_child(entity)
	entity.owner = content

	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	entity.add_child(mesh)
	mesh.owner = content

	var props: EntityProperties = EntityProperties.new()
	props.name = "EntityProperties"
	props.display_name = "瀹¤鐗╀欢"
	props.configure_from_category("wall")
	props.destructible = true
	props.max_hp = 37
	entity.add_child(props)
	props.owner = content

	var wall_props: Node = _wall_properties_script.new() as Node
	wall_props.name = "WallProperties"
	wall_props.call("configure_from_legacy", props)
	entity.add_child(wall_props)
	wall_props.owner = content

	var proxy: PickProxy = PickProxy.new()
	proxy.name = "PickProxy"
	proxy.target_node = entity
	entity.add_child(proxy)
	proxy.owner = content
	await get_tree().process_frame

	var save_error: int = ModuleIo.save_scene_tree(content, TEMP_SCENE_PATH)
	_check(save_error == OK, "鍦烘櫙淇濆瓨澶辫触")
	_check(proxy.get_parent() == entity, "淇濆瓨鍚庢嬀鍙栦唬鐞嗘病鏈夋仮澶嶅埌鍘熺埗鑺傜偣")
	_check(proxy.owner == content, "淇濆瓨鍚庢嬀鍙栦唬鐞?owner 娌℃湁鎭㈠")

	var loaded: Node = ModuleIo.load_scene_tree(TEMP_SCENE_PATH)
	_check(loaded != null, "鍦烘櫙鍔犺浇澶辫触")
	if loaded != null:
		var loaded_entity: Node3D = loaded.get_node_or_null("AuditEntity") as Node3D
		_check(loaded_entity != null, "鎸佷箙鐗╀欢鍦ㄥ瓨璇诲悗涓㈠け")
		if loaded_entity != null:
			var loaded_props: EntityProperties = (
				loaded_entity.get_node_or_null("EntityProperties") as EntityProperties
			)
			var loaded_proxy: PickProxy = (
				loaded_entity.get_node_or_null("PickProxy") as PickProxy
			)
			var loaded_wall_props: Node = loaded_entity.get_node_or_null("WallProperties")
			_check(loaded_props != null, "鐗╀欢灞炴€х粍浠跺湪瀛樿鍚庝涪澶?")
			if loaded_props != null:
				_check(loaded_props.display_name == "瀹¤鐗╀欢", "鐗╀欢鍚嶇О灞炴€ф湭鎸佷箙鍖?")
				_check(loaded_props.schema_version == EntityProperties.SCHEMA_VERSION, "schema 鐗堟湰鏈寔涔呭寲")
				_check(
					loaded_props.entity_type == EntityProperties.EntityType.WALL,
					"瀵硅薄璇箟绫诲瀷鏈寔涔呭寲"
				)
				_check(loaded_props.category == "wall", "鐗╀欢绫诲埆灞炴€ф湭鎸佷箙鍖?")
				_check(loaded_props.destructible, "鍙牬鍧忓睘鎬ф湭鎸佷箙鍖?")
				_check(loaded_props.max_hp == 37, "鐢熷懡鍊煎睘鎬ф湭鎸佷箙鍖?")
			_check(loaded_wall_props != null, "澧欎綋涓撳睘灞炴€х粍浠跺湪瀛樿鍚庝涪澶?")
			if loaded_wall_props != null:
				_check(loaded_wall_props.get("destructible"), "澧欎綋鍙牬鍧忓睘鎬ф湭鎸佷箙鍖?")
				_check(loaded_wall_props.get("durability_max") == 37, "澧欎綋鏈€澶ц€愪箙鏈粠鏃у瓧娈佃縼鍏?")
				_check(loaded_wall_props.get("durability_current") == 37, "澧欎綋褰撳墠鑰愪箙鏈粠鏃у瓧娈佃縼鍏?")
				_check(loaded_wall_props.get("blocks_los"), "澧欎綋鎸¤绾垮睘鎬ф湭杩佸叆")
				_check(loaded_wall_props.get("blocks_shot"), "澧欎綋鎸℃灙绾垮睘鎬ф湭杩佸叆")
			_check(loaded_proxy != null, "鎷惧彇浠ｇ悊鍦ㄥ瓨璇诲悗涓㈠け")
			if loaded_proxy != null:
				_check(loaded_proxy.target_node == loaded_entity, "鎷惧彇浠ｇ悊鐩爣寮曠敤鏈噸杩?")
				_check(
					loaded_proxy.get_node_or_null("PickProxyArea") == null,
					"杩愯鏈熸嬀鍙栬妭鐐硅閿欒鍐欏叆瀛樻。"
				)
		loaded.free()

	remove_child(content)
	content.free()


func _test_imported_ground_persistence() -> void:
	var ground_root: String = LibraryManager.ensure_category_dir("ground")
	var fixture_dir: String = ground_root + TEMP_GROUND_GROUP + "/"
	var mkdir_error: int = DirAccess.make_dir_recursive_absolute(fixture_dir)
	_check(mkdir_error == OK, "鏃犳硶鍒涘缓涓存椂鍦伴潰绾圭悊鐩綍")
	var image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.7, 0.3, 1.0))
	_check(
		image.save_png(fixture_dir + TEMP_GROUND_GROUP + "_albedo.png") == OK,
		"鏃犳硶鍒涘缓涓存椂鍦伴潰绾圭悊"
	)

	var fixture: Dictionary = {}
	var imported_sets: Array[Dictionary] = LibraryManager.scan_ground_textures()
	for texture_set: Dictionary in imported_sets:
		if texture_set.get("_base", "") == TEMP_GROUND_GROUP:
			fixture = texture_set
			break
	_check(not fixture.is_empty(), "瀵煎叆鍦伴潰绾圭悊娌℃湁琚礌鏉愬簱鎵弿鍒?")
	_check(fixture.get("source", "") == "imported", "瀵煎叆绾圭悊缂哄皯鏉ユ簮鏍囪")
	if fixture.is_empty():
		return

	_main.call("_on_ground_clicked", fixture)
	var content_root: Node3D = _main.get("_content_root") as Node3D
	_check(content_root.get("ground_tex_base") == TEMP_GROUND_GROUP, "鍦烘櫙鏈褰曠汗鐞嗙粍鍚?")
	_check(content_root.get("ground_tex_source") == "imported", "鍦烘櫙鏈褰曞鍏ユ潵婧?")
	_check(ModuleIo.save_scene_tree(content_root, TEMP_SCENE_PATH) == OK, "绾圭悊鍦烘櫙淇濆瓨澶辫触")

	var loaded: Node = ModuleIo.load_scene_tree(TEMP_SCENE_PATH)
	_check(loaded != null, "绾圭悊鍦烘櫙鍔犺浇澶辫触")
	if loaded != null:
		_main.call(
			"_apply_ground_texture_for_scene",
			str(loaded.get("ground_tex_base")),
			float(loaded.get("ground_tile")),
			str(loaded.get("ground_tex_source"))
		)
		var active: Dictionary = _main.get("_active_ground_ts") as Dictionary
		_check(active.get("_base", "") == TEMP_GROUND_GROUP, "瀵煎叆绾圭悊鍒囧満鏅悗鏈仮澶?")
		_check(active.get("source", "") == "imported", "鎭㈠鍚庣汗鐞嗘潵婧愰敊璇?")
		loaded.free()

	_main.call("_delete_ground_item", TEMP_GROUND_GROUP)
	var reset_active: Dictionary = _main.get("_active_ground_ts") as Dictionary
	_check(reset_active.get("_base", "") == DEFAULT_GROUND_BASE, "鍒犻櫎褰撳墠绾圭悊鍚庢湭鎭㈠榛樿鍦伴潰")
	_check(content_root.get("ground_tex_source") == "builtin", "鍒犻櫎绾圭悊鍚庡満鏅潵婧愭湭鍥炴敹")


func _test_model_cache() -> void:
	_check(_write_test_glb(), "鏃犳硶鐢熸垚妯″瀷缂撳瓨娴嬭瘯 GLB")
	if not FileAccess.file_exists(TEMP_MODEL_SOURCE_PATH):
		return

	var imported_path: String = LibraryManager.import_file(
		TEMP_MODEL_SOURCE_PATH, TEMP_MODEL_CATEGORY
	)
	_check(imported_path != "", "瀵煎叆 GLB 骞剁敓鎴愮紦瀛樺け璐?")
	if imported_path == "":
		return

	var cache_path: String = LibraryManager.get_current_model_cache_path(imported_path)
	var metadata_path: String = LibraryManager.get_model_cache_metadata_path(imported_path)
	_check(cache_path != "", "瀵煎叆鍚庢病鏈夋湁鏁堢殑鍘熺敓鍦烘櫙缂撳瓨")
	_check(FileAccess.file_exists(cache_path), "鍘熺敓 .scn 缂撳瓨鏂囦欢涓嶅瓨鍦?")
	_check(FileAccess.file_exists(metadata_path), "妯″瀷缂撳瓨鍏冩暟鎹笉瀛樺湪")

	var packed: PackedScene = ResourceLoader.load(
		cache_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP
	) as PackedScene
	_check(packed != null, "妯″瀷缂撳瓨涓嶆槸 PackedScene")
	if packed != null:
		var instance: Node = packed.instantiate()
		_check(instance != null, "妯″瀷缂撳瓨鏃犳硶瀹炰緥鍖?")
		if instance != null:
			_check(
				_count_mesh_instances(instance) > 0,
				"Model cache instantiated as an empty node without MeshInstance3D"
			)
			instance.free()

	var config: ConfigFile = ConfigFile.new()
	_check(config.load(metadata_path) == OK, "妯″瀷缂撳瓨鍏冩暟鎹棤娉曡鍙?")
	config.set_value("source", "size", -1)
	_check(config.save(metadata_path) == OK, "鏃犳硶鍐欏叆澶辨晥娴嬭瘯鍏冩暟鎹?")
	_check(
		LibraryManager.get_current_model_cache_path(imported_path) == "",
		"婧愭枃浠朵俊鎭笉鍖归厤鏃朵粛閿欒澶嶇敤缂撳瓨"
	)
	var rebuilt_path: String = LibraryManager.ensure_model_cache(imported_path)
	_check(rebuilt_path != "", "澶辨晥缂撳瓨娌℃湁鑷姩閲嶅缓")

	var panels: Dictionary = _main.get("_model_panelss") as Dictionary
	var left_panel: Control = _main.get("_left_panel") as Control
	var fixture_container: VBoxContainer = VBoxContainer.new()
	left_panel.add_child(fixture_container)
	var fixture_items: Array[Dictionary] = [
		{"source": "imported", "path": imported_path},
	]
	panels[TEMP_MODEL_CATEGORY] = {
		"items": fixture_items,
		"active_idx": -1,
		"label": "娴嬭瘯妯″瀷",
		"container": fixture_container,
	}
	var content_root: Node3D = _main.get("_content_root") as Node3D
	var legacy_root: Node3D = Node3D.new()
	legacy_root.name = "p1_runtime_cache_source2"
	content_root.add_child(legacy_root)
	legacy_root.owner = content_root
	var legacy_shell: Node3D = Node3D.new()
	legacy_shell.name = "p1_runtime_cache_source"
	legacy_root.add_child(legacy_shell)
	legacy_shell.owner = content_root
	var legacy_properties: EntityProperties = EntityProperties.new()
	legacy_properties.name = "EntityProperties"
	legacy_properties.configure_from_category(TEMP_MODEL_CATEGORY)
	legacy_root.add_child(legacy_properties)
	legacy_properties.owner = content_root
	var migrated_legacy_count: int = int(_main.call("_migrate_loaded_entity_type_properties"))
	_check(migrated_legacy_count > 0, "Empty legacy model entity was not reported as migrated")
	_check(
		_count_mesh_instances(legacy_root) > 0,
		"Empty legacy model shell was not restored from the matching asset"
	)
	content_root.remove_child(legacy_root)
	legacy_root.free()
	var gesture_button: Button = _main.call(
		"_btn_model", TEMP_MODEL_CATEGORY, 0) as Button
	fixture_container.add_child(gesture_button)
	await get_tree().process_frame
	var gesture_start: Vector2 = gesture_button.get_global_rect().get_center()
	_push_mouse_button(gesture_start, MOUSE_BUTTON_RIGHT, true)
	await get_tree().process_frame
	var right_click_menu: PopupMenu = null
	for ui_child: Node in _main.get_children():
		if ui_child is PopupMenu:
			right_click_menu = ui_child as PopupMenu
			break
	_check(right_click_menu != null, "鍙抽敭绱犳潗鑿滃崟娌℃湁浣跨敤浜嬩欢鍧愭爣鍛戒腑鎸夐挳")
	if right_click_menu != null:
		_main.remove_child(right_click_menu)
		right_click_menu.free()
	_push_left_mouse_button(gesture_start, true)
	await get_tree().process_frame
	var pointer: Object = _get_pointer_controller()
	_check(
		bool(pointer.call("is_model_candidate"))
		and pointer.call("get_model_button") == gesture_button,
		"绱犳潗鎸夐挳鎸変笅鍚庢病鏈夌櫥璁版墜鍔垮€欓€?"
	)
	_check(
		not bool(pointer.call("is_model_drag")),
		"绱犳潗鎸夐挳鍒氭寜涓嬨€佸皻鏈Щ鍔ㄥ氨閿欒杩涘叆鎷栨斁"
	)
	var slight_move: Vector2 = gesture_start + Vector2(2.0, 0.0)
	_push_left_mouse_motion(slight_move, Vector2(2.0, 0.0))
	await get_tree().process_frame
	_check(
		not bool(pointer.call("is_model_drag")),
		"绱犳潗鎵嬪娍鏈秴杩囩Щ鍔ㄩ槇鍊煎氨閿欒杩涘叆鎷栨斁"
	)
	_push_left_mouse_button(slight_move, false)
	await get_tree().process_frame
	_check(
		not (_main.call("_get_active_model_item") as Dictionary).is_empty(),
		"绱犳潗鎸夐挳杞诲井绉诲姩鍚庢澗寮€娌℃湁鎸夋櫘閫氱偣鍑昏繘鍏ユ斁缃ā寮?"
	)
	_push_left_mouse_button(gesture_start, true)
	_push_left_mouse_button(gesture_start, false)
	await get_tree().process_frame
	_check(
		(_main.call("_get_active_model_item") as Dictionary).is_empty(),
		"鍐嶆鐐瑰嚮鍚屼竴绱犳潗鎸夐挳娌℃湁閫€鍑烘斁缃ā寮?"
	)
	var existing_ids: Dictionary = {}
	for existing_child: Node in content_root.get_children():
		existing_ids[existing_child.get_instance_id()] = true
	var drop_position: Vector2 = get_viewport().get_visible_rect().size * 0.5
	_main.call("_place_model", TEMP_MODEL_CATEGORY, 0, true, drop_position)
	var placed_roots: Array[Node3D] = []
	for placed_child: Node in content_root.get_children():
		if placed_child is Node3D and not existing_ids.has(placed_child.get_instance_id()):
			placed_roots.append(placed_child as Node3D)
	_check(placed_roots.size() == 1, "首次放置同名模型没有生成对象根")
	if placed_roots.size() == 1:
		_main.call("_select_entity", placed_roots[0])
	_main.call("_place_model", TEMP_MODEL_CATEGORY, 0, true, drop_position)
	placed_roots.clear()
	for placed_child: Node in content_root.get_children():
		if placed_child is Node3D and not existing_ids.has(placed_child.get_instance_id()):
			placed_roots.append(placed_child as Node3D)
	_check(placed_roots.size() == 2, "杩炵画鏀剧疆涓や唤鍚屽悕妯″瀷娌℃湁鐢熸垚涓や釜瀵硅薄鏍?")
	if placed_roots.size() == 2:
		_check(
			_count_mesh_instances(placed_roots[0]) > 0
			and _count_mesh_instances(placed_roots[1]) > 0,
			"Placed model entities lost their MeshInstance3D before scene saving"
		)
		_check(
			not str(placed_roots[1].name).begins_with("@"),
			"绗簩涓悓鍚嶅璞¤ Godot 鑷姩鍛藉悕鎴愪笉鍙鐨?@Node3D@鏁板瓧"
		)
		var gizmo: Gizmo3D = _main.get("_gizmo") as Gizmo3D
		var gizmo_selections: Dictionary = {}
		if gizmo != null:
			gizmo_selections = gizmo.get("_selections") as Dictionary
		_check(
			_main.call("_get_selected_target") == placed_roots[1],
			"放置第二个同点同名模型后，选择仍停在旧对象"
		)
		_check(
			gizmo != null and gizmo_selections.has(placed_roots[1]),
			"放置第二个同点同名模型后，Gizmo 没有绑定新对象"
		)
		_main.set("_scene_dirty", false)
		var scale_before: Vector3 = placed_roots[1].scale
		_push_key(KEY_BRACKETRIGHT)
		await get_tree().process_frame
		var scale_after: Vector3 = placed_roots[1].scale
		_check(
			scale_after.x > scale_before.x
			and is_equal_approx(scale_after.x, scale_after.y)
			and is_equal_approx(scale_after.y, scale_after.z),
			"选中模型按 ] 后没有三轴等比放大"
		)
		if gizmo != null:
			gizmo_selections = gizmo.get("_selections") as Dictionary
		_check(
			gizmo != null and gizmo_selections.has(placed_roots[1]),
			"快捷键缩放后 Gizmo 没有继续绑定当前对象"
		)
		_check(
			ModuleIo.save_scene_tree(content_root, TEMP_SCENE_PATH) == OK,
			"Model entity scene could not be saved for mesh persistence verification"
		)
		var loaded_models: Node = ModuleIo.load_scene_tree(TEMP_SCENE_PATH)
		_check(loaded_models != null, "Model entity scene could not be read back")
		if loaded_models != null:
			var loaded_mesh_count: int = 0
			for loaded_child: Node in loaded_models.get_children():
				if loaded_child is Node3D:
					loaded_mesh_count += _count_mesh_instances(loaded_child)
			_check(
				loaded_mesh_count >= 2,
				"Placed model MeshInstance3D nodes were lost after save and read-back"
			)
			loaded_models.free()
		_check(
			bool(_main.get("_scene_dirty")),
			"快捷键缩放后场景没有标记为未保存"
		)
		var model_child: Node3D = null
		for child: Node in placed_roots[0].get_children():
			if child is Node3D:
				model_child = child as Node3D
				break
		if model_child != null:
			var child_before: Vector3 = model_child.global_position
			placed_roots[0].position += Vector3(3.0, 0.0, 0.0)
			await get_tree().process_frame
			_check(
				model_child.global_position.is_equal_approx(child_before + Vector3(3.0, 0.0, 0.0)),
				"瀵硅薄鏍圭Щ鍔ㄥ悗鍙妯″瀷娌℃湁璺熼殢"
			)

	for placed_root: Node3D in placed_roots:
		content_root.remove_child(placed_root)
		placed_root.free()

	var legacy_named: Node3D = Node3D.new()
	legacy_named.name = "鏃у璞?"
	content_root.add_child(legacy_named)
	var legacy_anonymous: Node3D = Node3D.new()
	legacy_anonymous.name = "鏃у璞?"
	content_root.add_child(legacy_anonymous)
	var legacy_model: Node3D = Node3D.new()
	legacy_model.name = "鏃ф苯杞?"
	legacy_anonymous.add_child(legacy_model)
	var legacy_props: EntityProperties = EntityProperties.new()
	legacy_props.name = "EntityProperties"
	legacy_props.configure_from_category("terrain")
	legacy_anonymous.add_child(legacy_props)
	_check(str(legacy_anonymous.name).begins_with("@"), "鏃у尶鍚嶅璞″す鍏锋病鏈夌敓鎴?@Node3D 鍚嶇О")
	_check(
		bool(_main.call("_ensure_readable_entity_name", legacy_anonymous, legacy_props)),
		"鏃у尶鍚嶅璞℃病鏈夎縼绉绘垚鍙鍚嶇О"
	)
	_check(not str(legacy_anonymous.name).begins_with("@"), "鏃у尶鍚嶅璞¤縼绉诲悗浠嶆槸 @Node3D 鍚嶇О")
	content_root.remove_child(legacy_named)
	legacy_named.free()
	content_root.remove_child(legacy_anonymous)
	legacy_anonymous.free()

	_push_left_mouse_button(gesture_start, true)
	_push_left_mouse_motion(drop_position, drop_position - gesture_start)
	await get_tree().process_frame
	_check(bool(pointer.call("is_model_drag")), "绱犳潗鎵嬪娍瓒呰繃闃堝€煎悗娌℃湁杩涘叆鎷栨斁")
	var placement: Object = _get_placement_controller()
	_check(
		bool(placement.call("has_drag_preview")),
		"绱犳潗鎷栨斁寮€濮嬪悗娌℃湁鍒涘缓 3D 棰勮"
	)
	_push_left_mouse_button(drop_position, false)
	await get_tree().process_frame
	var active_after_drag: Dictionary = _main.call("_get_active_model_item") as Dictionary
	_check(active_after_drag.is_empty(), "鎷栨斁缁撴潫鍚庨敊璇縺娲讳簡杩炵画鏀剧疆宸ュ叿")
	_check(
		not bool(pointer.call("is_model_candidate")),
		"鎷栨斁缁撴潫鍚庝粛娈嬬暀绱犳潗鎵嬪娍鍊欓€?"
	)
	_check(not bool(pointer.call("is_model_drag")), "鎷栨斁缁撴潫鍚庝粛娈嬬暀娲诲姩鐘舵€?")
	_check(
		not bool(placement.call("has_drag_preview")),
		"鎷栨斁缁撴潫鍚庝粛娈嬬暀 3D 棰勮"
	)
	var drag_placed_roots: Array[Node3D] = []
	for drag_child: Node in content_root.get_children():
		if drag_child is Node3D and not existing_ids.has(drag_child.get_instance_id()):
			drag_placed_roots.append(drag_child as Node3D)
	_check(drag_placed_roots.size() == 1, "涓€娆＄礌鏉愭嫋鏀炬墜鍔挎病鏈変笖浠呮病鏈夋斁缃竴涓璞?")
	for drag_root: Node3D in drag_placed_roots:
		content_root.remove_child(drag_root)
		drag_root.free()
	fixture_container.remove_child(gesture_button)
	gesture_button.free()
	left_panel.remove_child(fixture_container)
	fixture_container.free()
	panels.erase(TEMP_MODEL_CATEGORY)

	_check(
		LibraryManager.delete_model(TEMP_MODEL_CATEGORY, TEMP_MODEL_FILE_NAME),
		"鍒犻櫎瀵煎叆妯″瀷澶辫触"
	)
	_check(not FileAccess.file_exists(imported_path), "鍒犻櫎鍚庝粛娈嬬暀鍘熷 GLB")
	_check(not FileAccess.file_exists(rebuilt_path), "鍒犻櫎鍚庝粛娈嬬暀鍘熺敓缂撳瓨")
	_check(not FileAccess.file_exists(metadata_path), "鍒犻櫎鍚庝粛娈嬬暀缂撳瓨鍏冩暟鎹?")


func _test_rectangular_grid() -> void:
	var grid: GridManager = GridManager.new()
	add_child(grid)
	await get_tree().process_frame
	grid.set_grid_size(20.0, 100.0)
	grid.update_grid(0.1)
	var mesh_instance: MeshInstance3D = grid.get_child(0) as MeshInstance3D
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_check(vertices.size() == 168, "闀挎柟褰㈢綉鏍?X/Z 姝ユ暟浜ゅ弶")
	remove_child(grid)
	grid.free()


func _test_model_root_reset() -> void:
	var model_root: Node3D = Node3D.new()
	model_root.position = Vector3(9.0, 8.0, 7.0)
	var model_child: Node3D = Node3D.new()
	model_child.position = Vector3(1.0, 2.0, 3.0)
	model_child.rotation = Vector3(0.1, 0.2, 0.3)
	model_root.add_child(model_child)
	_main.call("_reset_all_transforms", model_root)
	_check(model_root.transform == Transform3D.IDENTITY, "妯″瀷鏍硅妭鐐规湭褰掗浂")
	_check(
		model_child.position.is_equal_approx(Vector3(1.0, 2.0, 3.0)),
		"妯″瀷瀛愯妭鐐逛綅绉昏鐮村潖"
	)
	_check(
		model_child.rotation.is_equal_approx(Vector3(0.1, 0.2, 0.3)),
		"妯″瀷瀛愯妭鐐规棆杞鐮村潖"
	)
	model_root.free()


func _test_runtime_token_movement() -> void:
	var content_root: Node3D = _main.get("_content_root") as Node3D
	var token: Node3D = Node3D.new()
	token.name = "RuntimeMoveToken"
	content_root.add_child(token)
	token.owner = content_root

	var token_entity_props: EntityProperties = EntityProperties.new()
	token_entity_props.name = "EntityProperties"
	token_entity_props.configure_from_category("token")
	token.add_child(token_entity_props)
	token_entity_props.owner = content_root

	_check(
		bool(_main.call(
			"_ensure_entity_type_properties_for_root", token, token_entity_props
		)),
		"鏃?Token 娌℃湁鑷姩琛ユ寕 TokenProperties"
	)
	var token_props: Node = token.get_node_or_null("TokenProperties")
	_check(token_props != null, "Token 杩佺Щ鍚庝粛缂轰笓灞炲睘鎬х粍浠?")
	var cpr_props: Node = token.get_node_or_null("CprTokenProperties")
	_check(cpr_props != null, "CPR Token 娌℃湁琛ユ寕瑙勫垯涓撳睘灞炴€?")
	if cpr_props != null:
		_check(int(cpr_props.get("move_stat")) == 5, "CPR Token default MOVE is not 5")
	var traversal_props: Node = token.get_node_or_null("TraversalProperties")
	_check(traversal_props != null, "Token 娌℃湁琛ユ寕閫氳鏍囩缁勪欢")
	_check(
		token_entity_props.entity_type == EntityProperties.EntityType.TOKEN,
		"鏃?Token 鐨?category 娌℃湁杩佺Щ鎴愬璞＄被鍨?"
	)
	_check(
		not bool(_main.call(
			"_ensure_entity_type_properties_for_root", token, token_entity_props
		)),
		"閲嶅杩佺Щ缁?Token 鎸備簡绗簩浠戒笓灞炵粍浠?"
	)
	if token_props == null:
		content_root.remove_child(token)
		token.free()
		return
	token.global_position = Vector3(1.25, 0.0, -2.5)
	var edit_position_before_run: Vector3 = token.global_position
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	await get_tree().process_frame
	_main.call("_select_entity", token)
	var prop_panel: PanelContainer = _main.get("_prop_panel") as PanelContainer
	var runtime_box: VBoxContainer = _main.get("_prop_runtime_box") as VBoxContainer
	var runtime_type_label: Label = _main.get("_prop_runtime_type_label") as Label
	var runtime_detail_label: Label = _main.get("_prop_runtime_detail_label") as Label
	var gizmo: Gizmo3D = _main.get("_gizmo") as Gizmo3D
	_check(prop_panel != null and prop_panel.visible, "杩愯鎬侀€変腑 Token 娌℃湁鎵撳紑鎿嶄綔闈㈡澘")
	_check(runtime_box != null and runtime_box.visible, "杩愯鎬佹搷浣滈潰鏉挎病鏈夊垏鍒板彧璇绘憳瑕?")
	_check(
		runtime_type_label != null and runtime_type_label.text.contains("Token"),
		"Runtime panel did not show the Token type"
	)
	_check(
		runtime_detail_label != null and runtime_detail_label.text.contains("10.0"),
		"Runtime panel did not show the default movement budget"
	)
	_check(
		gizmo != null
		and gizmo.get_selected_count() == 1
		and int(gizmo.mode) == 0
		and not gizmo.show_axes,
		"杩愯鎬侀€変腑娌℃湁淇濇寔閫夋嫨妗嗕笓鐢?Gizmo 妯″紡"
	)
	var pointer: Object = _get_pointer_controller()
	pointer.call("end_combat_aim")
	pointer.call(
		"begin_runtime_token_candidate", token, Vector2(100.0, 100.0)
	)
	_check(
		not bool(_main.call("_runtime_pointer_exceeded_drag_threshold", Vector2(105.0, 100.0))),
		"Token 杞诲井榧犳爣鎶栧姩琚敊璇瘑鍒负鎷栧姩"
	)
	_check(
		bool(_main.call("_runtime_pointer_exceeded_drag_threshold", Vector2(106.0, 100.0))),
		"Token 杈惧埌 6 鍍忕礌鍚庢病鏈夎繘鍏ユ嫋鍔ㄥ垽瀹?"
	)
	_check(
		bool(_main.call("_begin_runtime_token_drag", token, Vector2(106.0, 100.0))),
		"Token 杈惧埌鎷栧姩闃堝€煎悗娌℃湁寮€濮嬭繍琛屾€佹嫋鍔?"
	)
	_main.call("_select_entity_for_runtime_token_drag", token)
	_check(
		bool(pointer.call("is_runtime_token_drag")),
		"Token 杩愯鎬佹嫋鍔ㄧ姸鎬佹病鏈変繚鐣?"
	)
	_check(
		not bool(pointer.call("is_combat_aim_active")),
		"Token 杩愯鎬佹嫋鍔ㄨ閿欒鍚姩鎴樻枟鐬勫噯"
	)
	if bool(pointer.call("is_runtime_token_drag")):
		_main.call("_clear_runtime_token_drag")
	else:
		_main.call("_clear_runtime_pointer_candidate")
	var selected_items: Array[Object] = []
	var gizmo_selections: Dictionary = gizmo.get("_selections") as Dictionary
	for selection_value: Variant in gizmo_selections.values():
		selected_items.append(selection_value as Object)
	_main.call("_deselect")
	_check(
		not prop_panel.visible and gizmo.get_selected_count() == 0,
		"杩愯鎬佸彇娑堥€夋嫨鍚庨潰鏉挎垨閫夋嫨妗嗕粛鐒跺瓨鍦?"
	)
	var released_selected_items: bool = true
	for selected_item: Object in selected_items:
		if is_instance_valid(selected_item):
			released_selected_items = false
			break
	_check(released_selected_items, "Gizmo 娓呯┖閫夋嫨鍚庝粛娉勬紡 SelectedItem")
	var scene_session_controller: Object = _main.get("_scene_session_controller") as Object
	if scene_session_controller != null:
		scene_session_controller.call("clear_dirty")
	_main.set("_scene_dirty", false)
	token.global_position = Vector3(8.0, 0.0, 6.0)
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame
	_check(
		token.global_position.is_equal_approx(edit_position_before_run),
		"Runtime Token movement leaked into edit mode instead of restoring the edit position"
	)
	_check(
		not bool(_main.get("_scene_dirty"))
		and (scene_session_controller == null or not bool(scene_session_controller.call("is_dirty"))),
		"Runtime Token movement marked the edit scene dirty"
	)
	_check(
		int(gizmo.mode) == int(Gizmo3D.ToolMode.ALL) and gizmo.show_axes,
		"鍒囧洖缂栬緫鎬佸悗瀹屾暣 Gizmo 娌℃湁鎭㈠"
	)
	_main.call("_select_entity", token)
	var move_row: HBoxContainer = _main.get("_prop_move_row") as HBoxContainer
	_check(move_row != null and move_row.visible, "閫変腑 CPR Token 鏃?MOVE 缂栬緫琛屾病鏈夋樉绀?")
	var cpr_provider: MovementRuleProvider = load(
		"res://scripts/cpr_movement_rule_provider.gd").new() as MovementRuleProvider
	_check(cpr_provider != null, "CPR 绉诲姩瑙勫垯鎻愪緵鍣ㄥ姞杞藉け璐?")
	if cpr_provider != null and cpr_props != null:
		_check(
			is_equal_approx(cpr_provider.get_movement_budget_meters(token), 10.0),
			"Default CPR MOVE 5 did not produce a 10-meter movement budget"
		)
	_main.call("_on_prop_move_changed", 6.0)
	_check(int(cpr_props.get("move_stat")) == 6, "MOVE 缂栬緫鎺т欢娌℃湁鍥炲啓 CPR 缁勪欢")

	if cpr_provider == null or cpr_props == null:
		content_root.remove_child(token)
		token.free()
		return
	_check(
		is_equal_approx(cpr_provider.get_movement_budget_meters(token), 12.0),
		"CPR MOVE 6 娌℃湁鎹㈢畻鎴?12 绫崇Щ鍔ㄩ绠?"
	)
	var long_path: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
		Vector3(20.0, 0.0, 0.0),
	])
	var walk_tags: Array[StringName] = [&"walkable", &"walkable"]
	var truncated: Dictionary = cpr_provider.truncate_path(long_path, walk_tags, 12.0)
	var reachable_path: PackedVector3Array = truncated["path"] as PackedVector3Array
	_check(bool(truncated["truncated"]), "瓒呭嚭绉诲姩棰勭畻鐨勮矾绾挎病鏈夋埅鏂?")
	_check(
		reachable_path.size() == 3
		and reachable_path[-1].is_equal_approx(Vector3(12.0, 0.0, 0.0)),
		"瓒呰窛璺嚎娌℃湁鍋滃湪鏈€鍚庡彲杈剧偣"
	)
	var climb_tags: Array[StringName] = [&"climb"]
	var climb_path: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(10.0, 0.0, 0.0),
	])
	var climb_result: Dictionary = cpr_provider.truncate_path(climb_path, climb_tags, 12.0)
	var reachable_climb: PackedVector3Array = climb_result["path"] as PackedVector3Array
	_check(
		reachable_climb.size() == 2
		and reachable_climb[-1].is_equal_approx(Vector3(6.0, 0.0, 0.0)),
		"鏀€鐖弻鍊嶇Щ鍔ㄨ€楄垂娌℃湁鐢熸晥"
	)

	var route_wall: Node3D = Node3D.new()
	route_wall.name = "RouteWall"
	content_root.add_child(route_wall)
	route_wall.owner = content_root
	var route_wall_mesh: MeshInstance3D = MeshInstance3D.new()
	route_wall_mesh.name = "Mesh"
	var route_box: BoxMesh = BoxMesh.new()
	route_box.size = Vector3(4.0, 2.0, 1.0)
	route_wall_mesh.mesh = route_box
	route_wall.add_child(route_wall_mesh)
	route_wall_mesh.owner = content_root
	route_wall.rotation.y = PI * 0.25
	var route_wall_props: EntityProperties = EntityProperties.new()
	route_wall_props.name = "EntityProperties"
	route_wall_props.configure_from_category("wall")
	route_wall.add_child(route_wall_props)
	route_wall_props.owner = content_root
	_main.call("_ensure_entity_type_properties_for_root", route_wall, route_wall_props)
	var corridor_wall_left: Node3D = null
	var corridor_wall_right: Node3D = null
	_main.call("_select_entity", route_wall)
	var traversal_row: HBoxContainer = _main.get("_prop_traversal_row") as HBoxContainer
	_check(traversal_row != null and traversal_row.visible, "閫変腑澧欎綋鏃堕€氳鏍囩琛屾病鏈夋樉绀?")
	token.global_position = Vector3(-4.0, 0.0, 0.0)
	cpr_props.set("move_stat", 10)
	_check(bool(_main.call("_rebuild_movement_service")), "娴嬭瘯瀵艰埅缃戠敓鎴愬け璐?")
	var movement_service: Node3D = _main.get("_movement_service") as Node3D
	_check(movement_service != null, "杩愯鎬佹病鏈夊垱寤虹Щ鍔ㄦ湇鍔?")
	if movement_service != null:
		var navigation_region: NavigationRegion3D = movement_service.get(
			"_region") as NavigationRegion3D
		var movement_obstacle: NavigationObstacle3D = null
		if navigation_region != null:
			for navigation_child: Node in navigation_region.get_children():
				if navigation_child is NavigationObstacle3D:
					movement_obstacle = navigation_child as NavigationObstacle3D
					break
		_check(movement_obstacle != null, "Rotated blocker did not create a navigation obstacle")
		var blocker_box_shape: BoxShape3D = null
		var blocker_box_body: StaticBody3D = null
		for navigation_child: Node in navigation_region.get_children():
			if not (navigation_child is StaticBody3D):
				continue
			var candidate_body: StaticBody3D = navigation_child as StaticBody3D
			if candidate_body.collision_layer != MovementService.BLOCKER_LAYER_MASK:
				continue
			for shape_child: Node in candidate_body.get_children():
				if shape_child is CollisionShape3D:
					var candidate_shape: Shape3D = (shape_child as CollisionShape3D).shape
					if candidate_shape is BoxShape3D:
						var candidate_box: BoxShape3D = candidate_shape as BoxShape3D
						if candidate_box.size.is_equal_approx(Vector3(4.0, 2.0, 1.0)):
							blocker_box_shape = candidate_box
							blocker_box_body = candidate_body
							break
			if blocker_box_shape != null:
				break
		_check(blocker_box_shape != null, "Rotated blocker did not use its cached bounds as BoxShape3D")
		_check(
			blocker_box_body != null
			and is_equal_approx(blocker_box_body.global_rotation.y, route_wall.global_rotation.y),
			"Blocker BoxShape3D did not preserve the entity rotation"
		)
		if movement_obstacle != null:
			var obstacle_vertices: PackedVector3Array = movement_obstacle.vertices
			var obstacle_min: Vector3 = obstacle_vertices[0]
			var obstacle_max: Vector3 = obstacle_vertices[0]
			for obstacle_vertex: Vector3 in obstacle_vertices:
				obstacle_min = obstacle_min.min(obstacle_vertex)
				obstacle_max = obstacle_max.max(obstacle_vertex)
			_check(
				is_equal_approx(obstacle_max.x - obstacle_min.x, 4.0)
				and is_equal_approx(obstacle_max.z - obstacle_min.z, 1.0),
				"Rotated blocker obstacle used an inflated world-aligned box"
			)
			_check(
				is_equal_approx(movement_obstacle.global_rotation.y, route_wall.global_rotation.y),
				"Navigation obstacle did not preserve blocker yaw rotation"
			)
		var route: Dictionary = movement_service.call(
			"preview_to_world_position", token, Vector3(4.0, 0.0, 0.0))
		_check(not route.is_empty(), "澧欎綋涓や晶娌℃湁鐢熸垚鍙揪璺嚎")
		if not route.is_empty():
			_check(float(route["full_cost"]) > 8.1, "璺嚎绌胯繃澧欎綋鑰屼笉鏄粫琛?")
			var route_endpoint: Vector3 = route["endpoint"] as Vector3
			_check(
				route_endpoint.distance_to(Vector3(4.0, 0.0, 0.0)) < 0.75,
				"璺嚎棰勮琚瑙掓彁鍓嶆埅鍋滐紝娌℃湁鍒拌揪澧欎綋鍙︿竴渚?"
			)
			_check(absf(route_endpoint.y) < 0.05, "骞冲湴璺嚎璁?Token 鎮┖")
		movement_service.call("clear_preview")
		corridor_wall_left = _create_movement_blocker(
			content_root,
			"CorridorWallLeft",
			Vector3(11.0, 0.0, 0.0),
			Vector3(0.5, 2.0, 12.0)
		)
		corridor_wall_right = _create_movement_blocker(
			content_root,
			"CorridorWallRight",
			Vector3(13.0, 0.0, 0.0),
			Vector3(0.5, 2.0, 12.0)
		)
		movement_service.call("_clear_navigation_runtime")
		_check(bool(_main.call("_rebuild_movement_service")), "璧板粖瀵艰埅缃戠敓鎴愬け璐?")
		movement_service = _main.get("_movement_service") as Node3D
		_check(movement_service != null, "璧板粖娴嬭瘯娌℃湁閲嶅缓绉诲姩鏈嶅姟")
		cpr_props.set("move_stat", 20)
		token_props.set("collision_radius", 0.45)
		token_props.set("collision_height", 1.8)
		token.global_position = Vector3(12.0, 0.0, -8.0)
		var small_corridor_route: Dictionary = movement_service.call(
			"preview_to_world_position",
			token,
			Vector3(12.0, 0.0, 8.0)
		)
		_check(not small_corridor_route.is_empty(), "Default Token could not enter a 1.5-meter corridor")
		var small_corridor_cost: float = INF
		if not small_corridor_route.is_empty():
			small_corridor_cost = float(small_corridor_route["full_cost"])
			_check(
				small_corridor_cost < 17.5,
				"Default Token detoured instead of using the 1.5-meter corridor"
			)
		movement_service.call("clear_preview")
		token_props.set("collision_radius", 0.9)
		token_props.set("collision_height", 2.4)
		var large_corridor_route: Dictionary = movement_service.call(
			"preview_to_world_position",
			token,
			Vector3(12.0, 0.0, 8.0)
		)
		var navigation_profiles: Dictionary = movement_service.get(
			"_navigation_profiles") as Dictionary
		_check(navigation_profiles.size() == 2, "Two Token sizes did not produce exactly two cached navigation maps")
		_check(
			navigation_profiles.has(Vector2i(9, 10)),
			"Large Token did not create the 0.9-meter radius and 2.5-meter height profile"
		)
		_check(
			large_corridor_route.is_empty()
			or float(large_corridor_route["full_cost"]) > small_corridor_cost + 1.0,
			"Large Token incorrectly used the corridor reserved for the smaller Token"
		)
		movement_service.call("clear_preview")
		token_props.set("collision_radius", 0.45)
		token_props.set("collision_height", 1.8)
		cpr_props.set("move_stat", 10)
		_check(
			bool(movement_service.call("begin_preview", token)),
			"Default Token preview did not resume after the multi-size corridor test"
		)
		var range_instance: MeshInstance3D = movement_service.get(
			"_range_instance") as MeshInstance3D
		var range_mesh: ImmediateMesh = movement_service.get("_range_mesh") as ImmediateMesh
		_check(
			range_instance != null and range_instance.has_meta("gvtt_runtime_only"),
			"Movement range preview is not marked runtime-only"
		)
		_check(
			range_mesh != null and range_mesh.get_surface_count() == 1,
			"Movement range ring was not drawn during Token drag"
		)
		if range_mesh != null and range_mesh.get_surface_count() == 1:
			var range_arrays: Array = range_mesh.surface_get_arrays(0)
			var range_vertices: PackedVector3Array = range_arrays[Mesh.ARRAY_VERTEX]
			_check(
				range_vertices.size() == MovementService.RANGE_RING_SEGMENTS + 1,
				"Movement range ring is not a closed 64-segment line"
			)
		movement_service.call("clear_preview_path")
		_check(
			range_mesh != null and range_mesh.get_surface_count() == 1,
			"Clearing the route also removed the active movement range ring"
		)
		movement_service.call("clear_preview")
		_check(
			range_mesh != null and range_mesh.get_surface_count() == 0,
			"Movement range ring remained after Token drag ended"
		)
		cpr_props.set("move_stat", 5)
		var capped_start: Vector3 = Vector3(-4.0, 0.0, 0.0)
		token.global_position = capped_start
		var capped_preview: Dictionary = movement_service.call(
			"preview_to_world_position",
			token,
			Vector3(-4.0, 0.0, 20.0)
		)
		_check(not capped_preview.is_empty(), "Over-range straight route did not preview")
		if not capped_preview.is_empty():
			var capped_endpoint: Vector3 = capped_preview["endpoint"] as Vector3
			_check(bool(capped_preview["over_budget"]), "Over-range route was not capped")
			_check(
				is_equal_approx(
					float(capped_preview["cost"]),
					float(capped_preview["budget"])
				)
				and capped_endpoint.distance_to(capped_start) <= 10.01,
				"Over-range route did not stop at its 10-meter path budget"
			)
			var path_mesh: ImmediateMesh = movement_service.get("_preview_mesh") as ImmediateMesh
			_check(
				path_mesh != null and path_mesh.get_surface_count() == 1,
				"Over-range preview still drew a separate outside route"
			)
			var has_outside_vertex: bool = false
			if path_mesh != null and path_mesh.get_surface_count() == 1:
				var path_arrays: Array = path_mesh.surface_get_arrays(0)
				var path_vertices: PackedVector3Array = path_arrays[Mesh.ARRAY_VERTEX]
				for path_vertex: Vector3 in path_vertices:
					var horizontal_offset: Vector2 = Vector2(
						path_vertex.x - capped_start.x,
						path_vertex.z - capped_start.z
					)
					if horizontal_offset.length() > 10.01:
						has_outside_vertex = true
						break
			_check(not has_outside_vertex, "Over-range preview contains a vertex outside the ring")
			_check(
				bool(movement_service.call("commit_preview")),
				"Capped movement route did not commit"
			)
			for _movement_step: int in range(64):
				movement_service.call("_process", 0.25)
			_check(
				token.global_position.is_equal_approx(capped_endpoint),
				"Token did not finish at the capped route endpoint"
			)
		cpr_props.set("move_stat", 10)
	var movement_map_rids: Array[RID] = []
	var movement_profiles: Dictionary = movement_service.get("_navigation_profiles") as Dictionary
	for profile_value: Variant in movement_profiles.values():
		var movement_profile: Dictionary = profile_value as Dictionary
		movement_map_rids.append(movement_profile["map"] as RID)
	_main.call("_destroy_movement_service")
	await get_tree().physics_frame
	await get_tree().process_frame
	var remaining_navigation_maps: Array[RID] = NavigationServer3D.get_maps()
	var released_all_movement_maps: bool = true
	for movement_map_rid: RID in movement_map_rids:
		if remaining_navigation_maps.has(movement_map_rid):
			released_all_movement_maps = false
			break
	_check(released_all_movement_maps, "MovementService leaked a cached navigation map on destroy")
	_main.call("_deselect")
	content_root.remove_child(route_wall)
	route_wall.free()
	if corridor_wall_left != null:
		content_root.remove_child(corridor_wall_left)
		corridor_wall_left.free()
	if corridor_wall_right != null:
		content_root.remove_child(corridor_wall_right)
		corridor_wall_right.free()

	token.global_position = Vector3(3.25, 1.5, -2.75)
	_check(
		ModuleIo.save_scene_tree(content_root, TEMP_SCENE_PATH) == OK,
		"甯︾Щ鍔ㄨ鍒欑粍浠剁殑 Token 鍦烘櫙淇濆瓨澶辫触"
	)
	var loaded: Node = ModuleIo.load_scene_tree(TEMP_SCENE_PATH)
	_check(loaded != null, "甯︾Щ鍔ㄨ鍒欑粍浠剁殑 Token 鍦烘櫙璇诲洖澶辫触")
	if loaded != null:
		var loaded_token: Node3D = loaded.get_node_or_null("RuntimeMoveToken") as Node3D
		_check(loaded_token != null, "Token 鍦ㄨ鍥炴椂涓㈠け")
		if loaded_token != null:
			_check(
				loaded_token.position.is_equal_approx(Vector3(3.25, 1.5, -2.75)),
				"Token 绉诲姩浣嶇疆娌℃湁淇濆瓨/璇诲洖"
			)
			_check(
				loaded_token.get_node_or_null("TokenProperties") != null,
				"Token 涓撳睘灞炴€х粍浠舵病鏈夐殢绉诲姩浣嶇疆涓€璧蜂繚瀛?"
			)
			var loaded_cpr_props: Node = loaded_token.get_node_or_null("CprTokenProperties")
			_check(loaded_cpr_props != null, "CPR 瑙勫垯灞炴€х粍浠舵病鏈変繚瀛?璇诲洖")
			if loaded_cpr_props != null:
				_check(
					int(loaded_cpr_props.get("move_stat")) == 10,
					"Saved CPR MOVE was overwritten by the template default"
				)
			_check(
				loaded_token.get_node_or_null("TraversalProperties") != null,
				"閫氳鏍囩缁勪欢娌℃湁淇濆瓨/璇诲洖"
			)
		loaded.free()

	token_props.set("can_move", false)
	_check(
		not bool(_main.call("_can_runtime_move_token", token)),
		"can_move=false 鏃朵粛鍏佽杩涘叆 Token 绉诲姩閫氶亾"
	)

	var wall: Node3D = Node3D.new()
	wall.name = "RuntimeMoveWall"
	content_root.add_child(wall)
	var wall_entity_props: EntityProperties = EntityProperties.new()
	wall_entity_props.name = "EntityProperties"
	wall_entity_props.configure_from_category("wall")
	wall.add_child(wall_entity_props)
	_check(
		not bool(_main.call("_can_runtime_move_token", wall)),
		"闈?Token 瀵硅薄閿欒杩涘叆 Token 绉诲姩閫氶亾"
	)
	_check(wall.global_position == Vector3.ZERO, "澧欎綋琚?Token 绉诲姩閫昏緫鏀逛簡浣嶇疆")

	_main.call("_clear_owner_recursive", token)
	content_root.remove_child(token)
	token.free()
	content_root.remove_child(wall)
	wall.free()


func _test_runtime_selection_panel_entity_variants() -> void:
	var content_root: Node3D = _main.get("_content_root") as Node3D
	var prop_panel: PanelContainer = _main.get("_prop_panel") as PanelContainer
	var runtime_box: VBoxContainer = _main.get("_prop_runtime_box") as VBoxContainer
	var runtime_type_label: Label = _main.get("_prop_runtime_type_label") as Label
	var runtime_status_label: Label = _main.get("_prop_runtime_status_label") as Label
	var runtime_detail_label: Label = _main.get("_prop_runtime_detail_label") as Label
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	await get_tree().process_frame

	var wall: Node3D = Node3D.new()
	wall.name = "RuntimePanelWall"
	content_root.add_child(wall)
	var wall_entity_props: EntityProperties = EntityProperties.new()
	wall_entity_props.name = "EntityProperties"
	wall_entity_props.display_name = "Panel Wall"
	wall_entity_props.configure_from_category("wall")
	wall.add_child(wall_entity_props)
	_check(
		bool(_main.call("_ensure_entity_type_properties_for_root", wall, wall_entity_props)),
		"Runtime panel wall did not receive WallProperties"
	)
	var wall_props: Node = wall.get_node_or_null("WallProperties")
	if wall_props != null:
		wall_props.set("wall_state", 1)
		wall_props.set("durability_current", 7)
		wall_props.set("durability_max", 20)
		wall_props.set("destructible", true)
	_main.call("_select_entity", wall)
	_check(prop_panel != null and prop_panel.visible, "Runtime wall selection did not open panel")
	_check(runtime_box != null and runtime_box.visible, "Runtime wall panel did not use read-only box")
	_check(runtime_type_label != null and runtime_type_label.text.contains("墙体"), "Runtime wall type text is missing")
	_check(runtime_status_label != null and runtime_status_label.text.contains("受损"), "Runtime wall state text is missing")
	_check(runtime_detail_label != null and runtime_detail_label.text.contains("7 / 20"), "Runtime wall durability text is missing")
	_main.call("_on_runtime_wall_toggle_pressed")
	_check(
		wall_props != null
		and int(wall_props.get("wall_state")) == int(WallProperties.WallState.DESTROYED)
		and not wall.visible,
		"Runtime wall destruction did not hide the intact wall visual"
	)
	ModeGate.switch_to(ModeGate.AppMode.EDIT)
	await get_tree().process_frame
	_check(
		wall.visible,
		"Destroyed wall visual did not return for edit-mode authoring"
	)
	_check(
		wall_props != null
		and int(wall_props.get("wall_state")) == int(WallProperties.WallState.DESTROYED),
		"Edit-mode wall visibility incorrectly repaired the destroyed state"
	)
	_main.call("_select_entity", wall)
	_main.call("_on_prop_cover_toggled", false)
	_check(
		wall.visible,
		"Editing a destroyed wall property hid its edit-mode visual again"
	)
	ModeGate.switch_to(ModeGate.AppMode.RUN)
	await get_tree().process_frame
	_check(not wall.visible, "Destroyed wall visual remained visible after returning to run mode")
	_main.call("_select_entity", wall)
	_main.call("_on_runtime_wall_toggle_pressed")
	_check(
		wall_props != null
		and int(wall_props.get("wall_state")) == int(WallProperties.WallState.INTACT)
		and wall.visible,
		"Runtime wall repair did not restore the intact wall visual"
	)

	var light: Node3D = Node3D.new()
	light.name = "RuntimePanelLight"
	content_root.add_child(light)
	var light_entity_props: EntityProperties = EntityProperties.new()
	light_entity_props.name = "EntityProperties"
	light_entity_props.display_name = "Panel Light"
	light_entity_props.configure_from_category("light")
	light.add_child(light_entity_props)
	_check(
		bool(_main.call("_ensure_entity_type_properties_for_root", light, light_entity_props)),
		"Runtime panel light did not receive LightProperties"
	)
	var light_props: Node = light.get_node_or_null("LightProperties")
	if light_props != null:
		light_props.set("is_on", false)
		light_props.set("light_range", 12.5)
		light_props.set("energy", 2.5)
	_main.call("_select_entity", light)
	_check(runtime_type_label != null and runtime_type_label.text.contains("光源"), "Runtime light type text is missing")
	_check(runtime_status_label != null and runtime_status_label.text.contains("关闭"), "Runtime light switch state text is missing")
	_check(runtime_detail_label != null and runtime_detail_label.text.contains("12.5"), "Runtime light range text is missing")
	_check(runtime_detail_label != null and runtime_detail_label.text.contains("2.5"), "Runtime light energy text is missing")

	var interactable: Node3D = Node3D.new()
	interactable.name = "RuntimePanelInteractable"
	content_root.add_child(interactable)
	var interactable_entity_props: EntityProperties = EntityProperties.new()
	interactable_entity_props.name = "EntityProperties"
	interactable_entity_props.display_name = "Panel Switch"
	interactable_entity_props.configure_from_category("interactable")
	interactable.add_child(interactable_entity_props)
	_check(
		bool(_main.call("_ensure_entity_type_properties_for_root", interactable, interactable_entity_props)),
		"Runtime panel interactable did not receive InteractableProperties"
	)
	var interactable_props: Node = interactable.get_node_or_null("InteractableProperties")
	if interactable_props != null:
		interactable_props.set("interaction_state", 2)
		interactable_props.set("interaction_label", "Open Door")
	_main.call("_select_entity", interactable)
	_check(runtime_type_label != null and runtime_type_label.text.contains("交互物体"), "Runtime interactable type text is missing")
	_check(runtime_status_label != null and runtime_status_label.text.contains("已禁用"), "Runtime interactable state text is missing")
	_check(runtime_detail_label != null and runtime_detail_label.text.contains("Open Door"), "Runtime interactable label text is missing")

	_main.call("_deselect")
	content_root.remove_child(wall)
	wall.free()
	content_root.remove_child(light)
	light.free()
	content_root.remove_child(interactable)
	interactable.free()


func _create_movement_blocker(
		content_root: Node3D,
		blocker_name: String,
		blocker_position: Vector3,
		blocker_size: Vector3
) -> Node3D:
	var blocker: Node3D = Node3D.new()
	blocker.name = blocker_name
	blocker.position = blocker_position
	content_root.add_child(blocker)
	blocker.owner = content_root
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = blocker_size
	mesh_instance.mesh = box_mesh
	blocker.add_child(mesh_instance)
	mesh_instance.owner = content_root
	var entity_properties: EntityProperties = EntityProperties.new()
	entity_properties.name = "EntityProperties"
	entity_properties.configure_from_category("wall")
	blocker.add_child(entity_properties)
	entity_properties.owner = content_root
	_main.call(
		"_ensure_entity_type_properties_for_root",
		blocker,
		entity_properties
	)
	return blocker


func _test_movement_path_following() -> void:
	var movement_service: MovementService = MovementService.new()
	add_child(movement_service)
	var ring_center: Vector3 = Vector3(2.0, 3.0, 4.0)
	var ring_points: PackedVector3Array = movement_service.call(
		"_build_range_ring_points", ring_center, 10.0) as PackedVector3Array
	_check(
		ring_points.size() == MovementService.RANGE_RING_SEGMENTS + 1,
		"Default 10-meter range ring has the wrong segment count"
	)
	_check(
		ring_points[0].is_equal_approx(ring_points[-1]),
		"Default 10-meter range ring is not closed"
	)
	var first_ring_offset: Vector3 = ring_points[0] - ring_center
	_check(
		is_equal_approx(Vector2(first_ring_offset.x, first_ring_offset.z).length(), 10.0),
		"Default movement range ring radius is not 10 meters"
	)

	var short_token: Node3D = Node3D.new()
	add_child(short_token)
	movement_service.set("_preview_token", short_token)
	movement_service.set(
		"_preview_reachable_path",
		PackedVector3Array([Vector3.ZERO, Vector3(6.0, 0.0, 0.0)])
	)
	_check(bool(movement_service.call("commit_preview")), "Short movement route did not commit")
	_check(
		is_equal_approx(float(movement_service.get("_moving_speed")), 6.0),
		"Short movement route did not keep base speed"
	)
	movement_service.call("_process", 1.0)
	_check(
		short_token.global_position.is_equal_approx(Vector3(6.0, 0.0, 0.0)),
		"Short movement route did not arrive in one second"
	)
	_check(
		short_token.global_transform.basis.z.normalized().dot(Vector3.RIGHT) > 0.999,
		"Token local +Z did not face the movement direction"
	)

	var slope_token: Node3D = Node3D.new()
	add_child(slope_token)
	movement_service.set("_preview_token", slope_token)
	movement_service.set(
		"_preview_reachable_path",
		PackedVector3Array([Vector3.ZERO, Vector3(20.0, 5.0, 0.0)])
	)
	_check(bool(movement_service.call("commit_preview")), "Long movement route did not commit")
	var slope_length: float = Vector3.ZERO.distance_to(Vector3(20.0, 5.0, 0.0))
	_check(
		is_equal_approx(
			float(movement_service.get("_moving_speed")),
			slope_length / 2.0
		),
		"Long movement route was not capped at two seconds"
	)
	for _step_index: int in range(4):
		movement_service.call("_process", 0.5)
	_check(
		slope_token.global_position.is_equal_approx(Vector3(20.0, 5.0, 0.0)),
		"Long movement route did not arrive within two seconds"
	)
	_check(
		slope_token.global_transform.basis.z.normalized().dot(Vector3.RIGHT) > 0.999,
		"Slope movement did not preserve horizontal +Z facing"
	)
	_check(
		slope_token.global_transform.basis.y.normalized().dot(Vector3.UP) > 0.999,
		"Slope movement tilted the Token"
	)

	var stationary_token: Node3D = Node3D.new()
	stationary_token.rotation.y = 0.75
	add_child(stationary_token)
	var initial_basis: Basis = stationary_token.global_transform.basis
	movement_service.set("_preview_token", stationary_token)
	movement_service.set(
		"_preview_reachable_path",
		PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	)
	_check(bool(movement_service.call("commit_preview")), "Zero-length route did not commit")
	movement_service.call("_process", 0.1)
	_check(
		stationary_token.global_transform.basis.is_equal_approx(initial_basis),
		"Zero-length route changed Token facing"
	)
	_check(
		is_equal_approx(float(movement_service.get("_moving_speed")), 6.0),
		"Movement speed did not reset after route completion"
	)

	remove_child(short_token)
	short_token.free()
	remove_child(slope_token)
	slope_token.free()
	remove_child(stationary_token)
	stationary_token.free()
	remove_child(movement_service)
	movement_service.free()


func _write_test_glb() -> bool:
	var root: Node3D = Node3D.new()
	root.name = "CacheFixture"
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Box"
	mesh_instance.mesh = BoxMesh.new()
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var append_error: int = document.append_from_scene(root, state)
	var write_error: int = FAILED
	if append_error == OK:
		# GLTFState keeps raw scene-node pointers until serialization finishes.
		write_error = document.write_to_filesystem(state, TEMP_MODEL_SOURCE_PATH)
	root.free()
	return write_error == OK


func _count_mesh_instances(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _string_array_from_variant(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		var source: Array = value
		for item: Variant in source:
			result.append(String(item))
	return result


func _check_log_sequence(
		log: Array[String],
		expected_steps: Array[String],
		message: String
) -> void:
	var cursor: int = 0
	for entry: String in log:
		if cursor < expected_steps.size() and entry == expected_steps[cursor]:
			cursor += 1
	_check(
		cursor == expected_steps.size(),
		message + " log=" + JSON.stringify(log)
	)


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)


func _cleanup_fixtures() -> void:
	if ModuleGate.current_module_name() == TEMP_MODULE_NAME:
		ModuleGate.close_module()
	if FileAccess.file_exists(TEMP_SCENE_PATH):
		DirAccess.remove_absolute(TEMP_SCENE_PATH)
	var imported_model_path: String = (
		LibraryManager.LIBRARY_ROOT + TEMP_MODEL_CATEGORY + "/" + TEMP_MODEL_FILE_NAME
	)
	LibraryManager.delete_model_cache(imported_model_path)
	if FileAccess.file_exists(imported_model_path):
		DirAccess.remove_absolute(imported_model_path)
	if FileAccess.file_exists(TEMP_MODEL_SOURCE_PATH):
		DirAccess.remove_absolute(TEMP_MODEL_SOURCE_PATH)
	DirAccess.remove_absolute(LibraryManager.LIBRARY_ROOT + TEMP_MODEL_CATEGORY + "/")
	DirAccess.remove_absolute(LibraryManager.MODEL_CACHE_ROOT + TEMP_MODEL_CATEGORY + "/")
	LibraryManager.delete_ground_texture(TEMP_GROUND_GROUP)
	_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(TEMP_MODULE_NAME))
	_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(TEMP_EMPTY_IMPORT_MODULE_NAME))
	if _empty_imported_module_name != "":
		_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(_empty_imported_module_name))
	_remove_dir_recursive(TEMP_EMPTY_IMPORT_SOURCE_PATH)


func _remove_dir_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name == "." or entry_name == "..":
			entry_name = dir.get_next()
			continue
		var entry_path: String = dir_path.path_join(entry_name)
		if dir.current_is_dir():
			_remove_dir_recursive(entry_path)
		else:
			DirAccess.remove_absolute(entry_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)
