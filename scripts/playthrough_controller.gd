class_name PlaythroughController
extends Node

signal operation_step_recorded(step: String)

var _content_root: Node3D = null
var _scene_session_controller: SceneSessionController = null
var _runtime_dirty: bool = false
var _prepare_save: Callable = Callable()


func configure(
		content_root: Node3D,
		scene_session_controller: SceneSessionController,
		prepare_save: Callable = Callable()
) -> void:
	_content_root = content_root
	_scene_session_controller = scene_session_controller
	_prepare_save = prepare_save


func is_session_active() -> bool:
	return ModuleGate.current_session() != null


func is_runtime_dirty() -> bool:
	return _runtime_dirty


func mark_runtime_dirty() -> void:
	if is_session_active():
		_runtime_dirty = true


func clear_runtime_dirty() -> void:
	_runtime_dirty = false


func start_new_session(session_name: String) -> Dictionary:
	if not _is_configured():
		return _result(ERR_UNCONFIGURED, "带团会话控制器尚未配置")
	var create_result: Dictionary = ModuleGate.create_playthrough(session_name, false)
	if int(create_result.get("error", FAILED)) != OK:
		return create_result
	var session: Playthrough = create_result.get("value") as Playthrough
	if session == null:
		return _result(ERR_INVALID_DATA, "新会话数据为空")
	var load_result: Dictionary = _load_location_root(session, session.current_location_id)
	if int(load_result.get("error", FAILED)) != OK:
		return load_result
	var apply_result: Dictionary = _apply_location_root(
		load_result.get("value") as Node,
		session.current_location_id
	)
	if int(apply_result.get("error", FAILED)) != OK:
		return apply_result
	ModuleGate.commit_current_session(session)
	clear_runtime_dirty()
	return _result(OK, "已从模组底本开始新会话", session)


func open_session(session_id: String) -> Dictionary:
	if not _is_configured():
		return _result(ERR_UNCONFIGURED, "带团会话控制器尚未配置")
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return _result(ERR_UNCONFIGURED, "当前没有打开的模组")
	var load_session_result: Dictionary = ModuleIo.load_playthrough_for_session(
		ModuleGate.current_module_dir(), manifest, session_id
	)
	if int(load_session_result.get("error", FAILED)) != OK:
		return load_session_result
	var session: Playthrough = load_session_result.get("value") as Playthrough
	if session == null:
		return _result(ERR_INVALID_DATA, "带团会话数据为空")
	var load_location_result: Dictionary = _load_location_root(
		session, session.current_location_id
	)
	if int(load_location_result.get("error", FAILED)) != OK:
		return load_location_result
	var apply_result: Dictionary = _apply_location_root(
		load_location_result.get("value") as Node,
		session.current_location_id
	)
	if int(apply_result.get("error", FAILED)) != OK:
		return apply_result
	ModuleGate.commit_current_session(session)
	clear_runtime_dirty()
	return _result(OK, "带团会话已继续", session)


func save_current_session() -> Dictionary:
	if not _is_configured():
		return _result(ERR_UNCONFIGURED, "带团会话控制器尚未配置")
	var session: Playthrough = ModuleGate.current_session()
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if session == null or manifest == null:
		return _result(ERR_UNCONFIGURED, "当前没有正在进行的带团会话")
	if session.current_location_id == "":
		return _result(ERR_INVALID_DATA, "当前会话没有地点")
	if _prepare_save.is_valid():
		_prepare_save.call()
	operation_step_recorded.emit("session_save:begin")
	var session_dir: String = _session_dir(session.session_id)
	var snapshot_result: Dictionary = ModuleIo.save_session_snapshot_recoverable(
		session_dir, session.current_location_id, _content_root
	)
	if int(snapshot_result.get("error", FAILED)) != OK:
		return snapshot_result
	operation_step_recorded.emit("session_save:snapshot")
	var candidate: Playthrough = session.copy_data()
	candidate.location_states[session.current_location_id] = (
		"states/%s.scn" % session.current_location_id
	)
	var index_result: Dictionary = ModuleIo.save_playthrough_recoverable(
		ModuleGate.current_module_dir(), manifest, candidate
	)
	if int(index_result.get("error", FAILED)) != OK:
		return index_result
	operation_step_recorded.emit("session_save:index")
	ModuleGate.commit_current_session(candidate)
	clear_runtime_dirty()
	operation_step_recorded.emit("session_save:end")
	return _result(OK, "当前带团会话已保存", candidate)


