class_name ModuleBackupStore
extends RefCounted
## 用户主动创建的模组增量恢复点。
## 每个恢复点保存完整文件清单，文件内容按 SHA-256 只存一份。

const FORMAT: String = "gvtt_module_backup"
const SCHEMA_VERSION: int = 1
const BACKUP_DIR_NAME: String = "_backups"
const OBJECTS_DIR_NAME: String = "objects"
const SNAPSHOTS_DIR_NAME: String = "snapshots"
const SNAPSHOT_EXTENSION: String = ".json"
const TEMP_SUFFIX: String = ".tmp"


static func create_backup(module_dir: String) -> Dictionary:
	if not _is_direct_module_dir(module_dir):
		return _result(ERR_INVALID_PARAMETER, "", "", 0, 0, "备份路径不在模组目录内")
	if not DirAccess.dir_exists_absolute(module_dir):
		return _result(ERR_FILE_NOT_FOUND, "", "", 0, 0, "模组目录不存在")
	var manifest_result: Dictionary = ModuleIo.load_manifest_for_module(module_dir, false)
	var manifest_error: int = int(manifest_result.get("error", FAILED))
	if manifest_error != OK:
		return _result(manifest_error, "", "", 0, 0, "模组清单校验失败，未创建备份")
	var manifest: ModuleManifest = manifest_result.get("value") as ModuleManifest
	if manifest == null:
		return _result(ERR_INVALID_DATA, "", "", 0, 0, "模组清单为空")

	var backup_dir: String = module_dir.path_join(BACKUP_DIR_NAME)
	var objects_dir: String = backup_dir.path_join(OBJECTS_DIR_NAME)
	var snapshots_dir: String = backup_dir.path_join(SNAPSHOTS_DIR_NAME)
	var dir_error: int = DirAccess.make_dir_recursive_absolute(objects_dir)
	if dir_error != OK:
		return _result(dir_error, "", "", 0, 0, "无法创建备份内容目录")
	dir_error = DirAccess.make_dir_recursive_absolute(snapshots_dir)
	if dir_error != OK:
		return _result(dir_error, "", "", 0, 0, "无法创建恢复点目录")

	var collect_result: Dictionary = _collect_module_files(module_dir)
	var collect_error: int = int(collect_result.get("error", FAILED))
	if collect_error != OK:
		return _result(collect_error, "", "", 0, 0, String(collect_result.get("message", "模组文件扫描失败")))
	var relative_paths: Array[String] = []
	var collected_value: Variant = collect_result.get("files", [])
	if collected_value is Array:
		for path_value: Variant in collected_value as Array:
			relative_paths.append(String(path_value))
	relative_paths.sort()
	var backup_id: String = _new_backup_id(snapshots_dir)
	if backup_id == "":
		return _result(ERR_ALREADY_EXISTS, "", "", 0, 0, "无法生成不重复的恢复点标识")

	var file_entries: Array[Dictionary] = []
	var new_object_count: int = 0
	for relative_path: String in relative_paths:
		var source_path: String = module_dir.path_join(relative_path)
		var content_hash: String = FileAccess.get_sha256(source_path)
		if not _is_sha256(content_hash):
			return _result(ERR_FILE_CANT_READ, "", "", 0, new_object_count, "无法读取模组文件: " + relative_path)
		var object_path: String = objects_dir.path_join(content_hash)
		if FileAccess.file_exists(object_path):
			if FileAccess.get_sha256(object_path) != content_hash:
				return _result(ERR_FILE_CORRUPT, "", "", 0, new_object_count, "备份内容校验失败: " + relative_path)
		else:
			var object_temp_path: String = object_path + TEMP_SUFFIX + "." + backup_id
			var copy_error: int = DirAccess.copy_absolute(source_path, object_temp_path)
			if copy_error != OK:
				_remove_file_if_present(object_temp_path)
				return _result(copy_error, "", "", 0, new_object_count, "无法复制模组文件: " + relative_path)
			if FileAccess.get_sha256(object_temp_path) != content_hash:
				_remove_file_if_present(object_temp_path)
				return _result(ERR_FILE_CORRUPT, "", "", 0, new_object_count, "备份临时内容校验失败: " + relative_path)
			var object_commit_error: int = DirAccess.rename_absolute(object_temp_path, object_path)
			if object_commit_error != OK:
				_remove_file_if_present(object_temp_path)
				return _result(object_commit_error, "", "", 0, new_object_count, "无法提交备份内容: " + relative_path)
			new_object_count += 1
		file_entries.append({
			"path": relative_path,
			"sha256": content_hash,
			"size": FileAccess.get_size(source_path),
		})

	var snapshot_path: String = snapshots_dir.path_join(backup_id + SNAPSHOT_EXTENSION)
	var snapshot_temp_path: String = snapshot_path + TEMP_SUFFIX
	var snapshot_data: Dictionary = {
		"format": FORMAT,
		"schema_version": SCHEMA_VERSION,
		"backup_id": backup_id,
		"module_id": manifest.module_id,
		"created_unix_time": int(Time.get_unix_time_from_system()),
		"files": file_entries,
	}
	var write_error: int = _write_json(snapshot_temp_path, snapshot_data)
	if write_error != OK:
		_remove_file_if_present(snapshot_temp_path)
		return _result(write_error, "", "", file_entries.size(), new_object_count, "无法写入恢复点清单")
	var validation_error: int = _validate_snapshot(snapshot_temp_path, manifest.module_id, objects_dir)
	if validation_error != OK:
		_remove_file_if_present(snapshot_temp_path)
		return _result(validation_error, "", "", file_entries.size(), new_object_count, "恢复点清单校验失败")
	var commit_error: int = DirAccess.rename_absolute(snapshot_temp_path, snapshot_path)
	if commit_error != OK:
		_remove_file_if_present(snapshot_temp_path)
		return _result(commit_error, "", "", file_entries.size(), new_object_count, "无法提交恢复点清单")
	return _result(OK, backup_id, snapshot_path, file_entries.size(), new_object_count, "模组增量备份已创建")


