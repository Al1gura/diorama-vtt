extends Node

const TEMP_NEW_MODULE_NAME: String = "_p3_1_manifest_new"
const TEMP_LEGACY_MODULE_NAME: String = "_p3_1_manifest_legacy"
const TEMP_BAD_MODULE_NAME: String = "_p3_1_manifest_bad"
const TEMP_SCHEMA_MODULE_NAME: String = "_p3_1_manifest_schema"
const TEMP_FUTURE_MODULE_NAME: String = "_p3_1_manifest_future"
const TEMP_EXTERNAL_MODULE_NAME: String = "_p3_1_manifest_external"
const TEMP_ABSOLUTE_MODULE_NAME: String = "_p3_1_manifest_absolute"
const TEMP_CURRENT_MODULE_NAME: String = "_p3_1_manifest_current"
const TEMP_ONLY_TMP_MODULE_NAME: String = "_p3_1_manifest_only_tmp"
const TEMP_DOUBLE_CORRUPT_MODULE_NAME: String = "_p3_1_manifest_double_corrupt"
const TEMP_INVALID_ID_MODULE_NAME: String = "_p3_1_manifest_invalid_id"
const TEMP_EXTERNAL_ESCAPE_MODULE_NAME: String = "_p3_1_manifest_external_escape"
const TEMP_INCREMENTAL_BACKUP_MODULE_NAME: String = "_p3_1_incremental_backup"
const BACKUP_STORE_SCRIPT_PATH: String = "res://scripts/module_backup_store.gd"

var _assertion_count: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_cleanup_fixtures()
	_test_new_module_reopen_keeps_stable_ids()
	_test_legacy_canonical_migration_keeps_files_and_ids()
	_test_schema_zero_migrates_stepwise()
	_test_backup_restores_corrupt_manifest()
	_test_only_valid_temp_recovers_first_creation()
	_test_formal_and_backup_corrupt_are_rejected_without_rewrite()
	_test_future_version_is_rejected_without_rewrite()
	_test_path_escape_and_absolute_paths_are_rejected()
	_test_invalid_and_duplicate_ids_are_rejected()
	_test_external_module_relative_escape_is_rejected()
	_test_missing_refs_are_retained_and_marked_unavailable()
	_test_open_and_create_failures_do_not_replace_current_truth()
	_test_incremental_backups_create_recovery_points_and_reuse_content()
	_cleanup_fixtures()

	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P3_1_MODULE_MANIFEST_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P3_1_MODULE_MANIFEST_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_new_module_reopen_keeps_stable_ids() -> void:
	var create_err: int = ModuleGate.create_module(TEMP_NEW_MODULE_NAME)
	_check(create_err == OK, "New module could not be created")
	var first_scene_name: String = ModuleGate.add_scene()
	_check(first_scene_name != "", "New module could not create a scene reference")
	var first_manifest: ModuleManifest = ModuleGate.current_manifest()
	_check(first_manifest != null, "New module did not expose a manifest")
	if first_manifest == null:
		return
	var module_id: String = String(first_manifest.get("module_id"))
	var start_location_id: String = String(first_manifest.get("start_location_id"))
	_check(_is_hex32(module_id), "New module_id is not a 32-character lowercase hex ID")
	_check(_is_hex32(start_location_id), "New start_location_id is not a stable location ID")
	_check(FileAccess.file_exists(_manifest_path(TEMP_NEW_MODULE_NAME)), "New module did not write manifest.json")
	_check(first_manifest.locations.size() == 1, "New module scene reference was not stored in the manifest")
	if first_manifest.locations.size() == 0:
		return
	var first_location: LocationRef = first_manifest.locations[0]
	var location_id: String = String(first_location.get("location_id"))
	var canonical_relpath: String = String(first_location.get("canonical_relpath"))
	_check(_is_hex32(location_id), "New location_id is not a stable ID")
	_check(canonical_relpath.begins_with("_canonical/"), "New scene canonical path is not module-relative")
	_check(not canonical_relpath.is_absolute_path(), "New scene canonical path is absolute")
	first_location.display_name = "Renamed Scene"
	first_manifest.sync_legacy_start_location()
	var rename_result: Dictionary = ModuleIo.save_manifest_recoverable(
		_module_dir(TEMP_NEW_MODULE_NAME),
		first_manifest
	)
	_check(int(rename_result.get("error", FAILED)) == OK, "Renamed manifest could not be saved")
	ModuleGate.close_module()
	var open_err: int = ModuleGate.open_module(TEMP_NEW_MODULE_NAME)
	_check(open_err == OK, "New module could not be reopened")
	var reopened_manifest: ModuleManifest = ModuleGate.current_manifest()
	_check(reopened_manifest != null, "Reopened module manifest is missing")
	if reopened_manifest == null or reopened_manifest.locations.size() == 0:
		return
	_check(String(reopened_manifest.get("module_id")) == module_id, "module_id changed after reopen")
	_check(String(reopened_manifest.get("start_location_id")) == start_location_id, "start_location_id changed after reopen")
	_check(String(reopened_manifest.locations[0].get("location_id")) == location_id, "location_id changed after reopen")
	_check(
		String(reopened_manifest.locations[0].get("canonical_relpath")) == canonical_relpath,
		"Scene reference changed after display-name rename"
	)


