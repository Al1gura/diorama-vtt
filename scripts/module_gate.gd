extends Node
## ModuleGate -- global truth for the currently opened GM module and scene list.
##
## Startup must be an empty workspace. A module is opened only through explicit UI
## actions: create, import, or recover the old development test module.

signal current_location_changed(location_name: String)
signal scene_list_changed
signal external_contents_changed
signal acts_changed
signal module_changed(module_name: String)
signal session_changed(session_id: String)

const LEGACY_TEST_MODULE_NAME: String = "测试模组"
const LEGACY_MODULE_ROOT: String = "res://modules/"
const MODULE_ROOT: String = "user://modules/"

var _current_manifest: ModuleManifest = null
var _current_session: Playthrough = null
var _current_location_name: String = ""
var _current_module_name: String = ""
var _last_manifest_result: Dictionary = {}


func _ready() -> void:
	_close_current_module(false)


func has_open_module() -> bool:
	return _current_manifest != null and _current_module_name != ""


func current_module_name() -> String:
	return _current_module_name


func list_module_names() -> Array[String]:
	var module_names: Array[String] = []
	if not DirAccess.dir_exists_absolute(MODULE_ROOT):
		return module_names
	for directory_name: String in DirAccess.get_directories_at(MODULE_ROOT):
		if DirAccess.dir_exists_absolute(_module_dir_for(directory_name)):
			module_names.append(directory_name)
	module_names.sort()
	return module_names


func create_module(module_name: String) -> int:
	var normalized_name: String = _normalized_module_name(module_name)
	if normalized_name == "":
		return ERR_INVALID_PARAMETER
	var err: int = _ensure_module_dirs(normalized_name)
	if err != OK:
		return err
	var load_result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir_for(normalized_name),
		true
	)
	_last_manifest_result = load_result.duplicate(true)
	err = int(load_result.get("error", FAILED))
	if err != OK:
		return err
	var manifest: ModuleManifest = load_result.get("value") as ModuleManifest
	if manifest == null:
		return ERR_INVALID_DATA
	_commit_open_state(normalized_name, manifest)
	_emit_module_state_changed()
	return OK


func create_unique_module(base_name: String) -> int:
	return create_module(_unique_module_name(base_name))


func open_module(module_name: String) -> int:
	var normalized_name: String = _normalized_module_name(module_name)
	if normalized_name == "":
		return ERR_INVALID_PARAMETER
	if not DirAccess.dir_exists_absolute(_module_dir_for(normalized_name)):
		return ERR_FILE_NOT_FOUND
	var load_result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir_for(normalized_name),
		false
	)
	_last_manifest_result = load_result.duplicate(true)
	var err: int = int(load_result.get("error", FAILED))
	if err != OK:
		return err
	var manifest: ModuleManifest = load_result.get("value") as ModuleManifest
	if manifest == null:
		return ERR_INVALID_DATA
	_commit_open_state(normalized_name, manifest)
	_emit_module_state_changed()
	return OK


func import_module_from_path(source_path: String) -> int:
	var source_canonical_dir: String = _canonical_source_dir_for(source_path)
	if source_canonical_dir == "":
		return ERR_FILE_NOT_FOUND
	var source_scene_files: Array[String] = _scene_files_at(source_canonical_dir)
	var imported_module_name: String = _module_name_from_import_path(source_path)
	var target_module_name: String = _unique_module_name(imported_module_name)
	var err: int = _ensure_module_dirs(target_module_name)
	if err != OK:
		return err
	for file_name: String in source_scene_files:
		var copy_err: int = DirAccess.copy_absolute(
			source_canonical_dir.path_join(file_name),
			_canonical_dir_for(target_module_name).path_join(file_name)
		)
		if copy_err != OK:
			return copy_err
	var load_result: Dictionary = ModuleIo.load_manifest_for_module(
		_module_dir_for(target_module_name),
		true
	)
	_last_manifest_result = load_result.duplicate(true)
	err = int(load_result.get("error", FAILED))
	if err != OK:
		return err
	var manifest: ModuleManifest = load_result.get("value") as ModuleManifest
	if manifest == null:
		return ERR_INVALID_DATA
	_commit_open_state(target_module_name, manifest)
	_emit_module_state_changed()
	return OK


