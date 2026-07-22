class_name P3_4FixtureFactory
extends RefCounted

const MODULE_NAME: String = "__p3_4_lifecycle_fixture__"
const SOURCE_DIR: String = "res://tests/fixtures/p3_4"
const SOURCE_IMAGE_PATH: String = SOURCE_DIR + "/quadrants_640x480.png"
const SOURCE_VIDEO_PATH: String = SOURCE_DIR + "/motion_audio_320x180.ogv"
const IMAGE_RELATIVE_PATH: String = "content/quadrants_640x480.png"
const VIDEO_RELATIVE_PATH: String = "content/motion_audio_320x180.ogv"
const CORRUPT_IMAGE_RELATIVE_PATH: String = "content/corrupt_image.png"
const FAKE_VIDEO_RELATIVE_PATH: String = "content/fake_video.ogv"
const MISSING_IMAGE_RELATIVE_PATH: String = "content/missing_image.png"
const MISSING_VIDEO_RELATIVE_PATH: String = "content/missing_video.ogv"
const IMAGE_ID: String = "41000000000000000000000000000001"
const VIDEO_ID: String = "41000000000000000000000000000002"
const MISSING_IMAGE_ID: String = "41000000000000000000000000000003"
const CORRUPT_IMAGE_ID: String = "41000000000000000000000000000004"
const MISSING_VIDEO_ID: String = "41000000000000000000000000000005"
const FAKE_VIDEO_ID: String = "41000000000000000000000000000006"
const ESCAPE_ID: String = "41000000000000000000000000000007"


static func create() -> Dictionary:
	cleanup()
	if not FileAccess.file_exists(SOURCE_IMAGE_PATH) or not FileAccess.file_exists(SOURCE_VIDEO_PATH):
		return _result(ERR_FILE_NOT_FOUND, "P3.4 固定媒体夹具尚未生成")
	var create_error: int = ModuleGate.create_module(MODULE_NAME)
	if create_error != OK:
		return _result(create_error, "隔离测试模组创建失败")
	var module_dir: String = ModuleGate.current_module_dir()
	var content_dir: String = module_dir.path_join("content")
	var invalid_dir: String = module_dir.path_join("invalid_cases")
	var directory_error: int = DirAccess.make_dir_recursive_absolute(content_dir)
	if directory_error == OK:
		directory_error = DirAccess.make_dir_recursive_absolute(invalid_dir)
	if directory_error != OK:
		return _result(directory_error, "隔离测试模组内容目录创建失败")
	var copy_error: int = _copy_fixture(SOURCE_IMAGE_PATH, module_dir.path_join(IMAGE_RELATIVE_PATH))
	if copy_error == OK:
		copy_error = _copy_fixture(SOURCE_VIDEO_PATH, module_dir.path_join(VIDEO_RELATIVE_PATH))
	if copy_error != OK:
		return _result(copy_error, "固定媒体夹具复制失败")
	var corrupt_error: int = _write_text(
		module_dir.path_join(CORRUPT_IMAGE_RELATIVE_PATH),
		"not a png image"
	)
	if corrupt_error == OK:
		corrupt_error = _write_fake_ogv(module_dir.path_join(FAKE_VIDEO_RELATIVE_PATH))
	if corrupt_error != OK:
		return _result(corrupt_error, "损坏媒体夹具写入失败")

	var first_name: String = ModuleGate.add_scene()
	var second_name: String = ModuleGate.add_scene()
	if first_name == "" or second_name == "":
		return _result(ERR_CANT_CREATE, "测试地点创建失败")
	var first_root: Node3D = _build_location_root("FixtureLocationA", Vector3(1.0, 0.0, 2.0))
	var second_root: Node3D = _build_location_root("FixtureLocationB", Vector3(5.0, 0.0, 7.0))
	var first_save_error: int = ModuleGate.save_current_scene(first_name, first_root)
	var second_save_error: int = ModuleGate.save_current_scene(second_name, second_root)
	first_root.free()
	second_root.free()
	if first_save_error != OK or second_save_error != OK:
		return _result(ERR_CANT_CREATE, "测试地点底本保存失败")

	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null or manifest.locations.size() != 2:
		return _result(ERR_INVALID_DATA, "测试模组地点清单无效")
	manifest.external_contents.clear()
	manifest.external_contents.append(_content_ref(
		IMAGE_ID, ExternalContentRef.ContentType.IMAGE, "四象限测试图片", IMAGE_RELATIVE_PATH
	))
	manifest.external_contents.append(_content_ref(
		VIDEO_ID, ExternalContentRef.ContentType.VIDEO, "运动与测试音 OGV", VIDEO_RELATIVE_PATH
	))
	manifest.external_contents.append(_content_ref(
		MISSING_IMAGE_ID, ExternalContentRef.ContentType.IMAGE, "缺失图片", MISSING_IMAGE_RELATIVE_PATH
	))
	manifest.external_contents.append(_content_ref(
		CORRUPT_IMAGE_ID, ExternalContentRef.ContentType.IMAGE, "损坏图片", CORRUPT_IMAGE_RELATIVE_PATH
	))
	manifest.external_contents.append(_content_ref(
		MISSING_VIDEO_ID, ExternalContentRef.ContentType.VIDEO, "缺失视频", MISSING_VIDEO_RELATIVE_PATH
	))
	manifest.external_contents.append(_content_ref(
		FAKE_VIDEO_ID, ExternalContentRef.ContentType.VIDEO, "伪 OGV", FAKE_VIDEO_RELATIVE_PATH
	))
	var manifest_error: int = ModuleGate.save_current_manifest()
	if manifest_error != OK:
		return _result(manifest_error, "测试模组清单保存失败")
	var invalid_error: int = _write_invalid_manifest_copies(manifest, invalid_dir)
	if invalid_error != OK:
		return _result(invalid_error, "异常清单副本写入失败")

	var playthrough_result: Dictionary = ModuleGate.create_playthrough("P3.4 可恢复带团")
	var playthrough_error: int = int(playthrough_result.get("error", FAILED))
	var session: Playthrough = playthrough_result.get("value") as Playthrough
	if playthrough_error != OK or session == null:
		return _result(playthrough_error, "测试带团会话创建失败")
	var first_location_id: String = manifest.locations[0].location_id
	var session_dir: String = module_dir.path_join(ModuleIo.SESSIONS_DIR_NAME).path_join(session.session_id)
	var changed_root: Node3D = _build_location_root("RecoveredSessionLocation", Vector3(9.0, 0.0, 4.0))
	changed_root.set_meta("p3_4_recoverable_change", "wall_open")
	var snapshot_result: Dictionary = ModuleIo.save_session_snapshot_recoverable(
		session_dir,
		first_location_id,
		changed_root
	)
	changed_root.free()
	if int(snapshot_result.get("error", FAILED)) != OK:
		return _result(int(snapshot_result.get("error", FAILED)), "可恢复带团变化保存失败")
	var saved_session: Playthrough = session.copy_data()
	saved_session.current_location_id = first_location_id
	saved_session.location_states[first_location_id] = "states/%s.scn" % first_location_id
	saved_session.notes = "P3.4 recoverable change: wall_open"
	var session_save_result: Dictionary = ModuleIo.save_playthrough_recoverable(
		module_dir,
		manifest,
		saved_session
	)
	if int(session_save_result.get("error", FAILED)) != OK:
		return _result(int(session_save_result.get("error", FAILED)), "测试带团索引保存失败")
	ModuleGate.commit_current_session(saved_session)
	return {
		"error": OK,
		"message": "P3.4 隔离测试模组已创建",
		"module_dir": module_dir,
		"first_location_id": first_location_id,
		"second_location_id": manifest.locations[1].location_id,
		"session_id": saved_session.session_id,
		"image_ref": manifest.external_contents[0],
		"video_ref": manifest.external_contents[1],
		"missing_image_ref": manifest.external_contents[2],
		"corrupt_image_ref": manifest.external_contents[3],
		"missing_video_ref": manifest.external_contents[4],
		"fake_video_ref": manifest.external_contents[5],
		"escape_ref": _content_ref(
			ESCAPE_ID,
			ExternalContentRef.ContentType.IMAGE,
			"路径逃逸",
			"../outside.png"
		),
	}


