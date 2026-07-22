class_name ExternalContentResolver
extends RefCounted


func resolve(content: ExternalContentRef, module_dir: String) -> Dictionary:
	if content == null:
		return _result(ERR_INVALID_PARAMETER, null, "", false, "外部内容引用为空")
	content.resolved_path = ""
	content.available = false
	if not _is_stable_id(content.content_id):
		return _result(ERR_INVALID_DATA, content, "", false, "外部内容缺少稳定标识")
	if content.content_type not in [ExternalContentRef.ContentType.IMAGE, ExternalContentRef.ContentType.VIDEO]:
		return _result(ERR_INVALID_DATA, content, "", false, "外部内容类型无效")
	var resolved_path: String = ""
	match content.source_kind:
		ExternalContentRef.SourceKind.EXTERNAL_FILE:
			resolved_path = _resolve_external_file(content.source_path)
		ExternalContentRef.SourceKind.MODULE_RELATIVE:
			resolved_path = _resolve_module_relative(module_dir, content.source_path)
		_:
			return _result(ERR_INVALID_DATA, content, "", false, "外部内容来源类型无效")
	if resolved_path == "":
		return _result(ERR_INVALID_DATA, content, "", false, "外部内容路径无效或越出模组目录")
	content.resolved_path = resolved_path
	content.available = FileAccess.file_exists(resolved_path)
	if not content.available:
		return _result(ERR_FILE_NOT_FOUND, content, resolved_path, false, "外部内容文件不存在")
	return _result(OK, content, resolved_path, true, "外部内容可用")


func _resolve_external_file(source_path: String) -> String:
	if source_path == "" or source_path.begins_with("res://") or source_path.begins_with("user://"):
		return ""
	if _contains_nul(source_path):
		return ""
	var normalized: String = source_path.replace("\\", "/").simplify_path()
	if not normalized.is_absolute_path():
		return ""
	return normalized


func _resolve_module_relative(module_dir: String, source_path: String) -> String:
	if module_dir == "" or source_path == "" or source_path.is_absolute_path():
		return ""
	if source_path.contains("\\") or source_path.contains(":") or _contains_nul(source_path):
		return ""
	var segments: PackedStringArray = source_path.split("/", false)
	for segment: String in segments:
		if segment == "..":
			return ""
	var simplified_relative: String = source_path.simplify_path()
	if simplified_relative == "." or simplified_relative.begins_with("../"):
		return ""
	var global_root: String = ProjectSettings.globalize_path(module_dir).replace("\\", "/").trim_suffix("/").simplify_path()
	var candidate: String = global_root.path_join(simplified_relative).simplify_path()
	var root_prefix: String = global_root.to_lower() + "/"
	if not candidate.to_lower().begins_with(root_prefix):
		return ""
	return candidate


func _contains_nul(value: String) -> bool:
	for index: int in range(value.length()):
		if value.unicode_at(index) == 0:
			return true
	return false


func _is_stable_id(value: String) -> bool:
	if value.length() != 32:
		return false
	for index: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(index, 1)):
			return false
	return true


func _result(
		error: int,
		content: ExternalContentRef,
		resolved_path: String,
		available: bool,
		message: String
) -> Dictionary:
	return {
		"error": error,
		"content_id": content.content_id if content != null else "",
		"content_type": content.content_type if content != null else -1,
		"resolved_path": resolved_path,
		"available": available,
		"message": message,
	}