func _test_legacy_canonical_migration_keeps_files_and_ids() -> void:
	var canonical_dir: String = _canonical_dir(TEMP_LEGACY_MODULE_NAME)
	_check(DirAccess.make_dir_recursive_absolute(canonical_dir) == OK, "Legacy canonical dir could not be created")
	var old_scene_path: String = canonical_dir.path_join("Old Hall.scn")
	_check(_write_scene(old_scene_path), "Legacy scene fixture could not be saved")
	var open_err: int = ModuleGate.open_module(TEMP_LEGACY_MODULE_NAME)
	_check(open_err == OK, "Legacy module could not be migrated")
	_check(FileAccess.file_exists(old_scene_path), "Legacy migration moved or deleted the old scene file")
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	_check(manifest != null and manifest.locations.size() == 1, "Legacy migration did not create one manifest location")
	if manifest == null or manifest.locations.size() == 0:
		return
	var first_module_id: String = String(manifest.get("module_id"))
	var first_location_id: String = String(manifest.locations[0].get("location_id"))
	var first_relpath: String = String(manifest.locations[0].get("canonical_relpath"))
	_check(first_relpath == "_canonical/Old Hall.scn", "Legacy migration did not keep the old scene relative path")
	ModuleGate.close_module()
	open_err = ModuleGate.open_module(TEMP_LEGACY_MODULE_NAME)
	_check(open_err == OK, "Migrated legacy module could not be reopened")
	manifest = ModuleGate.current_manifest()
	_check(manifest != null and String(manifest.get("module_id")) == first_module_id, "Migrated module_id changed on second open")
	_check(
		manifest != null
		and manifest.locations.size() == 1
		and String(manifest.locations[0].get("location_id")) == first_location_id,
		"Migrated location_id changed on second open"
	)