func legacy_module_available() -> bool:
	return (
		DirAccess.dir_exists_absolute(_canonical_dir_for(LEGACY_TEST_MODULE_NAME))
		or DirAccess.dir_exists_absolute(_legacy_module_dir_for(LEGACY_TEST_MODULE_NAME))
	)


func recover_legacy_test_module() -> int:
	if not legacy_module_available():
		return ERR_FILE_NOT_FOUND
	var err: int = _ensure_module_dirs(LEGACY_TEST_MODULE_NAME)
	if err != OK:
		return err
	_migrate_legacy_scenes(LEGACY_TEST_MODULE_NAME)
	return open_module(LEGACY_TEST_MODULE_NAME)


func add_scene() -> String:
	if not has_open_module():
		push_warning("ModuleGate.add_scene: no module is open")
		return ""
	var used: Dictionary = {}
	for location: LocationRef in _current_manifest.locations:
		used[location.display_name] = true
	var n: int = 1
	var scene_name: String = "场景" + str(n)
	while used.has(scene_name):
		n += 1
		scene_name = "场景" + str(n)
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var ref: LocationRef = _new_location_ref(scene_name)
	candidate.locations.append(ref)
	if candidate.start_location_id == "":
		candidate.start_location_id = ref.location_id
		candidate.sync_legacy_start_location()
	var save_result: Dictionary = ModuleIo.save_manifest_recoverable(_module_dir(), candidate)
	if int(save_result.get("error", FAILED)) != OK:
		push_error(
			"ModuleGate.add_scene: manifest save failed code=%d"
			% int(save_result.get("error", FAILED))
		)
		return ""
	_current_manifest = candidate
	_current_location_name = scene_name
	scene_list_changed.emit()
	return scene_name


func save_current_scene(target_name: String, scene_root: Node) -> int:
	if not has_open_module():
		push_error("ModuleGate.save_current_scene: no module is open")
		return ERR_UNCONFIGURED
	if target_name == "":
		return ERR_INVALID_PARAMETER
	if scene_root == null or not is_instance_valid(scene_root):
		push_error("ModuleGate.save_current_scene: scene_root is invalid")
		return ERR_INVALID_PARAMETER
	var dir_err: int = _ensure_module_dirs(_current_module_name)
	if dir_err != OK:
		return dir_err
	var ref: LocationRef = _find_location(target_name)
	if ref == null:
		var candidate: ModuleManifest = _copy_manifest(_current_manifest)
		var candidate_ref: LocationRef = _new_location_ref(target_name)
		candidate.locations.append(candidate_ref)
		if candidate.start_location_id == "":
			candidate.start_location_id = candidate_ref.location_id
			candidate.sync_legacy_start_location()
		var manifest_result: Dictionary = ModuleIo.save_manifest_recoverable(
			_module_dir(),
			candidate
		)
		if int(manifest_result.get("error", FAILED)) != OK:
			return int(manifest_result.get("error", FAILED))
		_current_manifest = candidate
		ref = _current_manifest.find_location_by_id(candidate_ref.location_id)
	if ref == null:
		return ERR_INVALID_DATA
	var err: int = ModuleIo.save_scene_tree(scene_root, ref.canonical_path)
	if err == OK:
		ref.available = true
		_current_location_name = target_name
		scene_list_changed.emit()
	return err


func save_current_manifest() -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var save_result: Dictionary = ModuleIo.save_manifest_recoverable(
		_module_dir(),
		_current_manifest
	)
	return int(save_result.get("error", FAILED))


