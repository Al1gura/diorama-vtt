extends Node

const TEMP_MODULE_NAME: String = "__p3_2_visible_regression__"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _first_location_id: String = ""
var _second_location_id: String = ""
var _first_canonical_path: String = ""
var _first_canonical_bytes: PackedByteArray = PackedByteArray()

@onready var _main: Node3D = $Main


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_fixture()
	await _setup_fixture()
	await _test_visible_playthrough_workflow()
	_cleanup_fixture()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P3_2_VISIBLE_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_2_VISIBLE_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _setup_fixture() -> void:
	var create_error: int = ModuleGate.create_module(TEMP_MODULE_NAME)
	_check(create_error == OK, "Visible fixture module could not be created")
	await get_tree().process_frame
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		_check(false, "Visible fixture manifest is missing")
		return
	if manifest.locations.is_empty():
		_check(false, "Main did not create the first visible fixture location")
		return
	var second_name: String = ModuleGate.add_scene()
	_check(second_name != "", "Visible fixture second location could not be created")
	manifest = ModuleGate.current_manifest()
	if manifest == null or manifest.locations.size() < 2:
		_check(false, "Visible fixture does not contain two locations")
		return
	var first_location: LocationRef = manifest.locations[0]
	var second_location: LocationRef = manifest.locations[1]
	_first_location_id = first_location.location_id
	_second_location_id = second_location.location_id
	_first_canonical_path = first_location.canonical_path
	var first_root: Node3D = _build_content(
		Vector3(1.0, 0.0, 2.0), WallProperties.WallState.INTACT, true
	)
	var second_root: Node3D = _build_content(
		Vector3(21.0, 0.0, 22.0), WallProperties.WallState.INTACT, true
	)
	var first_error: int = ModuleIo.save_scene_tree(first_root, first_location.canonical_path)
	var second_error: int = ModuleIo.save_scene_tree(second_root, second_location.canonical_path)
	first_root.free()
	second_root.free()
	_check(first_error == OK and second_error == OK, "Visible fixture canonical scenes could not be saved")
	_first_canonical_bytes = FileAccess.get_file_as_bytes(_first_canonical_path)
	ModuleGate.set_current_location_by_id(_first_location_id)
	_main.call("_switch_to_scene", first_location.display_name)
	await get_tree().process_frame


