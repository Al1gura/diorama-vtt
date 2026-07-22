class_name ModuleIo
extends Node
## ModuleIo —— 模组/带团存档的存读盘封装 + owner 陷阱处理
##
## 设计依据:docs/multi_scene_draft.md 第 4 节 + 第 8 节坑 1。
## 把"场景保存/加载"所有 Godot API 调用收在这一个文件,
## main.gd / ModuleGate 只调本模块的语义方法,不直接碰 PackedScene/ResourceSaver。
## 依据集中在一处,API 变了只改本文件。
##
## 当前已接入 ModuleGate/main.gd 的场景保存与加载链路。

const MANIFEST_FILE_NAME: String = "manifest.json"
const MANIFEST_BACKUP_SUFFIX: String = ".bak"
const MANIFEST_TEMP_SUFFIX: String = ".tmp"
const CANONICAL_DIR_NAME: String = "_canonical"
const SESSIONS_DIR_NAME: String = "sessions"
const SESSION_FILE_NAME: String = "session.json"
const SESSION_BACKUP_SUFFIX: String = ".bak"
const SESSION_TEMP_SUFFIX: String = ".tmp"
const SESSION_STATES_DIR_NAME: String = "states"


## ⚠ 关键 API 依据(离线文档 4.7 实读核对,非猜测):
##   - PackedScene.pack(node) 把运行中节点树打包成可存盘资源 → gdd_1006 第 135 行
##   - pack 只打包"有 owner 关系"的节点!没设 owner 的子节点被漏 → gdd_1006 第 31-45 行
##   - PackedScene.instantiate() 装回节点树 → gdd_1006 第 129 行
##   - ResourceSaver.save(...) 存盘 → gdd_1477
##   - ResourceLoader.load(path, type_hint, cache_mode) 读回 → gdd_1476 第 165 行
## main.gd _place_building 放物件时未设 owner → 存场景会漏物件(草案坑1)。
## 此模块负责正面解决:存盘前遍历树补 owner。不准绕过去(CLAUDE.md 永远不准逃避问题)。


## 把"一棵运行中节点树"打成 PackedScene 并存盘。返回存盘 Error。
## 存盘前先调 _ensure_ownership 修 owner 陷阱(没 owner 的子节点 pack 时被漏)。
## 依据:PackedScene.pack(gdd_1006 第135行) + ResourceSaver.save(gdd_1477)。
static func save_scene_tree(root: Node, save_path: String) -> int:
	if root == null or not is_instance_valid(root):
		push_error("ModuleIo.save_scene_tree: root 无效")
		return ERR_INVALID_PARAMETER
	# 运行期辅助节点先临时摘下，保证 PackedScene 无论 owner 状态如何都不可能收进去。
	var detached_runtime_nodes: Array[Dictionary] = []
	_detach_runtime_nodes(root, detached_runtime_nodes)
	# 正面修 owner 陷阱:存盘前确保 root 下所有持久子树 owner=root,pack 才不漏。
	_ensure_ownership(root, root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	_restore_runtime_nodes(detached_runtime_nodes)
	if err != OK:
		push_error("ModuleIo: pack 失败 code=%d path=%s" % [err, save_path])
		return err
	err = ResourceSaver.save(packed, save_path)
	if err != OK:
		push_error("ModuleIo: ResourceSaver.save 失败 code=%d path=%s" % [err, save_path])
	return err


static func _detach_runtime_nodes(node: Node, detached: Array[Dictionary]) -> void:
	for child: Node in node.get_children():
		if child.has_meta("gvtt_runtime_only"):
			var original_owner: Node = child.owner
			detached.append({
				"node": child,
				"parent": node,
				"index": child.get_index(),
				"owner": original_owner,
			})
			# Godot 4.7 会在 add_child() 前检查旧 owner 是否仍为祖先。
			if original_owner != null:
				child.set_owner(null)
			node.remove_child(child)
			continue
		_detach_runtime_nodes(child, detached)


static func _restore_runtime_nodes(detached: Array[Dictionary]) -> void:
	for entry: Dictionary in detached:
		var parent: Node = entry["parent"]
		var child: Node = entry["node"]
		parent.add_child(child)
		parent.move_child(child, mini(int(entry["index"]), parent.get_child_count() - 1))
		var original_owner: Node = entry["owner"]
		if original_owner != null:
			child.set_owner(original_owner)


## 把一个存盘的场景读回成节点树(未挂进场景树,调用方 add_child)。
## 依据:ResourceLoader.load(gdd_1476 第165行) + PackedScene.instantiate(gdd_1006 第129行)。
static func load_scene_tree(save_path: String) -> Node:
	if not ResourceLoader.exists(save_path):
		push_warning("ModuleIo.load_scene_tree: 路径不存在 %s" % save_path)
		return null
	var packed: Resource = ResourceLoader.load(save_path, "PackedScene",
		ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
	if packed == null or not (packed is PackedScene):
		push_error("ModuleIo: 载入非 PackedScene: %s" % save_path)
		return null
	return (packed as PackedScene).instantiate()


## 保存版本化 session.json。正式会话只在提交后才替换内存真值。
static func save_playthrough_recoverable(
		module_dir: String,
		manifest: ModuleManifest,
		session: Playthrough
) -> Dictionary:
	if module_dir == "" or manifest == null or session == null:
		return _result(ERR_INVALID_PARAMETER, null, false, false, "带团会话参数无效")
	var validation: Dictionary = _playthrough_from_dictionary(
		session.to_json_dict(),
		module_dir,
		manifest,
		session.session_id
	)
	if int(validation.get("error", FAILED)) != OK:
		return validation
	var session_dir: String = _session_dir(module_dir, session.session_id)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(
		session_dir.path_join(SESSION_STATES_DIR_NAME)
	)
	if directory_error != OK:
		return _result(directory_error, null, false, false, "无法创建带团会话目录")
	var session_path: String = session_dir.path_join(SESSION_FILE_NAME)
	var backup_path: String = session_path + SESSION_BACKUP_SUFFIX
	var temp_path: String = session_path + SESSION_TEMP_SUFFIX
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	var json_text: String = JSON.stringify(session.to_json_dict(), "\t", true)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _result(FileAccess.get_open_error(), null, false, false, "无法写入临时会话")
	var write_ok: bool = file.store_string(json_text)
	file.flush()
	var write_error: int = file.get_error()
	file.close()
	if not write_ok or write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_CANT_CREATE, null, false, false, "临时会话写入不完整")
	var expected_bytes: PackedByteArray = json_text.to_utf8_buffer()
	var actual_bytes: PackedByteArray = FileAccess.get_file_as_bytes(temp_path)
	if actual_bytes != expected_bytes:
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_FILE_CORRUPT, null, false, false, "临时会话字节校验失败")
	var temp_validation: Dictionary = _load_playthrough_file(
		temp_path,
		module_dir,
		manifest,
		session.session_id
	)
	if int(temp_validation.get("error", FAILED)) != OK or bool(temp_validation.get("migrated", false)):
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_INVALID_DATA, null, false, false, "临时会话结构校验失败")
	if FileAccess.file_exists(session_path):
		var backup_error: int = DirAccess.copy_absolute(session_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _result(backup_error, null, false, false, "无法备份上一份会话")
	var commit_error: int = DirAccess.rename_absolute(temp_path, session_path)
	if commit_error != OK:
		_restore_file_if_missing(session_path, backup_path)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return _result(commit_error, null, false, false, "会话提交失败，已尝试恢复上一份")
	var committed_result: Dictionary = _load_playthrough_file(
		session_path,
		module_dir,
		manifest,
		session.session_id
	)
	if int(committed_result.get("error", FAILED)) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, session_path)
		else:
			DirAccess.remove_absolute(session_path)
		return _result(ERR_FILE_CORRUPT, null, false, false, "提交后的会话校验失败，已尝试恢复备份")
	return _result(OK, session, false, false, "带团会话已保存")