func switch_location(target_location_id: String) -> Dictionary:
	var current_session: Playthrough = ModuleGate.current_session()
	if current_session == null:
		return _result(ERR_UNCONFIGURED, "当前没有正在进行的带团会话")
	if target_location_id == current_session.current_location_id:
		return _result(OK, "已经位于目标地点", current_session)
	var save_result: Dictionary = save_current_session()
	if int(save_result.get("error", FAILED)) != OK:
		return save_result
	var saved_session: Playthrough = ModuleGate.current_session()
	var load_result: Dictionary = _load_location_root(saved_session, target_location_id)
	if int(load_result.get("error", FAILED)) != OK:
		return load_result
	var apply_result: Dictionary = _apply_location_root(
		load_result.get("value") as Node, target_location_id
	)
	if int(apply_result.get("error", FAILED)) != OK:
		return apply_result
	var candidate: Playthrough = saved_session.copy_data()
	candidate.current_location_id = target_location_id
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	var index_result: Dictionary = ModuleIo.save_playthrough_recoverable(
		ModuleGate.current_module_dir(), manifest, candidate
	)
	if int(index_result.get("error", FAILED)) != OK:
		var rollback_result: Dictionary = _load_location_root(
			saved_session, saved_session.current_location_id
		)
		if int(rollback_result.get("error", FAILED)) == OK:
			_apply_location_root(
				rollback_result.get("value") as Node,
				saved_session.current_location_id
			)
		return index_result
	ModuleGate.commit_current_session(candidate)
	clear_runtime_dirty()
	return _result(OK, "已切换带团地点", candidate)


func leave_session_for_edit() -> Dictionary:
	var session: Playthrough = ModuleGate.current_session()
	if session == null:
		return _result(ERR_UNCONFIGURED, "当前没有正在进行的带团会话")
	var save_result: Dictionary = save_current_session()
	if int(save_result.get("error", FAILED)) != OK:
		return save_result
	var canonical_result: Dictionary = _load_canonical_root(session.current_location_id)
	if int(canonical_result.get("error", FAILED)) != OK:
		return canonical_result
	var apply_result: Dictionary = _apply_location_root(
		canonical_result.get("value") as Node,
		session.current_location_id
	)
	if int(apply_result.get("error", FAILED)) != OK:
		return apply_result
	ModuleGate.clear_current_session()
	clear_runtime_dirty()
	return _result(OK, "已返回模组底本编辑态")


func _load_location_root(session: Playthrough, location_id: String) -> Dictionary:
	if session == null or location_id == "":
		return _result(ERR_INVALID_PARAMETER, "会话地点参数无效")
	if session.location_states.has(location_id):
		return ModuleIo.load_session_snapshot_recoverable(
			_session_dir(session.session_id), location_id
		)
	return _load_canonical_root(location_id)


func _load_canonical_root(location_id: String) -> Dictionary:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return _result(ERR_UNCONFIGURED, "当前没有打开的模组")
	var location: LocationRef = manifest.find_location_by_id(location_id)
	if location == null:
		return _result(ERR_DOES_NOT_EXIST, "会话引用的地点不存在")
	if location.canonical_path == "" or not FileAccess.file_exists(location.canonical_path):
		return _result(ERR_FILE_NOT_FOUND, "地点底本不存在")
	var loaded: Node = ModuleIo.load_scene_tree(location.canonical_path)
	if loaded == null:
		return _result(ERR_FILE_CORRUPT, "地点底本损坏")
	return _result(OK, "地点底本已加载", loaded)


func _apply_location_root(loaded: Node, location_id: String) -> Dictionary:
	if loaded == null:
		return _result(ERR_INVALID_DATA, "待替换的地点场景为空")
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	var location: LocationRef = null
	if manifest != null:
		location = manifest.find_location_by_id(location_id)
	if location == null:
		loaded.free()
		return _result(ERR_DOES_NOT_EXIST, "待替换的地点不在模组清单中")
	var replace_result: Dictionary = _scene_session_controller.replace_with_loaded_scene(
		loaded, location.display_name, false
	)
	if not bool(replace_result.get("ok", false)):
		if is_instance_valid(loaded):
			loaded.free()
		return _result(ERR_CANT_ACQUIRE_RESOURCE, "无法替换当前地点内容")
	return _result(OK, "地点内容已替换")


func _session_dir(session_id: String) -> String:
	return ModuleGate.current_module_dir().path_join(
		ModuleIo.SESSIONS_DIR_NAME
	).path_join(session_id)


func _is_configured() -> bool:
	return (
		_content_root != null
		and is_instance_valid(_content_root)
		and _scene_session_controller != null
		and is_instance_valid(_scene_session_controller)
	)


func _result(error: int, message: String, value: Variant = null) -> Dictionary:
	return {
		"error": error,
		"value": value,
		"recovered_from_backup": false,
		"migrated": false,
		"message": message,
	}