static func validate_backup(module_dir: String, backup_id: String) -> int:
	if not _is_direct_module_dir(module_dir) or not _is_stable_id(backup_id):
		return ERR_INVALID_PARAMETER
	var manifest_result: Dictionary = ModuleIo.load_manifest_for_module(module_dir, false)
	if int(manifest_result.get("error", FAILED)) != OK:
		return int(manifest_result.get("error", FAILED))
	var manifest: ModuleManifest = manifest_result.get("value") as ModuleManifest
	if manifest == null:
		return ERR_INVALID_DATA
	var backup_dir: String = module_dir.path_join(BACKUP_DIR_NAME)
	var snapshot_path: String = backup_dir.path_join(SNAPSHOTS_DIR_NAME).path_join(backup_id + SNAPSHOT_EXTENSION)
	var objects_dir: String = backup_dir.path_join(OBJECTS_DIR_NAME)
	return _validate_snapshot(snapshot_path, manifest.module_id, objects_dir)


static func _collect_module_files(module_dir: String) -> Dictionary:
	var files: Array[String] = []
	var error: int = _collect_directory(module_dir, "", files)
	if error != OK:
		return {"error": error, "files": [], "message": "模组包含目录链接或无法读取的路径"}
	return {"error": OK, "files": files, "message": "模组文件已扫描"}


static func _collect_directory(absolute_dir: String, relative_dir: String, files: Array[String]) -> int:
	var dir: DirAccess = DirAccess.open(absolute_dir)
	if dir == null:
		return DirAccess.get_open_error()
	var entries: Array[Dictionary] = []
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			entries.append({"name": entry_name, "is_dir": dir.current_is_dir()})
		entry_name = dir.get_next()
	dir.list_dir_end()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	for entry: Dictionary in entries:
		var name: String = String(entry["name"])
		if (
			relative_dir == ""
			and name in [BACKUP_DIR_NAME, ModuleIo.SESSIONS_DIR_NAME]
		):
			continue
		if dir.is_link(name):
			return ERR_INVALID_DATA
		var relative_path: String = name if relative_dir == "" else relative_dir.path_join(name)
		if bool(entry["is_dir"]):
			var child_error: int = _collect_directory(absolute_dir.path_join(name), relative_path, files)
			if child_error != OK:
				return child_error
			continue
		if relative_path == ModuleIo.MANIFEST_FILE_NAME + ModuleIo.MANIFEST_TEMP_SUFFIX:
			continue
		if relative_path == ModuleIo.MANIFEST_FILE_NAME + ModuleIo.MANIFEST_BACKUP_SUFFIX:
			continue
		if not _is_safe_relative_path(relative_path):
			return ERR_INVALID_DATA
		files.append(relative_path)
	return OK


