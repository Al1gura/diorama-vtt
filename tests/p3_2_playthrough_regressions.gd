extends Node

const TEMP_MODULE_NAME: String = "__p3_2_playthrough_regression__"
const SESSION_NAME: String = "周六团"
const SECOND_SESSION_NAME: String = "周日团"

var _assertion_count: int = 0
var _failures: Array[String] = []
var _module_dir: String = ""
var _manifest: ModuleManifest = null
var _location_id: String = ""
var _canonical_path: String = ""


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_fixture()
	_setup_fixture()
	_test_new_session_keeps_canonical_bytes()
	_test_snapshot_and_full_tree_recreation_restore_runtime_state()
	_test_new_session_does_not_modify_old_session()
	_test_session_json_backup_and_validation_failures()
	_test_snapshot_backup_missing_and_corrupt_failures()
	_cleanup_fixture()

	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P3_2_PLAYTHROUGH_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_2_PLAYTHROUGH_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _setup_fixture() -> void:
	var create_error: int = ModuleGate.create_module(TEMP_MODULE_NAME)
	_check(create_error == OK, "P3.2 fixture module could not be created")
	if create_error != OK:
		return
	var scene_name: String = ModuleGate.add_scene()
	_check(scene_name != "", "P3.2 fixture location could not be created")
	_manifest = ModuleGate.current_manifest()
	_check(_manifest != null, "P3.2 fixture manifest is missing")
	if _manifest == null or _manifest.locations.is_empty():
		return
	var location: LocationRef = _manifest.locations[0]
	_location_id = location.location_id
	_canonical_path = location.canonical_path
	_module_dir = ModuleGate.current_module_dir()
	var canonical_root: Node3D = _build_content(Vector3(1.0, 0.0, 2.0), WallProperties.WallState.INTACT)
	var save_error: int = ModuleIo.save_scene_tree(canonical_root, _canonical_path)
	canonical_root.free()
	_check(save_error == OK, "P3.2 fixture canonical scene could not be saved")


func _test_new_session_keeps_canonical_bytes() -> void:
	if _manifest == null:
		return
	var manifest_before: PackedByteArray = FileAccess.get_file_as_bytes(
		_module_dir.path_join(ModuleIo.MANIFEST_FILE_NAME)
	)
	var canonical_before: PackedByteArray = FileAccess.get_file_as_bytes(_canonical_path)
	var create_result: Dictionary = ModuleGate.create_playthrough(SESSION_NAME)
	_check(int(create_result.get("error", FAILED)) == OK, "New playthrough could not be created")
	var session: Playthrough = create_result.get("value") as Playthrough
	_check(session != null, "New playthrough did not return typed data")
	if session == null:
		return
	_check(_is_hex32(session.session_id), "New playthrough session_id is invalid")
	_check(session.schema_version == Playthrough.SCHEMA_VERSION, "New playthrough schema version is wrong")
	_check(session.module_id == _manifest.module_id, "New playthrough module_id is wrong")
	_check(session.current_location_id == _location_id, "New playthrough start location is wrong")
	_check(session.location_states.is_empty(), "New playthrough created a snapshot before visiting changes")
	_check(
		FileAccess.file_exists(
			_module_dir.path_join("sessions").path_join(session.session_id).path_join("session.json")
		),
		"New playthrough did not write session.json"
	)
	_check(
		FileAccess.get_file_as_bytes(_module_dir.path_join(ModuleIo.MANIFEST_FILE_NAME)) == manifest_before,
		"Creating a playthrough changed manifest.json"
	)
	_check(
		FileAccess.get_file_as_bytes(_canonical_path) == canonical_before,
		"Creating a playthrough changed the canonical scene"
	)