func _test_schema_zero_migrates_stepwise() -> void:
	var module_dir: String = _module_dir(TEMP_SCHEMA_MODULE_NAME)
	var canonical_dir: String = _canonical_dir(TEMP_SCHEMA_MODULE_NAME)
	_check(DirAccess.make_dir_recursive_absolute(canonical_dir) == OK, "Schema fixture dir could not be created")
	_check(_write_scene(canonical_dir.path_join("schema_old.scn")), "Schema fixture scene could not be saved")
	var location_id: String = _fixed_id("12")
	var data: Dictionary = {
		"format": "gvtt_module_manifest",
		"schema_version": 0,
		"module_id": _fixed_id("11"),
		"module_name": TEMP_SCHEMA_MODULE_NAME,
		"start_location": "Schema Old",
		"locations": [
			{
				"location_id": location_id,
				"display_name": "Schema Old",
				"canonical_path": module_dir.path_join("_canonical/schema_old.scn"),
			}
		],
		"external_contents": [],
	}
	_write_json(_manifest_path(TEMP_SCHEMA_MODULE_NAME), data)
	var open_err: int = ModuleGate.open_module(TEMP_SCHEMA_MODULE_NAME)
	_check(open_err == OK, "Schema v0 manifest did not migrate")
	var migrated_text: String = _read_text(_manifest_path(TEMP_SCHEMA_MODULE_NAME))
	var parsed: Dictionary = _parse_json_dict(migrated_text)
	_check(
		int(parsed.get("schema_version", -1)) == ModuleManifest.SCHEMA_VERSION,
		"Schema migration did not write the current version"
	)
	_check(String(parsed.get("start_location_id", "")) == location_id, "Schema migration did not convert start_location")
	_check(not parsed.has("start_location"), "Schema migration kept the legacy start_location field")
	_check(parsed.get("acts", null) is Array, "Schema migration did not add the acts array")
	_check((parsed.get("acts", []) as Array).is_empty(), "Schema migration seeded non-empty acts")


func _test_backup_restores_corrupt_manifest() -> void:
	var create_err: int = ModuleGate.create_module(TEMP_BAD_MODULE_NAME)
	_check(create_err == OK, "Backup fixture module could not be created")
	ModuleGate.add_scene()
	var valid_text: String = _read_text(_manifest_path(TEMP_BAD_MODULE_NAME))
	_write_text(_manifest_path(TEMP_BAD_MODULE_NAME) + ".bak", valid_text)
	_write_text(_manifest_path(TEMP_BAD_MODULE_NAME), "{broken")
	ModuleGate.close_module()
	var open_err: int = ModuleGate.open_module(TEMP_BAD_MODULE_NAME)
	_check(open_err == OK, "Corrupt manifest was not restored from backup")
	_check(_read_text(_manifest_path(TEMP_BAD_MODULE_NAME)) == valid_text, "Backup restore did not rewrite the formal manifest")
	var gate_result: Dictionary = ModuleGate.last_manifest_result()
	_check(bool(gate_result.get("recovered_from_backup", false)), "Backup recovery was not reported")


func _test_only_valid_temp_recovers_first_creation() -> void:
	var module_id: String = _fixed_id("51")
	var location_id: String = _fixed_id("52")
	var data: Dictionary = _valid_manifest_dict(
		TEMP_ONLY_TMP_MODULE_NAME,
		module_id,
		location_id,
		"_canonical/missing.scn"
	)
	DirAccess.make_dir_recursive_absolute(_module_dir(TEMP_ONLY_TMP_MODULE_NAME))
	_write_json(_manifest_path(TEMP_ONLY_TMP_MODULE_NAME) + ".tmp", data)
	var result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir(TEMP_ONLY_TMP_MODULE_NAME),
		false
	)
	_check(int(result.get("error", FAILED)) == OK, "Valid orphan temp manifest was not recovered")
	_check(
		FileAccess.file_exists(_manifest_path(TEMP_ONLY_TMP_MODULE_NAME)),
		"Recovered temp manifest was not committed"
	)


func _test_formal_and_backup_corrupt_are_rejected_without_rewrite() -> void:
	var manifest_path: String = _manifest_path(TEMP_DOUBLE_CORRUPT_MODULE_NAME)
	DirAccess.make_dir_recursive_absolute(_module_dir(TEMP_DOUBLE_CORRUPT_MODULE_NAME))
	_write_text(manifest_path, "{formal-broken")
	_write_text(manifest_path + ".bak", "{backup-broken")
	var formal_before: String = _read_text(manifest_path)
	var backup_before: String = _read_text(manifest_path + ".bak")
	var result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir(TEMP_DOUBLE_CORRUPT_MODULE_NAME),
		false
	)
	_check(int(result.get("error", OK)) != OK, "Double-corrupt manifest unexpectedly opened")
	_check(_read_text(manifest_path) == formal_before, "Corrupt formal manifest was overwritten")
	_check(_read_text(manifest_path + ".bak") == backup_before, "Corrupt backup was overwritten")