func register_external_content(
		source_path: String,
		content_type: ExternalContentRef.ContentType
) -> Dictionary:
	if not has_open_module():
		return _external_content_result(ERR_UNCONFIGURED, null, {}, "当前没有打开的模组")
	if content_type not in [ExternalContentRef.ContentType.IMAGE, ExternalContentRef.ContentType.VIDEO]:
		return _external_content_result(ERR_INVALID_PARAMETER, null, {}, "媒体类型无效")
	var normalized_path: String = source_path.replace("\\", "/").simplify_path()
	var content: ExternalContentRef = ExternalContentRef.new()
	content.content_id = ModuleIo.generate_stable_id()
	while _find_external_content(_current_manifest, content.content_id) != null:
		content.content_id = ModuleIo.generate_stable_id()
	content.content_type = content_type
	content.display_name = normalized_path.get_file().get_basename().strip_edges()
	if content.display_name == "":
		content.display_name = normalized_path.get_file()
	content.source_kind = ExternalContentRef.SourceKind.EXTERNAL_FILE
	content.source_path = normalized_path
	var inspection: Dictionary = MediaRegistry.inspect(content, _module_dir())
	var status: StringName = StringName(String(inspection.get("status", "")))
	if status == MediaRegistry.STATUS_MISSING:
		return _external_content_result(ERR_FILE_NOT_FOUND, null, inspection, "所选媒体文件不存在")
	if String(inspection.get("resolved_path", "")) == "":
		return _external_content_result(
			int(inspection.get("error", ERR_INVALID_DATA)), null, inspection, "媒体路径无效"
		)
	content.metadata = (inspection.get("metadata", {}) as Dictionary).duplicate(true)

	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	candidate.external_contents.append(content)
	var save_result: Dictionary = ModuleIo.save_manifest_recoverable(_module_dir(), candidate)
	var save_error: int = int(save_result.get("error", FAILED))
	if save_error != OK:
		return _external_content_result(save_error, null, inspection, "媒体登记保存失败")
	_current_manifest = candidate
	var saved_content: ExternalContentRef = _find_external_content(_current_manifest, content.content_id)
	external_contents_changed.emit()
	return _external_content_result(OK, saved_content, inspection, "媒体已登记")


func rename_external_content(content_id: String, display_name: String) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var normalized_name: String = display_name.strip_edges()
	if normalized_name == "":
		return ERR_INVALID_PARAMETER
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var content: ExternalContentRef = _find_external_content(candidate, content_id)
	if content == null:
		return ERR_DOES_NOT_EXIST
	content.display_name = normalized_name
	var save_result: Dictionary = ModuleIo.save_manifest_recoverable(_module_dir(), candidate)
	var save_error: int = int(save_result.get("error", FAILED))
	if save_error != OK:
		return save_error
	_current_manifest = candidate
	external_contents_changed.emit()
	return OK


func remove_external_content(content_id: String) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var remove_index: int = -1
	for index: int in range(candidate.external_contents.size()):
		if candidate.external_contents[index].content_id == content_id:
			remove_index = index
			break
	if remove_index < 0:
		return ERR_DOES_NOT_EXIST
	candidate.external_contents.remove_at(remove_index)
	var save_result: Dictionary = ModuleIo.save_manifest_recoverable(_module_dir(), candidate)
	var save_error: int = int(save_result.get("error", FAILED))
	if save_error != OK:
		return save_error
	_current_manifest = candidate
	external_contents_changed.emit()
	return OK


func list_external_content_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not has_open_module():
		return entries
	for content: ExternalContentRef in _current_manifest.external_contents:
		var entry: Dictionary = MediaRegistry.inspect(content, _module_dir())
		entry["content"] = content
		entries.append(entry)
	return entries


func create_act(display_name: String) -> Dictionary:
	if not has_open_module():
		return _act_result(ERR_UNCONFIGURED, null, "当前没有打开的模组")
	var normalized_name: String = display_name.strip_edges()
	if normalized_name == "":
		return _act_result(ERR_INVALID_PARAMETER, null, "幕名称不能为空")
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = ActRef.new()
	act.act_id = ModuleIo.generate_stable_id()
	while candidate.find_act_by_id(act.act_id) != null:
		act.act_id = ModuleIo.generate_stable_id()
	act.display_name = normalized_name
	candidate.acts.append(act)
	var save_error: int = _save_act_candidate(candidate)
	var saved_act: ActRef = null
	if save_error == OK:
		saved_act = _current_manifest.find_act_by_id(act.act_id)
	return _act_result(
		save_error,
		saved_act,
		"幕已创建" if save_error == OK else "幕创建失败"
	)


func rename_act(act_id: String, display_name: String) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var normalized_name: String = display_name.strip_edges()
	if normalized_name == "":
		return ERR_INVALID_PARAMETER
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = candidate.find_act_by_id(act_id)
	if act == null:
		return ERR_DOES_NOT_EXIST
	act.display_name = normalized_name
	return _save_act_candidate(candidate)


