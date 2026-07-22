extends Node

const MODULE_NAME: String = "__p4_1_media_registration__"
const EXTERNAL_DIR: String = "user://p4_1_external_media"
const SOURCE_IMAGE: String = "res://tests/fixtures/p3_4/quadrants_640x480.png"
const SOURCE_VIDEO: String = "res://tests/fixtures/p3_4/motion_audio_320x180.ogv"
const SOURCE_MP4: String = "res://build/p45_acceptance/vlc_fixture.mp4"
const MEDIA_BYTE_MARKER: String = "P4_MEDIA_BYTE_MARKER_7f6c4d2a"

var _assertion_count: int = 0
var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_cleanup()
	_test_registration_lifecycle()
	_cleanup()
	var result: Dictionary = {
		"assertions": _assertion_count,
		"failed": _failures.size(),
		"failures": _failures,
	}
	print("P4_1_MEDIA_REGISTRATION_RESULT " + JSON.stringify(result))
	if not _failures.is_empty():
		push_error("P4_1_MEDIA_REGISTRATION_FAILURES " + JSON.stringify(_failures))
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_registration_lifecycle() -> void:
	_check(ModuleGate.create_module(MODULE_NAME) == OK, "Could not create isolated P4.1 module")
	if not ModuleGate.has_open_module():
		return
	var external_global_dir: String = ProjectSettings.globalize_path(EXTERNAL_DIR)
	_check(
		DirAccess.make_dir_recursive_absolute(external_global_dir) == OK,
		"Could not create isolated external media directory"
	)
	var image_path: String = external_global_dir.path_join("playable_image.png")
	var video_path: String = external_global_dir.path_join("playable_video.ogv")
	var mp4_path: String = external_global_dir.path_join("playable_video.mp4")
	var corrupt_mp4_path: String = external_global_dir.path_join("corrupt_video.mp4")
	var missing_path: String = external_global_dir.path_join("becomes_missing.png")
	var corrupt_image_path: String = external_global_dir.path_join("corrupt_image.png")
	var fake_video_path: String = external_global_dir.path_join("fake_video.ogv")
	var unsupported_video_path: String = external_global_dir.path_join("future_video.flv")
	_check(_copy_fixture(SOURCE_IMAGE, image_path) == OK, "Playable image fixture copy failed")
	_check(_copy_fixture(SOURCE_VIDEO, video_path) == OK, "Playable video fixture copy failed")
	_check(_copy_fixture(SOURCE_MP4, mp4_path) == OK, "Playable MP4 fixture copy failed")
	_check(_copy_fixture(SOURCE_IMAGE, missing_path) == OK, "Missing-state fixture copy failed")
	_check(_write_text(corrupt_image_path, MEDIA_BYTE_MARKER) == OK, "Corrupt image fixture write failed")
	_check(_write_fake_ogv(fake_video_path) == OK, "Fake OGV fixture write failed")
	_check(_write_text(corrupt_mp4_path, MEDIA_BYTE_MARKER) == OK, "Corrupt MP4 fixture write failed")
	_check(_write_text(unsupported_video_path, MEDIA_BYTE_MARKER) == OK, "Unsupported video fixture write failed")

	var image_result: Dictionary = ModuleGate.register_external_content(
		image_path, ExternalContentRef.ContentType.IMAGE
	)
	_check(int(image_result.get("error", FAILED)) == OK, "Playable image was not registered")
	_check(_status_from_result(image_result) == MediaRegistry.STATUS_PLAYABLE, "Image status is not playable")
	var image_ref: ExternalContentRef = image_result.get("content") as ExternalContentRef
	_check(image_ref != null and image_ref.metadata.get("natural_width", 0) == 640, "Image width metadata is wrong")
	_check(image_ref != null and image_ref.metadata.get("natural_height", 0) == 480, "Image height metadata is wrong")

	var video_result: Dictionary = ModuleGate.register_external_content(
		video_path, ExternalContentRef.ContentType.VIDEO
	)
	_check(int(video_result.get("error", FAILED)) == OK, "Playable OGV was not registered")
	_check(_status_from_result(video_result) == MediaRegistry.STATUS_PLAYABLE, "OGV status is not playable")
	var video_ref: ExternalContentRef = video_result.get("content") as ExternalContentRef
	var natural_width: int = int(video_ref.metadata.get("natural_width", 0)) if video_ref != null else 0
	var natural_height: int = int(video_ref.metadata.get("natural_height", 0)) if video_ref != null else 0
	_check(natural_width == 640, "OGV width metadata is wrong: %d" % natural_width)
	_check(natural_height == 360, "OGV height metadata is wrong: %d" % natural_height)

	var mp4_result: Dictionary = ModuleGate.register_external_content(
		mp4_path, ExternalContentRef.ContentType.VIDEO
	)
	_check(int(mp4_result.get("error", FAILED)) == OK, "Playable MP4 was not registered")
	_check(_status_from_result(mp4_result) == MediaRegistry.STATUS_PLAYABLE, "MP4 status is not playable")
	var mp4_ref: ExternalContentRef = mp4_result.get("content") as ExternalContentRef
	_check(
		mp4_ref != null and float(mp4_ref.metadata.get("duration_seconds", 0.0)) > 0.0,
		"MP4 duration metadata is missing"
	)

	var corrupt_mp4_result: Dictionary = ModuleGate.register_external_content(
		corrupt_mp4_path, ExternalContentRef.ContentType.VIDEO
	)
	_check(int(corrupt_mp4_result.get("error", FAILED)) == OK, "Corrupt MP4 reference was not retained")
	_check(
		_status_from_result(corrupt_mp4_result) == MediaRegistry.STATUS_DAMAGED,
		"Corrupt MP4 status is not damaged"
	)

	var corrupt_result: Dictionary = ModuleGate.register_external_content(
		corrupt_image_path, ExternalContentRef.ContentType.IMAGE
	)
	_check(int(corrupt_result.get("error", FAILED)) == OK, "Corrupt image reference was not retained")
	_check(_status_from_result(corrupt_result) == MediaRegistry.STATUS_DAMAGED, "Corrupt image status is not damaged")
	var fake_video_result: Dictionary = ModuleGate.register_external_content(
		fake_video_path, ExternalContentRef.ContentType.VIDEO
	)
	_check(int(fake_video_result.get("error", FAILED)) == OK, "Fake OGV reference was not retained")
	_check(_status_from_result(fake_video_result) == MediaRegistry.STATUS_DAMAGED, "Fake OGV status is not damaged")
	var unsupported_result: Dictionary = ModuleGate.register_external_content(
		unsupported_video_path, ExternalContentRef.ContentType.VIDEO
	)
	_check(int(unsupported_result.get("error", FAILED)) == OK, "Unsupported video reference was not retained")
	_check(
		_status_from_result(unsupported_result) == MediaRegistry.STATUS_UNSUPPORTED,
		"FLV status is not unsupported"
	)

	var missing_result: Dictionary = ModuleGate.register_external_content(
		missing_path, ExternalContentRef.ContentType.IMAGE
	)
	_check(int(missing_result.get("error", FAILED)) == OK, "Future-missing image was not registered")
	var missing_ref: ExternalContentRef = missing_result.get("content") as ExternalContentRef
	_check(DirAccess.remove_absolute(missing_path) == OK, "Could not remove missing-state fixture")
	var missing_inspection: Dictionary = MediaRegistry.inspect(missing_ref, ModuleGate.current_module_dir())
	_check(
		StringName(String(missing_inspection.get("status", ""))) == MediaRegistry.STATUS_MISSING,
		"Deleted external file was not marked missing"
	)

	var original_image_id: String = image_ref.content_id if image_ref != null else ""
	var original_image_path: String = image_ref.source_path if image_ref != null else ""
	_check(ModuleGate.rename_external_content(original_image_id, "战场概览") == OK, "Media rename failed")
	var renamed_ref: ExternalContentRef = _find_content(original_image_id)
	_check(renamed_ref != null and renamed_ref.display_name == "战场概览", "Renamed display name was not stored")
	_check(renamed_ref != null and renamed_ref.source_path == original_image_path, "Rename changed the source path")

	var escape_ref: ExternalContentRef = ExternalContentRef.new()
	escape_ref.content_id = "4a000000000000000000000000000001"
	escape_ref.content_type = ExternalContentRef.ContentType.IMAGE
	escape_ref.display_name = "逃逸"
	escape_ref.source_kind = ExternalContentRef.SourceKind.MODULE_RELATIVE
	escape_ref.source_path = "../outside.png"
	var escape_result: Dictionary = MediaRegistry.inspect(escape_ref, ModuleGate.current_module_dir())
	_check(int(escape_result.get("error", OK)) != OK, "Module-relative path escape was accepted")
	_check(String(escape_result.get("resolved_path", "")) == "", "Escaping path resolved outside module")

	var unsupported_ref: ExternalContentRef = unsupported_result.get("content") as ExternalContentRef
	var unsupported_id: String = unsupported_ref.content_id if unsupported_ref != null else ""
	_check(ModuleGate.remove_external_content(unsupported_id) == OK, "Media registration delete failed")
	_check(_find_content(unsupported_id) == null, "Deleted media reference remains in manifest")
	_check(FileAccess.file_exists(unsupported_video_path), "Deleting registration deleted the source file")

	var scene_name: String = ModuleGate.add_scene()
	var scene_root: Node3D = Node3D.new()
	scene_root.name = "P4MediaByteBoundary"
	_check(scene_name != "", "Could not add scene for byte-boundary test")
	_check(ModuleGate.save_current_scene(scene_name, scene_root) == OK, "Could not save byte-boundary scene")
	scene_root.free()
	var playthrough_result: Dictionary = ModuleGate.create_playthrough("P4.1 字节边界")
	_check(int(playthrough_result.get("error", FAILED)) == OK, "Could not save byte-boundary session")
	var playthrough: Playthrough = playthrough_result.get("value") as Playthrough
	var module_dir: String = ModuleGate.current_module_dir()
	var manifest_path: String = module_dir.path_join("manifest.json")
	var scene_path: String = ModuleGate.current_manifest().locations[0].canonical_path
	var session_path: String = module_dir.path_join("sessions").path_join(
		playthrough.session_id if playthrough != null else ""
	).path_join("session.json")
	_check(not _file_contains_marker(manifest_path), "manifest.json contains media bytes")
	_check(not _file_contains_marker(session_path), "session.json contains media bytes")
	_check(not _file_contains_marker(scene_path), ".scn contains media bytes")

	ModuleGate.close_module()
	_check(ModuleGate.open_module(MODULE_NAME) == OK, "Module manifest could not be read back")
	var reopened_image: ExternalContentRef = _find_content(original_image_id)
	_check(reopened_image != null and reopened_image.display_name == "战场概览", "Manifest readback lost media rename")
	_check(reopened_image != null and reopened_image.source_path == original_image_path, "Manifest readback changed media path")
	_check(
		ModuleGate.current_manifest() != null and ModuleGate.current_manifest().external_contents.size() == 7,
		"Manifest readback lost or added media references"
	)


