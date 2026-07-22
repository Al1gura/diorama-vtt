class_name SceneSessionController
extends Node

const DEFAULT_GROUND_SOURCE: String = "builtin"

var _content_root: Node3D = null
var _current_scene_name: String = ""
var _dirty: bool = false
var _default_ground_tex_base: String = ""
var _default_ground_tile: float = 0.0
var _default_scene_width: float = 100.0
var _default_scene_height: float = 100.0
var _prepare_switch: Callable = Callable()
var _apply_ground_texture: Callable = Callable()
var _apply_scene_size: Callable = Callable()
var _sync_scene_size_inputs: Callable = Callable()
var _migrate_loaded_entities: Callable = Callable()
var _add_scene: Callable = Callable()
var _save_current_scene: Callable = Callable()
var _set_current_location: Callable = Callable()
var _get_current_manifest: Callable = Callable()
var _last_migration_count: int = 0
var _test_snapshot: PackedScene = null
var _test_scene_name: String = ""
var _test_was_dirty: bool = false


func configure(
		content_root: Node3D,
		default_ground_tex_base: String,
		default_ground_tile: float,
		default_scene_width: float,
		default_scene_height: float,
		prepare_switch: Callable,
		apply_ground_texture: Callable,
		apply_scene_size: Callable,
		sync_scene_size_inputs: Callable,
		migrate_loaded_entities: Callable,
		add_scene_callable: Callable = Callable(),
		save_current_scene_callable: Callable = Callable(),
		set_current_location_callable: Callable = Callable(),
		get_current_manifest_callable: Callable = Callable()
) -> void:
	_content_root = content_root
	_default_ground_tex_base = default_ground_tex_base
	_default_ground_tile = default_ground_tile
	_default_scene_width = default_scene_width
	_default_scene_height = default_scene_height
	_prepare_switch = prepare_switch
	_apply_ground_texture = apply_ground_texture
	_apply_scene_size = apply_scene_size
	_sync_scene_size_inputs = sync_scene_size_inputs
	_migrate_loaded_entities = migrate_loaded_entities
	_add_scene = add_scene_callable
	_save_current_scene = save_current_scene_callable
	_set_current_location = set_current_location_callable
	_get_current_manifest = get_current_manifest_callable


func set_current_scene_name(scene_name: String) -> void:
	_current_scene_name = scene_name


func get_current_scene_name() -> String:
	return _current_scene_name


func mark_dirty() -> void:
	_dirty = true


func clear_dirty() -> void:
	_dirty = false


func is_dirty() -> bool:
	return _dirty


func is_test_run_active() -> bool:
	return _test_snapshot != null


func begin_test_run() -> Dictionary:
	if not _has_content_root():
		return {
			"error": ERR_UNCONFIGURED,
			"message": "当前场景内容不可用",
		}
	if is_test_run_active():
		return {
			"error": ERR_ALREADY_IN_USE,
			"message": "当前已经处于测试运行",
		}
	for child: Node in _content_root.get_children():
		_ensure_owner_recursive(child, _content_root)
	var snapshot: PackedScene = PackedScene.new()
	var pack_error: int = snapshot.pack(_content_root)
	if pack_error != OK:
		return {
			"error": pack_error,
			"message": "无法建立测试前内存快照",
		}
	var validation_root: Node = snapshot.instantiate()
	if validation_root == null:
		return {
			"error": ERR_CANT_CREATE,
			"message": "测试前内存快照无法实例化",
		}
	validation_root.free()
	_test_snapshot = snapshot
	_test_scene_name = _current_scene_name
	_test_was_dirty = _dirty
	return {
		"error": OK,
		"message": "已进入测试",
	}