## 读取会话；正式文件损坏时只从通过完整校验的备份恢复。
static func load_playthrough_for_session(
		module_dir: String,
		manifest: ModuleManifest,
		session_id: String
) -> Dictionary:
	if module_dir == "" or manifest == null or not _is_stable_id(session_id):
		return _result(ERR_INVALID_PARAMETER, null, false, false, "带团会话标识无效")
	var session_dir: String = _session_dir(module_dir, session_id)
	var session_path: String = session_dir.path_join(SESSION_FILE_NAME)
	var backup_path: String = session_path + SESSION_BACKUP_SUFFIX
	var temp_path: String = session_path + SESSION_TEMP_SUFFIX
	if FileAccess.file_exists(session_path):
		var formal_result: Dictionary = _load_playthrough_file(
			session_path, module_dir, manifest, session_id
		)
		var formal_error: int = int(formal_result.get("error", FAILED))
		if formal_error == OK:
			if bool(formal_result.get("migrated", false)):
				var migrated_session: Playthrough = formal_result.get("value") as Playthrough
				var save_result: Dictionary = save_playthrough_recoverable(
					module_dir, manifest, migrated_session
				)
				if int(save_result.get("error", FAILED)) != OK:
					return save_result
			return formal_result
		if not bool(formal_result.get("backup_recovery_allowed", true)):
			return formal_result
		var backup_result: Dictionary = _restore_playthrough_from_backup(
			module_dir, manifest, session_id, backup_path, session_path
		)
		if int(backup_result.get("error", FAILED)) == OK:
			return backup_result
		return formal_result
	if FileAccess.file_exists(backup_path):
		return _restore_playthrough_from_backup(
			module_dir, manifest, session_id, backup_path, session_path
		)
	if FileAccess.file_exists(temp_path):
		var temp_result: Dictionary = _load_playthrough_file(
			temp_path, module_dir, manifest, session_id
		)
		if int(temp_result.get("error", FAILED)) == OK:
			var commit_error: int = DirAccess.rename_absolute(temp_path, session_path)
			if commit_error != OK:
				return _result(commit_error, null, false, false, "有效临时会话无法提交")
			temp_result["recovered_from_backup"] = true
			temp_result["message"] = "已恢复写入中断的带团会话"
			return temp_result
	return _result(ERR_FILE_NOT_FOUND, null, false, false, "带团会话文件不存在")


static func list_playthroughs(module_dir: String, manifest: ModuleManifest) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if module_dir == "" or manifest == null:
		return entries
	var sessions_dir: String = module_dir.path_join(SESSIONS_DIR_NAME)
	if not DirAccess.dir_exists_absolute(sessions_dir):
		return entries
	var session_ids: Array[String] = []
	for directory_name: String in DirAccess.get_directories_at(sessions_dir):
		session_ids.append(directory_name)
	session_ids.sort()
	for session_id: String in session_ids:
		var load_result: Dictionary = load_playthrough_for_session(
			module_dir, manifest, session_id
		)
		var session: Playthrough = load_result.get("value") as Playthrough
		entries.append({
			"error": int(load_result.get("error", FAILED)),
			"session_id": session_id,
			"session_name": session.session_name if session != null else "",
			"message": String(load_result.get("message", "")),
			"recovered_from_backup": bool(load_result.get("recovered_from_backup", false)),
		})
	return entries


## 保存一个地点的完整运行态快照，临时和备份文件都保持 .scn 扩展名。
static func save_session_snapshot_recoverable(
		session_dir: String,
		location_id: String,
		root: Node
) -> Dictionary:
	if session_dir == "" or not _is_stable_id(location_id):
		return _result(ERR_INVALID_PARAMETER, null, false, false, "会话快照参数无效")
	if root == null or not is_instance_valid(root):
		return _result(ERR_INVALID_PARAMETER, null, false, false, "会话快照内容根无效")
	var states_dir: String = session_dir.path_join(SESSION_STATES_DIR_NAME)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(states_dir)
	if directory_error != OK:
		return _result(directory_error, null, false, false, "无法创建会话快照目录")
	var final_path: String = states_dir.path_join(location_id + ".scn")
	var backup_path: String = states_dir.path_join(location_id + ".bak.scn")
	var temp_path: String = states_dir.path_join(location_id + ".tmp.scn")
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	var save_error: int = save_scene_tree(root, temp_path)
	if save_error != OK:
		return _result(save_error, null, false, false, "临时会话快照写入失败")
	var validation_root: Node = load_scene_tree(temp_path)
	if validation_root == null:
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_FILE_CORRUPT, null, false, false, "临时会话快照实例化校验失败")
	validation_root.free()
	if FileAccess.file_exists(final_path):
		var backup_error: int = DirAccess.copy_absolute(final_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _result(backup_error, null, false, false, "无法备份上一份会话快照")
	var commit_error: int = DirAccess.rename_absolute(temp_path, final_path)
	if commit_error != OK:
		_restore_file_if_missing(final_path, backup_path)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return _result(commit_error, null, false, false, "会话快照提交失败，已尝试恢复上一份")
	var committed_root: Node = load_scene_tree(final_path)
	if committed_root == null:
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, final_path)
		else:
			DirAccess.remove_absolute(final_path)
		return _result(ERR_FILE_CORRUPT, null, false, false, "提交后的会话快照损坏，已尝试恢复备份")
	committed_root.free()
	return _result(OK, final_path, false, false, "会话地点快照已保存")


