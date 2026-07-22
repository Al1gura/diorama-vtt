extends Node

const TEMP_MODULE_NAME: String = "__p3_2_controller_regression__"
const PLAYTHROUGH_CONTROLLER_SCRIPT: GDScript = preload(
	"res://scripts/playthrough_controller.gd"
)

var _assertion_count: int = 0
var _failures: Array[String] = []
var _steps: Array[String] = []
var _module_dir: String = ""
var _manifest: ModuleManifest = null
var _first_location_id: String = ""
var _second_location_id: String = ""
var _canonical_bytes: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_fixture()
	_setup_fixture()
	await _test_controller_lifecycle_and_recreation()
	_cleanup_fixture()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P3_2_CONTROLLER_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_2_CONTROLLER_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _setup_fixture() -> void:
	var create_error: int = ModuleGate.create_module(TEMP_MODULE_NAME)
	_check(create_error == OK, "Controller fixture module could not be created")
	if create_error != OK:
		return
	var first_name: String = ModuleGate.add_scene()
	var second_name: String = ModuleGate.add_scene()
	_check(first_name != "" and second_name != "", "Controller fixture locations could not be created")
	_manifest = ModuleGate.current_manifest()
	if _manifest == null or _manifest.locations.size() < 2:
		_check(false, "Controller fixture manifest does not contain two locations")
		return
	_first_location_id = _manifest.locations[0].location_id
	_second_location_id = _manifest.locations[1].location_id
	_module_dir = ModuleGate.current_module_dir()
	var first_root: Node3D = _build_content(
		Vector3(1.0, 0.0, 2.0),
		WallProperties.WallState.INTACT,
		true
	)
	var second_root: Node3D = _build_content(
		Vector3(21.0, 0.0, 22.0),
		WallProperties.WallState.INTACT,
		true
	)
	var first_error: int = ModuleIo.save_scene_tree(
		first_root, _manifest.locations[0].canonical_path
	)
	var second_error: int = ModuleIo.save_scene_tree(
		second_root, _manifest.locations[1].canonical_path
	)
	first_root.free()
	second_root.free()
	_check(first_error == OK and second_error == OK, "Controller canonical fixtures could not be saved")
	for location: LocationRef in _manifest.locations:
		_canonical_bytes[location.location_id] = FileAccess.get_file_as_bytes(
			location.canonical_path
		)