func _test_future_version_is_rejected_without_rewrite() -> void:
	var data: Dictionary = _valid_manifest_dict(TEMP_FUTURE_MODULE_NAME, _fixed_id("21"), _fixed_id("22"), "_canonical/future.scn")
	data["schema_version"] = 999
	DirAccess.make_dir_recursive_absolute(_canonical_dir(TEMP_FUTURE_MODULE_NAME))
	_write_json(_manifest_path(TEMP_FUTURE_MODULE_NAME), data)
	var before_text: String = _read_text(_manifest_path(TEMP_FUTURE_MODULE_NAME))
	var current_before: String = ModuleGate.current_module_name()
	var open_err: int = ModuleGate.open_module(TEMP_FUTURE_MODULE_NAME)
	_check(open_err == ERR_UNAVAILABLE, "Future manifest version was not rejected")
	_check(_read_text(_manifest_path(TEMP_FUTURE_MODULE_NAME)) == before_text, "Future manifest was rewritten")
	_check(ModuleGate.current_module_name() == current_before, "Future-version failure replaced current module truth")


func _test_path_escape_and_absolute_paths_are_rejected() -> void:
	_write_invalid_path_manifest(TEMP_BAD_MODULE_NAME, "../escape.scn")
	var rel_result: Dictionary = ModuleIo.load_manifest_for_module(_module_dir(TEMP_BAD_MODULE_NAME), false)
	_check(int(rel_result.get("error", OK)) != OK, "Relative path escape was accepted")
	_write_invalid_path_manifest(TEMP_ABSOLUTE_MODULE_NAME, "C:/escape.scn")
	var abs_result: Dictionary = ModuleIo.load_manifest_for_module(_module_dir(TEMP_ABSOLUTE_MODULE_NAME), false)
	_check(int(abs_result.get("error", OK)) != OK, "Absolute canonical path was accepted")


func _test_invalid_and_duplicate_ids_are_rejected() -> void:
	var invalid_data: Dictionary = _valid_manifest_dict(
		TEMP_INVALID_ID_MODULE_NAME,
		"ABC",
		_fixed_id("62"),
		"_canonical/invalid.scn"
	)
	DirAccess.make_dir_recursive_absolute(_module_dir(TEMP_INVALID_ID_MODULE_NAME))
	_write_json(_manifest_path(TEMP_INVALID_ID_MODULE_NAME), invalid_data)
	var invalid_result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir(TEMP_INVALID_ID_MODULE_NAME),
		false
	)
	_check(int(invalid_result.get("error", OK)) != OK, "Invalid stable ID was accepted")
	var duplicate_id: String = _fixed_id("63")
	var duplicate_data: Dictionary = _valid_manifest_dict(
		TEMP_INVALID_ID_MODULE_NAME,
		_fixed_id("64"),
		duplicate_id,
		"_canonical/one.scn"
	)
	var duplicate_locations: Array = duplicate_data["locations"] as Array
	duplicate_locations.append({
		"location_id": duplicate_id,
		"display_name": "Duplicate",
		"canonical_relpath": "_canonical/two.scn",
	})
	_write_json(_manifest_path(TEMP_INVALID_ID_MODULE_NAME), duplicate_data)
	var duplicate_result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir(TEMP_INVALID_ID_MODULE_NAME),
		false
	)
	_check(int(duplicate_result.get("error", OK)) != OK, "Duplicate stable IDs were accepted")