static func load_session_snapshot_recoverable(
		session_dir: String,
		location_id: String
) -> Dictionary:
	if session_dir == "" or not _is_stable_id(location_id):
		return _result(ERR_INVALID_PARAMETER, null, false, false, "会话快照参数无效")
	var states_dir: String = session_dir.path_join(SESSION_STATES_DIR_NAME)
	var final_path: String = states_dir.path_join(location_id + ".scn")
	var backup_path: String = states_dir.path_join(location_id + ".bak.scn")
	var temp_path: String = states_dir.path_join(location_id + ".tmp.scn")
	if FileAccess.file_exists(final_path):
		var formal_root: Node = load_scene_tree(final_path)
		if formal_root != null:
			if FileAccess.file_exists(temp_path):
				DirAccess.remove_absolute(temp_path)
			return _result(OK, formal_root, false, false, "会话快照已加载")
	if FileAccess.file_exists(backup_path):
		var backup_root: Node = load_scene_tree(backup_path)
		if backup_root != null:
			backup_root.free()
			var restore_error: int = DirAccess.copy_absolute(backup_path, final_path)
			if restore_error != OK:
				return _result(restore_error, null, false, false, "备份快照有效但无法恢复正式文件")
			var restored_root: Node = load_scene_tree(final_path)
			if restored_root != null:
				return _result(OK, restored_root, true, false, "已从备份恢复会话快照")
			return _result(ERR_FILE_CORRUPT, null, false, false, "恢复后的会话快照仍然损坏")
	if not FileAccess.file_exists(final_path):
		return _result(ERR_FILE_NOT_FOUND, null, false, false, "会话快照不存在")
	return _result(ERR_FILE_CORRUPT, null, false, false, "正式和备份会话快照都已损坏")


static func _session_dir(module_dir: String, session_id: String) -> String:
	return module_dir.path_join(SESSIONS_DIR_NAME).path_join(session_id)


static func _restore_file_if_missing(final_path: String, backup_path: String) -> void:
	if not FileAccess.file_exists(final_path) and FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(backup_path, final_path)


static func _restore_playthrough_from_backup(
		module_dir: String,
		manifest: ModuleManifest,
		session_id: String,
		backup_path: String,
		session_path: String
) -> Dictionary:
	var backup_result: Dictionary = _load_playthrough_file(
		backup_path, module_dir, manifest, session_id
	)
	var backup_error: int = int(backup_result.get("error", FAILED))
	if backup_error != OK:
		return _result(backup_error, null, false, false, "正式会话和备份都不可用")
	var restore_error: int = DirAccess.copy_absolute(backup_path, session_path)
	if restore_error != OK:
		return _result(restore_error, null, false, false, "会话备份有效，但恢复正式文件失败")
	var session: Playthrough = backup_result.get("value") as Playthrough
	var migrated: bool = bool(backup_result.get("migrated", false))
	if migrated:
		var save_result: Dictionary = save_playthrough_recoverable(
			module_dir, manifest, session
		)
		if int(save_result.get("error", FAILED)) != OK:
			return save_result
	return _result(OK, session, true, migrated, "已从备份恢复带团会话")