func _test_controller_lifecycle_and_recreation() -> void:
	if _manifest == null or _manifest.locations.size() < 2:
		return
	var first_app: Node = Node.new()
	first_app.name = "FirstApplicationTree"
	add_child(first_app)
	var first_bundle: Dictionary = _build_controller_bundle(first_app)
	var first_controller: Node = first_bundle.get("playthrough") as Node
	var first_content: Node3D = first_bundle.get("content") as Node3D
	var start_result: Dictionary = first_controller.start_new_session("控制器测试团")
	_check(int(start_result.get("error", FAILED)) == OK, "Controller could not start a new session")
	var session: Playthrough = ModuleGate.current_session()
	_check(session != null, "Controller did not commit the new session")
	if session == null:
		first_app.free()
		return
	var session_id: String = session.session_id
	_assert_content(first_content, Vector3(1.0, 0.0, 2.0), WallProperties.WallState.INTACT, true, "New session canonical load")

	_set_runtime_content(first_content, Vector3(8.0, 0.0, 9.0), WallProperties.WallState.DESTROYED, false)
	first_controller.mark_runtime_dirty()
	_steps.clear()
	var switch_result: Dictionary = first_controller.switch_location(_second_location_id)
	_check(int(switch_result.get("error", FAILED)) == OK, "Controller could not switch to an unvisited location")
	_check(_steps.find("session_save:snapshot") >= 0, "Location switch did not save a snapshot")
	_check(_steps.find("prepare_switch") > _steps.find("session_save:snapshot"), "Content cleanup happened before snapshot save")
	_assert_content(first_content, Vector3(21.0, 0.0, 22.0), WallProperties.WallState.INTACT, true, "Unvisited location canonical load")

	_set_runtime_content(first_content, Vector3(28.0, 0.0, 29.0), WallProperties.WallState.DESTROYED, false)
	first_controller.mark_runtime_dirty()
	var return_result: Dictionary = first_controller.switch_location(_first_location_id)
	_check(int(return_result.get("error", FAILED)) == OK, "Controller could not return to a visited location")
	_assert_content(first_content, Vector3(8.0, 0.0, 9.0), WallProperties.WallState.DESTROYED, false, "Visited location snapshot load")

	var active_session: Playthrough = ModuleGate.current_session()
	if active_session != null:
		var original_module_id: String = active_session.module_id
		active_session.module_id = "ffffffffffffffffffffffffffffffff"
		_steps.clear()
		var failed_switch: Dictionary = first_controller.switch_location(_second_location_id)
		_check(int(failed_switch.get("error", OK)) != OK, "Invalid session identity did not stop a location switch")
		_check(_steps.find("prepare_switch") < 0, "Failed save still cleaned or replaced content")
		_assert_content(first_content, Vector3(8.0, 0.0, 9.0), WallProperties.WallState.DESTROYED, false, "Failed save retained current content")
		active_session.module_id = original_module_id

	_steps.clear()
	var edit_result: Dictionary = first_controller.leave_session_for_edit()
	_check(int(edit_result.get("error", FAILED)) == OK, "Controller could not return to edit mode")
	_check(ModuleGate.current_session() == null, "Returning to edit mode did not clear the active session")
	_check(_steps.find("prepare_switch") > _steps.find("session_save:snapshot"), "Edit return cleaned content before saving")
	_assert_content(first_content, Vector3(1.0, 0.0, 2.0), WallProperties.WallState.INTACT, true, "Edit mode canonical reload")
	_assert_canonical_unchanged()

	first_app.free()
	ModuleGate.close_module()
	var second_app: Node = Node.new()
	second_app.name = "SecondApplicationTree"
	add_child(second_app)
	var reopen_error: int = ModuleGate.open_module(TEMP_MODULE_NAME)
	_check(reopen_error == OK, "Module could not reopen after application tree recreation")
	_manifest = ModuleGate.current_manifest()
	var second_bundle: Dictionary = _build_controller_bundle(second_app)
	var second_controller: Node = second_bundle.get("playthrough") as Node
	var second_content: Node3D = second_bundle.get("content") as Node3D
	var open_result: Dictionary = second_controller.open_session(session_id)
	_check(int(open_result.get("error", FAILED)) == OK, "Controller could not continue session after application tree recreation")
	_check(ModuleGate.current_location_id() == _first_location_id, "Recreated controller restored the wrong current location")
	_assert_content(second_content, Vector3(8.0, 0.0, 9.0), WallProperties.WallState.DESTROYED, false, "Recreated controller session restore")
	_assert_canonical_unchanged()
	second_app.free()


func _build_controller_bundle(parent: Node) -> Dictionary:
	var content: Node3D = Node3D.new()
	content.name = "ContentRoot"
	content.set_script(load("res://scripts/scene_props.gd"))
	parent.add_child(content)
	var scene_controller: SceneSessionController = SceneSessionController.new()
	parent.add_child(scene_controller)
	scene_controller.configure(
		content,
		"builtin",
		0.0,
		100.0,
		100.0,
		Callable(self, "_record_prepare_switch"),
		Callable(self, "_noop_ground"),
		Callable(self, "_noop_scene_size"),
		Callable(self, "_noop_scene_size"),
		Callable(self, "_zero_migrations"),
		Callable(),
		Callable(),
		Callable(self, "_set_location_name"),
		Callable(self, "_get_manifest")
	)
	var playthrough: Node = PLAYTHROUGH_CONTROLLER_SCRIPT.new()
	parent.add_child(playthrough)
	playthrough.configure(content, scene_controller)
	playthrough.operation_step_recorded.connect(_record_controller_step)
	return {
		"content": content,
		"scene": scene_controller,
		"playthrough": playthrough,
	}


func _record_prepare_switch() -> void:
	_steps.append("prepare_switch")


func _record_controller_step(step: String) -> void:
	_steps.append(step)


func _noop_ground(_base: String, _tile: float, _source: String) -> void:
	pass


func _noop_scene_size(_width: float, _height: float) -> void:
	pass


func _zero_migrations() -> int:
	return 0


func _set_location_name(location_name: String) -> void:
	ModuleGate.set_current_location(location_name)


func _get_manifest() -> ModuleManifest:
	return ModuleGate.current_manifest()


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


func _assert_canonical_unchanged() -> void:
	if _manifest == null:
		return
	for location: LocationRef in _manifest.locations:
		var before: PackedByteArray = _canonical_bytes.get(location.location_id, PackedByteArray()) as PackedByteArray
		var after: PackedByteArray = FileAccess.get_file_as_bytes(location.canonical_path)
		_check(after == before, "Controller changed canonical bytes for " + location.location_id)


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