func update_act_notes(act_id: String, gm_notes: String) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = candidate.find_act_by_id(act_id)
	if act == null:
		return ERR_DOES_NOT_EXIST
	act.gm_notes = gm_notes
	return _save_act_candidate(candidate)


func remove_act(act_id: String) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var remove_index: int = -1
	for index: int in range(candidate.acts.size()):
		if candidate.acts[index].act_id == act_id:
			remove_index = index
			break
	if remove_index < 0:
		return ERR_DOES_NOT_EXIST
	candidate.acts.remove_at(remove_index)
	return _save_act_candidate(candidate)


func add_act_item(
		act_id: String,
		item_type: ActItemRef.ItemType,
		target_id: String = "",
		display_name: String = "",
		text_content: String = "",
		gm_notes: String = ""
) -> Dictionary:
	if not has_open_module():
		return _act_item_result(ERR_UNCONFIGURED, null, "当前没有打开的模组")
	if item_type == ActItemRef.ItemType.TEXT:
		if target_id != "" or display_name.strip_edges() == "":
			return _act_item_result(ERR_INVALID_PARAMETER, null, "文本条目参数无效")
	elif not _target_id_matches_item_type(item_type, target_id):
		return _act_item_result(ERR_DOES_NOT_EXIST, null, "引用目标不存在")
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = candidate.find_act_by_id(act_id)
	if act == null:
		return _act_item_result(ERR_DOES_NOT_EXIST, null, "幕不存在")
	var item: ActItemRef = ActItemRef.new()
	item.item_id = ModuleIo.generate_stable_id()
	while _manifest_has_stable_id(candidate, item.item_id):
		item.item_id = ModuleIo.generate_stable_id()
	item.item_type = item_type
	item.target_id = target_id
	item.display_name = display_name.strip_edges()
	item.text_content = text_content
	item.gm_notes = gm_notes
	act.items.append(item)
	var save_error: int = _save_act_candidate(candidate)
	var saved_item: ActItemRef = null
	if save_error == OK:
		var saved_act: ActRef = _current_manifest.find_act_by_id(act_id)
		if saved_act != null:
			saved_item = saved_act.find_item(item.item_id)
	return _act_item_result(save_error, saved_item, "内容已加入幕" if save_error == OK else "加入幕失败")


func update_act_item(
		act_id: String,
		item_id: String,
		display_name: String,
		text_content: String,
		gm_notes: String
) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = candidate.find_act_by_id(act_id)
	var item: ActItemRef = act.find_item(item_id) if act != null else null
	if item == null:
		return ERR_DOES_NOT_EXIST
	var normalized_name: String = display_name.strip_edges()
	if item.item_type == ActItemRef.ItemType.TEXT and normalized_name == "":
		return ERR_INVALID_PARAMETER
	item.display_name = normalized_name
	item.text_content = text_content
	item.gm_notes = gm_notes
	return _save_act_candidate(candidate)


func remove_act_item(act_id: String, item_id: String) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = candidate.find_act_by_id(act_id)
	if act == null:
		return ERR_DOES_NOT_EXIST
	var remove_index: int = -1
	for index: int in range(act.items.size()):
		if act.items[index].item_id == item_id:
			remove_index = index
			break
	if remove_index < 0:
		return ERR_DOES_NOT_EXIST
	act.items.remove_at(remove_index)
	return _save_act_candidate(candidate)


func move_act_item(act_id: String, item_id: String, target_index: int) -> int:
	if not has_open_module():
		return ERR_UNCONFIGURED
	var candidate: ModuleManifest = _copy_manifest(_current_manifest)
	var act: ActRef = candidate.find_act_by_id(act_id)
	if act == null or target_index < 0 or target_index >= act.items.size():
		return ERR_INVALID_PARAMETER
	var source_index: int = -1
	for index: int in range(act.items.size()):
		if act.items[index].item_id == item_id:
			source_index = index
			break
	if source_index < 0:
		return ERR_DOES_NOT_EXIST
	if source_index == target_index:
		return OK
	var item: ActItemRef = act.items[source_index]
	act.items.remove_at(source_index)
	act.items.insert(target_index, item)
	return _save_act_candidate(candidate)