func _test_snapshot_and_full_tree_recreation_restore_runtime_state() -> void:
	var session: Playthrough = ModuleGate.current_session()
	_check(session != null, "Snapshot test has no active playthrough")
	if session == null:
		return
	var first_application_tree: Node = Node.new()
	first_application_tree.name = "FirstApplicationTree"
	add_child(first_application_tree)
	var runtime_root: Node3D = _build_content(
		Vector3(8.0, 0.0, 9.0),
		WallProperties.WallState.DESTROYED
	)
	first_application_tree.add_child(runtime_root)
	var session_dir: String = _module_dir.path_join("sessions").path_join(session.session_id)
	var snapshot_result: Dictionary = ModuleIo.save_session_snapshot_recoverable(
		session_dir,
		_location_id,
		runtime_root
	)
	_check(int(snapshot_result.get("error", FAILED)) == OK, "Runtime location snapshot could not be saved")
	var candidate: Playthrough = session.copy_data()
	candidate.location_states[_location_id] = "states/%s.scn" % _location_id
	var session_result: Dictionary = ModuleIo.save_playthrough_recoverable(
		_module_dir,
		_manifest,
		candidate
	)
	_check(int(session_result.get("error", FAILED)) == OK, "Updated session.json could not be saved")
	if int(session_result.get("error", FAILED)) == OK:
		ModuleGate.commit_current_session(candidate)
	first_application_tree.free()
	ModuleGate.close_module()

	var second_application_tree: Node = Node.new()
	second_application_tree.name = "SecondApplicationTree"
	add_child(second_application_tree)
	var open_module_error: int = ModuleGate.open_module(TEMP_MODULE_NAME)
	_check(open_module_error == OK, "Module could not reopen after full application tree recreation")
	var open_session_result: Dictionary = ModuleGate.open_playthrough(candidate.session_id)
	_check(int(open_session_result.get("error", FAILED)) == OK, "Playthrough could not reopen from disk")
	var snapshot_load: Dictionary = ModuleIo.load_session_snapshot_recoverable(
		session_dir,
		_location_id
	)
	_check(int(snapshot_load.get("error", FAILED)) == OK, "Runtime snapshot could not be restored")
	var restored_root: Node3D = snapshot_load.get("value") as Node3D
	_check(restored_root != null, "Runtime snapshot did not instantiate a content root")
	if restored_root != null:
		second_application_tree.add_child(restored_root)
		var token: Node3D = restored_root.get_node_or_null("Token") as Node3D
		var wall_properties: WallProperties = restored_root.get_node_or_null(
			"Wall/WallProperties"
		) as WallProperties
		_check(token != null and token.position == Vector3(8.0, 0.0, 9.0), "Token position was not restored")
		_check(
			wall_properties != null
			and wall_properties.wall_state == WallProperties.WallState.DESTROYED,
			"Wall destruction state was not restored"
		)
		_check(
			restored_root.get_node_or_null("RuntimeOnly") == null,
			"Runtime-only node leaked into the session snapshot"
		)
	second_application_tree.free()


func _test_new_session_does_not_modify_old_session() -> void:
	var old_session: Playthrough = ModuleGate.current_session()
	_check(old_session != null, "Old playthrough is missing before creating another")
	if old_session == null:
		return
	var old_session_path: String = _module_dir.path_join("sessions").path_join(
		old_session.session_id
	).path_join("session.json")
	var old_session_before: PackedByteArray = FileAccess.get_file_as_bytes(old_session_path)
	var canonical_before: PackedByteArray = FileAccess.get_file_as_bytes(_canonical_path)
	var create_result: Dictionary = ModuleGate.create_playthrough(SECOND_SESSION_NAME)
	_check(int(create_result.get("error", FAILED)) == OK, "Second playthrough could not be created")
	var new_session: Playthrough = create_result.get("value") as Playthrough
	_check(
		new_session != null and new_session.session_id != old_session.session_id,
		"Second playthrough reused the old session_id"
	)
	_check(FileAccess.get_file_as_bytes(old_session_path) == old_session_before, "Second playthrough changed old session.json")
	_check(FileAccess.get_file_as_bytes(_canonical_path) == canonical_before, "Second playthrough changed the canonical scene")


