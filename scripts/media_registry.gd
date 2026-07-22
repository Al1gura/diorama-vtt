class_name MediaRegistry
extends RefCounted

const STATUS_PLAYABLE: StringName = &"playable"
const STATUS_MISSING: StringName = &"missing"
const STATUS_DAMAGED: StringName = &"damaged"
const STATUS_UNSUPPORTED: StringName = &"unsupported"

const IMAGE_EXTENSIONS: Array[String] = ["bmp", "jpeg", "jpg", "png", "svg", "tga", "webp"]
const VIDEO_EXTENSIONS: Array[String] = ["avi", "m4v", "mkv", "mov", "mp4", "ogv", "webm"]
const NATIVE_VIDEO_EXTENSIONS: Array[String] = ["m4v", "mov", "mp4"]
const NATIVE_VIDEO_BACKEND_SCRIPT: Script = preload("res://scripts/native_video_playback_backend.gd")


static func inspect(content: ExternalContentRef, module_dir: String) -> Dictionary:
	var resolver: ExternalContentResolver = ExternalContentResolver.new()
	var resolve_result: Dictionary = resolver.resolve(content, module_dir)
	var resolve_error: int = int(resolve_result.get("error", FAILED))
	if resolve_error == ERR_FILE_NOT_FOUND:
		return _result(
			STATUS_MISSING,
			ERR_FILE_NOT_FOUND,
			String(resolve_result.get("resolved_path", "")),
			"文件不存在",
			content.metadata if content != null else {}
		)
	if resolve_error != OK:
		return _result(
			STATUS_DAMAGED,
			resolve_error,
			String(resolve_result.get("resolved_path", "")),
			String(resolve_result.get("message", "引用无效")),
			content.metadata if content != null else {}
		)

	var resolved_path: String = String(resolve_result.get("resolved_path", ""))
	var extension: String = resolved_path.get_extension().to_lower()
	var metadata: Dictionary = content.metadata.duplicate(true)
	metadata["extension"] = extension
	match content.content_type:
		ExternalContentRef.ContentType.IMAGE:
			return _inspect_image(resolved_path, extension, metadata)
		ExternalContentRef.ContentType.VIDEO:
			return _inspect_video(resolved_path, extension, metadata)
	return _result(STATUS_DAMAGED, ERR_INVALID_DATA, resolved_path, "媒体类型无效", metadata)


static func status_text(status: StringName) -> String:
	match status:
		STATUS_PLAYABLE:
			return "可播放"
		STATUS_MISSING:
			return "缺失"
		STATUS_DAMAGED:
			return "损坏"
		STATUS_UNSUPPORTED:
			return "暂不支持"
	return "未知"


static func content_type_text(content_type: ExternalContentRef.ContentType) -> String:
	return "图片" if content_type == ExternalContentRef.ContentType.IMAGE else "视频"


static func source_text(content: ExternalContentRef) -> String:
	if content.source_kind == ExternalContentRef.SourceKind.MODULE_RELATIVE:
		return "模组内 · " + content.source_path
	return "外部 · " + content.source_path


static func _inspect_image(path: String, extension: String, metadata: Dictionary) -> Dictionary:
	if not IMAGE_EXTENSIONS.has(extension):
		return _result(STATUS_UNSUPPORTED, ERR_UNAVAILABLE, path, "图片格式暂不支持", metadata)
	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return _result(STATUS_DAMAGED, ERR_FILE_CORRUPT, path, "图片无法解码", metadata)
	var natural_size: Vector2i = image.get_size()
	if natural_size.x <= 0 or natural_size.y <= 0:
		return _result(STATUS_DAMAGED, ERR_FILE_CORRUPT, path, "图片尺寸无效", metadata)
	metadata["natural_width"] = natural_size.x
	metadata["natural_height"] = natural_size.y
	return _result(STATUS_PLAYABLE, OK, path, "图片可播放", metadata)


static func _inspect_video(path: String, extension: String, metadata: Dictionary) -> Dictionary:
	if not VIDEO_EXTENSIONS.has(extension):
		return _result(
			STATUS_UNSUPPORTED,
			ERR_UNAVAILABLE,
			path,
			"视频格式暂不支持",
			metadata
		)
	if extension == "ogv":
		return _inspect_ogv(path, metadata)
	if NATIVE_VIDEO_EXTENSIONS.has(extension):
		return _inspect_native_video(path, extension, metadata)
	return _result(STATUS_UNSUPPORTED, ERR_UNAVAILABLE, path, "视频格式暂不支持", metadata)


static func _inspect_ogv(path: String, metadata: Dictionary) -> Dictionary:
	var stream: VideoStreamTheora = VideoStreamTheora.new()
	stream.file = path
	var player: VideoStreamPlayer = VideoStreamPlayer.new()
	player.stream = stream
	var texture: Texture2D = player.get_video_texture()
	var natural_size: Vector2i = texture.get_size() if texture != null else Vector2i.ZERO
	var duration_seconds: float = player.get_stream_length()
	player.stream = null
	player.free()
	if natural_size.x <= 0 or natural_size.y <= 0:
		return _result(STATUS_DAMAGED, ERR_FILE_CORRUPT, path, "OGV 没有可解码视频流", metadata)
	metadata["natural_width"] = natural_size.x
	metadata["natural_height"] = natural_size.y
	metadata["duration_seconds"] = maxf(duration_seconds, 0.0)
	return _result(STATUS_PLAYABLE, OK, path, "OGV 可播放", metadata)


static func _inspect_native_video(
		path: String,
		extension: String,
		metadata: Dictionary
) -> Dictionary:
	var stream: VideoStream = NATIVE_VIDEO_BACKEND_SCRIPT.create_stream(path)
	if stream == null:
		return _result(STATUS_DAMAGED, ERR_FILE_CORRUPT, path, "视频无法解码", metadata)
	var player: VideoStreamPlayer = VideoStreamPlayer.new()
	player.stream = stream
	var duration_seconds: float = player.get_stream_length()
	var texture: Texture2D = player.get_video_texture()
	var natural_size: Vector2i = texture.get_size() if texture != null else Vector2i.ZERO
	player.stream = null
	player.free()
	stream = null
	if duration_seconds <= 0.0:
		return _result(STATUS_DAMAGED, ERR_FILE_CORRUPT, path, "视频无法解码", metadata)
	if natural_size.x > 0 and natural_size.y > 0:
		metadata["natural_width"] = natural_size.x
		metadata["natural_height"] = natural_size.y
	metadata["duration_seconds"] = duration_seconds
	return _result(STATUS_PLAYABLE, OK, path, extension.to_upper() + " 可播放", metadata)


static func _result(
		status: StringName,
		error: int,
		resolved_path: String,
		message: String,
		metadata: Dictionary
) -> Dictionary:
	return {
		"status": status,
		"status_text": status_text(status),
		"error": error,
		"resolved_path": resolved_path,
		"message": message,
		"metadata": metadata.duplicate(true),
	}