func end_test_run() -> Dictionary:
	if not is_test_run_active():
		return {
			"error": ERR_UNCONFIGURED,
			"message": "当前没有正在进行的测试",
		}
	var restored_root: Node = _test_snapshot.instantiate()
	if restored_root == null:
		return {
			"error": ERR_CANT_CREATE,
			"message": "测试前场景无法恢复",
		}
	var restored_scene_name: String = _test_scene_name
	var restored_dirty: bool = _test_was_dirty
	var replace_result: Dictionary = replace_with_loaded_scene(
		restored_root,
		restored_scene_name,
		false
	)
	if not bool(replace_result.get("ok", false)):
		if is_instance_valid(restored_root):
			restored_root.free()
		return {
			"error": ERR_CANT_CREATE,
			"message": "测试结束后无法恢复场景",
		}
	_test_snapshot = null
	_test_scene_name = ""
	_test_was_dirty = false
	if restored_dirty:
		mark_dirty()
	return {
		"error": OK,
		"message": "测试已结束",
	}


func create_scene() -> String:
	if not _add_scene.is_valid():
		return ""
	var result: Variant = _add_scene.call()
	return String(result)


func save_current_scene() -> int:
	if _current_scene_name == "" or not _has_content_root():
		return ERR_INVALID_PARAMETER
	if not _save_current_scene.is_valid():
		return ERR_UNCONFIGURED
	var result: Variant = _save_current_scene.call(_current_scene_name, _content_root)
	var err: int = int(result)
	if err == OK:
		clear_dirty()
	return err


func apply_default_scene() -> Dictionary:
	if not _has_content_root():
		return {
			"ok": false,
			"scene_name": _current_scene_name,
			"loaded": false,
			"used_default": false,
			"error": "content_root_invalid",
		}
	_call_if_valid(_prepare_switch)
	_clear_content_root()
	_apply_default_scene_state()
	clear_dirty()
	return {
		"ok": true,
		"scene_name": _current_scene_name,
		"loaded": false,
		"used_default": true,
		"error": "",
	}


func switch_to_scene(target_name: String) -> Dictionary:
	_last_migration_count = 0
	if target_name == "":
		return {
			"ok": false,
			"scene_name": _current_scene_name,
			"loaded": false,
			"used_default": false,
			"error": "empty_scene_name",
		}
	if not _has_content_root():
		return {
			"ok": false,
			"scene_name": _current_scene_name,
			"loaded": false,
			"used_default": false,
			"error": "content_root_invalid",
		}

	_call_if_valid(_prepare_switch)
	_clear_content_root()
	var loaded_from_disk: bool = false
	var used_default: bool = false
	var ref: LocationRef = _find_location(target_name)
	if ref != null and ref.canonical_path != "" and ResourceLoader.exists(ref.canonical_path):
		var loaded: Node = ModuleIo.load_scene_tree(ref.canonical_path)
		if loaded != null and is_instance_valid(loaded):
			_apply_loaded_scene_state(loaded)
			loaded_from_disk = true
		else:
			_apply_default_scene_state()
			used_default = true
	else:
		_apply_default_scene_state()
		used_default = true

	_current_scene_name = target_name
	if _set_current_location.is_valid():
		_set_current_location.call(target_name)
	clear_dirty()
	if _last_migration_count > 0:
		mark_dirty()
	return {
		"ok": true,
		"scene_name": _current_scene_name,
		"loaded": loaded_from_disk,
		"used_default": used_default,
		"migrated_count": _last_migration_count,
		"error": "",
	}


## 接收调用方已完成读取和实例化校验的场景。失败时不清理当前内容，也不回退默认场景。
func replace_with_loaded_scene(
		loaded: Node,
		target_name: String,
		update_module_location: bool = true
) -> Dictionary:
	_last_migration_count = 0
	if target_name == "":
		return {
			"ok": false,
			"scene_name": _current_scene_name,
			"loaded": false,
			"used_default": false,
			"error": "empty_scene_name",
		}
	if loaded == null or not is_instance_valid(loaded):
		return {
			"ok": false,
			"scene_name": _current_scene_name,
			"loaded": false,
			"used_default": false,
			"error": "loaded_scene_invalid",
		}
	if not _has_content_root():
		return {
			"ok": false,
			"scene_name": _current_scene_name,
			"loaded": false,
			"used_default": false,
			"error": "content_root_invalid",
		}

	_call_if_valid(_prepare_switch)
	_clear_content_root()
	_apply_loaded_scene_state(loaded)
	_current_scene_name = target_name
	if update_module_location and _set_current_location.is_valid():
		_set_current_location.call(target_name)
	clear_dirty()
	if _last_migration_count > 0:
		mark_dirty()
	return {
		"ok": true,
		"scene_name": _current_scene_name,
		"loaded": true,
		"used_default": false,
		"migrated_count": _last_migration_count,
		"error": "",
	}