func _test_external_module_relative_escape_is_rejected() -> void:
	var data: Dictionary = _valid_manifest_dict(
		TEMP_EXTERNAL_ESCAPE_MODULE_NAME,
		_fixed_id("71"),
		_fixed_id("72"),
		"_canonical/missing.scn"
	)
	data["external_contents"] = [{
		"content_id": _fixed_id("73"),
		"content_type": "image",
		"display_name": "Escaped",
		"source_kind": "module_relative",
		"source_path": "../escaped.png",
		"metadata": {},
	}]
	DirAccess.make_dir_recursive_absolute(_module_dir(TEMP_EXTERNAL_ESCAPE_MODULE_NAME))
	_write_json(_manifest_path(TEMP_EXTERNAL_ESCAPE_MODULE_NAME), data)
	var result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir(TEMP_EXTERNAL_ESCAPE_MODULE_NAME),
		false
	)
	_check(int(result.get("error", OK)) != OK, "External module-relative escape was accepted")


func _test_missing_refs_are_retained_and_marked_unavailable() -> void:
	var module_id: String = _fixed_id("31")
	var location_id: String = _fixed_id("32")
	var content_id: String = _fixed_id("33")
	var data: Dictionary = _valid_manifest_dict(TEMP_EXTERNAL_MODULE_NAME, module_id, location_id, "_canonical/missing.scn")
	data["external_contents"] = [
		{
			"content_id": content_id,
			"content_type": "image",
			"display_name": "Missing Image",
			"source_kind": "module_relative",
			"source_path": "_media/missing.png",
			"metadata": {},
		}
	]
	DirAccess.make_dir_recursive_absolute(_module_dir(TEMP_EXTERNAL_MODULE_NAME))
	_write_json(_manifest_path(TEMP_EXTERNAL_MODULE_NAME), data)
	var result: Dictionary = ModuleIo.load_manifest_for_module(_module_dir(TEMP_EXTERNAL_MODULE_NAME), false)
	_check(int(result.get("error", FAILED)) == OK, "Missing file references made the manifest fail")
	var manifest: ModuleManifest = result.get("value") as ModuleManifest
	_check(manifest != null and manifest.locations.size() == 1, "Missing scene location was not retained")
	_check(
		manifest != null
		and manifest.locations.size() == 1
		and not bool(manifest.locations[0].get("available")),
		"Missing scene was not marked unavailable"
	)
	_check(
		manifest != null
		and int(manifest.get("external_contents").size()) == 1
		and not bool(manifest.get("external_contents")[0].get("available")),
		"Missing external content was not marked unavailable"
	)


func _test_open_and_create_failures_do_not_replace_current_truth() -> void:
	var current_err: int = ModuleGate.create_module(TEMP_CURRENT_MODULE_NAME)
	_check(current_err == OK, "Current truth fixture module could not be created")
	var current_name: String = ModuleGate.current_module_name()
	_write_invalid_path_manifest(TEMP_BAD_MODULE_NAME, "../bad.scn")
	var open_err: int = ModuleGate.open_module(TEMP_BAD_MODULE_NAME)
	_check(open_err != OK, "Bad module unexpectedly opened")
	_check(ModuleGate.current_module_name() == current_name, "Open failure replaced current module name")
	var create_err: int = ModuleGate.create_module("")
	_check(create_err != OK, "Blank module name unexpectedly created")
	_check(ModuleGate.current_module_name() == current_name, "Create failure replaced current module name")
	create_err = ModuleGate.create_module("..")
	_check(create_err != OK, "Parent-directory module name unexpectedly created")
	_check(ModuleGate.current_module_name() == current_name, "Escaping create replaced current module name")