func _test_visible_playthrough_workflow() -> void:
	if _first_location_id == "" or _second_location_id == "":
		return
	var app_menu_button: MenuButton = _main.get("_app_menu_btn") as MenuButton
	var app_popup: PopupMenu = app_menu_button.get_popup() if app_menu_button != null else null
	_check(app_popup != null and app_popup.item_count == 2, "Visible File menu does not show exactly two module commands")
	_check(
		app_popup == null or app_popup.get_item_index(4) < 0,
		"Visible File menu still contains the add-table command"
	)
	_check(
		app_popup == null or app_popup.get_item_index(2) < 0,
		"Visible File menu still exposes the manual module-backup command"
	)

	var mode_button: Button = _main.get("_mode_btn") as Button
	var test_button: Button = _main.get("_test_btn") as Button
	var scene_controller: SceneSessionController = (
		_main.get("_scene_session_controller") as SceneSessionController
	)
	var left_panel: Control = _main.get("_left_panel") as Control
	_check(
		not _control_tree_has_button_text(left_panel, "带团记录"),
		"Visible edit panel still contains the playthrough section"
	)
	_check(
		_main.get("_playthrough_list") == null,
		"Visible playthrough list exists before Start is pressed"
	)
	_check(mode_button != null and mode_button.text == "开始 ▶", "Visible recorded entry is not labeled 开始")
	_check(test_button != null and test_button.text == "测试 ▶", "Visible temporary entry is not labeled 测试")
	if scene_controller != null:
		scene_controller.mark_dirty()
	_main.call("_on_test_btn_pressed")
	await get_tree().process_frame
	_check(ModeGate.is_run(), "Visible Test did not enter run mode")
	_check(ModuleGate.current_session() == null, "Visible Test unexpectedly created a playthrough")
	var mode_label: Label = _main.get("_mode_label") as Label
	_check(mode_label != null and mode_label.text == "测试中", "Visible Test does not show the testing state")
	var content: Node3D = _main.get("_content_root") as Node3D
	_set_runtime_content(
		content,
		Vector3(6.0, 0.0, 7.0),
		WallProperties.WallState.DESTROYED,
		false
	)
	_main.call("_mark_scene_dirty")
	await get_tree().create_timer(1.5).timeout
	_check(ModuleGate.list_playthroughs().is_empty(), "Visible Test wrote a playthrough after the autosave delay")
	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	_check(ModeGate.is_edit(), "Visible Test did not return to edit mode")
	_check(ModuleGate.current_session() == null, "Visible Test left an active playthrough")
	_check(
		scene_controller != null and scene_controller.is_dirty(),
		"Visible Test did not preserve the previous edit dirty state"
	)
	_assert_content(
		content,
		Vector3(1.0, 0.0, 2.0),
		WallProperties.WallState.INTACT,
		true,
		"Visible Test memory snapshot restore"
	)
	_check(
		FileAccess.get_file_as_bytes(_first_canonical_path) == _first_canonical_bytes,
		"Visible Test changed canonical bytes"
	)
	if scene_controller != null:
		scene_controller.clear_dirty()

	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	var playthrough_dialog: AcceptDialog = _main.get("_playthrough_dialog") as AcceptDialog
	_check(
		playthrough_dialog != null and playthrough_dialog.title == "开始带团",
		"Visible Start did not open the playthrough dialog"
	)
	var add_table_button: Button = _main.get("_add_table_button") as Button
	_check(
		add_table_button != null and add_table_button.text == "＋ 新增一桌",
		"Visible Start dialog add-table button is missing"
	)
	if add_table_button != null:
		add_table_button.pressed.emit()
	await get_tree().process_frame
	var add_table_dialog: ConfirmationDialog = _main.get("_add_table_dialog") as ConfirmationDialog
	var add_table_name_edit: LineEdit = _main.get("_add_table_name_edit") as LineEdit
	_check(
		add_table_dialog != null and add_table_dialog.title == "新增一桌",
		"Visible add-table command did not open the naming dialog"
	)
	_check(
		add_table_name_edit != null and add_table_name_edit.text == "第1桌",
		"Visible add-table dialog did not suggest the first table name"
	)
	if add_table_name_edit != null:
		add_table_name_edit.text = "周五团"
	_main.call("_on_add_table_confirmed")
	await get_tree().process_frame
	var session: Playthrough = ModuleGate.current_session()
	_check(session != null and ModeGate.is_run(), "Visible Start Playthrough did not enter run mode")
	_check(session != null and session.session_name == "周五团", "Visible add-table command did not preserve the Friday table name")
	if session == null:
		return
	var session_id: String = session.session_id
	_assert_content(
		content,
		Vector3(1.0, 0.0, 2.0),
		WallProperties.WallState.INTACT,
		true,
		"Visible new session canonical load"
	)
	_set_runtime_content(
		content,
		Vector3(8.0, 0.0, 9.0),
		WallProperties.WallState.DESTROYED,
		false
	)
	_main.call("_mark_scene_dirty")
	await get_tree().create_timer(1.5).timeout
	session = ModuleGate.current_session()
	_check(
		session != null and session.location_states.has(_first_location_id),
		"Visible Save Playthrough did not register the first location snapshot"
	)
	_check(
		FileAccess.file_exists(
			ModuleGate.current_module_dir().path_join("sessions").path_join(
				session_id
			).path_join("states").path_join(_first_location_id + ".scn")
		),
		"Visible Save Playthrough did not write the first location snapshot"
	)

	var manifest: ModuleManifest = ModuleGate.current_manifest()
	var second_location: LocationRef = manifest.find_location_by_id(_second_location_id)
	var first_location: LocationRef = manifest.find_location_by_id(_first_location_id)
	_main.call("_on_scene_selected", second_location.display_name)
	await get_tree().process_frame
	_check(ModuleGate.current_location_id() == _second_location_id, "Visible runtime switch did not reach the second location")
	_assert_content(
		content,
		Vector3(21.0, 0.0, 22.0),
		WallProperties.WallState.INTACT,
		true,
		"Visible unvisited location canonical load"
	)
	_main.call("_on_scene_selected", first_location.display_name)
	await get_tree().process_frame
	_assert_content(
		content,
		Vector3(8.0, 0.0, 9.0),
		WallProperties.WallState.DESTROYED,
		false,
		"Visible visited location snapshot restore"
	)

	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	_check(ModeGate.is_edit() and ModuleGate.current_session() == null, "Visible Edit Mode did not leave the active session")
	_assert_content(
		content,
		Vector3(1.0, 0.0, 2.0),
		WallProperties.WallState.INTACT,
		true,
		"Visible edit mode canonical reload"
	)
	_check(
		FileAccess.get_file_as_bytes(_first_canonical_path) == _first_canonical_bytes,
		"Visible playthrough workflow changed canonical bytes"
	)

	_check(mode_button != null and mode_button.text == "开始 ▶", "Visible recorded entry changed away from 开始")
	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	playthrough_dialog = _main.get("_playthrough_dialog") as AcceptDialog
	_check(
		playthrough_dialog != null and _find_table_enter_button("周五团") != null,
		"Visible Start dialog does not show the existing Friday table"
	)
	add_table_button = _main.get("_add_table_button") as Button
	if add_table_button != null:
		add_table_button.pressed.emit()
	await get_tree().process_frame
	add_table_name_edit = _main.get("_add_table_name_edit") as LineEdit
	if add_table_name_edit != null:
		add_table_name_edit.text = "周六团"
	_main.call("_on_add_table_confirmed")
	await get_tree().process_frame
	var saturday_session: Playthrough = ModuleGate.current_session()
	_check(
		saturday_session != null
		and saturday_session.session_id != session_id
		and saturday_session.session_name == "周六团",
		"Visible add-table command did not create an independent Saturday table"
	)
	_assert_content(
		content,
		Vector3(1.0, 0.0, 2.0),
		WallProperties.WallState.INTACT,
		true,
		"Visible Saturday table canonical start"
	)
	_set_runtime_content(
		content,
		Vector3(12.0, 0.0, 13.0),
		WallProperties.WallState.INTACT,
		false
	)
	_main.call("_mark_scene_dirty")
	await get_tree().create_timer(1.5).timeout
	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	_check(ModeGate.is_edit(), "Visible Saturday table did not return to edit mode")
	_assert_content(
		content,
		Vector3(1.0, 0.0, 2.0),
		WallProperties.WallState.INTACT,
		true,
		"Visible edit mode after Saturday table"
	)
	var table_entries: Array[Dictionary] = ModuleGate.list_playthroughs()
	var table_names: Array[String] = []
	for table_entry: Dictionary in table_entries:
		if int(table_entry.get("error", FAILED)) == OK:
			table_names.append(String(table_entry.get("session_name", "")))
	_check(
		table_names.size() == 2 and table_names.has("周五团") and table_names.has("周六团"),
		"Visible module does not contain exactly the Friday and Saturday records"
	)
	_main.call("_on_mode_btn_pressed")
	await get_tree().process_frame
	_check(
		ModeGate.is_edit(),
		"Visible Start changed mode before a table was selected"
	)
	playthrough_dialog = _main.get("_playthrough_dialog") as AcceptDialog
	_check(
		playthrough_dialog != null and playthrough_dialog.title == "开始带团",
		"Visible Start did not reopen the playthrough dialog for multiple tables"
	)
	var friday_button: Button = _find_table_enter_button("周五团")
	_check(friday_button != null, "Visible Start dialog does not show the Friday table")
	_check(_find_table_enter_button("周六团") != null, "Visible Start dialog does not show the Saturday table")
	if friday_button != null:
		friday_button.pressed.emit()
	await get_tree().process_frame
	_check(ModeGate.is_run(), "Visible Friday table restore did not enter run mode")
	_check(
		ModuleGate.current_session() != null
		and ModuleGate.current_session().session_id == session_id,
		"Visible Friday table restore selected the wrong table"
	)
	_assert_content(
		content,
		Vector3(8.0, 0.0, 9.0),
		WallProperties.WallState.DESTROYED,
		false,
		"Visible Friday table restore after Saturday play"
	)

	_main.call("clear_application_contract_log")
	var exit_ready: bool = bool(_main.call("_prepare_application_exit"))
	var exit_log: Array[String] = []
	exit_log.assign(_main.call("get_application_contract_log"))
	_check(exit_ready, "Visible application exit preparation could not save the session")
	_check(
		exit_log.find("session_save:snapshot") >= 0
		and exit_log.find("session_save:snapshot") < exit_log.find("exit:movement"),
		"Visible application exit released movement before saving the session"
	)