func _has_content_root() -> bool:
	return _content_root != null and is_instance_valid(_content_root)


func _call_if_valid(callable: Callable) -> void:
	if callable.is_valid():
		callable.call()


func _clear_content_root() -> void:
	if not _has_content_root():
		return
	for child: Node in _content_root.get_children():
		_content_root.remove_child(child)
		child.queue_free()


func _apply_default_scene_state() -> void:
	_set_scene_props(
		_default_ground_tex_base,
		DEFAULT_GROUND_SOURCE,
		_default_ground_tile,
		_default_scene_width,
		_default_scene_height
	)
	_apply_scene_visuals(
		_default_ground_tex_base,
		_default_ground_tile,
		DEFAULT_GROUND_SOURCE,
		_default_scene_width,
		_default_scene_height
	)


func _apply_loaded_scene_state(loaded: Node) -> void:
	var loaded_base: String = ""
	var loaded_source: String = ""
	var loaded_tile: float = 2.0
	var loaded_width: float = _default_scene_width
	var loaded_height: float = _default_scene_height
	if loaded.get_script() != null and loaded.get("ground_tex_base") != null:
		loaded_base = str(loaded.get("ground_tex_base"))
		if loaded.get("ground_tex_source") != null:
			loaded_source = str(loaded.get("ground_tex_source"))
		loaded_tile = float(loaded.get("ground_tile"))
		if loaded.get("scene_width") != null:
			loaded_width = float(loaded.get("scene_width"))
			loaded_height = float(loaded.get("scene_height"))
		elif loaded.get("scene_size") != null:
			loaded_width = float(loaded.get("scene_size"))
			loaded_height = float(loaded.get("scene_size"))

	_set_scene_props(loaded_base, loaded_source, loaded_tile, loaded_width, loaded_height)
	for child: Node in loaded.get_children():
		_clear_owner_recursive(child)
		loaded.remove_child(child)
		_content_root.add_child(child)
		_ensure_owner_recursive(child, _content_root)
	if _migrate_loaded_entities.is_valid():
		var migration_result: Variant = _migrate_loaded_entities.call()
		if migration_result is int:
			_last_migration_count = int(migration_result)
	loaded.queue_free()
	_apply_scene_visuals(loaded_base, loaded_tile, loaded_source, loaded_width, loaded_height)


func _set_scene_props(base: String, source: String, tile: float, width: float, height: float) -> void:
	if not _has_content_root() or _content_root.get_script() == null:
		return
	_content_root.set("ground_tex_base", base)
	_content_root.set("ground_tex_source", source)
	_content_root.set("ground_tile", tile)
	_content_root.set("scene_width", width)
	_content_root.set("scene_height", height)


func _apply_scene_visuals(base: String, tile: float, source: String, width: float, height: float) -> void:
	if _apply_ground_texture.is_valid():
		_apply_ground_texture.call(base, tile, source)
	if _apply_scene_size.is_valid():
		_apply_scene_size.call(width, height)
	if _sync_scene_size_inputs.is_valid():
		_sync_scene_size_inputs.call(width, height)


func _find_location(target_name: String) -> LocationRef:
	if not _get_current_manifest.is_valid():
		return null
	var manifest_value: Variant = _get_current_manifest.call()
	var manifest: ModuleManifest = manifest_value as ModuleManifest
	if manifest == null:
		return null
	for location: LocationRef in manifest.locations:
		if location.display_name == target_name:
			return location
	return null


func _ensure_owner_recursive(node: Node, owner_node: Node) -> void:
	if node.has_meta("gvtt_runtime_only"):
		if node.owner != null:
			node.set_owner(null)
		return
	node.set_owner(owner_node)
	for child: Node in node.get_children():
		_ensure_owner_recursive(child, owner_node)


func _clear_owner_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		_clear_owner_recursive(child)
	if node.owner != null:
		node.set_owner(null)