func _test_session_json_backup_and_validation_failures() -> void:
	var session: Playthrough = ModuleGate.current_session()
	if session == null:
		return
	var session_dir: String = _module_dir.path_join("sessions").path_join(session.session_id)
	var session_path: String = session_dir.path_join("session.json")
	var valid_text: String = FileAccess.get_file_as_string(session_path)
	_write_text(session_path + ".bak", valid_text)
	_write_text(session_path, "{broken")
	var recovered_result: Dictionary = ModuleIo.load_playthrough_for_session(
		_module_dir,
		_manifest,
		session.session_id
	)
	_check(int(recovered_result.get("error", FAILED)) == OK, "Corrupt session.json was not restored from backup")
	_check(bool(recovered_result.get("recovered_from_backup", false)), "Session backup recovery was not reported")

	var future_data: Dictionary = session.to_json_dict()
	future_data["schema_version"] = 999
	_write_json(session_path, future_data)
	var future_before: String = FileAccess.get_file_as_string(session_path)
	var future_result: Dictionary = ModuleIo.load_playthrough_for_session(
		_module_dir,
		_manifest,
		session.session_id
	)
	_check(int(future_result.get("error", OK)) == ERR_UNAVAILABLE, "Future session version was not rejected")
	_check(FileAccess.get_file_as_string(session_path) == future_before, "Future session was rewritten")

	var mismatch_data: Dictionary = session.to_json_dict()
	mismatch_data["module_id"] = _fixed_id("ab")
	_write_json(session_path, mismatch_data)
	var mismatch_result: Dictionary = ModuleIo.load_playthrough_for_session(
		_module_dir,
		_manifest,
		session.session_id
	)
	_check(int(mismatch_result.get("error", OK)) == ERR_INVALID_DATA, "Mismatched module_id was not rejected")
	_write_text(session_path, valid_text)


func _test_snapshot_backup_missing_and_corrupt_failures() -> void:
	var session: Playthrough = ModuleGate.current_session()
	if session == null:
		return
	var session_dir: String = _module_dir.path_join("sessions").path_join(session.session_id)
	var state_dir: String = session_dir.path_join("states")
	DirAccess.make_dir_recursive_absolute(state_dir)
	var final_path: String = state_dir.path_join(_location_id + ".scn")
	var backup_path: String = state_dir.path_join(_location_id + ".bak.scn")
	var root: Node3D = _build_content(Vector3(3.0, 0.0, 4.0), WallProperties.WallState.DESTROYED)
	_check(ModuleIo.save_scene_tree(root, backup_path) == OK, "Snapshot backup fixture could not be written")
	root.free()
	_write_text(final_path, "broken snapshot")
	var recovered_result: Dictionary = ModuleIo.load_session_snapshot_recoverable(session_dir, _location_id)
	_check(int(recovered_result.get("error", FAILED)) == OK, "Corrupt snapshot was not restored from backup")
	_check(bool(recovered_result.get("recovered_from_backup", false)), "Snapshot backup recovery was not reported")
	var recovered_root: Node = recovered_result.get("value") as Node
	if recovered_root != null:
		recovered_root.free()
	DirAccess.remove_absolute(final_path)
	DirAccess.remove_absolute(backup_path)
	var missing_result: Dictionary = ModuleIo.load_session_snapshot_recoverable(session_dir, _location_id)
	_check(int(missing_result.get("error", OK)) == ERR_FILE_NOT_FOUND, "Missing snapshot did not fail explicitly")
	_write_text(final_path, "broken final")
	_write_text(backup_path, "broken backup")
	var corrupt_result: Dictionary = ModuleIo.load_session_snapshot_recoverable(session_dir, _location_id)
	_check(int(corrupt_result.get("error", OK)) != OK, "Double-corrupt snapshot unexpectedly loaded")


func _build_content(token_position: Vector3, wall_state: WallProperties.WallState) -> Node3D:
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
	var runtime_only: Node3D = Node3D.new()
	runtime_only.name = "RuntimeOnly"
	runtime_only.set_meta("gvtt_runtime_only", true)
	root.add_child(runtime_only)
	return root


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


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t", true))


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _fixed_id(byte_text: String) -> String:
	return byte_text.repeat(16).left(32).to_lower()


func _is_hex32(value: String) -> bool:
	if value.length() != 32 or value != value.to_lower():
		return false
	for index: int in range(value.length()):
		if "0123456789abcdef".find(value.substr(index, 1)) < 0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