static func cleanup() -> void:
	if ModuleGate.current_module_name() == MODULE_NAME:
		ModuleGate.close_module()
	_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(MODULE_NAME))


static func _content_ref(
		content_id: String,
		content_type: ExternalContentRef.ContentType,
		display_name: String,
		source_path: String
) -> ExternalContentRef:
	var content: ExternalContentRef = ExternalContentRef.new()
	content.content_id = content_id
	content.content_type = content_type
	content.display_name = display_name
	content.source_kind = ExternalContentRef.SourceKind.MODULE_RELATIVE
	content.source_path = source_path
	return content


static func _build_location_root(root_name: String, marker_position: Vector3) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = root_name
	var marker: Node3D = Node3D.new()
	marker.name = "LifecycleMarker"
	marker.position = marker_position
	root.add_child(marker)
	return root


static func _copy_fixture(source_path: String, target_path: String) -> int:
	return DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(target_path)
	)


static func _write_fake_ogv(path: String) -> int:
	var bytes: PackedByteArray = PackedByteArray([79, 103, 103, 83, 0, 2, 0, 0, 0, 0, 0, 0])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	var error: int = file.get_error()
	file.close()
	return error


static func _write_invalid_manifest_copies(
		manifest: ModuleManifest,
		invalid_dir: String
) -> int:
	var escape_data: Dictionary = manifest.to_json_dict().duplicate(true)
	var escape_entries: Array = escape_data.get("external_contents", []) as Array
	escape_entries.append({
		"content_id": ESCAPE_ID,
		"content_type": "image",
		"display_name": "路径逃逸",
		"source_kind": "module_relative",
		"source_path": "../outside.png",
		"metadata": {},
	})
	escape_data["external_contents"] = escape_entries
	var escape_error: int = _write_text(
		invalid_dir.path_join("path_escape_manifest.json"),
		JSON.stringify(escape_data, "\t", true)
	)
	if escape_error != OK:
		return escape_error
	var future_data: Dictionary = manifest.to_json_dict().duplicate(true)
	future_data["schema_version"] = ModuleManifest.SCHEMA_VERSION + 100
	return _write_text(
		invalid_dir.path_join("future_schema_manifest.json"),
		JSON.stringify(future_data, "\t", true)
	)


static func _write_text(path: String, content: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored: bool = file.store_string(content)
	var error: int = file.get_error()
	file.close()
	return error if stored else ERR_CANT_CREATE


static func _remove_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory_name: String in DirAccess.get_directories_at(path):
		_remove_dir_recursive(path.path_join(directory_name))
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


static func _result(error: int, message: String) -> Dictionary:
	return {
		"error": error,
		"message": message,
	}