static func _load_playthrough_file(
		path: String,
		module_dir: String,
		manifest: ModuleManifest,
		expected_session_id: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(ERR_FILE_NOT_FOUND, null, false, false, "带团会话文件不存在")
	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		return _result(parse_error, null, false, false, "带团会话 JSON 语法损坏")
	var data_value: Variant = parser.data
	if not (data_value is Dictionary):
		return _result(ERR_INVALID_DATA, null, false, false, "带团会话根结构必须是字典")
	var data: Dictionary = (data_value as Dictionary).duplicate(true)
	var version_value: Variant = data.get("schema_version", -1)
	if not (version_value is int or version_value is float):
		return _result(ERR_INVALID_DATA, null, false, false, "带团会话结构版本必须是整数")
	var version_number: float = float(version_value)
	if (
			not is_finite(version_number)
			or version_number < 0.0
			or version_number > 2147483647.0
			or version_number != floorf(version_number)
	):
		return _result(ERR_INVALID_DATA, null, false, false, "带团会话结构版本必须是非负整数")
	var version: int = int(version_number)
	if version > Playthrough.SCHEMA_VERSION:
		var future_result: Dictionary = _result(
			ERR_UNAVAILABLE,
			null,
			false,
			false,
			"该会话由更高版本创建，当前版本不会覆盖它"
		)
		future_result["backup_recovery_allowed"] = false
		return future_result
	var migrated: bool = false
	while version < Playthrough.SCHEMA_VERSION:
		var migration_result: Dictionary = _migrate_playthrough_step(
			data, version, manifest, expected_session_id
		)
		if int(migration_result.get("error", FAILED)) != OK:
			return migration_result
		data = migration_result.get("value", {}) as Dictionary
		version += 1
		migrated = true
	var result: Dictionary = _playthrough_from_dictionary(
		data, module_dir, manifest, expected_session_id
	)
	result["migrated"] = migrated
	return result


static func _migrate_playthrough_step(
		data: Dictionary,
		version: int,
		manifest: ModuleManifest,
		expected_session_id: String
) -> Dictionary:
	if version != 0:
		return _result(ERR_UNAVAILABLE, null, false, false, "缺少对应的会话逐版本迁移器")
	var migrated: Dictionary = {
		"format": Playthrough.FORMAT,
		"schema_version": 1,
		"session_id": expected_session_id,
		"module_id": manifest.module_id,
		"session_name": String(data.get("session_name", "默认带团")),
		"current_location_id": "",
		"location_states": [],
		"notes": String(data.get("notes", data.get("historical_notes", ""))),
	}
	var current_location_name: String = String(data.get("current_location", ""))
	var current_location: LocationRef = manifest.find_location(current_location_name)
	if current_location != null:
		migrated["current_location_id"] = current_location.location_id
	elif manifest.locations.is_empty() and current_location_name == "":
		migrated["current_location_id"] = ""
	else:
		return _result(ERR_INVALID_DATA, null, false, false, "旧会话当前地点无法迁移")
	var visited_value: Variant = data.get("visited", {})
	if not (visited_value is Dictionary):
		return _result(ERR_INVALID_DATA, null, false, false, "旧会话地点状态无效")
	var state_entries: Array[Dictionary] = []
	var visited: Dictionary = visited_value as Dictionary
	for display_name_value: Variant in visited.keys():
		var location: LocationRef = manifest.find_location(String(display_name_value))
		if location == null:
			return _result(ERR_INVALID_DATA, null, false, false, "旧会话引用了未知地点")
		state_entries.append({
			"location_id": location.location_id,
			"state_relpath": "states/%s.scn" % location.location_id,
		})
	migrated["location_states"] = state_entries
	return _result(OK, migrated, false, true, "带团会话已从版本 0 迁移到版本 1")


static func _playthrough_from_dictionary(
		data: Dictionary,
		module_dir: String,
		manifest: ModuleManifest,
		expected_session_id: String
) -> Dictionary:
	if not _has_string_fields(
		data,
		[
			"format",
			"session_id",
			"module_id",
			"session_name",
			"current_location_id",
			"notes",
		]
	):
		return _result(ERR_INVALID_DATA, null, false, false, "带团会话缺少字符串字段")
	if String(data.get("format", "")) != Playthrough.FORMAT:
		return _result(ERR_INVALID_DATA, null, false, false, "带团会话格式标识不匹配")
	var session_id: String = String(data.get("session_id", ""))
	if not _is_stable_id(session_id) or session_id != expected_session_id:
		var session_id_result: Dictionary = _result(
			ERR_INVALID_DATA, null, false, false, "会话目录名与 session_id 不匹配"
		)
		session_id_result["backup_recovery_allowed"] = false
		return session_id_result
	if String(data.get("module_id", "")) != manifest.module_id:
		var module_id_result: Dictionary = _result(
			ERR_INVALID_DATA, null, false, false, "会话不属于当前模组"
		)
		module_id_result["backup_recovery_allowed"] = false
		return module_id_result
	var current_location_id: String = String(data.get("current_location_id", ""))
	if current_location_id == "":
		if not manifest.locations.is_empty():
			return _result(ERR_INVALID_DATA, null, false, false, "非空模组的会话缺少当前地点")
	elif manifest.find_location_by_id(current_location_id) == null:
		return _result(ERR_INVALID_DATA, null, false, false, "会话当前地点不在模组清单中")
	var states_value: Variant = data.get("location_states", [])
	if not (states_value is Array):
		return _result(ERR_INVALID_DATA, null, false, false, "会话地点状态列表无效")
	var location_states: Dictionary = {}
	var state_values: Array = states_value as Array
	for state_value: Variant in state_values:
		if not (state_value is Dictionary):
			return _result(ERR_INVALID_DATA, null, false, false, "会话地点状态条目无效")
		var state_data: Dictionary = state_value as Dictionary
		if not _has_string_fields(state_data, ["location_id", "state_relpath"]):
			return _result(ERR_INVALID_DATA, null, false, false, "会话地点状态字段无效")
		var location_id: String = String(state_data.get("location_id", ""))
		var state_relpath: String = String(state_data.get("state_relpath", ""))
		if (
				not _is_stable_id(location_id)
				or manifest.find_location_by_id(location_id) == null
				or location_states.has(location_id)
		):
			return _result(ERR_INVALID_DATA, null, false, false, "会话地点标识无效或重复")
		if not _is_safe_session_state_path(module_dir, session_id, state_relpath):
			return _result(ERR_INVALID_DATA, null, false, false, "会话快照路径越界或扩展名无效")
		location_states[location_id] = state_relpath
	var session: Playthrough = Playthrough.new()
	session.schema_version = Playthrough.SCHEMA_VERSION
	session.session_id = session_id
	session.module_id = manifest.module_id
	session.session_name = String(data.get("session_name", ""))
	session.current_location_id = current_location_id
	session.location_states = location_states
	session.notes = String(data.get("notes", ""))
	return _result(OK, session, false, false, "带团会话已加载")


static func _is_safe_session_state_path(
		module_dir: String,
		session_id: String,
		state_relpath: String
) -> bool:
	if not state_relpath.to_lower().ends_with(".scn"):
		return false
	var session_dir: String = _session_dir(module_dir, session_id)
	return _is_safe_module_relative_path(
		session_dir,
		state_relpath,
		SESSION_STATES_DIR_NAME + "/"
	)


## 生成与文件名、显示名无关的 128 位稳定标识。
static func generate_stable_id() -> String:
	var crypto: Crypto = Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()


## 读取、恢复或迁移一个模组清单。所有失败都通过结果字典返回。
static func load_manifest_for_module(module_dir: String, create_if_missing: bool) -> Dictionary:
	if module_dir == "":
		return _result(ERR_INVALID_PARAMETER, null, false, false, "模组目录为空")
	var manifest_path: String = module_dir.path_join(MANIFEST_FILE_NAME)
	var backup_path: String = manifest_path + MANIFEST_BACKUP_SUFFIX
	var temp_path: String = manifest_path + MANIFEST_TEMP_SUFFIX

	if FileAccess.file_exists(manifest_path):
		var formal_result: Dictionary = _load_manifest_file(manifest_path, module_dir)
		var formal_error: int = int(formal_result.get("error", FAILED))
		if formal_error == OK:
			var formal_manifest: ModuleManifest = formal_result.get("value") as ModuleManifest
			var formal_migrated: bool = bool(formal_result.get("migrated", false))
			if formal_migrated:
				var migrate_save_result: Dictionary = save_manifest_recoverable(module_dir, formal_manifest)
				if int(migrate_save_result.get("error", FAILED)) != OK:
					return migrate_save_result
			elif FileAccess.file_exists(temp_path):
				DirAccess.remove_absolute(temp_path)
			return _result(OK, formal_manifest, false, formal_migrated, "模组清单已读取")
		if formal_error == ERR_UNAVAILABLE:
			return formal_result
		if FileAccess.file_exists(backup_path):
			return _restore_manifest_from_backup(module_dir, backup_path, manifest_path)
		return _result(formal_error, null, false, false, "正式清单损坏，且没有可用备份")

	if FileAccess.file_exists(backup_path):
		return _restore_manifest_from_backup(module_dir, backup_path, manifest_path)

	if FileAccess.file_exists(temp_path):
		var temp_result: Dictionary = _load_manifest_file(temp_path, module_dir)
		if int(temp_result.get("error", FAILED)) == OK:
			var temp_manifest: ModuleManifest = temp_result.get("value") as ModuleManifest
			var temp_migrated: bool = bool(temp_result.get("migrated", false))
			if temp_migrated:
				var temp_save_result: Dictionary = save_manifest_recoverable(module_dir, temp_manifest)
				if int(temp_save_result.get("error", FAILED)) != OK:
					return temp_save_result
			else:
				var temp_commit_error: int = DirAccess.rename_absolute(temp_path, manifest_path)
				if temp_commit_error != OK:
					return _result(temp_commit_error, null, false, false, "临时清单提交失败")
			return _result(OK, temp_manifest, false, temp_migrated, "已恢复首次创建留下的临时清单")
		if int(temp_result.get("error", FAILED)) == ERR_UNAVAILABLE:
			return temp_result

	var legacy_result: Dictionary = _build_legacy_manifest(module_dir)
	if int(legacy_result.get("error", FAILED)) == OK:
		var legacy_manifest: ModuleManifest = legacy_result.get("value") as ModuleManifest
		var legacy_save_result: Dictionary = save_manifest_recoverable(module_dir, legacy_manifest)
		if int(legacy_save_result.get("error", FAILED)) != OK:
			return legacy_save_result
		return _result(OK, legacy_manifest, false, true, "旧模组场景已迁入清单，原文件保持不动")

	if not create_if_missing:
		return _result(ERR_FILE_NOT_FOUND, null, false, false, "找不到模组清单")
	var create_error: int = DirAccess.make_dir_recursive_absolute(
		module_dir.path_join(CANONICAL_DIR_NAME)
	)
	if create_error != OK:
		return _result(create_error, null, false, false, "无法创建模组目录")
	var new_manifest: ModuleManifest = ModuleManifest.new()
	new_manifest.schema_version = ModuleManifest.SCHEMA_VERSION
	new_manifest.module_id = generate_stable_id()
	new_manifest.module_name = module_dir.trim_suffix("/").get_file()
	var create_result: Dictionary = save_manifest_recoverable(module_dir, new_manifest)
	if int(create_result.get("error", FAILED)) != OK:
		return create_result
	return _result(OK, new_manifest, false, false, "新模组清单已创建")


## 以 tmp -> 校验 -> bak -> 提交的顺序保存清单。
## 该链路可恢复，但不宣称 Windows 断电级原子性。
static func save_manifest_recoverable(module_dir: String, manifest: ModuleManifest) -> Dictionary:
	if module_dir == "" or manifest == null:
		return _result(ERR_INVALID_PARAMETER, null, false, false, "模组清单参数无效")
	var validation_result: Dictionary = _manifest_from_dictionary(manifest.to_json_dict(), module_dir)
	if int(validation_result.get("error", FAILED)) != OK:
		return validation_result
	var dir_error: int = DirAccess.make_dir_recursive_absolute(module_dir)
	if dir_error != OK:
		return _result(dir_error, null, false, false, "无法创建模组目录")

	var manifest_path: String = module_dir.path_join(MANIFEST_FILE_NAME)
	var backup_path: String = manifest_path + MANIFEST_BACKUP_SUFFIX
	var temp_path: String = manifest_path + MANIFEST_TEMP_SUFFIX
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	var json_text: String = JSON.stringify(manifest.to_json_dict(), "\t", true)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _result(FileAccess.get_open_error(), null, false, false, "无法写入临时清单")
	var write_ok: bool = file.store_string(json_text)
	file.flush()
	file.close()
	if not write_ok:
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_CANT_CREATE, null, false, false, "临时清单写入不完整")
	var expected_bytes: PackedByteArray = json_text.to_utf8_buffer()
	var actual_bytes: PackedByteArray = FileAccess.get_file_as_bytes(temp_path)
	if actual_bytes != expected_bytes:
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_FILE_CORRUPT, null, false, false, "临时清单字节校验失败")
	var temp_validation: Dictionary = _load_manifest_file(temp_path, module_dir)
	if int(temp_validation.get("error", FAILED)) != OK or bool(temp_validation.get("migrated", false)):
		DirAccess.remove_absolute(temp_path)
		return _result(ERR_INVALID_DATA, null, false, false, "临时清单结构校验失败")

	if FileAccess.file_exists(manifest_path):
		var backup_error: int = DirAccess.copy_absolute(manifest_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _result(backup_error, null, false, false, "无法备份上一份清单")
	var commit_error: int = DirAccess.rename_absolute(temp_path, manifest_path)
	if commit_error != OK:
		if not FileAccess.file_exists(manifest_path) and FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, manifest_path)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		return _result(commit_error, null, false, false, "清单提交失败，已尝试恢复上一份")
	var committed_result: Dictionary = _load_manifest_file(manifest_path, module_dir)
	if int(committed_result.get("error", FAILED)) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.copy_absolute(backup_path, manifest_path)
		return _result(ERR_FILE_CORRUPT, null, false, false, "提交后的清单校验失败，已尝试恢复备份")
	return _result(OK, manifest, false, false, "模组清单已保存")