static func _validate_snapshot(snapshot_path: String, module_id: String, objects_dir: String) -> int:
	if not FileAccess.file_exists(snapshot_path):
		return ERR_FILE_NOT_FOUND
	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(FileAccess.get_file_as_string(snapshot_path))
	if parse_error != OK or not (parser.data is Dictionary):
		return ERR_PARSE_ERROR
	var data: Dictionary = parser.data as Dictionary
	if String(data.get("format", "")) != FORMAT:
		return ERR_INVALID_DATA
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return ERR_UNAVAILABLE
	if not _is_stable_id(String(data.get("backup_id", ""))):
		return ERR_INVALID_DATA
	if String(data.get("module_id", "")) != module_id:
		return ERR_INVALID_DATA
	if not _is_nonnegative_integer(data.get("created_unix_time", null)):
		return ERR_INVALID_DATA
	var files_value: Variant = data.get("files", null)
	if not (files_value is Array):
		return ERR_INVALID_DATA
	var seen_paths: Dictionary = {}
	for entry_value: Variant in files_value as Array:
		if not (entry_value is Dictionary):
			return ERR_INVALID_DATA
		var entry: Dictionary = entry_value as Dictionary
		var relative_path: String = String(entry.get("path", ""))
		var content_hash: String = String(entry.get("sha256", ""))
		if (
			not _is_safe_relative_path(relative_path)
			or relative_path.begins_with(BACKUP_DIR_NAME + "/")
			or relative_path.begins_with(ModuleIo.SESSIONS_DIR_NAME + "/")
		):
			return ERR_INVALID_DATA
		if seen_paths.has(relative_path) or not _is_sha256(content_hash):
			return ERR_INVALID_DATA
		if not _is_nonnegative_integer(entry.get("size", null)):
			return ERR_INVALID_DATA
		seen_paths[relative_path] = true
		var object_path: String = objects_dir.path_join(content_hash)
		if not FileAccess.file_exists(object_path):
			return ERR_FILE_NOT_FOUND
		if FileAccess.get_sha256(object_path) != content_hash:
			return ERR_FILE_CORRUPT
	return OK


static func _write_json(path: String, data: Dictionary) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(JSON.stringify(data, "\t", true))
	file.flush()
	file.close()
	return OK if stored else ERR_FILE_CANT_WRITE


static func _new_backup_id(snapshots_dir: String) -> String:
	for attempt: int in range(8):
		var backup_id: String = ModuleIo.generate_stable_id()
		var snapshot_path: String = snapshots_dir.path_join(backup_id + SNAPSHOT_EXTENSION)
		if not FileAccess.file_exists(snapshot_path):
			return backup_id
	return ""


static func _is_direct_module_dir(module_dir: String) -> bool:
	if module_dir == "":
		return false
	var global_root: String = ProjectSettings.globalize_path(ModuleGate.MODULE_ROOT).simplify_path().replace("\\", "/").trim_suffix("/")
	var global_module: String = ProjectSettings.globalize_path(module_dir).simplify_path().replace("\\", "/").trim_suffix("/")
	if global_module == global_root:
		return false
	if global_module.get_base_dir().to_lower() != global_root.to_lower():
		return false
	var root_dir: DirAccess = DirAccess.open(ModuleGate.MODULE_ROOT)
	if root_dir == null:
		return false
	return not root_dir.is_link(module_dir.trim_suffix("/").get_file())


static func _is_safe_relative_path(path: String) -> bool:
	if path == "" or path.is_absolute_path() or path.contains("\\"):
		return false
	for segment: String in path.split("/", false):
		if segment == "" or segment == "." or segment == "..":
			return false
	return true


static func _is_stable_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for index: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _is_nonnegative_integer(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= 0.0 and number == floor(number)


static func _remove_file_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _result(
	error: int,
	backup_id: String,
	snapshot_path: String,
	file_count: int,
	new_object_count: int,
	message: String
) -> Dictionary:
	return {
		"error": error,
		"backup_id": backup_id,
		"snapshot_path": snapshot_path,
		"file_count": file_count,
		"new_object_count": new_object_count,
		"message": message,
	}