func _status_from_result(result: Dictionary) -> StringName:
	var inspection: Dictionary = result.get("inspection", {}) as Dictionary
	return StringName(String(inspection.get("status", "")))


func _find_content(content_id: String) -> ExternalContentRef:
	var manifest: ModuleManifest = ModuleGate.current_manifest()
	if manifest == null:
		return null
	for content: ExternalContentRef in manifest.external_contents:
		if content.content_id == content_id:
			return content
	return null


func _copy_fixture(source_path: String, target_path: String) -> int:
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), target_path)


func _write_text(path: String, value: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(value)
	var error: int = file.get_error()
	file.close()
	return error


func _write_fake_ogv(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(PackedByteArray([79, 103, 103, 83, 0, 2, 0, 0, 0, 0, 0, 0]))
	var error: int = file.get_error()
	file.close()
	return error


func _file_contains_marker(path: String) -> bool:
	if not FileAccess.file_exists(path):
		_check(false, "Expected storage file is missing: " + path)
		return false
	return FileAccess.get_file_as_bytes(path).get_string_from_utf8().contains(MEDIA_BYTE_MARKER)


func _cleanup() -> void:
	if ModuleGate.has_open_module():
		ModuleGate.close_module()
	_remove_dir_recursive(ModuleGate.MODULE_ROOT.path_join(MODULE_NAME))
	_remove_dir_recursive(ProjectSettings.globalize_path(EXTERNAL_DIR))


func _remove_dir_recursive(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
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