static func _restore_manifest_from_backup(
	module_dir: String,
	backup_path: String,
	manifest_path: String
) -> Dictionary:
	var backup_result: Dictionary = _load_manifest_file(backup_path, module_dir)
	var backup_error: int = int(backup_result.get("error", FAILED))
	if backup_error != OK:
		return _result(backup_error, null, false, false, "正式清单和备份都不可用")
	var manifest: ModuleManifest = backup_result.get("value") as ModuleManifest
	var migrated: bool = bool(backup_result.get("migrated", false))
	if migrated:
		var save_result: Dictionary = save_manifest_recoverable(module_dir, manifest)
		if int(save_result.get("error", FAILED)) != OK:
			return save_result
	else:
		var restore_error: int = DirAccess.copy_absolute(backup_path, manifest_path)
		if restore_error != OK:
			return _result(restore_error, null, false, false, "备份有效，但恢复正式清单失败")
	return _result(OK, manifest, true, migrated, "已从备份恢复模组清单")


static func _load_manifest_file(path: String, module_dir: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _result(ERR_FILE_NOT_FOUND, null, false, false, "清单文件不存在")
	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		return _result(parse_error, null, false, false, "清单 JSON 语法损坏")
	var data_value: Variant = parser.data
	if not (data_value is Dictionary):
		return _result(ERR_INVALID_DATA, null, false, false, "清单顶层必须是对象")
	var data: Dictionary = (data_value as Dictionary).duplicate(true)
	if String(data.get("format", "")) != ModuleManifest.FORMAT:
		return _result(ERR_INVALID_DATA, null, false, false, "清单格式标记不匹配")
	var version_value: Variant = data.get("schema_version", null)
	if not (version_value is int or version_value is float):
		return _result(ERR_INVALID_DATA, null, false, false, "清单缺少结构版本")
	var version_number: float = float(version_value)
	if version_number < 0.0 or version_number > 2147483647.0 or version_number != floorf(version_number):
		return _result(ERR_INVALID_DATA, null, false, false, "清单结构版本必须是非负整数")
	var version: int = int(version_value)
	if version > ModuleManifest.SCHEMA_VERSION:
		return _result(ERR_UNAVAILABLE, null, false, false, "该模组由更高版本创建，当前版本不会覆盖它")
	if version < 0:
		return _result(ERR_INVALID_DATA, null, false, false, "清单结构版本无效")
	var migrated: bool = false
	while version < ModuleManifest.SCHEMA_VERSION:
		var migration_result: Dictionary = _migrate_manifest_step(data, version, module_dir)
		if int(migration_result.get("error", FAILED)) != OK:
			return migration_result
		data = migration_result.get("value", {}) as Dictionary
		version += 1
		migrated = true
	var result: Dictionary = _manifest_from_dictionary(data, module_dir)
	result["migrated"] = migrated
	return result


static func _migrate_manifest_step(data: Dictionary, version: int, module_dir: String) -> Dictionary:
	if version == 1:
		var version_two: Dictionary = data.duplicate(true)
		version_two["schema_version"] = 2
		if not version_two.has("acts"):
			version_two["acts"] = []
		return _result(OK, version_two, false, true, "清单已从版本 1 迁移到版本 2")
	if version != 0:
		return _result(ERR_UNAVAILABLE, null, false, false, "缺少对应的逐版本迁移器")
	var migrated: Dictionary = data.duplicate(true)
	var location_values: Variant = migrated.get("locations", [])
	if not (location_values is Array):
		return _result(ERR_INVALID_DATA, null, false, false, "旧清单地点列表无效")
	var migrated_locations: Array = []
	var location_array: Array = location_values as Array
	for location_value: Variant in location_array:
		if not (location_value is Dictionary):
			return _result(ERR_INVALID_DATA, null, false, false, "旧清单地点条目无效")
		var old_location: Dictionary = (location_value as Dictionary).duplicate(true)
		var old_path: String = String(old_location.get("canonical_path", ""))
		var relative_path: String = _module_relative_path(module_dir, old_path)
		if relative_path == "":
			return _result(ERR_INVALID_DATA, null, false, false, "旧清单场景路径无法迁移")
		old_location.erase("canonical_path")
		old_location["canonical_relpath"] = relative_path
		migrated_locations.append(old_location)
	migrated["locations"] = migrated_locations
	var start_name: String = String(migrated.get("start_location", ""))
	var start_id: String = ""
	for migrated_location_value: Variant in migrated_locations:
		var migrated_location: Dictionary = migrated_location_value as Dictionary
		if String(migrated_location.get("display_name", "")) == start_name:
			start_id = String(migrated_location.get("location_id", ""))
			break
	migrated.erase("start_location")
	migrated["start_location_id"] = start_id
	migrated["schema_version"] = 1
	if not migrated.has("ruleset_id"):
		migrated["ruleset_id"] = "cpr"
	if not migrated.has("notes"):
		migrated["notes"] = ""
	if not migrated.has("external_contents"):
		migrated["external_contents"] = []
	return _result(OK, migrated, false, true, "清单已从版本 0 迁移到版本 1")


static func _manifest_from_dictionary(data: Dictionary, module_dir: String) -> Dictionary:
	if not _has_string_fields(
		data,
		[
			"format",
			"module_id",
			"module_name",
			"start_location_id",
			"ruleset_id",
			"notes",
		]
	):
		return _result(ERR_INVALID_DATA, null, false, false, "清单文本字段类型无效")
	if String(data.get("format", "")) != ModuleManifest.FORMAT:
		return _result(ERR_INVALID_DATA, null, false, false, "清单格式标记不匹配")
	var schema_version_value: Variant = data.get("schema_version", null)
	if not (schema_version_value is int or schema_version_value is float):
		return _result(ERR_INVALID_DATA, null, false, false, "清单结构版本类型无效")
	var schema_version_number: float = float(schema_version_value)
	if schema_version_number != floorf(schema_version_number):
		return _result(ERR_INVALID_DATA, null, false, false, "清单结构版本必须是整数")
	if int(schema_version_value) != ModuleManifest.SCHEMA_VERSION:
		return _result(ERR_INVALID_DATA, null, false, false, "清单结构版本不匹配")
	var manifest: ModuleManifest = ModuleManifest.new()
	manifest.schema_version = ModuleManifest.SCHEMA_VERSION
	manifest.module_id = String(data.get("module_id", ""))
	manifest.module_name = String(data.get("module_name", ""))
	manifest.start_location_id = String(data.get("start_location_id", ""))
	manifest.ruleset_id = StringName(String(data.get("ruleset_id", "cpr")))
	manifest.notes = String(data.get("notes", ""))
	if not _is_stable_id(manifest.module_id):
		return _result(ERR_INVALID_DATA, null, false, false, "module_id 不是合法稳定标识")
	var all_ids: Dictionary = {}
	all_ids[manifest.module_id] = true
	var location_values: Variant = data.get("locations", null)
	if not (location_values is Array):
		return _result(ERR_INVALID_DATA, null, false, false, "locations 必须是数组")
	var location_array: Array = location_values as Array
	for location_value: Variant in location_array:
		if not (location_value is Dictionary):
			return _result(ERR_INVALID_DATA, null, false, false, "地点条目必须是对象")
		var location_data: Dictionary = location_value as Dictionary
		if not _has_string_fields(
			location_data,
			["location_id", "display_name", "canonical_relpath"]
		):
			return _result(ERR_INVALID_DATA, null, false, false, "地点文本字段类型无效")
		var location: LocationRef = LocationRef.new()
		location.location_id = String(location_data.get("location_id", ""))
		location.display_name = String(location_data.get("display_name", ""))
		location.canonical_relpath = String(location_data.get("canonical_relpath", ""))
		if not _is_stable_id(location.location_id) or all_ids.has(location.location_id):
			return _result(ERR_INVALID_DATA, null, false, false, "地点稳定标识无效或重复")
		if not _is_safe_module_relative_path(
			module_dir,
			location.canonical_relpath,
			CANONICAL_DIR_NAME + "/"
		):
			return _result(ERR_INVALID_DATA, null, false, false, "地点路径越出 _canonical 目录")
		if not location.canonical_relpath.to_lower().ends_with(".scn"):
			return _result(ERR_INVALID_DATA, null, false, false, "地点底本必须使用 .scn")
		all_ids[location.location_id] = true
		location.canonical_path = module_dir.path_join(location.canonical_relpath).simplify_path()
		location.available = FileAccess.file_exists(location.canonical_path)
		manifest.locations.append(location)
	if manifest.start_location_id != "" and manifest.find_location_by_id(manifest.start_location_id) == null:
		return _result(ERR_INVALID_DATA, null, false, false, "起始地点引用不存在")
	manifest.sync_legacy_start_location()

	var external_values: Variant = data.get("external_contents", null)
	if not (external_values is Array):
		return _result(ERR_INVALID_DATA, null, false, false, "external_contents 必须是数组")
	var external_array: Array = external_values as Array
	for external_value: Variant in external_array:
		if not (external_value is Dictionary):
			return _result(ERR_INVALID_DATA, null, false, false, "外部内容条目必须是对象")
		var external_data: Dictionary = external_value as Dictionary
		if not _has_string_fields(
			external_data,
			["content_id", "content_type", "display_name", "source_kind", "source_path"]
		):
			return _result(ERR_INVALID_DATA, null, false, false, "外部内容文本字段类型无效")
		var content: ExternalContentRef = ExternalContentRef.new()
		content.content_id = String(external_data.get("content_id", ""))
		content.display_name = String(external_data.get("display_name", ""))
		content.source_path = String(external_data.get("source_path", ""))
		var content_type_value: int = ExternalContentRef.content_type_from_string(
			String(external_data.get("content_type", ""))
		)
		var source_kind_value: int = ExternalContentRef.source_kind_from_string(
			String(external_data.get("source_kind", ""))
		)
		if content_type_value < 0:
			return _result(ERR_INVALID_DATA, null, false, false, "外部内容类型无效")
		if source_kind_value < 0:
			return _result(ERR_INVALID_DATA, null, false, false, "外部内容来源类型无效")
		content.content_type = content_type_value
		content.source_kind = source_kind_value
		var metadata_value: Variant = external_data.get("metadata", null)
		if not (metadata_value is Dictionary):
			return _result(ERR_INVALID_DATA, null, false, false, "外部内容 metadata 必须是对象")
		content.metadata = (metadata_value as Dictionary).duplicate(true)
		for dimension_name: String in ["natural_width", "natural_height", "duration_seconds"]:
			if not content.metadata.has(dimension_name):
				continue
			var dimension_value: Variant = content.metadata[dimension_name]
			if not (dimension_value is int or dimension_value is float) or float(dimension_value) < 0.0:
				return _result(ERR_INVALID_DATA, null, false, false, "外部内容 metadata 数值无效")
		if not _is_stable_id(content.content_id) or all_ids.has(content.content_id):
			return _result(ERR_INVALID_DATA, null, false, false, "外部内容稳定标识无效或重复")
		var resolver: ExternalContentResolver = ExternalContentResolver.new()
		var resolve_result: Dictionary = resolver.resolve(content, module_dir)
		var resolve_error: int = int(resolve_result.get("error", FAILED))
		if resolve_error != OK and resolve_error != ERR_FILE_NOT_FOUND:
			return _result(ERR_INVALID_DATA, null, false, false, String(resolve_result.get("message", "外部内容路径无效")))
		all_ids[content.content_id] = true
		manifest.external_contents.append(content)

	var act_values: Variant = data.get("acts", null)
	if not (act_values is Array):
		return _result(ERR_INVALID_DATA, null, false, false, "acts 必须是数组")
	var act_array: Array = act_values as Array
	for act_value: Variant in act_array:
		if not (act_value is Dictionary):
			return _result(ERR_INVALID_DATA, null, false, false, "幕条目必须是对象")
		var act_data: Dictionary = act_value as Dictionary
		if not _has_string_fields(act_data, ["act_id", "display_name", "gm_notes"]):
			return _result(ERR_INVALID_DATA, null, false, false, "幕文本字段类型无效")
		var act: ActRef = ActRef.new()
		act.act_id = String(act_data.get("act_id", ""))
		act.display_name = String(act_data.get("display_name", "")).strip_edges()
		act.gm_notes = String(act_data.get("gm_notes", ""))
		if not _is_stable_id(act.act_id) or all_ids.has(act.act_id):
			return _result(ERR_INVALID_DATA, null, false, false, "幕稳定标识无效或重复")
		if act.display_name == "":
			return _result(ERR_INVALID_DATA, null, false, false, "幕名称不能为空")
		all_ids[act.act_id] = true
		var item_values: Variant = act_data.get("items", null)
		if not (item_values is Array):
			return _result(ERR_INVALID_DATA, null, false, false, "幕内容必须是数组")
		var item_array: Array = item_values as Array
		for item_value: Variant in item_array:
			if not (item_value is Dictionary):
				return _result(ERR_INVALID_DATA, null, false, false, "幕内容条目必须是对象")
			var item_data: Dictionary = item_value as Dictionary
			if not _has_string_fields(
					item_data,
					["item_id", "item_type", "target_id", "display_name", "text_content", "gm_notes"]
			):
				return _result(ERR_INVALID_DATA, null, false, false, "幕内容文本字段类型无效")
			var item: ActItemRef = ActItemRef.new()
			item.item_id = String(item_data.get("item_id", ""))
			item.target_id = String(item_data.get("target_id", ""))
			item.display_name = String(item_data.get("display_name", ""))
			item.text_content = String(item_data.get("text_content", ""))
			item.gm_notes = String(item_data.get("gm_notes", ""))
			var item_type_value: int = ActItemRef.item_type_from_string(
				String(item_data.get("item_type", ""))
			)
			if item_type_value < 0:
				return _result(ERR_INVALID_DATA, null, false, false, "幕内容类型无效")
			if not _is_stable_id(item.item_id) or all_ids.has(item.item_id):
				return _result(ERR_INVALID_DATA, null, false, false, "幕内容稳定标识无效或重复")
			item.item_type = item_type_value
			if item.item_type == ActItemRef.ItemType.TEXT:
				if item.target_id != "":
					return _result(ERR_INVALID_DATA, null, false, false, "文本条目不能引用外部目标")
				if item.display_name.strip_edges() == "":
					return _result(ERR_INVALID_DATA, null, false, false, "文本条目名称不能为空")
			elif not _is_stable_id(item.target_id):
				return _result(ERR_INVALID_DATA, null, false, false, "幕内容目标标识无效")
			all_ids[item.item_id] = true
			act.items.append(item)
		manifest.acts.append(act)
	return _result(OK, manifest, false, false, "模组清单结构有效")


static func _build_legacy_manifest(module_dir: String) -> Dictionary:
	var canonical_dir: String = module_dir.path_join(CANONICAL_DIR_NAME)
	if not DirAccess.dir_exists_absolute(canonical_dir):
		return _result(ERR_FILE_NOT_FOUND, null, false, false, "没有旧模组目录")
	var scene_files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(canonical_dir):
		if file_name.to_lower().ends_with(".scn"):
			scene_files.append(file_name)
	scene_files.sort()
	if scene_files.is_empty():
		return _result(ERR_FILE_NOT_FOUND, null, false, false, "旧模组没有场景文件")
	var manifest: ModuleManifest = ModuleManifest.new()
	manifest.module_id = generate_stable_id()
	manifest.module_name = module_dir.trim_suffix("/").get_file()
	for file_name: String in scene_files:
		var location: LocationRef = LocationRef.new()
		location.location_id = generate_stable_id()
		location.display_name = file_name.get_basename()
		location.canonical_relpath = CANONICAL_DIR_NAME + "/" + file_name
		location.canonical_path = canonical_dir.path_join(file_name)
		location.available = true
		manifest.locations.append(location)
	if not manifest.locations.is_empty():
		manifest.start_location_id = manifest.locations[0].location_id
		manifest.sync_legacy_start_location()
	return _result(OK, manifest, false, true, "旧模组场景已扫描")


static func _module_relative_path(module_dir: String, path: String) -> String:
	var normalized_root: String = module_dir.replace("\\", "/").trim_suffix("/").simplify_path()
	var normalized_path: String = path.replace("\\", "/").simplify_path()
	var prefix: String = normalized_root + "/"
	if not normalized_path.begins_with(prefix):
		return ""
	var relative_path: String = normalized_path.trim_prefix(prefix)
	if not _is_safe_module_relative_path(module_dir, relative_path, CANONICAL_DIR_NAME + "/"):
		return ""
	return relative_path


static func _is_safe_module_relative_path(
	module_dir: String,
	relative_path: String,
	required_prefix: String
) -> bool:
	if relative_path == "" or relative_path.is_absolute_path():
		return false
	if relative_path.contains("\\"):
		return false
	var normalized: String = relative_path.replace("\\", "/")
	if normalized.contains(":") or normalized.contains("\u0000"):
		return false
	var segments: PackedStringArray = normalized.split("/", false)
	for segment: String in segments:
		if segment == "..":
			return false
	var simplified: String = normalized.simplify_path()
	if required_prefix != "" and not simplified.begins_with(required_prefix):
		return false
	var root: String = module_dir.replace("\\", "/").trim_suffix("/").simplify_path()
	var candidate: String = root.path_join(simplified).simplify_path()
	return candidate.begins_with(root + "/")


static func _is_stable_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for index: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


static func _has_string_fields(data: Dictionary, field_names: Array) -> bool:
	for field_name: String in field_names:
		if not data.has(field_name) or not (data[field_name] is String):
			return false
	return true


static func _result(
	error: int,
	value: Variant,
	recovered_from_backup: bool,
	migrated: bool,
	message: String
) -> Dictionary:
	return {
		"error": error,
		"value": value,
		"recovered_from_backup": recovered_from_backup,
		"migrated": migrated,
		"message": message,
	}


## 递归把 root 下所有节点 owner 设成 root——修 pack 的 owner 陷阱。
## 依据:gdd_1006 第 31-45 行原文举例:pack 只打包"有 owner 联结"的节点。
## main.gd _place_building 放物件 add_child 未设 owner → 存盘会漏物件。
## 此方法在 save_scene_tree 内部调用,调用方无需关心。
## 注:Godot 里 Node.owner 主要服务于编辑器场景编辑;运行时场景基本不设。
##      这里临时补上仅为 pack 能抓全节点——存完之后是否回退
##      (避运行时意外副作用)留给落地测(game_eval 实证存→读→树完整)。
static func _ensure_ownership(node: Node, scene_owner: Node) -> void:
	for c: Node in node.get_children():
		if c.has_meta("gvtt_runtime_only"):
			if c.owner != null:
				c.set_owner(null)
			continue
		if c.owner != scene_owner and c.owner == null:
			c.set_owner(scene_owner)
		_ensure_ownership(c, scene_owner)