func backup_current_module() -> Dictionary:
	if not has_open_module():
		return {
			"error": ERR_UNCONFIGURED,
			"backup_id": "",
			"snapshot_path": "",
			"file_count": 0,
			"new_object_count": 0,
			"message": "当前没有打开的模组",
		}
	return ModuleBackupStore.create_backup(_module_dir())


func list_scene_names() -> Array[String]:
	var out: Array[String] = []
	if not has_open_module():
		return out
	for location: LocationRef in _current_manifest.locations:
		out.append(location.display_name)
	return out


func set_current_location(location_name: String) -> void:
	if not has_open_module() and location_name != "":
		return
	if _current_location_name == location_name:
		return
	_current_location_name = location_name
	current_location_changed.emit(location_name)


func switch_location(location_name: String) -> void:
	set_current_location(location_name)


func current_location() -> String:
	return _current_location_name


func current_manifest() -> ModuleManifest:
	return _current_manifest


func current_module_dir() -> String:
	return _module_dir()


func current_location_id() -> String:
	if _current_manifest == null:
		return ""
	var location: LocationRef = _current_manifest.find_location(_current_location_name)
	return location.location_id if location != null else ""


func set_current_location_by_id(location_id: String) -> int:
	if _current_manifest == null:
		return ERR_UNCONFIGURED
	var location: LocationRef = _current_manifest.find_location_by_id(location_id)
	if location == null:
		return ERR_DOES_NOT_EXIST
	set_current_location(location.display_name)
	return OK


func last_manifest_result() -> Dictionary:
	return _last_manifest_result.duplicate(true)


func current_session() -> Playthrough:
	return _current_session


func list_playthroughs() -> Array[Dictionary]:
	if not has_open_module():
		return []
	return ModuleIo.list_playthroughs(_module_dir(), _current_manifest)


func create_playthrough(session_name: String, commit_session: bool = true) -> Dictionary:
	if not has_open_module():
		return _session_result(ERR_UNCONFIGURED, null, "当前没有打开的模组")
	var session_id: String = ModuleIo.generate_stable_id()
	while DirAccess.dir_exists_absolute(
		_module_dir().path_join(ModuleIo.SESSIONS_DIR_NAME).path_join(session_id)
	):
		session_id = ModuleIo.generate_stable_id()
	var session: Playthrough = Playthrough.new()
	session.session_id = session_id
	session.module_id = _current_manifest.module_id
	session.session_name = session_name.strip_edges()
	if session.session_name == "":
		session.session_name = "默认带团"
	session.current_location_id = _current_manifest.start_location_id
	if session.current_location_id == "" and not _current_manifest.locations.is_empty():
		session.current_location_id = _current_manifest.locations[0].location_id
	var save_result: Dictionary = ModuleIo.save_playthrough_recoverable(
		_module_dir(), _current_manifest, session
	)
	if int(save_result.get("error", FAILED)) != OK:
		return save_result
	if commit_session:
		commit_current_session(session)
	return _session_result(OK, session, "已从模组底本开始新会话")


func open_playthrough(session_id: String) -> Dictionary:
	if not has_open_module():
		return _session_result(ERR_UNCONFIGURED, null, "当前没有打开的模组")
	var load_result: Dictionary = ModuleIo.load_playthrough_for_session(
		_module_dir(), _current_manifest, session_id
	)
	if int(load_result.get("error", FAILED)) != OK:
		return load_result
	var session: Playthrough = load_result.get("value") as Playthrough
	if session == null:
		return _session_result(ERR_INVALID_DATA, null, "带团会话数据为空")
	commit_current_session(session)
	return load_result


func commit_current_session(session: Playthrough) -> void:
	_current_session = session
	if _current_session == null:
		session_changed.emit("")
		return
	var location: LocationRef = _current_manifest.find_location_by_id(
		_current_session.current_location_id
	) if _current_manifest != null else null
	if location != null:
		set_current_location(location.display_name)
	session_changed.emit(_current_session.session_id)


func clear_current_session() -> void:
	commit_current_session(null)


func close_module() -> void:
	_close_current_module(true)


func _close_current_module(emit_changed: bool) -> void:
	_current_manifest = null
	_current_session = null
	_current_location_name = ""
	_current_module_name = ""
	session_changed.emit("")
	if emit_changed:
		_emit_module_state_changed()