func _test_incremental_backups_create_recovery_points_and_reuse_content() -> void:
	var create_err: int = ModuleGate.create_module(TEMP_INCREMENTAL_BACKUP_MODULE_NAME)
	_check(create_err == OK, "Incremental-backup fixture module could not be created")
	if create_err != OK:
		return
	var module_dir: String = _module_dir(TEMP_INCREMENTAL_BACKUP_MODULE_NAME)
	var note_path: String = module_dir.path_join("notes.txt")
	_write_text(note_path, "first version")
	var session_fixture_path: String = module_dir.path_join(
		"sessions/11111111111111111111111111111111/session.json"
	)
	_check(
		DirAccess.make_dir_recursive_absolute(session_fixture_path.get_base_dir()) == OK,
		"Incremental-backup session fixture directory could not be created"
	)
	_write_text(session_fixture_path, "runtime wall destroyed")
	_check(
		FileAccess.file_exists(BACKUP_STORE_SCRIPT_PATH),
		"Incremental backup store script is missing"
	)
	if not FileAccess.file_exists(BACKUP_STORE_SCRIPT_PATH):
		return
	var backup_script: GDScript = load(BACKUP_STORE_SCRIPT_PATH) as GDScript
	_check(backup_script != null, "Incremental backup store script could not be loaded")
	if backup_script == null:
		return
	var first_value: Variant = backup_script.call("create_backup", module_dir)
	var first_result: Dictionary = first_value as Dictionary
	_check(int(first_result.get("error", FAILED)) == OK, "First recovery point could not be created")
	var first_snapshot_text: String = _read_text(String(first_result.get("snapshot_path", "")))
	_check(
		not first_snapshot_text.contains("sessions/"),
		"Module recovery point included one table's playthrough files"
	)
	var first_backup_id: String = String(first_result.get("backup_id", ""))
	_check(_is_hex32(first_backup_id), "First recovery point ID is not stable hex")
	var first_object_count: int = _count_files_recursive(module_dir.path_join("_backups/objects"))
	_check(first_object_count >= 2, "First recovery point did not store module file contents")

	var second_value: Variant = backup_script.call("create_backup", module_dir)
	var second_result: Dictionary = second_value as Dictionary
	_check(int(second_result.get("error", FAILED)) == OK, "Second recovery point could not be created")
	var second_backup_id: String = String(second_result.get("backup_id", ""))
	_check(
		_is_hex32(second_backup_id) and second_backup_id != first_backup_id,
		"Second recovery point did not get a new stable ID"
	)
	var second_object_count: int = _count_files_recursive(module_dir.path_join("_backups/objects"))
	_check(
		second_object_count == first_object_count,
		"Unchanged backup duplicated file content instead of reusing it"
	)

	_write_text(note_path, "second version")
	var third_value: Variant = backup_script.call("create_backup", module_dir)
	var third_result: Dictionary = third_value as Dictionary
	_check(int(third_result.get("error", FAILED)) == OK, "Changed recovery point could not be created")
	var third_object_count: int = _count_files_recursive(module_dir.path_join("_backups/objects"))
	_check(
		third_object_count == first_object_count + 1,
		"Changing one file did not add exactly one content object"
	)
	var snapshot_dir: String = module_dir.path_join("_backups/snapshots")
	_check(_count_files_recursive(snapshot_dir) == 3, "Each backup click did not add one recovery point")
	var snapshot_text: String = _read_text(String(third_result.get("snapshot_path", "")))
	_check(not snapshot_text.contains("_backups/"), "Backup repository recursively backed up itself")

	var current_name: String = ModuleGate.current_module_name()
	var escape_value: Variant = backup_script.call(
		"create_backup",
		ModuleGate.MODULE_ROOT.path_join("..").path_join("outside")
	)
	var escape_result: Dictionary = escape_value as Dictionary
	_check(int(escape_result.get("error", OK)) != OK, "Escaping backup path was accepted")
	_check(
		ModuleGate.current_module_name() == current_name,
		"Backup failure replaced the current module truth"
	)