func _build_content(
		token_position: Vector3,
		wall_state: WallProperties.WallState,
		light_on: bool
) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ContentRoot"
	root.set_script(load("res://scripts/scene_props.gd"))
	var token: Node3D = Node3D.new()
	token.name = "Token"
	token.position = token_position
	root.add_child(token)
	var wall: Node3D = Node3D.new()
	wall.name = "Wall"
	root.add_child(wall)
	var wall_properties: WallProperties = WallProperties.new()
	wall_properties.name = "WallProperties"
	wall_properties.wall_state = wall_state
	wall.add_child(wall_properties)
	var light: Node3D = Node3D.new()
	light.name = "Light"
	root.add_child(light)
	var light_properties: LightProperties = LightProperties.new()
	light_properties.name = "LightProperties"
	light_properties.is_on = light_on
	light.add_child(light_properties)
	return root


func _find_table_enter_button(table_name: String) -> Button:
	var playthrough_list: VBoxContainer = _main.get("_playthrough_list") as VBoxContainer
	if playthrough_list == null:
		return null
	for child: Node in playthrough_list.get_children():
		if String(child.get_meta("gvtt_session_name", "")) != table_name:
			continue
		return child.get_node_or_null("EnterTable") as Button
	return null


func _control_tree_has_button_text(root: Control, text: String) -> bool:
	if root == null:
		return false
	var buttons: Array[Node] = root.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and button.text.contains(text):
			return true
	return false