func _commit_open_state(module_name: String, manifest: ModuleManifest) -> void:
	_current_module_name = module_name
	_current_manifest = manifest
	_current_session = null
	var start_location: LocationRef = manifest.find_location_by_id(manifest.start_location_id)
	if start_location == null and not manifest.locations.is_empty():
		start_location = manifest.locations[0]
	_current_location_name = ""
	if start_location != null:
		_current_location_name = start_location.display_name


func _session_result(error: int, value: Playthrough, message: String) -> Dictionary:
	return {
		"error": error,
		"value": value,
		"recovered_from_backup": false,
		"migrated": false,
		"message": message,
	}


func _emit_module_state_changed() -> void:
	module_changed.emit(_current_module_name)
	scene_list_changed.emit()
	acts_changed.emit()


func _ensure_module_dirs(module_name: String) -> int:
	var module_dir: String = _module_dir_for(module_name)
	var module_error: int = OK
	if not DirAccess.dir_exists_absolute(module_dir):
		module_error = DirAccess.make_dir_recursive_absolute(module_dir)
	if module_error != OK:
		return module_error
	var canonical_dir: String = _canonical_dir_for(module_name)
	if DirAccess.dir_exists_absolute(canonical_dir):
		return OK
	return DirAccess.make_dir_recursive_absolute(canonical_dir)


func _module_dir() -> String:
	if _current_module_name == "":
		return ""
	return _module_dir_for(_current_module_name)


func _module_dir_for(module_name: String) -> String:
	return MODULE_ROOT.path_join(_normalized_module_name(module_name))


func _canonical_dir_for(module_name: String) -> String:
	return _module_dir_for(module_name).path_join("_canonical")


func _legacy_module_dir_for(module_name: String) -> String:
	return LEGACY_MODULE_ROOT.path_join(_normalized_module_name(module_name)).path_join("_canonical")


func _migrate_legacy_scenes(module_name: String) -> void:
	var legacy_dir: String = _legacy_module_dir_for(module_name)
	var target_dir: String = _canonical_dir_for(module_name)
	if not DirAccess.dir_exists_absolute(legacy_dir):
		return
	for file_name: String in _scene_files_at(legacy_dir):
		var source_path: String = legacy_dir.path_join(file_name)
		var target_path: String = target_dir.path_join(file_name)
		if FileAccess.file_exists(target_path):
			continue
		var copy_err: int = DirAccess.copy_absolute(source_path, target_path)
		if copy_err != OK:
			push_warning("ModuleGate: failed to recover legacy scene %s (code=%d)" % [file_name, copy_err])


func _scene_files_at(dir_path: String) -> Array[String]:
	var file_names: Array[String] = []
	if dir_path == "" or not DirAccess.dir_exists_absolute(dir_path):
		return file_names
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.to_lower().ends_with(".scn"):
			file_names.append(file_name)
	file_names.sort()
	return file_names


func _find_location(target_name: String) -> LocationRef:
	if _current_manifest == null:
		return null
	for location: LocationRef in _current_manifest.locations:
		if location.display_name == target_name:
			return location
	return null


func _canonical_source_dir_for(source_path: String) -> String:
	if source_path == "":
		return ""
	if DirAccess.dir_exists_absolute(source_path.path_join("_canonical")):
		return source_path.path_join("_canonical")
	if DirAccess.dir_exists_absolute(source_path):
		return source_path
	return ""


func _module_name_from_import_path(source_path: String) -> String:
	var name: String = source_path.get_file()
	if name == "" or name == "_canonical":
		name = source_path.get_base_dir().get_file()
	return _normalized_module_name(name)


func _unique_module_name(base_name: String) -> String:
	var normalized_base: String = _normalized_module_name(base_name)
	if normalized_base == "":
		normalized_base = "新模组"
	var candidate: String = normalized_base
	var n: int = 1
	while DirAccess.dir_exists_absolute(_module_dir_for(candidate)):
		n += 1
		candidate = normalized_base + str(n)
	return candidate


func _normalized_module_name(module_name: String) -> String:
	var normalized: String = module_name.strip_edges()
	var invalid_chars: Array[String] = ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	for ch: String in invalid_chars:
		normalized = normalized.replace(ch, "_")
	if normalized == "." or normalized == "..":
		return ""
	return normalized