func _valid_manifest_dict(module_name: String, module_id: String, location_id: String, relpath: String) -> Dictionary:
	return {
		"format": "gvtt_module_manifest",
		"schema_version": 1,
		"module_id": module_id,
		"module_name": module_name,
		"start_location_id": location_id,
		"ruleset_id": "cpr",
		"notes": "",
		"locations": [
			{
				"location_id": location_id,
				"display_name": "Only Scene",
				"canonical_relpath": relpath,
			}
		],
		"external_contents": [],
	}


func _write_invalid_path_manifest(module_name: String, relpath: String) -> void:
	DirAccess.make_dir_recursive_absolute(_module_dir(module_name))
	var backup_path: String = _manifest_path(module_name) + ".bak"
	var temp_path: String = _manifest_path(module_name) + ".tmp"
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	var data: Dictionary = _valid_manifest_dict(module_name, _fixed_id("41"), _fixed_id("42"), relpath)
	_write_json(_manifest_path(module_name), data)


func _write_scene(scene_path: String) -> bool:
	var root: Node3D = Node3D.new()
	root.name = "SceneFixture"
	var packed: PackedScene = PackedScene.new()
	var pack_err: int = packed.pack(root)
	root.free()
	if pack_err != OK:
		return false
	return ResourceSaver.save(packed, scene_path) == OK


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t", true))


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "Could not write fixture " + path)
		return
	file.store_string(text)
	file.flush()
	file.close()


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


func _parse_json_dict(text: String) -> Dictionary:
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return {}
	var data: Variant = parser.data
	if data is Dictionary:
		return data as Dictionary
	return {}


func _is_hex32(value: String) -> bool:
	if value.length() != 32:
		return false
	for index: int in range(value.length()):
		var ch: String = value.substr(index, 1)
		if not "0123456789abcdef".contains(ch):
			return false
	return true


func _fixed_id(pair: String) -> String:
	var result: String = ""
	for index: int in range(16):
		result += pair
	return result.substr(0, 32)


func _manifest_path(module_name: String) -> String:
	return _module_dir(module_name).path_join("manifest.json")


func _canonical_dir(module_name: String) -> String:
	return _module_dir(module_name).path_join("_canonical")


func _module_dir(module_name: String) -> String:
	return ModuleGate.MODULE_ROOT.path_join(module_name)


func _cleanup_fixtures() -> void:
	if ModuleGate.has_open_module():
		ModuleGate.close_module()
	for module_name: String in [
		TEMP_NEW_MODULE_NAME,
		TEMP_LEGACY_MODULE_NAME,
		TEMP_BAD_MODULE_NAME,
		TEMP_SCHEMA_MODULE_NAME,
		TEMP_FUTURE_MODULE_NAME,
		TEMP_EXTERNAL_MODULE_NAME,
		TEMP_ABSOLUTE_MODULE_NAME,
		TEMP_CURRENT_MODULE_NAME,
		TEMP_ONLY_TMP_MODULE_NAME,
		TEMP_DOUBLE_CORRUPT_MODULE_NAME,
		TEMP_INVALID_ID_MODULE_NAME,
		TEMP_EXTERNAL_ESCAPE_MODULE_NAME,
		TEMP_INCREMENTAL_BACKUP_MODULE_NAME,
	]:
		_remove_dir_recursive(_module_dir(module_name))


func _count_files_recursive(dir_path: String) -> int:
	if not DirAccess.dir_exists_absolute(dir_path):
		return 0
	var count: int = 0
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return 0
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name == "." or entry_name == "..":
			entry_name = dir.get_next()
			continue
		var entry_path: String = dir_path.path_join(entry_name)
		if dir.current_is_dir():
			count += _count_files_recursive(entry_path)
		else:
			count += 1
		entry_name = dir.get_next()
	dir.list_dir_end()
	return count


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


func _check(condition: bool, message: String) -> void:
	_assertion_count += 1
	if not condition:
		_failures.append(message)