func _set_runtime_content(
		content: Node3D,
		token_position: Vector3,
		wall_state: WallProperties.WallState,
		light_on: bool
) -> void:
	var token: Node3D = content.get_node_or_null("Token") as Node3D
	var wall_properties: WallProperties = content.get_node_or_null("Wall/WallProperties") as WallProperties
	var light_properties: LightProperties = content.get_node_or_null("Light/LightProperties") as LightProperties
	if token != null:
		token.position = token_position
	if wall_properties != null:
		wall_properties.wall_state = wall_state
	if light_properties != null:
		light_properties.is_on = light_on


func _assert_content(
		content: Node3D,
		token_position: Vector3,
		wall_state: WallProperties.WallState,
		light_on: bool,
		context: String
) -> void:
	var token: Node3D = content.get_node_or_null("Token") as Node3D
	var wall_properties: WallProperties = content.get_node_or_null("Wall/WallProperties") as WallProperties
	var light_properties: LightProperties = content.get_node_or_null("Light/LightProperties") as LightProperties
	_check(token != null and token.position == token_position, context + ": token position mismatch")
	_check(wall_properties != null and wall_properties.wall_state == wall_state, context + ": wall state mismatch")
	_check(light_properties != null and light_properties.is_on == light_on, context + ": light state mismatch")


func _cleanup_fixture() -> void:
	if ModuleGate.has_open_module():
		ModuleGate.close_module()
	_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(TEMP_MODULE_NAME))


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