func _new_location_ref(display_name: String) -> LocationRef:
	var ref: LocationRef = LocationRef.new()
	ref.location_id = ModuleIo.generate_stable_id()
	ref.display_name = display_name
	ref.canonical_relpath = "_canonical/" + ref.location_id + ".scn"
	ref.canonical_path = _module_dir().path_join(ref.canonical_relpath)
	ref.available = FileAccess.file_exists(ref.canonical_path)
	return ref


func _find_external_content(
		manifest: ModuleManifest,
		content_id: String
) -> ExternalContentRef:
	if manifest == null:
		return null
	for content: ExternalContentRef in manifest.external_contents:
		if content.content_id == content_id:
			return content
	return null


func _external_content_result(
		error: int,
		content: ExternalContentRef,
		inspection: Dictionary,
		message: String
) -> Dictionary:
	return {
		"error": error,
		"content": content,
		"inspection": inspection.duplicate(true),
		"message": message,
	}


func _copy_manifest(source: ModuleManifest) -> ModuleManifest:
	var copy: ModuleManifest = ModuleManifest.new()
	copy.schema_version = source.schema_version
	copy.module_id = source.module_id
	copy.module_name = source.module_name
	copy.start_location_id = source.start_location_id
	copy.notes = source.notes
	copy.ruleset_id = source.ruleset_id
	for source_location: LocationRef in source.locations:
		var location: LocationRef = LocationRef.new()
		location.location_id = source_location.location_id
		location.display_name = source_location.display_name
		location.canonical_relpath = source_location.canonical_relpath
		location.canonical_path = source_location.canonical_path
		location.available = source_location.available
		copy.locations.append(location)
	for source_content: ExternalContentRef in source.external_contents:
		var content: ExternalContentRef = ExternalContentRef.new()
		content.content_id = source_content.content_id
		content.content_type = source_content.content_type
		content.display_name = source_content.display_name
		content.source_kind = source_content.source_kind
		content.source_path = source_content.source_path
		content.metadata = source_content.metadata.duplicate(true)
		content.resolved_path = source_content.resolved_path
		content.available = source_content.available
		copy.external_contents.append(content)
	for source_act: ActRef in source.acts:
		var act: ActRef = ActRef.new()
		act.act_id = source_act.act_id
		act.display_name = source_act.display_name
		act.gm_notes = source_act.gm_notes
		for source_item: ActItemRef in source_act.items:
			var item: ActItemRef = ActItemRef.new()
			item.item_id = source_item.item_id
			item.item_type = source_item.item_type
			item.target_id = source_item.target_id
			item.display_name = source_item.display_name
			item.text_content = source_item.text_content
			item.gm_notes = source_item.gm_notes
			act.items.append(item)
		copy.acts.append(act)
	copy.sync_legacy_start_location()
	return copy


func _save_act_candidate(candidate: ModuleManifest) -> int:
	var save_result: Dictionary = ModuleIo.save_manifest_recoverable(_module_dir(), candidate)
	var save_error: int = int(save_result.get("error", FAILED))
	if save_error != OK:
		return save_error
	_current_manifest = candidate
	acts_changed.emit()
	return OK


func _target_id_matches_item_type(item_type: ActItemRef.ItemType, target_id: String) -> bool:
	if _current_manifest == null:
		return false
	match item_type:
		ActItemRef.ItemType.MEDIA:
			return _find_external_content(_current_manifest, target_id) != null
		ActItemRef.ItemType.LOCATION:
			return _current_manifest.find_location_by_id(target_id) != null
	return false


func _manifest_has_stable_id(manifest: ModuleManifest, stable_id: String) -> bool:
	if manifest.module_id == stable_id:
		return true
	for location: LocationRef in manifest.locations:
		if location.location_id == stable_id:
			return true
	for content: ExternalContentRef in manifest.external_contents:
		if content.content_id == stable_id:
			return true
	for act: ActRef in manifest.acts:
		if act.act_id == stable_id or act.find_item(stable_id) != null:
			return true
	return false


func _act_result(error: int, act: ActRef, message: String) -> Dictionary:
	return {
		"error": error,
		"act": act,
		"message": message,
	}


func _act_item_result(error: int, item: ActItemRef, message: String) -> Dictionary:
	return {
		"error": error,
		"item": item,
		"message": message,
	}
